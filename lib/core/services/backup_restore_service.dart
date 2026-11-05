import 'dart:convert';
import 'dart:io';
import 'package:archive/archive.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:sqflite/sqflite.dart';
import '../constants/app_constants.dart';
import '../database/app_database.dart';
import '../database/tables.dart';

class BackupManifest {
  final String appVersion;
  final int schemaVersion;
  final int backupTimestampEpoch;
  final Map<String, int> tableCounts;

  BackupManifest({
    required this.appVersion,
    required this.schemaVersion,
    required this.backupTimestampEpoch,
    required this.tableCounts,
  });

  Map<String, dynamic> toMap() => {
    'app_version': appVersion,
    'schema_version': schemaVersion,
    'backup_timestamp_epoch': backupTimestampEpoch,
    'table_counts': tableCounts,
  };

  factory BackupManifest.fromMap(Map<String, dynamic> map) {
    return BackupManifest(
      appVersion: map['app_version'] as String,
      schemaVersion: map['schema_version'] as int,
      backupTimestampEpoch: map['backup_timestamp_epoch'] as int,
      tableCounts: Map<String, int>.from(map['table_counts'] as Map),
    );
  }
}

class BackupRestoreService {
  final AppDatabase _dbProvider = AppDatabase.instance;

  /// Creates a complete standalone backup ZIP containing JSON tables + manifest + attachments
  Future<String> createBackupZip() async {
    final db = await _dbProvider.database;
    final now = DateTime.now();
    final timestampStr = '${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}_'
        '${now.hour.toString().padLeft(2, '0')}${now.minute.toString().padLeft(2, '0')}${now.second.toString().padLeft(2, '0')}';

    final archive = Archive();
    final Map<String, dynamic> exportData = {};
    final Map<String, int> tableCounts = {};

    final tablesToExport = [
      DatabaseTables.properties,
      DatabaseTables.rooms,
      DatabaseTables.tenants,
      DatabaseTables.tenancies,
      DatabaseTables.meters,
      DatabaseTables.meterReadings,
      DatabaseTables.electricityBills,
      DatabaseTables.electricityAllocations,
      DatabaseTables.monthlyBills,
      DatabaseTables.billLineItems,
      DatabaseTables.payments,
      DatabaseTables.paymentAllocations,
      DatabaseTables.expenses,
      DatabaseTables.auditLogs,
      DatabaseTables.appSettings,
    ];

    for (final table in tablesToExport) {
      final rows = await db.query(table);
      exportData[table] = rows;
      tableCounts[table] = rows.length;
    }

    // 1. Add manifest.json
    final manifest = BackupManifest(
      appVersion: AppConstants.appVersion,
      schemaVersion: AppConstants.schemaVersion,
      backupTimestampEpoch: now.millisecondsSinceEpoch,
      tableCounts: tableCounts,
    );

    final manifestBytes = utf8.encode(jsonEncode(manifest.toMap()));
    archive.addFile(ArchiveFile('manifest.json', manifestBytes.length, manifestBytes));

    // 2. Add database.json
    final dbJsonBytes = utf8.encode(jsonEncode(exportData));
    archive.addFile(ArchiveFile('database.json', dbJsonBytes.length, dbJsonBytes));

    // 3. Compress into zip file in cache/temporary directory
    final tempDir = await getTemporaryDirectory();
    final zipFileName = 'RentPulse_Backup_$timestampStr${AppConstants.backupExtension}';
    final zipPath = p.join(tempDir.path, zipFileName);

    final zipEncoder = ZipEncoder();
    final encodedZip = zipEncoder.encode(archive);

    if (encodedZip != null) {
      final file = File(zipPath);
      await file.writeAsBytes(encodedZip);
      return zipPath;
    } else {
      throw Exception('Failed to generate ZIP archive.');
    }
  }

  /// Shares backup zip via Android share sheet (to Drive, WhatsApp, Files, etc.)
  Future<void> shareBackup(String zipPath) async {
    final xFile = XFile(zipPath, mimeType: 'application/zip');
    await Share.shareXFiles([xFile], text: 'RentPulse Rental Room App Backup');
  }

  /// Validates and restores from a backup zip file
  Future<BackupManifest> restoreBackupZip(String zipPath) async {
    final zipFile = File(zipPath);
    if (!await zipFile.exists()) {
      throw Exception('Selected backup file does not exist.');
    }

    final bytes = await zipFile.readAsBytes();
    final archive = ZipDecoder().decodeBytes(bytes);

    // 1. Locate manifest.json
    final manifestFile = archive.findFile('manifest.json');
    if (manifestFile == null) {
      throw Exception('Invalid backup: manifest.json is missing.');
    }

    final manifestJson = jsonDecode(utf8.decode(manifestFile.content as List<int>)) as Map<String, dynamic>;
    final manifest = BackupManifest.fromMap(manifestJson);

    // 2. Locate database.json
    final dbFile = archive.findFile('database.json');
    if (dbFile == null) {
      throw Exception('Invalid backup: database.json is missing.');
    }

    final dbData = jsonDecode(utf8.decode(dbFile.content as List<int>)) as Map<String, dynamic>;

    final db = await _dbProvider.database;

    // 3. Execute atomic restoration
    await db.transaction((txn) async {
      // Clear existing records in reverse dependency order
      final clearOrder = [
        DatabaseTables.paymentAllocations,
        DatabaseTables.payments,
        DatabaseTables.billLineItems,
        DatabaseTables.monthlyBills,
        DatabaseTables.electricityAllocations,
        DatabaseTables.electricityBills,
        DatabaseTables.meterReadings,
        DatabaseTables.meters,
        DatabaseTables.tenancies,
        DatabaseTables.tenants,
        DatabaseTables.expenses,
        DatabaseTables.rooms,
        DatabaseTables.properties,
        DatabaseTables.auditLogs,
        DatabaseTables.appSettings,
      ];

      for (final table in clearOrder) {
        await txn.delete(table);
      }

      // Insert restored data
      final restoreOrder = clearOrder.reversed.toList();
      for (final table in restoreOrder) {
        if (dbData.containsKey(table) && dbData[table] is List) {
          final List rows = dbData[table] as List;
          for (final row in rows) {
            await txn.insert(table, Map<String, dynamic>.from(row as Map));
          }
        }
      }
    });

    return manifest;
  }
}

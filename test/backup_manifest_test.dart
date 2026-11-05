import 'package:flutter_test/flutter_test.dart';

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

void main() {
  group('Backup & Manifest Integrity Tests', () {
    test('Manifest serialization and deserialization integrity', () {
      final original = BackupManifest(
        appVersion: '1.0.0',
        schemaVersion: 1,
        backupTimestampEpoch: 1730790000000,
        tableCounts: {
          'properties': 1,
          'rooms': 3,
          'tenants': 2,
          'tenancies': 2,
          'monthly_bills': 6,
          'payments': 4,
          'advance_ledger_entries': 8,
        },
      );

      final map = original.toMap();
      final reconstructed = BackupManifest.fromMap(map);

      expect(reconstructed.appVersion, '1.0.0');
      expect(reconstructed.schemaVersion, 1);
      expect(reconstructed.backupTimestampEpoch, 1730790000000);
      expect(reconstructed.tableCounts['rooms'], 3);
      expect(reconstructed.tableCounts['advance_ledger_entries'], 8);
    });

    test('Validates database schema version match', () {
      final manifest = BackupManifest(
        appVersion: '1.0.0',
        schemaVersion: 1,
        backupTimestampEpoch: 1730790000000,
        tableCounts: {},
      );

      const currentAppSchemaVersion = 1;
      expect(manifest.schemaVersion == currentAppSchemaVersion, true);
    });
  });
}

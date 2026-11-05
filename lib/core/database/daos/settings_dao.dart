import '../app_database.dart';
import '../tables.dart';

class SettingsDao {
  final AppDatabase _dbProvider = AppDatabase.instance;

  Future<String?> getSetting(String key) async {
    final db = await _dbProvider.database;
    final res = await db.query(
      DatabaseTables.appSettings,
      columns: ['value'],
      where: 'key = ?',
      whereArgs: [key],
    );
    if (res.isNotEmpty) {
      return res.first['value'] as String;
    }
    return null;
  }

  Future<void> setSetting(String key, String value) async {
    final db = await _dbProvider.database;
    await db.insert(
      DatabaseTables.appSettings,
      {'key': key, 'value': value},
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<Map<String, String>> getAllSettings() async {
    final db = await _dbProvider.database;
    final res = await db.query(DatabaseTables.appSettings);
    final map = <String, String>{};
    for (final row in res) {
      map[row['key'] as String] = row['value'] as String;
    }
    return map;
  }
}

class AuditDao {
  final AppDatabase _dbProvider = AppDatabase.instance;

  Future<void> logAction({
    required String action,
    required String targetTable,
    required String targetId,
    String? oldValuesJson,
    String? newValuesJson,
    String? reason,
  }) async {
    final db = await _dbProvider.database;
    final now = DateTime.now().millisecondsSinceEpoch;
    final id = 'audit_$now';

    await db.insert(DatabaseTables.auditLogs, {
      'id': id,
      'action': action,
      'target_table': targetTable,
      'target_id': targetId,
      'old_values_json': oldValuesJson,
      'new_values_json': newValuesJson,
      'reason': reason?.trim(),
      'timestamp_epoch': now,
    });
  }
}

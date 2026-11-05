import 'dart:convert';
import 'dart:io';

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
  int passed = 0;
  int failed = 0;

  void test(String name, void Function() body) {
    try {
      body();
      print('  ✓ $name');
      passed++;
    } catch (e) {
      print('  ✗ $name ($e)');
      failed++;
    }
  }

  void expect(dynamic actual, dynamic expected) {
    if (actual != expected) {
      throw Exception('Expected "$expected", got "$actual"');
    }
  }

  print('\n=== Running Backup & Manifest Integrity Tests ===\n');

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
        'meters': 3,
        'meter_readings': 6,
        'monthly_bills': 4,
        'payments': 3,
      },
    );

    final jsonStr = jsonEncode(original.toMap());
    final decodedMap = jsonDecode(jsonStr) as Map<String, dynamic>;
    final reconstructed = BackupManifest.fromMap(decodedMap);

    expect(reconstructed.appVersion, '1.0.0');
    expect(reconstructed.schemaVersion, 1);
    expect(reconstructed.backupTimestampEpoch, 1730790000000);
    expect(reconstructed.tableCounts['rooms'], 3);
    expect(reconstructed.tableCounts['tenants'], 2);
  });

  test('Rejects invalid manifest when required fields are missing', () {
    final invalidJson = {'invalid_key': '123'};
    bool caught = false;
    try {
      BackupManifest.fromMap(invalidJson);
    } catch (_) {
      caught = true;
    }
    expect(caught, true);
  });

  print('\n=== Manifest Test Summary: $passed Passed, $failed Failed ===\n');
  if (failed > 0) exit(1);
}

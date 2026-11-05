import 'dart:async';
import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';
import '../constants/app_constants.dart';
import 'tables.dart';

class AppDatabase {
  static final AppDatabase instance = AppDatabase._internal();
  static Database? _database;

  AppDatabase._internal();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    final dbPath = await getDatabasesPath();
    final path = p.join(dbPath, AppConstants.databaseName);

    return await openDatabase(
      path,
      version: AppConstants.schemaVersion,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
      onOpen: (db) async {
        // Ensure columns exist on legacy databases without crash
        try {
          await db.execute('ALTER TABLE ${DatabaseTables.rooms} ADD COLUMN electricity_rate_paise INTEGER NOT NULL DEFAULT 1000');
        } catch (_) {}
        try {
          await db.execute('ALTER TABLE ${DatabaseTables.tenancies} ADD COLUMN billing_due_day INTEGER NOT NULL DEFAULT 5');
        } catch (_) {}
      },
      onConfigure: _onConfigure,
    );
  }

  Future<void> _onConfigure(Database db) async {
    await db.execute('PRAGMA foreign_keys = ON');
  }

  Future<void> _onCreate(Database db, int version) async {
    final batch = db.batch();

    // Create all 16 tables
    for (final query in DatabaseTables.createTableQueries) {
      batch.execute(query);
    }

    // Create all performance indexes
    for (final query in DatabaseTables.createIndexQueries) {
      batch.execute(query);
    }

    await batch.commit(noResult: true);

    // Seed default property and basic settings (no dummy rooms or tenants)
    await _seedInitialData(db);
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      try {
        await db.execute('ALTER TABLE ${DatabaseTables.rooms} ADD COLUMN electricity_rate_paise INTEGER NOT NULL DEFAULT 1000');
      } catch (_) {}
      try {
        await db.execute('ALTER TABLE ${DatabaseTables.tenancies} ADD COLUMN billing_due_day INTEGER NOT NULL DEFAULT 5');
      } catch (_) {}
    }
  }

  Future<void> _seedInitialData(Database db) async {
    final now = DateTime.now().millisecondsSinceEpoch;

    // 1. Seed Property Master
    await db.insert(DatabaseTables.properties, {
      'id': AppConstants.defaultPropertyId,
      'name': AppConstants.defaultPropertyName,
      'address': AppConstants.defaultPropertyAddress,
      'electricity_billing_type': 'FIXED_PER_UNIT',
      'default_electricity_rate_paise': AppConstants.defaultRatePerUnitPaise,
      'created_at_epoch': now,
    });

    // 2. Default App Settings
    await db.insert(DatabaseTables.appSettings, {
      'key': 'owner_name',
      'value': 'Homeowner',
    });
    await db.insert(DatabaseTables.appSettings, {
      'key': 'owner_phone',
      'value': '',
    });
    await db.insert(DatabaseTables.appSettings, {
      'key': 'owner_upi_id',
      'value': '',
    });
    await db.insert(DatabaseTables.appSettings, {
      'key': 'default_electricity_rate',
      'value': '10',
    });
  }

  Future<void> close() async {
    if (_database != null) {
      await _database!.close();
      _database = null;
    }
  }
}

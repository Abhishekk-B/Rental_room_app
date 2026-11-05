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

    // Seed initial property, 3 rooms, sub-meters, and advance ledgers
    await _seedInitialData(db);
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    // Schema migration safety
  }

  Future<void> _seedInitialData(Database db) async {
    final now = DateTime.now().millisecondsSinceEpoch;

    // 1. Seed Property
    await db.insert(DatabaseTables.properties, {
      'id': AppConstants.defaultPropertyId,
      'name': AppConstants.defaultPropertyName,
      'address': AppConstants.defaultPropertyAddress,
      'electricity_billing_type': 'PROPORTIONAL',
      'default_electricity_rate_paise': AppConstants.defaultRatePerUnitPaise,
      'created_at_epoch': now,
    });

    // 2. Seed 3 Rental Rooms
    final rooms = [
      {
        'id': 'room_01',
        'property_id': AppConstants.defaultPropertyId,
        'room_number': 'Room 101',
        'description': 'Ground floor spacious room with attached bath and private entrance.',
        'default_rent_paise': 850000, // ₹8,500
        'is_active': 1,
        'notes': 'Sub-meter installed beside main doorway.',
        'created_at_epoch': now,
      },
      {
        'id': 'room_02',
        'property_id': AppConstants.defaultPropertyId,
        'room_number': 'Room 102',
        'description': 'First floor front room with balcony and cross-ventilation.',
        'default_rent_paise': 750000, // ₹7,500
        'is_active': 1,
        'notes': 'Sub-meter in 1st floor corridor.',
        'created_at_epoch': now,
      },
      {
        'id': 'room_03',
        'property_id': AppConstants.defaultPropertyId,
        'room_number': 'Room 103',
        'description': 'First floor terrace-facing room with private bathroom.',
        'default_rent_paise': 800000, // ₹8,000
        'is_active': 1,
        'notes': 'Sub-meter in 1st floor electrical distribution box.',
        'created_at_epoch': now,
      },
    ];

    for (final room in rooms) {
      await db.insert(DatabaseTables.rooms, room);
    }

    // 3. Seed Sub-Meters for each room
    final meters = [
      {
        'id': 'meter_01',
        'room_id': 'room_01',
        'meter_number': 'MTR-101',
        'initial_reading_centiunits': 100000, // 1000.00 units
        'is_active': 1,
        'created_at_epoch': now,
      },
      {
        'id': 'meter_02',
        'room_id': 'room_02',
        'meter_number': 'MTR-102',
        'initial_reading_centiunits': 100000, // 1000.00 units
        'is_active': 1,
        'created_at_epoch': now,
      },
      {
        'id': 'meter_03',
        'room_id': 'room_03',
        'meter_number': 'MTR-103',
        'initial_reading_centiunits': 100000, // 1000.00 units
        'is_active': 1,
        'created_at_epoch': now,
      },
    ];

    for (final meter in meters) {
      await db.insert(DatabaseTables.meters, meter);
    }

    // 4. Seed 2 Sample Tenants & Active Tenancies
    final t1Id = 'tenant_01';
    final t2Id = 'tenant_02';

    await db.insert(DatabaseTables.tenants, {
      'id': t1Id,
      'full_name': 'Rahul Sharma',
      'phone_number': '+91 9876543210',
      'email': 'rahul.sharma@example.com',
      'permanent_address': 'Flat 204, Green Heights, Lucknow, UP',
      'emergency_contact': '+91 9123456789 (Father)',
      'id_proof_type': 'Aadhaar Card',
      'id_proof_number': 'XXXX-XXXX-4589',
      'notes': 'Works in IT, rent due on 5th of every month.',
      'is_active': 1,
      'created_at_epoch': now,
    });

    await db.insert(DatabaseTables.tenants, {
      'id': t2Id,
      'full_name': 'Priya Verma',
      'phone_number': '+91 9811223344',
      'email': 'priya.verma@example.com',
      'permanent_address': 'Sector 14, Chandigarh',
      'emergency_contact': '+91 9811223399 (Brother)',
      'id_proof_type': 'PAN Card',
      'id_proof_number': 'ABCDE1234F',
      'notes': 'Bank Officer, pays via UPI.',
      'is_active': 1,
      'created_at_epoch': now,
    });

    final tenancy1Id = 'tenancy_01';
    final tenancy2Id = 'tenancy_02';

    // Active Tenancy for Room 101
    await db.insert(DatabaseTables.tenancies, {
      'id': tenancy1Id,
      'tenant_id': t1Id,
      'room_id': 'room_01',
      'move_in_date_epoch': now - (90 * 86400000), // 3 months ago
      'move_out_date_epoch': null,
      'agreed_rent_paise': 850000,
      'security_deposit_paise': 1700000, // ₹17,000
      'status': 'ACTIVE',
      'created_at_epoch': now,
    });

    // Active Tenancy for Room 102
    await db.insert(DatabaseTables.tenancies, {
      'id': tenancy2Id,
      'tenant_id': t2Id,
      'room_id': 'room_02',
      'move_in_date_epoch': now - (60 * 86400000), // 2 months ago
      'move_out_date_epoch': null,
      'agreed_rent_paise': 750000,
      'security_deposit_paise': 1500000, // ₹15,000
      'status': 'ACTIVE',
      'created_at_epoch': now,
    });

    // 5. Seed Independent Advance & Deposit Ledgers (Mandatory Feature)
    // Tenant 1 Advance Accounts
    final sampleLedger = [
      // Tenant 1: Security Deposit
      {
        'id': 'adv_sec_01',
        'tenancy_id': tenancy1Id,
        'account_type': 'SECURITY_DEPOSIT',
        'transaction_type': 'CREDIT_RECEIVED',
        'amount_paise': 1700000, // ₹17,000
        'monthly_bill_id': null,
        'payment_id': null,
        'description': 'Security deposit received at move-in',
        'entry_date_epoch': now - (90 * 86400000),
        'created_at_epoch': now,
      },
      // Tenant 1: Rent Advance
      {
        'id': 'adv_rent_01',
        'tenancy_id': tenancy1Id,
        'account_type': 'RENT_ADVANCE',
        'transaction_type': 'CREDIT_RECEIVED',
        'amount_paise': 1000000, // ₹10,000
        'monthly_bill_id': null,
        'payment_id': null,
        'description': 'Advance rent payment received (strictly for room rent)',
        'entry_date_epoch': now - (30 * 86400000),
        'created_at_epoch': now,
      },
      // Tenant 1: Electricity Advance
      {
        'id': 'adv_elec_01',
        'tenancy_id': tenancy1Id,
        'account_type': 'ELECTRICITY_ADVANCE',
        'transaction_type': 'CREDIT_RECEIVED',
        'amount_paise': 200000, // ₹2,000
        'monthly_bill_id': null,
        'payment_id': null,
        'description': 'Electricity deposit / advance buffer received',
        'entry_date_epoch': now - (30 * 86400000),
        'created_at_epoch': now,
      },

      // Tenant 2: Security Deposit
      {
        'id': 'adv_sec_02',
        'tenancy_id': tenancy2Id,
        'account_type': 'SECURITY_DEPOSIT',
        'transaction_type': 'CREDIT_RECEIVED',
        'amount_paise': 1500000, // ₹15,000
        'monthly_bill_id': null,
        'payment_id': null,
        'description': 'Security deposit received at move-in',
        'entry_date_epoch': now - (60 * 86400000),
        'created_at_epoch': now,
      },
      // Tenant 2: Rent Advance
      {
        'id': 'adv_rent_02',
        'tenancy_id': tenancy2Id,
        'account_type': 'RENT_ADVANCE',
        'transaction_type': 'CREDIT_RECEIVED',
        'amount_paise': 750000, // ₹7,500
        'monthly_bill_id': null,
        'payment_id': null,
        'description': 'One month advance rent received',
        'entry_date_epoch': now - (15 * 86400000),
        'created_at_epoch': now,
      },
      // Tenant 2: Electricity Advance
      {
        'id': 'adv_elec_02',
        'tenancy_id': tenancy2Id,
        'account_type': 'ELECTRICITY_ADVANCE',
        'transaction_type': 'CREDIT_RECEIVED',
        'amount_paise': 150000, // ₹1,500
        'monthly_bill_id': null,
        'payment_id': null,
        'description': 'Advance electricity credit buffer',
        'entry_date_epoch': now - (15 * 86400000),
        'created_at_epoch': now,
      },
    ];

    for (final entry in sampleLedger) {
      await db.insert(DatabaseTables.advanceLedgerEntries, entry);
    }

    // 6. Seed App Settings
    final settings = {
      'owner_name': 'Homeowner',
      'owner_phone': '+91 9876500000',
      'owner_upi_id': 'owner@upi',
      'pin_lock_enabled': '0',
      'pin_code_hash': '',
      'currency_code': 'INR',
      'currency_symbol': '₹',
      'default_due_day': '7',
    };

    for (final entry in settings.entries) {
      await db.insert(DatabaseTables.appSettings, {
        'key': entry.key,
        'value': entry.value,
      });
    }
  }

  Future<void> close() async {
    final db = _database;
    if (db != null) {
      await db.close();
      _database = null;
    }
  }
}

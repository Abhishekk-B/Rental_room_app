import 'package:sqflite/sqflite.dart';
import '../app_database.dart';
import '../tables.dart';

class RoomWithDetails {
  final String id;
  final String propertyId;
  final String roomNumber;
  final String? description;
  final int defaultRentPaise;
  final int electricityRatePaise;
  final bool isActive;
  final String? notes;
  final bool isOccupied;
  final String? activeTenantName;
  final String? activeTenantPhone;
  final String? activeTenancyId;
  final int? agreedRentPaise;
  final int? billingDueDay;
  final String? meterId;
  final String? meterNumber;
  final int? latestReadingCentiunits;

  RoomWithDetails({
    required this.id,
    required this.propertyId,
    required this.roomNumber,
    this.description,
    required this.defaultRentPaise,
    this.electricityRatePaise = 1000,
    required this.isActive,
    this.notes,
    required this.isOccupied,
    this.activeTenantName,
    this.activeTenantPhone,
    this.activeTenancyId,
    this.agreedRentPaise,
    this.billingDueDay,
    this.meterId,
    this.meterNumber,
    this.latestReadingCentiunits,
  });

  factory RoomWithDetails.fromMap(Map<String, dynamic> map) {
    return RoomWithDetails(
      id: map['id'] as String,
      propertyId: map['property_id'] as String,
      roomNumber: map['room_number'] as String,
      description: map['description'] as String?,
      defaultRentPaise: (map['default_rent_paise'] as int?) ?? 0,
      electricityRatePaise: (map['electricity_rate_paise'] as int?) ?? 1000,
      isActive: ((map['is_active'] as int?) ?? 1) == 1,
      notes: map['notes'] as String?,
      isOccupied: map['active_tenancy_id'] != null,
      activeTenantName: map['tenant_name'] as String?,
      activeTenantPhone: map['tenant_phone'] as String?,
      activeTenancyId: map['active_tenancy_id'] as String?,
      agreedRentPaise: map['agreed_rent_paise'] as int?,
      billingDueDay: map['billing_due_day'] as int?,
      meterId: map['meter_id'] as String?,
      meterNumber: map['meter_number'] as String?,
      latestReadingCentiunits: map['latest_reading'] as int?,
    );
  }
}

class RoomDao {
  final AppDatabase _dbProvider = AppDatabase.instance;

  Future<List<RoomWithDetails>> getAllRoomsWithDetails() async {
    final db = await _dbProvider.database;
    final query = '''
      SELECT 
        r.id,
        r.property_id,
        r.room_number,
        r.description,
        r.default_rent_paise,
        COALESCE(r.electricity_rate_paise, 1000) AS electricity_rate_paise,
        r.is_active,
        r.notes,
        t.id AS active_tenancy_id,
        t.agreed_rent_paise,
        t.billing_due_day,
        ten.full_name AS tenant_name,
        ten.phone_number AS tenant_phone,
        m.id AS meter_id,
        m.meter_number,
        COALESCE(
          (
            SELECT mr.current_reading_centiunits 
            FROM ${DatabaseTables.meterReadings} mr 
            WHERE mr.meter_id = m.id 
            ORDER BY mr.billing_year DESC, mr.billing_month DESC, mr.reading_date_epoch DESC 
            LIMIT 1
          ),
          m.initial_reading_centiunits,
          0
        ) AS latest_reading
      FROM ${DatabaseTables.rooms} r
      LEFT JOIN ${DatabaseTables.tenancies} t 
        ON r.id = t.room_id AND t.status = 'ACTIVE'
      LEFT JOIN ${DatabaseTables.tenants} ten 
        ON t.tenant_id = ten.id
      LEFT JOIN ${DatabaseTables.meters} m 
        ON r.id = m.room_id
      ORDER BY r.room_number ASC;
    ''';

    final result = await db.rawQuery(query);
    return result.map((row) => RoomWithDetails.fromMap(row)).toList();
  }

  Future<RoomWithDetails?> getRoomById(String roomId) async {
    final db = await _dbProvider.database;
    final query = '''
      SELECT 
        r.id,
        r.property_id,
        r.room_number,
        r.description,
        r.default_rent_paise,
        COALESCE(r.electricity_rate_paise, 1000) AS electricity_rate_paise,
        r.is_active,
        r.notes,
        t.id AS active_tenancy_id,
        t.agreed_rent_paise,
        t.billing_due_day,
        ten.full_name AS tenant_name,
        ten.phone_number AS tenant_phone,
        m.id AS meter_id,
        m.meter_number,
        COALESCE(
          (
            SELECT mr.current_reading_centiunits 
            FROM ${DatabaseTables.meterReadings} mr 
            WHERE mr.meter_id = m.id 
            ORDER BY mr.billing_year DESC, mr.billing_month DESC, mr.reading_date_epoch DESC 
            LIMIT 1
          ),
          m.initial_reading_centiunits,
          0
        ) AS latest_reading
      FROM ${DatabaseTables.rooms} r
      LEFT JOIN ${DatabaseTables.tenancies} t 
        ON r.id = t.room_id AND t.status = 'ACTIVE'
      LEFT JOIN ${DatabaseTables.tenants} ten 
        ON t.tenant_id = ten.id
      LEFT JOIN ${DatabaseTables.meters} m 
        ON r.id = m.room_id
      WHERE r.id = ?
      LIMIT 1;
    ''';

    final result = await db.rawQuery(query, [roomId]);
    if (result.isEmpty) return null;
    return RoomWithDetails.fromMap(result.first);
  }

  Future<void> createRoom({
    required String id,
    required String propertyId,
    required String roomNumber,
    String? description,
    required int defaultRentPaise,
    int electricityRatePaise = 1000,
    String? notes,
    String? meterNumber,
    int initialMeterReadingCentiunits = 0,
  }) async {
    final db = await _dbProvider.database;
    final now = DateTime.now().millisecondsSinceEpoch;

    await db.transaction((txn) async {
      await txn.insert(DatabaseTables.rooms, {
        'id': id,
        'property_id': propertyId,
        'room_number': roomNumber.trim(),
        'description': description?.trim(),
        'default_rent_paise': defaultRentPaise,
        'electricity_rate_paise': electricityRatePaise,
        'is_active': 1,
        'notes': notes?.trim(),
        'created_at_epoch': now,
      });

      if (meterNumber != null && meterNumber.trim().isNotEmpty) {
        final meterId = 'meter_${id.replaceAll('room_', '')}';
        await txn.insert(DatabaseTables.meters, {
          'id': meterId,
          'room_id': id,
          'meter_number': meterNumber.trim(),
          'initial_reading_centiunits': initialMeterReadingCentiunits,
          'is_active': 1,
          'created_at_epoch': now,
        });
      }
    });
  }

  Future<void> updateRoom({
    required String id,
    required String roomNumber,
    String? description,
    required int defaultRentPaise,
    int electricityRatePaise = 1000,
    required bool isActive,
    String? notes,
    String? meterNumber,
    int? meterReadingCentiunits,
  }) async {
    final db = await _dbProvider.database;
    final now = DateTime.now().millisecondsSinceEpoch;

    await db.transaction((txn) async {
      await txn.update(
        DatabaseTables.rooms,
        {
          'room_number': roomNumber.trim(),
          'description': description?.trim(),
          'default_rent_paise': defaultRentPaise,
          'electricity_rate_paise': electricityRatePaise,
          'is_active': isActive ? 1 : 0,
          'notes': notes?.trim(),
        },
        where: 'id = ?',
        whereArgs: [id],
      );

      final existingMeter = await txn.query(
        DatabaseTables.meters,
        where: 'room_id = ?',
        whereArgs: [id],
      );

      String? activeMeterId;
      if (meterNumber != null && meterNumber.trim().isNotEmpty) {
        if (existingMeter.isEmpty) {
          activeMeterId = 'meter_${id.replaceAll('room_', '')}';
          await txn.insert(DatabaseTables.meters, {
            'id': activeMeterId,
            'room_id': id,
            'meter_number': meterNumber.trim(),
            'initial_reading_centiunits': meterReadingCentiunits ?? 0,
            'is_active': 1,
            'created_at_epoch': now,
          });
        } else {
          activeMeterId = existingMeter.first['id'] as String;
          await txn.update(
            DatabaseTables.meters,
            {'meter_number': meterNumber.trim()},
            where: 'room_id = ?',
            whereArgs: [id],
          );
        }
      } else if (existingMeter.isNotEmpty) {
        activeMeterId = existingMeter.first['id'] as String;
      }

      if (meterReadingCentiunits != null && activeMeterId != null) {
        final latestReadingRows = await txn.query(
          DatabaseTables.meterReadings,
          where: 'meter_id = ?',
          whereArgs: [activeMeterId],
          orderBy: 'billing_year DESC, billing_month DESC, reading_date_epoch DESC',
          limit: 1,
        );
        if (latestReadingRows.isNotEmpty) {
          final lrId = latestReadingRows.first['id'] as String;
          final prev = latestReadingRows.first['previous_reading_centiunits'] as int;
          final newUnits = meterReadingCentiunits >= prev ? (meterReadingCentiunits - prev) : 0;
          await txn.update(
            DatabaseTables.meterReadings,
            {
              'current_reading_centiunits': meterReadingCentiunits,
              'units_consumed_centiunits': newUnits,
            },
            where: 'id = ?',
            whereArgs: [lrId],
          );
        } else {
          await txn.update(
            DatabaseTables.meters,
            {'initial_reading_centiunits': meterReadingCentiunits},
            where: 'id = ?',
            whereArgs: [activeMeterId],
          );
        }
      }
    });
  }

  Future<void> deleteRoom(String roomId) async {
    final db = await _dbProvider.database;
    await db.transaction((txn) async {
      // 1. Delete associated tenancies and all their child records
      final tenancies = await txn.query(
        DatabaseTables.tenancies,
        where: 'room_id = ?',
        whereArgs: [roomId],
      );

      for (final t in tenancies) {
        final tenancyId = t['id'] as String;
        await txn.delete(DatabaseTables.advanceLedgerEntries, where: 'tenancy_id = ?', whereArgs: [tenancyId]);

        final payments = await txn.query(DatabaseTables.payments, where: 'tenancy_id = ?', whereArgs: [tenancyId]);
        for (final p in payments) {
          await txn.delete(DatabaseTables.paymentAllocations, where: 'payment_id = ?', whereArgs: [p['id']]);
        }
        await txn.delete(DatabaseTables.payments, where: 'tenancy_id = ?', whereArgs: [tenancyId]);

        final bills = await txn.query(DatabaseTables.monthlyBills, where: 'tenancy_id = ?', whereArgs: [tenancyId]);
        for (final b in bills) {
          await txn.delete(DatabaseTables.billLineItems, where: 'monthly_bill_id = ?', whereArgs: [b['id']]);
        }
        await txn.delete(DatabaseTables.monthlyBills, where: 'tenancy_id = ?', whereArgs: [tenancyId]);
        await txn.delete(DatabaseTables.tenancies, where: 'id = ?', whereArgs: [tenancyId]);
      }

      // 2. Delete meter readings and meters
      final meters = await txn.query(DatabaseTables.meters, where: 'room_id = ?', whereArgs: [roomId]);
      for (final m in meters) {
        await txn.delete(DatabaseTables.meterReadings, where: 'meter_id = ?', whereArgs: [m['id']]);
      }
      await txn.delete(DatabaseTables.meters, where: 'room_id = ?', whereArgs: [roomId]);

      // 3. Delete room
      await txn.delete(DatabaseTables.rooms, where: 'id = ?', whereArgs: [roomId]);
    });
  }
}

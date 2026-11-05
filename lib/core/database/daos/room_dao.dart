import 'package:sqflite/sqflite.dart';
import '../app_database.dart';
import '../tables.dart';

class RoomWithDetails {
  final String id;
  final String propertyId;
  final String roomNumber;
  final String? description;
  final int defaultRentPaise;
  final bool isActive;
  final String? notes;
  final bool isOccupied;
  final String? activeTenantName;
  final String? activeTenantPhone;
  final String? activeTenancyId;
  final int? agreedRentPaise;
  final String? meterId;
  final String? meterNumber;
  final int? latestReadingCentiunits;

  RoomWithDetails({
    required this.id,
    required this.propertyId,
    required this.roomNumber,
    this.description,
    required this.defaultRentPaise,
    required this.isActive,
    this.notes,
    required this.isOccupied,
    this.activeTenantName,
    this.activeTenantPhone,
    this.activeTenancyId,
    this.agreedRentPaise,
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
      defaultRentPaise: map['default_rent_paise'] as int,
      isActive: (map['is_active'] as int) == 1,
      notes: map['notes'] as String?,
      isOccupied: map['active_tenancy_id'] != null,
      activeTenantName: map['tenant_name'] as String?,
      activeTenantPhone: map['tenant_phone'] as String?,
      activeTenancyId: map['active_tenancy_id'] as String?,
      agreedRentPaise: map['agreed_rent_paise'] as int?,
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
        r.is_active,
        r.notes,
        t.id AS active_tenancy_id,
        t.agreed_rent_paise,
        ten.full_name AS tenant_name,
        ten.phone_number AS tenant_phone,
        m.id AS meter_id,
        m.meter_number,
        (
          SELECT mr.current_reading_centiunits 
          FROM ${DatabaseTables.meterReadings} mr 
          WHERE mr.meter_id = m.id 
          ORDER BY mr.billing_year DESC, mr.billing_month DESC, mr.reading_date_epoch DESC 
          LIMIT 1
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
        r.is_active,
        r.notes,
        t.id AS active_tenancy_id,
        t.agreed_rent_paise,
        ten.full_name AS tenant_name,
        ten.phone_number AS tenant_phone,
        m.id AS meter_id,
        m.meter_number,
        (
          SELECT mr.current_reading_centiunits 
          FROM ${DatabaseTables.meterReadings} mr 
          WHERE mr.meter_id = m.id 
          ORDER BY mr.billing_year DESC, mr.billing_month DESC, mr.reading_date_epoch DESC 
          LIMIT 1
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
    required bool isActive,
    String? notes,
  }) async {
    final db = await _dbProvider.database;
    await db.update(
      DatabaseTables.rooms,
      {
        'room_number': roomNumber.trim(),
        'description': description?.trim(),
        'default_rent_paise': defaultRentPaise,
        'is_active': isActive ? 1 : 0,
        'notes': notes?.trim(),
      },
      where: 'id = ?',
      whereArgs: [id],
    );
  }
}

import 'package:sqflite/sqflite.dart';
import '../app_database.dart';
import '../tables.dart';
import 'package:rental_room_app/features/electricity/domain/electricity_calculator.dart';

class MeterReadingRecord {
  final String id;
  final String meterId;
  final String roomNumber;
  final int billingMonth;
  final int billingYear;
  final int readingDateEpoch;
  final int previousReadingCentiunits;
  final int currentReadingCentiunits;
  final int unitsConsumedCentiunits;
  final bool isReset;
  final String? photoPath;
  final String? notes;

  MeterReadingRecord({
    required this.id,
    required this.meterId,
    required this.roomNumber,
    required this.billingMonth,
    required this.billingYear,
    required this.readingDateEpoch,
    required this.previousReadingCentiunits,
    required this.currentReadingCentiunits,
    required this.unitsConsumedCentiunits,
    required this.isReset,
    this.photoPath,
    this.notes,
  });

  factory MeterReadingRecord.fromMap(Map<String, dynamic> map) {
    return MeterReadingRecord(
      id: map['id'] as String,
      meterId: map['meter_id'] as String,
      roomNumber: (map['room_number'] as String?) ?? 'Sub-meter',
      billingMonth: map['billing_month'] as int,
      billingYear: map['billing_year'] as int,
      readingDateEpoch: map['reading_date_epoch'] as int,
      previousReadingCentiunits: map['previous_reading_centiunits'] as int,
      currentReadingCentiunits: map['current_reading_centiunits'] as int,
      unitsConsumedCentiunits: map['units_consumed_centiunits'] as int,
      isReset: (map['is_reset'] as int) == 1,
      photoPath: map['photo_path'] as String?,
      notes: map['notes'] as String?,
    );
  }
}

class MasterBillRecord {
  final String id;
  final String propertyId;
  final int billingMonth;
  final int billingYear;
  final int totalAmountPaise;
  final int fixedChargesPaise;
  final int commonAreaChargesPaise;
  final String commonChargeAllocationRule;
  final bool isAllocated;
  final int billDateEpoch;
  final List<RoomAllocationResult> allocations;

  MasterBillRecord({
    required this.id,
    required this.propertyId,
    required this.billingMonth,
    required this.billingYear,
    required this.totalAmountPaise,
    required this.fixedChargesPaise,
    required this.commonAreaChargesPaise,
    required this.commonChargeAllocationRule,
    required this.isAllocated,
    required this.billDateEpoch,
    this.allocations = const [],
  });
}

class ElectricityDao {
  final AppDatabase _dbProvider = AppDatabase.instance;

  /// Retrieves the previous reading for a given meter
  /// Returns initial_reading_centiunits if no previous reading exists.
  Future<int> getPreviousReadingCentiunits(String meterId) async {
    final db = await _dbProvider.database;

    final result = await db.rawQuery(
      '''
      SELECT current_reading_centiunits 
      FROM ${DatabaseTables.meterReadings} 
      WHERE meter_id = ? 
      ORDER BY billing_year DESC, billing_month DESC, reading_date_epoch DESC 
      LIMIT 1
      ''',
      [meterId],
    );

    if (result.isNotEmpty) {
      return result.first['current_reading_centiunits'] as int;
    }

    // Fallback to meter's initial reading
    final meter = await db.rawQuery(
      'SELECT initial_reading_centiunits FROM ${DatabaseTables.meters} WHERE id = ? LIMIT 1',
      [meterId],
    );
    if (meter.isNotEmpty) {
      return meter.first['initial_reading_centiunits'] as int;
    }

    return 0;
  }

  /// Records a meter reading with validation and duplicate prevention
  Future<void> recordMeterReading({
    required String id,
    required String meterId,
    required int billingMonth,
    required int billingYear,
    required int readingDateEpoch,
    required int previousReadingCentiunits,
    required int currentReadingCentiunits,
    bool isReset = false,
    String? photoPath,
    String? notes,
  }) async {
    final db = await _dbProvider.database;

    // Validate units calculation
    final units = ElectricityCalculator.calculateUnitsCentiunits(
      previousReadingCentiunits: previousReadingCentiunits,
      currentReadingCentiunits: currentReadingCentiunits,
      isReset: isReset,
    );

    final now = DateTime.now().millisecondsSinceEpoch;

    // Use ConflictAlgorithm.replace to allow updating an existing period's reading while preserving audit
    await db.insert(
      DatabaseTables.meterReadings,
      {
        'id': id,
        'meter_id': meterId,
        'billing_month': billingMonth,
        'billing_year': billingYear,
        'reading_date_epoch': readingDateEpoch,
        'previous_reading_centiunits': previousReadingCentiunits,
        'current_reading_centiunits': currentReadingCentiunits,
        'units_consumed_centiunits': units,
        'is_reset': isReset ? 1 : 0,
        'photo_path': photoPath,
        'notes': notes?.trim(),
        'created_at_epoch': now,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  /// Retrieves all meter readings for a specific month and year
  Future<List<MeterReadingRecord>> getReadingsForPeriod(int month, int year) async {
    final db = await _dbProvider.database;
    final query = '''
      SELECT 
        mr.*,
        r.room_number
      FROM ${DatabaseTables.meterReadings} mr
      JOIN ${DatabaseTables.meters} m ON mr.meter_id = m.id
      JOIN ${DatabaseTables.rooms} r ON m.room_id = r.id
      WHERE mr.billing_month = ? AND mr.billing_year = ?
      ORDER BY r.room_number ASC;
    ''';

    final result = await db.rawQuery(query, [month, year]);
    return result.map((row) => MeterReadingRecord.fromMap(row)).toList();
  }

  /// Commits master electricity bill and creates room allocations transactionally
  Future<void> saveMasterBillAndAllocations({
    required String billId,
    required String propertyId,
    required int billingMonth,
    required int billingYear,
    required int totalAmountPaise,
    int fixedChargesPaise = 0,
    int commonAreaChargesPaise = 0,
    String commonChargeAllocationRule = 'EQUAL',
    required List<RoomAllocationResult> allocations,
  }) async {
    final db = await _dbProvider.database;
    final now = DateTime.now().millisecondsSinceEpoch;

    await db.transaction((txn) async {
      // 1. Insert master bill
      await txn.insert(
        DatabaseTables.electricityBills,
        {
          'id': billId,
          'property_id': propertyId,
          'billing_month': billingMonth,
          'billing_year': billingYear,
          'total_amount_paise': totalAmountPaise,
          'fixed_charges_paise': fixedChargesPaise,
          'common_area_charges_paise': commonAreaChargesPaise,
          'common_charge_allocation_rule': commonChargeAllocationRule,
          'is_allocated': 1,
          'bill_date_epoch': now,
          'created_at_epoch': now,
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );

      // 2. Remove old allocations for this bill if re-calculating
      await txn.delete(
        DatabaseTables.electricityAllocations,
        where: 'electricity_bill_id = ?',
        whereArgs: [billId],
      );

      // 3. Insert allocations
      for (final alloc in allocations) {
        final allocId = 'alloc_${billId}_${alloc.roomId}';
        await txn.insert(DatabaseTables.electricityAllocations, {
          'id': allocId,
          'electricity_bill_id': billId,
          'room_id': alloc.roomId,
          'units_consumed_centiunits': alloc.unitsConsumedCentiunits,
          'allocated_amount_paise': alloc.totalChargePaise,
          'created_at_epoch': now,
        });
      }
    });
  }

  /// Retrieves saved allocation for a specific room and billing period
  Future<int?> getAllocatedElectricityForRoom({
    required String roomId,
    required int month,
    required int year,
  }) async {
    final db = await _dbProvider.database;
    final query = '''
      SELECT ea.allocated_amount_paise 
      FROM ${DatabaseTables.electricityAllocations} ea
      JOIN ${DatabaseTables.electricityBills} eb ON ea.electricity_bill_id = eb.id
      WHERE ea.room_id = ? AND eb.billing_month = ? AND eb.billing_year = ?
      LIMIT 1;
    ''';
    final result = await db.rawQuery(query, [roomId, month, year]);
    if (result.isNotEmpty) {
      return result.first['allocated_amount_paise'] as int;
    }
    return null;
  }
}

import 'package:sqflite/sqflite.dart';
import '../app_database.dart';
import '../tables.dart';
import 'package:rental_room_app/features/billing/domain/billing_engine.dart';

class MonthlyBillRecord {
  final String id;
  final String tenancyId;
  final String billNumber;
  final String tenantName;
  final String tenantPhone;
  final String roomId;
  final String roomNumber;
  final int billingMonth;
  final int billingYear;
  final int billDateEpoch;
  final int dueDateEpoch;
  final int rentAmountPaise;
  final int rentAdvanceAppliedPaise;
  final int outstandingRentPaise;
  final int electricityUnitsCentiunits;
  final int electricityAmountPaise;
  final int electricityAdvanceAppliedPaise;
  final int outstandingElectricityPaise;
  final int additionalChargesPaise;
  final int previousBalancePaise;
  final int totalDuePaise;
  final int netAmountDuePaise;
  final int amountPaidPaise;
  final int remainingBalancePaise;
  final String status;
  final String? notes;
  final List<LineItemInput> lineItems;

  MonthlyBillRecord({
    required this.id,
    required this.tenancyId,
    required this.billNumber,
    required this.tenantName,
    required this.tenantPhone,
    required this.roomId,
    required this.roomNumber,
    required this.billingMonth,
    required this.billingYear,
    required this.billDateEpoch,
    required this.dueDateEpoch,
    required this.rentAmountPaise,
    this.rentAdvanceAppliedPaise = 0,
    required this.outstandingRentPaise,
    required this.electricityUnitsCentiunits,
    required this.electricityAmountPaise,
    this.electricityAdvanceAppliedPaise = 0,
    required this.outstandingElectricityPaise,
    required this.additionalChargesPaise,
    required this.previousBalancePaise,
    required this.totalDuePaise,
    required this.netAmountDuePaise,
    required this.amountPaidPaise,
    required this.remainingBalancePaise,
    required this.status,
    this.notes,
    this.lineItems = const [],
  });

  factory MonthlyBillRecord.fromMap(Map<String, dynamic> map, {List<LineItemInput> items = const []}) {
    return MonthlyBillRecord(
      id: map['id'] as String,
      tenancyId: map['tenancy_id'] as String,
      billNumber: map['bill_number'] as String,
      tenantName: (map['tenant_name'] as String?) ?? 'Tenant',
      tenantPhone: (map['tenant_phone'] as String?) ?? '',
      roomId: (map['room_id'] as String?) ?? '',
      roomNumber: (map['room_number'] as String?) ?? 'Room',
      billingMonth: map['billing_month'] as int,
      billingYear: map['billing_year'] as int,
      billDateEpoch: map['bill_date_epoch'] as int,
      dueDateEpoch: map['due_date_epoch'] as int,
      rentAmountPaise: map['rent_amount_paise'] as int,
      rentAdvanceAppliedPaise: (map['rent_advance_applied_paise'] as int?) ?? 0,
      outstandingRentPaise: (map['outstanding_rent_paise'] as int?) ?? (map['rent_amount_paise'] as int),
      electricityUnitsCentiunits: map['electricity_units_centiunits'] as int,
      electricityAmountPaise: map['electricity_amount_paise'] as int,
      electricityAdvanceAppliedPaise: (map['electricity_advance_applied_paise'] as int?) ?? 0,
      outstandingElectricityPaise: (map['outstanding_electricity_paise'] as int?) ?? (map['electricity_amount_paise'] as int),
      additionalChargesPaise: map['additional_charges_paise'] as int,
      previousBalancePaise: map['previous_balance_paise'] as int,
      totalDuePaise: map['total_due_paise'] as int,
      netAmountDuePaise: (map['net_amount_due_paise'] as int?) ?? (map['total_due_paise'] as int),
      amountPaidPaise: map['amount_paid_paise'] as int,
      remainingBalancePaise: map['remaining_balance_paise'] as int,
      status: map['status'] as String,
      notes: map['notes'] as String?,
      lineItems: items,
    );
  }
}

class BillingDao {
  final AppDatabase _dbProvider = AppDatabase.instance;

  Future<List<MonthlyBillRecord>> getBills({
    int? month,
    int? year,
    String? status,
    String? roomId,
  }) async {
    final db = await _dbProvider.database;
    final whereClauses = <String>[];
    final whereArgs = <dynamic>[];

    if (month != null) {
      whereClauses.add('mb.billing_month = ?');
      whereArgs.add(month);
    }
    if (year != null) {
      whereClauses.add('mb.billing_year = ?');
      whereArgs.add(year);
    }
    if (status != null && status != 'ALL') {
      whereClauses.add('mb.status = ?');
      whereArgs.add(status);
    }
    if (roomId != null) {
      whereClauses.add('t.room_id = ?');
      whereArgs.add(roomId);
    }

    final whereSql = whereClauses.isNotEmpty ? 'WHERE ${whereClauses.join(' AND ')}' : '';

    final query = '''
      SELECT 
        mb.*,
        ten.full_name AS tenant_name,
        ten.phone_number AS tenant_phone,
        t.room_id,
        r.room_number
      FROM ${DatabaseTables.monthlyBills} mb
      JOIN ${DatabaseTables.tenancies} t ON mb.tenancy_id = t.id
      JOIN ${DatabaseTables.tenants} ten ON t.tenant_id = ten.id
      JOIN ${DatabaseTables.rooms} r ON t.room_id = r.id
      $whereSql
      ORDER BY mb.billing_year DESC, mb.billing_month DESC, mb.bill_date_epoch DESC;
    ''';

    final result = await db.rawQuery(query, whereArgs);
    return result.map((row) => MonthlyBillRecord.fromMap(row)).toList();
  }

  Future<MonthlyBillRecord?> getBillById(String id) async {
    final db = await _dbProvider.database;
    final query = '''
      SELECT 
        mb.*,
        ten.full_name AS tenant_name,
        ten.phone_number AS tenant_phone,
        t.room_id,
        r.room_number
      FROM ${DatabaseTables.monthlyBills} mb
      JOIN ${DatabaseTables.tenancies} t ON mb.tenancy_id = t.id
      JOIN ${DatabaseTables.tenants} ten ON t.tenant_id = ten.id
      JOIN ${DatabaseTables.rooms} r ON t.room_id = r.id
      WHERE mb.id = ?
      LIMIT 1;
    ''';

    final result = await db.rawQuery(query, [id]);
    if (result.isEmpty) return null;

    final itemRows = await db.query(
      DatabaseTables.billLineItems,
      where: 'monthly_bill_id = ?',
      whereArgs: [id],
    );

    final items = itemRows.map((r) => LineItemInput(
      description: r['description'] as String,
      category: r['category'] as String,
      amountPaise: r['amount_paise'] as int,
    )).toList();

    return MonthlyBillRecord.fromMap(result.first, items: items);
  }

  Future<int> getPreviousOutstandingBalance({
    required String tenancyId,
    required int month,
    required int year,
  }) async {
    final db = await _dbProvider.database;
    final query = '''
      SELECT SUM(remaining_balance_paise) AS total_outstanding
      FROM ${DatabaseTables.monthlyBills}
      WHERE tenancy_id = ?
        AND (
          billing_year < ? 
          OR (billing_year = ? AND billing_month < ?)
        )
        AND remaining_balance_paise > 0;
    ''';

    final result = await db.rawQuery(query, [tenancyId, year, year, month]);
    if (result.isNotEmpty && result.first['total_outstanding'] != null) {
      return result.first['total_outstanding'] as int;
    }
    return 0;
  }

  /// Saves a calculated monthly bill, line items, and creates independent advance ledger debits
  Future<void> saveMonthlyBill(CalculatedBillResult bill) async {
    final db = await _dbProvider.database;
    final billId = 'bill_${bill.tenancyId}_${bill.billingYear}_${bill.billingMonth}';
    final now = DateTime.now().millisecondsSinceEpoch;

    await db.transaction((txn) async {
      await txn.insert(
        DatabaseTables.monthlyBills,
        {
          'id': billId,
          'tenancy_id': bill.tenancyId,
          'bill_number': bill.billNumber,
          'billing_month': bill.billingMonth,
          'billing_year': bill.billingYear,
          'bill_date_epoch': bill.billDateEpoch,
          'due_date_epoch': bill.dueDateEpoch,
          'rent_amount_paise': bill.rentAmountPaise,
          'rent_advance_applied_paise': bill.rentAdvanceAppliedPaise,
          'outstanding_rent_paise': bill.outstandingRentPaise,
          'electricity_units_centiunits': bill.electricityUnitsCentiunits,
          'electricity_amount_paise': bill.electricityAmountPaise,
          'electricity_advance_applied_paise': bill.electricityAdvanceAppliedPaise,
          'outstanding_electricity_paise': bill.outstandingElectricityPaise,
          'additional_charges_paise': bill.additionalChargesPaise,
          'previous_balance_paise': bill.previousBalancePaise,
          'total_due_paise': bill.totalDuePaise,
          'net_amount_due_paise': bill.netAmountDuePaise,
          'amount_paid_paise': bill.amountPaidPaise,
          'remaining_balance_paise': bill.remainingBalancePaise,
          'status': bill.status,
          'created_at_epoch': now,
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );

      // Clean existing line items & old advance ledger debits for this bill if re-generating
      await txn.delete(
        DatabaseTables.billLineItems,
        where: 'monthly_bill_id = ?',
        whereArgs: [billId],
      );

      await txn.delete(
        DatabaseTables.advanceLedgerEntries,
        where: 'monthly_bill_id = ?',
        whereArgs: [billId],
      );

      // Insert line items
      for (int i = 0; i < bill.lineItems.length; i++) {
        final item = bill.lineItems[i];
        final itemId = '${billId}_item_$i';
        await txn.insert(DatabaseTables.billLineItems, {
          'id': itemId,
          'monthly_bill_id': billId,
          'description': item.description,
          'category': item.category,
          'amount_paise': item.amountPaise,
          'created_at_epoch': now,
        });
      }

      // 1. Independent Rent Advance Debit Entry
      if (bill.rentAdvanceAppliedPaise > 0) {
        final rentEntryId = 'adv_adj_rent_${billId}';
        await txn.insert(DatabaseTables.advanceLedgerEntries, {
          'id': rentEntryId,
          'tenancy_id': bill.tenancyId,
          'account_type': 'RENT_ADVANCE',
          'transaction_type': 'DEBIT_ADJUSTED',
          'amount_paise': bill.rentAdvanceAppliedPaise,
          'monthly_bill_id': billId,
          'payment_id': null,
          'description': 'Applied against room rent for ${bill.billNumber}',
          'entry_date_epoch': bill.billDateEpoch,
          'created_at_epoch': now,
        });
      }

      // 2. Independent Electricity Advance Debit Entry
      if (bill.electricityAdvanceAppliedPaise > 0) {
        final elecEntryId = 'adv_adj_elec_${billId}';
        await txn.insert(DatabaseTables.advanceLedgerEntries, {
          'id': elecEntryId,
          'tenancy_id': bill.tenancyId,
          'account_type': 'ELECTRICITY_ADVANCE',
          'transaction_type': 'DEBIT_ADJUSTED',
          'amount_paise': bill.electricityAdvanceAppliedPaise,
          'monthly_bill_id': billId,
          'payment_id': null,
          'description': 'Applied against electricity charges for ${bill.billNumber}',
          'entry_date_epoch': bill.billDateEpoch,
          'created_at_epoch': now,
        });
      }
    });
  }
}

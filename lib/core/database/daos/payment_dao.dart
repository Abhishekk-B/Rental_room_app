import 'package:sqflite/sqflite.dart';
import '../app_database.dart';
import '../tables.dart';

class PaymentRecord {
  final String id;
  final String tenancyId;
  final String tenantName;
  final String roomNumber;
  final String receiptNumber;
  final int amountPaise;
  final int paymentDateEpoch;
  final String paymentMethod;
  final String? transactionRef;
  final String? notes;

  PaymentRecord({
    required this.id,
    required this.tenancyId,
    required this.tenantName,
    required this.roomNumber,
    required this.receiptNumber,
    required this.amountPaise,
    required this.paymentDateEpoch,
    required this.paymentMethod,
    this.transactionRef,
    this.notes,
  });

  factory PaymentRecord.fromMap(Map<String, dynamic> map) {
    return PaymentRecord(
      id: map['id'] as String,
      tenancyId: map['tenancy_id'] as String,
      tenantName: (map['tenant_name'] as String?) ?? 'Tenant',
      roomNumber: (map['room_number'] as String?) ?? 'Room',
      receiptNumber: map['receipt_number'] as String,
      amountPaise: map['amount_paise'] as int,
      paymentDateEpoch: map['payment_date_epoch'] as int,
      paymentMethod: map['payment_method'] as String,
      transactionRef: map['transaction_ref'] as String?,
      notes: map['notes'] as String?,
    );
  }
}

class PaymentDao {
  final AppDatabase _dbProvider = AppDatabase.instance;

  Future<List<PaymentRecord>> getPayments({String? tenancyId, String? roomId}) async {
    final db = await _dbProvider.database;
    final whereClauses = <String>[];
    final args = <dynamic>[];

    if (tenancyId != null) {
      whereClauses.add('p.tenancy_id = ?');
      args.add(tenancyId);
    }
    if (roomId != null) {
      whereClauses.add('t.room_id = ?');
      args.add(roomId);
    }

    final whereSql = whereClauses.isNotEmpty ? 'WHERE ${whereClauses.join(' AND ')}' : '';

    final query = '''
      SELECT 
        p.*,
        ten.full_name AS tenant_name,
        r.room_number
      FROM ${DatabaseTables.payments} p
      JOIN ${DatabaseTables.tenancies} t ON p.tenancy_id = t.id
      JOIN ${DatabaseTables.tenants} ten ON t.tenant_id = ten.id
      JOIN ${DatabaseTables.rooms} r ON t.room_id = r.id
      $whereSql
      ORDER BY p.payment_date_epoch DESC;
    ''';

    final result = await db.rawQuery(query, args.isNotEmpty ? args : null);
    return result.map((row) => PaymentRecord.fromMap(row)).toList();
  }

  /// Records a payment with separate rent vs electricity amounts and allocates to bills
  Future<String> recordPayment({
    required String tenancyId,
    required int amountPaise,
    int? rentAmountPaidPaise,
    int? electricityAmountPaidPaise,
    required int paymentDateEpoch,
    required String paymentMethod,
    String? transactionRef,
    String? specificBillId,
    String? notes,
  }) async {
    final db = await _dbProvider.database;
    final now = DateTime.now().millisecondsSinceEpoch;
    final receiptNumber = 'REC-${now.toString().substring(5, 12)}';
    final paymentId = 'pay_$now';

    await db.transaction((txn) async {
      // 1. Insert payment record
      await txn.insert(DatabaseTables.payments, {
        'id': paymentId,
        'tenancy_id': tenancyId,
        'receipt_number': receiptNumber,
        'amount_paise': amountPaise,
        'payment_date_epoch': paymentDateEpoch,
        'payment_method': paymentMethod,
        'transaction_ref': transactionRef?.trim(),
        'notes': notes?.trim(),
        'created_at_epoch': now,
      });

      // 2. Query target bills to allocate towards
      List<Map<String, dynamic>> eligibleBills;
      if (specificBillId != null) {
        eligibleBills = await txn.query(
          DatabaseTables.monthlyBills,
          where: 'id = ? AND remaining_balance_paise > 0',
          whereArgs: [specificBillId],
        );
      } else {
        // Oldest bills first
        eligibleBills = await txn.query(
          DatabaseTables.monthlyBills,
          where: 'tenancy_id = ? AND remaining_balance_paise > 0',
          whereArgs: [tenancyId],
          orderBy: 'billing_year ASC, billing_month ASC, bill_date_epoch ASC',
        );
      }

      int unallocatedTotal = amountPaise;
      int unallocatedRent = rentAmountPaidPaise ?? 0;
      int unallocatedElec = electricityAmountPaidPaise ?? 0;

      for (final bill in eligibleBills) {
        if (unallocatedTotal <= 0) break;

        final billId = bill['id'] as String;
        final currentRemaining = bill['remaining_balance_paise'] as int;
        final currentPaid = bill['amount_paid_paise'] as int;
        final dueDate = bill['due_date_epoch'] as int;
        int outRent = (bill['outstanding_rent_paise'] as int?) ?? 0;
        int outElec = (bill['outstanding_electricity_paise'] as int?) ?? 0;

        final int allocateToThis = unallocatedTotal >= currentRemaining ? currentRemaining : unallocatedTotal;
        final int newPaid = currentPaid + allocateToThis;
        final int newRemaining = currentRemaining - allocateToThis;
        unallocatedTotal -= allocateToThis;

        // Reduce category outstanding if specified
        if (unallocatedRent > 0 && outRent > 0) {
          final deduct = unallocatedRent >= outRent ? outRent : unallocatedRent;
          outRent -= deduct;
          unallocatedRent -= deduct;
        }
        if (unallocatedElec > 0 && outElec > 0) {
          final deduct = unallocatedElec >= outElec ? outElec : unallocatedElec;
          outElec -= deduct;
          unallocatedElec -= deduct;
        }

        // Record payment allocation
        await txn.insert(DatabaseTables.paymentAllocations, {
          'id': 'palloc_${paymentId}_$billId',
          'payment_id': paymentId,
          'monthly_bill_id': billId,
          'amount_allocated_paise': allocateToThis,
          'created_at_epoch': now,
        });

        // Determine new bill status
        String newStatus = 'PARTIALLY_PAID';
        if (newRemaining <= 0) {
          newStatus = 'PAID';
        } else if (now > dueDate) {
          newStatus = 'OVERDUE';
        }

        // Update bill balances
        await txn.update(
          DatabaseTables.monthlyBills,
          {
            'amount_paid_paise': newPaid,
            'remaining_balance_paise': newRemaining,
            'outstanding_rent_paise': outRent,
            'outstanding_electricity_paise': outElec,
            'status': newStatus,
          },
          where: 'id = ?',
          whereArgs: [billId],
        );
      }
    });

    return receiptNumber;
  }
}

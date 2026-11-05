import 'package:sqflite/sqflite.dart';
import '../app_database.dart';
import '../tables.dart';

class AccountSummary {
  final String accountType; // 'RENT_ADVANCE', 'ELECTRICITY_ADVANCE', 'SECURITY_DEPOSIT'
  final int receivedPaise;
  final int adjustedPaise;
  final int refundedPaise;
  final int transferredInPaise;
  final int transferredOutPaise;
  final int availableBalancePaise;

  AccountSummary({
    required this.accountType,
    required this.receivedPaise,
    required this.adjustedPaise,
    required this.refundedPaise,
    this.transferredInPaise = 0,
    this.transferredOutPaise = 0,
    required this.availableBalancePaise,
  });

  String get displayName {
    switch (accountType) {
      case 'RENT_ADVANCE':
        return 'Rent Advance';
      case 'ELECTRICITY_ADVANCE':
        return 'Electricity Advance';
      case 'SECURITY_DEPOSIT':
        return 'Security Deposit';
      default:
        return accountType;
    }
  }
}

class TenancyAdvancesOverview {
  final AccountSummary rentAdvance;
  final AccountSummary electricityAdvance;
  final AccountSummary securityDeposit;
  final int outstandingRentPaise;
  final int outstandingElectricityPaise;

  TenancyAdvancesOverview({
    required this.rentAdvance,
    required this.electricityAdvance,
    required this.securityDeposit,
    required this.outstandingRentPaise,
    required this.outstandingElectricityPaise,
  });
}

class AdvanceLedgerEntryRecord {
  final String id;
  final String tenancyId;
  final String accountType;
  final String transactionType; // 'CREDIT_RECEIVED', 'DEBIT_ADJUSTED', 'DEBIT_REFUNDED', 'TRANSFER', 'REVERSAL'
  final int amountPaise;
  final String? monthlyBillId;
  final String? paymentId;
  final String description;
  final int entryDateEpoch;

  AdvanceLedgerEntryRecord({
    required this.id,
    required this.tenancyId,
    required this.accountType,
    required this.transactionType,
    required this.amountPaise,
    this.monthlyBillId,
    this.paymentId,
    required this.description,
    required this.entryDateEpoch,
  });

  factory AdvanceLedgerEntryRecord.fromMap(Map<String, dynamic> map) {
    return AdvanceLedgerEntryRecord(
      id: map['id'] as String,
      tenancyId: map['tenancy_id'] as String,
      accountType: map['account_type'] as String,
      transactionType: map['transaction_type'] as String,
      amountPaise: map['amount_paise'] as int,
      monthlyBillId: map['monthly_bill_id'] as String?,
      paymentId: map['payment_id'] as String?,
      description: map['description'] as String,
      entryDateEpoch: map['entry_date_epoch'] as int,
    );
  }
}

class GlobalAdvanceStats {
  final int totalRentAdvanceBalancePaise;
  final int totalElectricityAdvanceBalancePaise;
  final int totalSecurityDepositBalancePaise;
  final int totalOutstandingRentPaise;
  final int totalOutstandingElectricityPaise;

  GlobalAdvanceStats({
    required this.totalRentAdvanceBalancePaise,
    required this.totalElectricityAdvanceBalancePaise,
    required this.totalSecurityDepositBalancePaise,
    required this.totalOutstandingRentPaise,
    required this.totalOutstandingElectricityPaise,
  });
}

class AdvanceLedgerDao {
  final AppDatabase _dbProvider = AppDatabase.instance;

  /// Retrieves balance and totals for an independent account
  Future<AccountSummary> getAccountSummary(String tenancyId, String accountType) async {
    final db = await _dbProvider.database;

    final query = '''
      SELECT 
        transaction_type,
        SUM(amount_paise) AS total_amount
      FROM ${DatabaseTables.advanceLedgerEntries}
      WHERE tenancy_id = ? AND account_type = ?
      GROUP BY transaction_type;
    ''';

    final rows = await db.rawQuery(query, [tenancyId, accountType]);

    int received = 0;
    int adjusted = 0;
    int refunded = 0;
    int transferIn = 0;
    int transferOut = 0;

    for (final row in rows) {
      final type = row['transaction_type'] as String;
      final amount = (row['total_amount'] as int?) ?? 0;
      switch (type) {
        case 'CREDIT_RECEIVED':
          received += amount;
          break;
        case 'DEBIT_ADJUSTED':
          adjusted += amount;
          break;
        case 'DEBIT_REFUNDED':
          refunded += amount;
          break;
        case 'TRANSFER_IN':
          transferIn += amount;
          break;
        case 'TRANSFER_OUT':
          transferOut += amount;
          break;
      }
    }

    final balance = (received + transferIn) - (adjusted + refunded + transferOut);

    return AccountSummary(
      accountType: accountType,
      receivedPaise: received,
      adjustedPaise: adjusted,
      refundedPaise: refunded,
      transferredInPaise: transferIn,
      transferredOutPaise: transferOut,
      availableBalancePaise: balance > 0 ? balance : 0,
    );
  }

  /// Retrieves comprehensive overview of all 3 accounts + outstanding dues for a tenancy
  Future<TenancyAdvancesOverview> getTenancyAdvancesOverview(String tenancyId) async {
    final rentAdv = await getAccountSummary(tenancyId, 'RENT_ADVANCE');
    final elecAdv = await getAccountSummary(tenancyId, 'ELECTRICITY_ADVANCE');
    final secDep = await getAccountSummary(tenancyId, 'SECURITY_DEPOSIT');

    final db = await _dbProvider.database;

    // Calculate outstanding rent and electricity across all past and current bills
    final dueQuery = '''
      SELECT 
        COALESCE(SUM(outstanding_rent_paise), 0) AS total_out_rent,
        COALESCE(SUM(outstanding_electricity_paise), 0) AS total_out_elec
      FROM ${DatabaseTables.monthlyBills}
      WHERE tenancy_id = ? AND remaining_balance_paise > 0;
    ''';
    final dueRows = await db.rawQuery(dueQuery, [tenancyId]);

    final outRent = (dueRows.first['total_out_rent'] as int?) ?? 0;
    final outElec = (dueRows.first['total_out_elec'] as int?) ?? 0;

    return TenancyAdvancesOverview(
      rentAdvance: rentAdv,
      electricityAdvance: elecAdv,
      securityDeposit: secDep,
      outstandingRentPaise: outRent,
      outstandingElectricityPaise: outElec,
    );
  }

  /// Records an advance payment received from the tenant
  Future<void> recordAdvancePayment({
    required String tenancyId,
    required String accountType, // 'RENT_ADVANCE', 'ELECTRICITY_ADVANCE', 'SECURITY_DEPOSIT'
    required int amountPaise,
    required String description,
    int? entryDateEpoch,
  }) async {
    if (amountPaise <= 0) {
      throw ArgumentError('Advance amount must be greater than zero.');
    }
    final db = await _dbProvider.database;
    final now = DateTime.now().millisecondsSinceEpoch;
    final id = 'adv_${now}_${accountType.substring(0, 3).toLowerCase()}';

    await db.insert(DatabaseTables.advanceLedgerEntries, {
      'id': id,
      'tenancy_id': tenancyId,
      'account_type': accountType,
      'transaction_type': 'CREDIT_RECEIVED',
      'amount_paise': amountPaise,
      'monthly_bill_id': null,
      'payment_id': null,
      'description': description.trim(),
      'entry_date_epoch': entryDateEpoch ?? now,
      'created_at_epoch': now,
    });
  }

  /// Records an advance refund back to the tenant (e.g. upon move-out)
  Future<void> refundAdvance({
    required String tenancyId,
    required String accountType,
    required int amountPaise,
    required String reason,
  }) async {
    final summary = await getAccountSummary(tenancyId, accountType);
    if (amountPaise > summary.availableBalancePaise) {
      throw ArgumentError(
        'Cannot refund more than the available balance (${summary.availableBalancePaise ~/ 100} INR).',
      );
    }

    final db = await _dbProvider.database;
    final now = DateTime.now().millisecondsSinceEpoch;
    final id = 'ref_${now}_${accountType.substring(0, 3).toLowerCase()}';

    await db.insert(DatabaseTables.advanceLedgerEntries, {
      'id': id,
      'tenancy_id': tenancyId,
      'account_type': accountType,
      'transaction_type': 'DEBIT_REFUNDED',
      'amount_paise': amountPaise,
      'monthly_bill_id': null,
      'payment_id': null,
      'description': reason.trim(),
      'entry_date_epoch': now,
      'created_at_epoch': now,
    });
  }

  /// Strictly controlled manual transfer between advance accounts with mandatory audit record
  Future<void> transferBetweenAccounts({
    required String tenancyId,
    required String sourceAccountType,
    required String destinationAccountType,
    required int amountPaise,
    required String authorizedReason,
  }) async {
    if (sourceAccountType == destinationAccountType) {
      throw ArgumentError('Source and destination accounts must be different.');
    }
    if (amountPaise <= 0) {
      throw ArgumentError('Transfer amount must be greater than zero.');
    }

    final sourceSummary = await getAccountSummary(tenancyId, sourceAccountType);
    if (amountPaise > sourceSummary.availableBalancePaise) {
      throw ArgumentError('Insufficient balance in $sourceAccountType for transfer.');
    }

    final db = await _dbProvider.database;
    final now = DateTime.now().millisecondsSinceEpoch;

    await db.transaction((txn) async {
      // 1. Debit source
      await txn.insert(DatabaseTables.advanceLedgerEntries, {
        'id': 'txout_${now}',
        'tenancy_id': tenancyId,
        'account_type': sourceAccountType,
        'transaction_type': 'TRANSFER_OUT',
        'amount_paise': amountPaise,
        'description': 'Authorized transfer to $destinationAccountType: $authorizedReason',
        'entry_date_epoch': now,
        'created_at_epoch': now,
      });

      // 2. Credit destination
      await txn.insert(DatabaseTables.advanceLedgerEntries, {
        'id': 'txin_${now}',
        'tenancy_id': tenancyId,
        'account_type': destinationAccountType,
        'transaction_type': 'TRANSFER_IN',
        'amount_paise': amountPaise,
        'description': 'Authorized transfer from $sourceAccountType: $authorizedReason',
        'entry_date_epoch': now,
        'created_at_epoch': now,
      });

      // 3. Write mandatory audit log
      await txn.insert(DatabaseTables.auditLogs, {
        'id': 'audit_tx_${now}',
        'action': 'MANUAL_ADVANCE_TRANSFER',
        'target_table': DatabaseTables.advanceLedgerEntries,
        'target_id': tenancyId,
        'old_values_json': '{"source": "$sourceAccountType", "amount": $amountPaise}',
        'new_values_json': '{"destination": "$destinationAccountType", "amount": $amountPaise}',
        'reason': authorizedReason.trim(),
        'timestamp_epoch': now,
      });
    });
  }

  /// Retrieves full immutable ledger history for an account or all accounts
  Future<List<AdvanceLedgerEntryRecord>> getLedgerHistory(
    String tenancyId, {
    String? accountType,
  }) async {
    final db = await _dbProvider.database;
    final where = <String>['tenancy_id = ?'];
    final args = <dynamic>[tenancyId];

    if (accountType != null && accountType != 'ALL') {
      where.add('account_type = ?');
      args.add(accountType);
    }

    final query = '''
      SELECT * FROM ${DatabaseTables.advanceLedgerEntries}
      WHERE ${where.join(' AND ')}
      ORDER BY entry_date_epoch DESC, created_at_epoch DESC;
    ''';

    final result = await db.rawQuery(query, args);
    return result.map((r) => AdvanceLedgerEntryRecord.fromMap(r)).toList();
  }

  /// Calculates aggregated global stats across all active tenancies
  Future<GlobalAdvanceStats> getGlobalAdvancesSummary() async {
    final db = await _dbProvider.database;

    // Balances of active tenancies
    final query = '''
      SELECT 
        e.account_type,
        e.transaction_type,
        SUM(e.amount_paise) AS total_amount
      FROM ${DatabaseTables.advanceLedgerEntries} e
      JOIN ${DatabaseTables.tenancies} t ON e.tenancy_id = t.id AND t.status = 'ACTIVE'
      GROUP BY e.account_type, e.transaction_type;
    ''';

    final rows = await db.rawQuery(query);

    int rentCredit = 0, rentDebit = 0;
    int elecCredit = 0, elecDebit = 0;
    int secCredit = 0, secDebit = 0;

    for (final r in rows) {
      final acc = r['account_type'] as String;
      final type = r['transaction_type'] as String;
      final amt = (r['total_amount'] as int?) ?? 0;

      final isCredit = type == 'CREDIT_RECEIVED' || type == 'TRANSFER_IN';
      if (acc == 'RENT_ADVANCE') {
        if (isCredit) rentCredit += amt; else rentDebit += amt;
      } else if (acc == 'ELECTRICITY_ADVANCE') {
        if (isCredit) elecCredit += amt; else elecDebit += amt;
      } else if (acc == 'SECURITY_DEPOSIT') {
        if (isCredit) secCredit += amt; else secDebit += amt;
      }
    }

    // Outstanding Dues
    final duesQuery = '''
      SELECT 
        COALESCE(SUM(mb.outstanding_rent_paise), 0) AS total_out_rent,
        COALESCE(SUM(mb.outstanding_electricity_paise), 0) AS total_out_elec
      FROM ${DatabaseTables.monthlyBills} mb
      JOIN ${DatabaseTables.tenancies} t ON mb.tenancy_id = t.id AND t.status = 'ACTIVE'
      WHERE mb.remaining_balance_paise > 0;
    ''';
    final dueRows = await db.rawQuery(duesQuery);

    return GlobalAdvanceStats(
      totalRentAdvanceBalancePaise: (rentCredit - rentDebit) > 0 ? (rentCredit - rentDebit) : 0,
      totalElectricityAdvanceBalancePaise: (elecCredit - elecDebit) > 0 ? (elecCredit - elecDebit) : 0,
      totalSecurityDepositBalancePaise: (secCredit - secDebit) > 0 ? (secCredit - secDebit) : 0,
      totalOutstandingRentPaise: (dueRows.first['total_out_rent'] as int?) ?? 0,
      totalOutstandingElectricityPaise: (dueRows.first['total_out_elec'] as int?) ?? 0,
    );
  }
}

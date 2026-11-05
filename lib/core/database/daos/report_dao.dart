import 'package:sqflite/sqflite.dart';
import '../app_database.dart';
import '../tables.dart';
import 'advance_ledger_dao.dart';
import 'payment_dao.dart';

class DashboardSummary {
  final int totalRooms;
  final int occupiedRooms;
  final int vacantRooms;
  final int totalRentDuePaise;
  final int totalElectricityChargesPaise;
  final int totalPaymentsReceivedPaise;
  final int totalOutstandingDuesPaise;

  // Mandatory Independent Advance & Dues Cards
  final int totalRentAdvanceBalancePaise;
  final int totalElectricityAdvanceBalancePaise;
  final int totalSecurityDepositBalancePaise;
  final int totalOutstandingRentPaise;
  final int totalOutstandingElectricityPaise;

  final List<PaymentRecord> recentPayments;
  final List<UpcomingDueDate> upcomingDueDates;

  DashboardSummary({
    required this.totalRooms,
    required this.occupiedRooms,
    required this.vacantRooms,
    required this.totalRentDuePaise,
    required this.totalElectricityChargesPaise,
    required this.totalPaymentsReceivedPaise,
    required this.totalOutstandingDuesPaise,
    required this.totalRentAdvanceBalancePaise,
    required this.totalElectricityAdvanceBalancePaise,
    required this.totalSecurityDepositBalancePaise,
    required this.totalOutstandingRentPaise,
    required this.totalOutstandingElectricityPaise,
    required this.recentPayments,
    required this.upcomingDueDates,
  });
}

class UpcomingDueDate {
  final String roomNumber;
  final String tenantName;
  final String tenantPhone;
  final int dueDateEpoch;
  final int amountDuePaise;

  UpcomingDueDate({
    required this.roomNumber,
    required this.tenantName,
    required this.tenantPhone,
    required this.dueDateEpoch,
    required this.amountDuePaise,
  });
}

class IncomeExpenseMonthSummary {
  final int month;
  final int year;
  final int rentalIncomePaise;
  final int electricityIncomePaise;
  final int totalCollectedPaise;
  final int totalExpensePaise;
  final int netProfitPaise;

  IncomeExpenseMonthSummary({
    required this.month,
    required this.year,
    required this.rentalIncomePaise,
    required this.electricityIncomePaise,
    required this.totalCollectedPaise,
    required this.totalExpensePaise,
    required this.netProfitPaise,
  });
}

class ReportDao {
  final AppDatabase _dbProvider = AppDatabase.instance;
  final AdvanceLedgerDao _advanceDao = AdvanceLedgerDao();

  Future<DashboardSummary> getDashboardSummary(int month, int year) async {
    final db = await _dbProvider.database;

    // 1. Rooms statistics
    final roomStats = await db.rawQuery('''
      SELECT 
        COUNT(r.id) AS total_rooms,
        COUNT(t.id) AS occupied_rooms
      FROM ${DatabaseTables.rooms} r
      LEFT JOIN ${DatabaseTables.tenancies} t ON r.id = t.room_id AND t.status = 'ACTIVE'
      WHERE r.is_active = 1;
    ''');

    final int totalRooms = (roomStats.first['total_rooms'] as int?) ?? 0;
    final int occupiedRooms = (roomStats.first['occupied_rooms'] as int?) ?? 0;
    final int vacantRooms = totalRooms > occupiedRooms ? totalRooms - occupiedRooms : 0;

    // 2. Billing summary for selected period
    final billStats = await db.rawQuery('''
      SELECT 
        COALESCE(SUM(rent_amount_paise), 0) AS total_rent,
        COALESCE(SUM(electricity_amount_paise), 0) AS total_elec,
        COALESCE(SUM(amount_paid_paise), 0) AS total_paid,
        COALESCE(SUM(remaining_balance_paise), 0) AS total_outstanding
      FROM ${DatabaseTables.monthlyBills}
      WHERE billing_month = ? AND billing_year = ?;
    ''', [month, year]);

    final int totalRent = (billStats.first['total_rent'] as int?) ?? 0;
    final int totalElec = (billStats.first['total_elec'] as int?) ?? 0;
    final int totalPaid = (billStats.first['total_paid'] as int?) ?? 0;
    final int totalOutstanding = (billStats.first['total_outstanding'] as int?) ?? 0;

    // 3. Query Global Independent Advance & Dues Balances
    final globalAdvances = await _advanceDao.getGlobalAdvancesSummary();

    // 4. Recent payments
    final recentPayRows = await db.rawQuery('''
      SELECT 
        p.*,
        ten.full_name AS tenant_name,
        r.room_number
      FROM ${DatabaseTables.payments} p
      JOIN ${DatabaseTables.tenancies} t ON p.tenancy_id = t.id
      JOIN ${DatabaseTables.tenants} ten ON t.tenant_id = ten.id
      JOIN ${DatabaseTables.rooms} r ON t.room_id = r.id
      ORDER BY p.payment_date_epoch DESC
      LIMIT 5;
    ''');
    final recentPayments = recentPayRows.map((r) => PaymentRecord.fromMap(r)).toList();

    // 5. Upcoming dues
    final dueRows = await db.rawQuery('''
      SELECT 
        r.room_number,
        ten.full_name AS tenant_name,
        ten.phone_number AS tenant_phone,
        mb.due_date_epoch,
        mb.remaining_balance_paise
      FROM ${DatabaseTables.monthlyBills} mb
      JOIN ${DatabaseTables.tenancies} t ON mb.tenancy_id = t.id
      JOIN ${DatabaseTables.tenants} ten ON t.tenant_id = ten.id
      JOIN ${DatabaseTables.rooms} r ON t.room_id = r.id
      WHERE mb.billing_month = ? AND mb.billing_year = ? AND mb.remaining_balance_paise > 0
      ORDER BY mb.due_date_epoch ASC;
    ''', [month, year]);

    final upcomingDues = dueRows.map((r) => UpcomingDueDate(
      roomNumber: r['room_number'] as String,
      tenantName: r['tenant_name'] as String,
      tenantPhone: r['tenant_phone'] as String,
      dueDateEpoch: r['due_date_epoch'] as int,
      amountDuePaise: r['remaining_balance_paise'] as int,
    )).toList();

    return DashboardSummary(
      totalRooms: totalRooms,
      occupiedRooms: occupiedRooms,
      vacantRooms: vacantRooms,
      totalRentDuePaise: totalRent,
      totalElectricityChargesPaise: totalElec,
      totalPaymentsReceivedPaise: totalPaid,
      totalOutstandingDuesPaise: totalOutstanding,
      totalRentAdvanceBalancePaise: globalAdvances.totalRentAdvanceBalancePaise,
      totalElectricityAdvanceBalancePaise: globalAdvances.totalElectricityAdvanceBalancePaise,
      totalSecurityDepositBalancePaise: globalAdvances.totalSecurityDepositBalancePaise,
      totalOutstandingRentPaise: globalAdvances.totalOutstandingRentPaise,
      totalOutstandingElectricityPaise: globalAdvances.totalOutstandingElectricityPaise,
      recentPayments: recentPayments,
      upcomingDueDates: upcomingDues,
    );
  }

  Future<List<IncomeExpenseMonthSummary>> getYearlyIncomeVsExpense(int year) async {
    final db = await _dbProvider.database;
    final List<IncomeExpenseMonthSummary> list = [];

    for (int m = 1; m <= 12; m++) {
      final start = DateTime(year, m, 1).millisecondsSinceEpoch;
      final end = DateTime(year, m + 1, 0, 23, 59, 59).millisecondsSinceEpoch;

      final payResult = await db.rawQuery('''
        SELECT COALESCE(SUM(amount_paise), 0) AS total_collected
        FROM ${DatabaseTables.payments}
        WHERE payment_date_epoch >= ? AND payment_date_epoch <= ?;
      ''', [start, end]);

      final int collected = (payResult.first['total_collected'] as int?) ?? 0;

      final expResult = await db.rawQuery('''
        SELECT COALESCE(SUM(amount_paise), 0) AS total_exp
        FROM ${DatabaseTables.expenses}
        WHERE expense_date_epoch >= ? AND expense_date_epoch <= ?;
      ''', [start, end]);

      final int expense = (expResult.first['total_exp'] as int?) ?? 0;

      list.add(
        IncomeExpenseMonthSummary(
          month: m,
          year: year,
          rentalIncomePaise: (collected * 80) ~/ 100,
          electricityIncomePaise: (collected * 20) ~/ 100,
          totalCollectedPaise: collected,
          totalExpensePaise: expense,
          netProfitPaise: collected - expense,
        ),
      );
    }

    return list;
  }
}

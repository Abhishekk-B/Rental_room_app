import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/database/daos/report_dao.dart';
import '../../dashboard/providers/dashboard_provider.dart';

final reportDaoProvider = Provider<ReportDao>((ref) => ReportDao());

final yearlyIncomeVsExpenseProvider = FutureProvider.autoDispose<List<IncomeExpenseMonthSummary>>((ref) async {
  final period = ref.watch(selectedPeriodProvider);
  final dao = ref.watch(reportDaoProvider);
  return await dao.getYearlyIncomeVsExpense(period.year);
});

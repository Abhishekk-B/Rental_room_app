import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/database/daos/report_dao.dart';

class DashboardFilter {
  final int month;
  final int year;

  DashboardFilter({required this.month, required this.year});

  DashboardFilter copyWith({int? month, int? year}) {
    return DashboardFilter(
      month: month ?? this.month,
      year: year ?? this.year,
    );
  }
}

final selectedPeriodProvider = StateProvider<DashboardFilter>((ref) {
  final now = DateTime.now();
  return DashboardFilter(month: now.month, year: now.year);
});

final dashboardSummaryProvider = FutureProvider.autoDispose<DashboardSummary>((ref) async {
  final filter = ref.watch(selectedPeriodProvider);
  final dao = ReportDao();
  return await dao.getDashboardSummary(filter.month, filter.year);
});

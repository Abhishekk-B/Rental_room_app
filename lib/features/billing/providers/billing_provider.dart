import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/database/daos/billing_dao.dart';
import '../../dashboard/providers/dashboard_provider.dart';

final billingDaoProvider = Provider<BillingDao>((ref) => BillingDao());

final billStatusFilterProvider = StateProvider<String>((ref) => 'ALL');

final billsListProvider = FutureProvider.autoDispose<List<MonthlyBillRecord>>((ref) async {
  final period = ref.watch(selectedPeriodProvider);
  final status = ref.watch(billStatusFilterProvider);
  final dao = ref.watch(billingDaoProvider);
  return await dao.getBills(
    month: period.month,
    year: period.year,
    status: status,
  );
});

final billDetailProvider = FutureProvider.autoDispose.family<MonthlyBillRecord?, String>((ref, id) async {
  final dao = ref.watch(billingDaoProvider);
  return await dao.getBillById(id);
});

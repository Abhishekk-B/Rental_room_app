import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/database/daos/advance_ledger_dao.dart';

final advanceLedgerDaoProvider = Provider<AdvanceLedgerDao>((ref) => AdvanceLedgerDao());

final tenancyAdvancesProvider = FutureProvider.autoDispose.family<TenancyAdvancesOverview, String>((ref, tenancyId) async {
  final dao = ref.watch(advanceLedgerDaoProvider);
  return await dao.getTenancyAdvancesOverview(tenancyId);
});

class LedgerHistoryFilter {
  final String tenancyId;
  final String? accountType;

  LedgerHistoryFilter({required this.tenancyId, this.accountType});
}

final advanceLedgerHistoryProvider = FutureProvider.autoDispose.family<List<AdvanceLedgerEntryRecord>, LedgerHistoryFilter>((ref, filter) async {
  final dao = ref.watch(advanceLedgerDaoProvider);
  return await dao.getLedgerHistory(filter.tenancyId, accountType: filter.accountType);
});

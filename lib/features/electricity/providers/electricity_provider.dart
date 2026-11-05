import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/database/daos/electricity_dao.dart';
import '../../dashboard/providers/dashboard_provider.dart';

final electricityDaoProvider = Provider<ElectricityDao>((ref) => ElectricityDao());

final periodReadingsProvider = FutureProvider.autoDispose<List<MeterReadingRecord>>((ref) async {
  final period = ref.watch(selectedPeriodProvider);
  final dao = ref.watch(electricityDaoProvider);
  return await dao.getReadingsForPeriod(period.month, period.year);
});

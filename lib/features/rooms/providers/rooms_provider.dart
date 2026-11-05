import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/database/daos/billing_dao.dart';
import '../../../core/database/daos/payment_dao.dart';
import '../../../core/database/daos/room_dao.dart';
import '../../billing/providers/billing_provider.dart';
import '../../payments/providers/payments_provider.dart';

final roomDaoProvider = Provider<RoomDao>((ref) => RoomDao());

final roomsListProvider = FutureProvider.autoDispose<List<RoomWithDetails>>((ref) async {
  final dao = ref.watch(roomDaoProvider);
  return await dao.getAllRoomsWithDetails();
});

final roomDetailProvider = FutureProvider.autoDispose.family<RoomWithDetails?, String>((ref, roomId) async {
  final dao = ref.watch(roomDaoProvider);
  return await dao.getRoomById(roomId);
});

final roomBillsProvider = FutureProvider.autoDispose.family<List<MonthlyBillRecord>, String>((ref, roomId) async {
  final billingDao = ref.watch(billingDaoProvider);
  return await billingDao.getBills(roomId: roomId);
});

final roomPaymentsProvider = FutureProvider.autoDispose.family<List<PaymentRecord>, String>((ref, roomId) async {
  final paymentDao = ref.watch(paymentDaoProvider);
  return await paymentDao.getPayments(roomId: roomId);
});

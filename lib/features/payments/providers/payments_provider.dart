import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/database/daos/payment_dao.dart';

final paymentDaoProvider = Provider<PaymentDao>((ref) => PaymentDao());

final paymentsListProvider = FutureProvider.autoDispose<List<PaymentRecord>>((ref) async {
  final dao = ref.watch(paymentDaoProvider);
  return await dao.getPayments();
});

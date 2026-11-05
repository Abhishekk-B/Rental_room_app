import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/database/daos/tenant_dao.dart';

final tenantDaoProvider = Provider<TenantDao>((ref) => TenantDao());

final tenantsListProvider = FutureProvider.autoDispose<List<TenantModel>>((ref) async {
  final dao = ref.watch(tenantDaoProvider);
  return await dao.getAllTenants();
});

final tenantDetailProvider = FutureProvider.autoDispose.family<TenantModel?, String>((ref, tenantId) async {
  final dao = ref.watch(tenantDaoProvider);
  return await dao.getTenantById(tenantId);
});

final tenantHistoryProvider = FutureProvider.autoDispose.family<List<TenancyHistoryModel>, String>((ref, tenantId) async {
  final dao = ref.watch(tenantDaoProvider);
  return await dao.getTenancyHistory(tenantId);
});

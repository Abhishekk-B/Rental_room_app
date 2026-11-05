import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/utils/currency_helper.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/status_badge.dart';
import '../providers/tenants_provider.dart';

class TenantListScreen extends ConsumerWidget {
  const TenantListScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tenantsAsync = ref.watch(tenantsListProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Tenants Directory', style: TextStyle(fontWeight: FontWeight.bold)),
      ),
      body: tenantsAsync.when(
        data: (tenants) {
          if (tenants.isEmpty) {
            return EmptyStateView(
              icon: Icons.people_outline,
              title: 'No Tenants Registered',
              message: 'Add tenants and assign them to your rental rooms.',
              buttonText: 'Add Tenant',
              onAction: () => context.push('/tenants/add'),
            );
          }

          return RefreshIndicator(
            onRefresh: () async => ref.refresh(tenantsListProvider),
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              itemCount: tenants.length,
              itemBuilder: (context, index) {
                final tenant = tenants[index];
                final isCurrent = tenant.activeTenancyId != null;

                return Card(
                  elevation: 0,
                  margin: const EdgeInsets.only(bottom: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                    side: BorderSide(color: Theme.of(context).colorScheme.outlineVariant.withOpacity(0.5)),
                  ),
                  child: ListTile(
                    contentPadding: const EdgeInsets.all(16),
                    leading: CircleAvatar(
                      radius: 24,
                      backgroundColor: isCurrent ? AppColors.primaryContainer : Colors.grey.shade200,
                      child: Text(
                        tenant.fullName.isNotEmpty ? tenant.fullName[0].toUpperCase() : 'T',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: isCurrent ? AppColors.primary : Colors.grey.shade700,
                        ),
                      ),
                    ),
                    title: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            tenant.fullName,
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                          ),
                        ),
                        StatusBadge(status: isCurrent ? 'ACTIVE' : 'TERMINATED'),
                      ],
                    ),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            const Icon(Icons.phone_outlined, size: 14, color: Colors.grey),
                            const SizedBox(width: 4),
                            Text(tenant.phoneNumber, style: const TextStyle(fontSize: 13)),
                          ],
                        ),
                        const SizedBox(height: 4),
                        if (isCurrent)
                          Text(
                            'Occupying: ${tenant.activeRoomNumber ?? "Room"} • Agreed: ${CurrencyHelper.formatPaise(tenant.agreedRentPaise ?? 0)}/mo',
                            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.primary),
                          )
                        else
                          Text(
                            'Past / Unassigned Tenant',
                            style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                          ),
                      ],
                    ),
                    onTap: () => context.push('/tenants/${tenant.id}'),
                  ),
                );
              },
            ),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, _) => Center(child: Text('Error: $err')),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push('/tenants/add'),
        icon: const Icon(Icons.person_add),
        label: const Text('New Tenant'),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/database/daos/tenant_dao.dart';
import '../../../core/utils/currency_helper.dart';
import '../../../core/utils/date_helper.dart';
import '../../../core/widgets/confirm_dialog.dart';
import '../../../core/widgets/status_badge.dart';
import '../../advances/providers/advance_provider.dart';
import '../../dashboard/providers/dashboard_provider.dart';
import '../../rooms/providers/rooms_provider.dart';
import '../providers/tenants_provider.dart';

class TenantDetailScreen extends ConsumerWidget {
  final String tenantId;

  const TenantDetailScreen({Key? key, required this.tenantId}) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tenantAsync = ref.watch(tenantDetailProvider(tenantId));
    final historyAsync = ref.watch(tenantHistoryProvider(tenantId));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Tenant Profile'),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit_outlined),
            onPressed: () => context.push('/tenants/$tenantId/edit'),
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline, color: Colors.red),
            tooltip: 'Delete Tenant',
            onPressed: () async {
              final confirmed = await showConfirmDialog(
                context: context,
                title: 'Delete Tenant',
                message: 'Are you sure you want to delete this tenant and all associated records?',
                confirmLabel: 'Delete',
                isDestructive: true,
              );
              if (confirmed == true && context.mounted) {
                await ref.read(tenantDaoProvider).deleteTenant(tenantId);
                ref.invalidate(tenantsListProvider);
                ref.invalidate(roomsListProvider);
                Navigator.pop(context);
              }
            },
          ),
        ],
      ),
      body: tenantAsync.when(
        data: (tenant) {
          if (tenant == null) {
            return const Center(child: Text('Tenant not found.'));
          }

          final isCurrent = tenant.activeTenancyId != null;

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              // 1. Profile Header Card
              Card(
                elevation: 0,
                color: Theme.of(context).colorScheme.surface,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                  side: BorderSide(color: Colors.grey.shade300),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(20.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              CircleAvatar(
                                radius: 26,
                                backgroundColor: isCurrent ? AppColors.primaryContainer : Colors.grey.shade200,
                                child: Text(
                                  tenant.fullName.isNotEmpty ? tenant.fullName[0].toUpperCase() : 'T',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 22,
                                    color: isCurrent ? AppColors.primary : Colors.grey.shade700,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 14),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    tenant.fullName,
                                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                                  ),
                                  Text(
                                    tenant.phoneNumber,
                                    style: const TextStyle(fontSize: 14, color: Colors.grey),
                                  ),
                                ],
                              ),
                            ],
                          ),
                          StatusBadge(status: isCurrent ? 'ACTIVE' : 'TERMINATED'),
                        ],
                      ),
                      const SizedBox(height: 16),
                      const Divider(),
                      const SizedBox(height: 8),
                      if (tenant.email != null && tenant.email!.isNotEmpty)
                        _buildRow('Email', tenant.email!),
                      if (tenant.permanentAddress != null && tenant.permanentAddress!.isNotEmpty)
                        _buildRow('Permanent Address', tenant.permanentAddress!),
                      if (tenant.emergencyContact != null && tenant.emergencyContact!.isNotEmpty)
                        _buildRow('Emergency Contact', tenant.emergencyContact!),
                      if (tenant.idProofType != null && tenant.idProofType!.isNotEmpty)
                        _buildRow('ID Document', '${tenant.idProofType}: ${tenant.idProofNumber ?? "-"}'),
                      if (tenant.notes != null && tenant.notes!.isNotEmpty)
                        _buildRow('Notes', tenant.notes!),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20),

              // 2. MANDATORY INDEPENDENT ADVANCE & DEPOSIT ACCOUNTS (If Active Tenancy)
              if (isCurrent && tenant.activeTenancyId != null) ...[
                _buildAdvanceAccountsSection(context, ref, tenant),
                const SizedBox(height: 20),
              ],

              // 3. Current Lease Status Card
              Card(
                elevation: 0,
                color: Theme.of(context).colorScheme.surface,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                  side: BorderSide(color: Colors.grey.shade300),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Room Assignment & Lease',
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 12),
                      if (isCurrent) ...[
                        Text(
                          'Occupying: ${tenant.activeRoomNumber ?? "Room"}',
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          (tenant.agreedRentPaise ?? 0) == 0
                              ? 'Agreed Monthly Rent: ₹0 (Rent-Free)'
                              : 'Agreed Monthly Rent: ${CurrencyHelper.formatPaise(tenant.agreedRentPaise ?? 0)}/mo',
                        ),
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            Expanded(
                              child: OutlinedButton.icon(
                                style: OutlinedButton.styleFrom(foregroundColor: AppColors.error),
                                onPressed: () => _handleMoveOut(context, ref, tenant),
                                icon: const Icon(Icons.exit_to_app, size: 18),
                                label: const Text('Record Move-Out'),
                              ),
                            ),
                          ],
                        ),
                      ] else ...[
                        const Text('Tenant is not currently assigned to any room.'),
                        const SizedBox(height: 12),
                        FilledButton.icon(
                          onPressed: () => context.push('/tenants/assign?tenantId=${tenant.id}'),
                          icon: const Icon(Icons.meeting_room_outlined),
                          label: const Text('Assign to a Room'),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20),

              // 4. Historical Leases Section
              Text('Lease History', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              historyAsync.when(
                data: (history) {
                  if (history.isEmpty) {
                    return const Text('No prior tenancy records.', style: TextStyle(color: Colors.grey));
                  }
                  return ListView.separated(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: history.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 8),
                    itemBuilder: (context, index) {
                      final item = history[index];
                      return Card(
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                          side: BorderSide(color: Colors.grey.shade300),
                        ),
                        child: ListTile(
                          title: Text(item.roomNumber, style: const TextStyle(fontWeight: FontWeight.bold)),
                          subtitle: Text(
                            'Moved in: ${DateHelper.formatEpoch(item.moveInDateEpoch)}'
                            '${item.moveOutDateEpoch != null ? " • Moved out: ${DateHelper.formatEpoch(item.moveOutDateEpoch!)}" : ""}',
                            style: const TextStyle(fontSize: 12),
                          ),
                          trailing: StatusBadge(status: item.status),
                        ),
                      );
                    },
                  );
                },
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (err, _) => Text('Error loading history: $err'),
              ),
            ],
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, _) => Center(child: Text('Error: $err')),
      ),
    );
  }

  Widget _buildAdvanceAccountsSection(BuildContext context, WidgetRef ref, TenantModel tenant) {
    final advancesAsync = ref.watch(tenancyAdvancesProvider(tenant.activeTenancyId!));

    return advancesAsync.when(
      data: (overview) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'INDEPENDENT ADVANCE ACCOUNTS',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.grey),
                ),
                TextButton.icon(
                  onPressed: () => _showTransferDialog(context, ref, tenant),
                  icon: const Icon(Icons.swap_horiz, size: 16),
                  label: const Text('Authorized Transfer'),
                ),
              ],
            ),
            const SizedBox(height: 8),

            // 1. Rent Advance Account Card
            _buildAccountCard(
              context,
              ref,
              tenant: tenant,
              title: 'Rent Advance Account',
              subtitle: 'Strictly applied against room rent charges only',
              color: AppColors.primary,
              accountType: 'RENT_ADVANCE',
              summary: overview.rentAdvance,
            ),
            const SizedBox(height: 12),

            // 2. Electricity Advance Account Card
            _buildAccountCard(
              context,
              ref,
              tenant: tenant,
              title: 'Electricity Advance Account',
              subtitle: 'Strictly applied against electricity charges only',
              color: Colors.amber.shade900,
              accountType: 'ELECTRICITY_ADVANCE',
              summary: overview.electricityAdvance,
            ),
            const SizedBox(height: 12),

            // 3. Security Deposit Card
            _buildAccountCard(
              context,
              ref,
              tenant: tenant,
              title: 'Security Deposit Account',
              subtitle: 'Refundable security deposit (held separately)',
              color: Colors.indigo.shade800,
              accountType: 'SECURITY_DEPOSIT',
              summary: overview.securityDeposit,
            ),
            const SizedBox(height: 16),

            // 4. Outstanding Dues Breakdown Card
            Card(
              elevation: 0,
              color: Colors.grey.shade50,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
                side: BorderSide(color: Colors.grey.shade300),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Outstanding Dues for this Tenant', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Outstanding Rent: ${CurrencyHelper.formatPaise(overview.outstandingRentPaise)}',
                            style: TextStyle(fontWeight: FontWeight.bold, color: overview.outstandingRentPaise > 0 ? AppColors.error : AppColors.success)),
                        Text('Outstanding Elec: ${CurrencyHelper.formatPaise(overview.outstandingElectricityPaise)}',
                            style: TextStyle(fontWeight: FontWeight.bold, color: overview.outstandingElectricityPaise > 0 ? Colors.deepOrange : AppColors.success)),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        );
      },
      loading: () => const Center(child: LinearProgressIndicator()),
      error: (e, _) => Text('Error loading advance accounts: $e'),
    );
  }

  Widget _buildAccountCard(
    BuildContext context,
    WidgetRef ref, {
    required TenantModel tenant,
    required String title,
    required String subtitle,
    required Color color,
    required String accountType,
    required summary,
  }) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: color.withOpacity(0.3), width: 1.2),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: color)),
                    Text(subtitle, style: const TextStyle(fontSize: 11, color: Colors.grey)),
                  ],
                ),
                Text(
                  CurrencyHelper.formatPaise(summary.availableBalancePaise),
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: color),
                ),
              ],
            ),
            const SizedBox(height: 12),
            const Divider(height: 1),
            const SizedBox(height: 8),

            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Received: ${CurrencyHelper.formatPaise(summary.receivedPaise)}', style: const TextStyle(fontSize: 12)),
                Text('Adjusted: ${CurrencyHelper.formatPaise(summary.adjustedPaise)}', style: const TextStyle(fontSize: 12)),
                Text('Refunded: ${CurrencyHelper.formatPaise(summary.refundedPaise)}', style: const TextStyle(fontSize: 12)),
              ],
            ),
            const SizedBox(height: 12),

            Row(
              children: [
                Expanded(
                  child: FilledButton.tonalIcon(
                    style: FilledButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 8)),
                    onPressed: () => _showAddAdvanceDialog(context, ref, tenant, accountType, title),
                    icon: const Icon(Icons.add, size: 16),
                    label: const Text('Add Advance'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 8)),
                    onPressed: summary.availableBalancePaise > 0
                        ? () => _showRefundDialog(context, ref, tenant, accountType, summary.availableBalancePaise)
                        : null,
                    icon: const Icon(Icons.undo, size: 16),
                    label: const Text('Refund'),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  tooltip: 'View Transaction Ledger',
                  icon: const Icon(Icons.history, size: 20),
                  onPressed: () => context.push(
                    '/tenants/${tenant.id}/advances?tenancyId=${tenant.activeTenancyId}&accountType=$accountType',
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 130,
            child: Text(label, style: const TextStyle(color: Colors.grey, fontSize: 13)),
          ),
          Expanded(
            child: Text(value, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
          ),
        ],
      ),
    );
  }

  void _showAddAdvanceDialog(
    BuildContext context,
    WidgetRef ref,
    TenantModel tenant,
    String accountType,
    String title,
  ) {
    final amountCtrl = TextEditingController();
    final descCtrl = TextEditingController(text: 'Advance payment received');

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Add to $title'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: amountCtrl,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Amount (₹) *', border: OutlineInputBorder()),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: descCtrl,
              decoration: const InputDecoration(labelText: 'Remarks / Notes', border: OutlineInputBorder()),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          FilledButton(
            onPressed: () async {
              final paise = CurrencyHelper.parseRupeesToPaise(amountCtrl.text);
              if (paise <= 0) return;

              await ref.read(advanceLedgerDaoProvider).recordAdvancePayment(
                tenancyId: tenant.activeTenancyId!,
                accountType: accountType,
                amountPaise: paise,
                description: descCtrl.text,
              );

              ref.invalidate(tenancyAdvancesProvider(tenant.activeTenancyId!));
              ref.invalidate(dashboardSummaryProvider);
              if (context.mounted) Navigator.pop(context);
            },
            child: const Text('Record Advance'),
          ),
        ],
      ),
    );
  }

  void _showRefundDialog(
    BuildContext context,
    WidgetRef ref,
    TenantModel tenant,
    String accountType,
    int availablePaise,
  ) {
    final amountCtrl = TextEditingController(text: CurrencyHelper.paiseToRupeesString(availablePaise));
    final reasonCtrl = TextEditingController(text: 'Refunded to tenant upon request');

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Refund Advance Balance'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Max available to refund: ${CurrencyHelper.formatPaise(availablePaise)}',
                style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.grey)),
            const SizedBox(height: 12),
            TextField(
              controller: amountCtrl,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Refund Amount (₹) *', border: OutlineInputBorder()),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: reasonCtrl,
              decoration: const InputDecoration(labelText: 'Refund Reason *', border: OutlineInputBorder()),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          FilledButton(
            onPressed: () async {
              final paise = CurrencyHelper.parseRupeesToPaise(amountCtrl.text);
              if (paise <= 0 || paise > availablePaise) return;

              await ref.read(advanceLedgerDaoProvider).refundAdvance(
                tenancyId: tenant.activeTenancyId!,
                accountType: accountType,
                amountPaise: paise,
                reason: reasonCtrl.text,
              );

              ref.invalidate(tenancyAdvancesProvider(tenant.activeTenancyId!));
              ref.invalidate(dashboardSummaryProvider);
              if (context.mounted) Navigator.pop(context);
            },
            child: const Text('Confirm Refund'),
          ),
        ],
      ),
    );
  }

  void _showTransferDialog(BuildContext context, WidgetRef ref, TenantModel tenant) {
    String source = 'RENT_ADVANCE';
    String destination = 'ELECTRICITY_ADVANCE';
    final amountCtrl = TextEditingController();
    final reasonCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Authorized Cross-Account Transfer'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Notice: Advance accounts are strictly separated. Cross-account transfers are recorded in the permanent audit trail.',
                style: TextStyle(fontSize: 12, color: Colors.orange, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                value: source,
                decoration: const InputDecoration(labelText: 'From Account *', border: OutlineInputBorder()),
                items: const [
                  DropdownMenuItem(value: 'RENT_ADVANCE', child: Text('Rent Advance')),
                  DropdownMenuItem(value: 'ELECTRICITY_ADVANCE', child: Text('Electricity Advance')),
                  DropdownMenuItem(value: 'SECURITY_DEPOSIT', child: Text('Security Deposit')),
                ],
                onChanged: (val) {
                  if (val != null) setDialogState(() => source = val);
                },
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                value: destination,
                decoration: const InputDecoration(labelText: 'To Account *', border: OutlineInputBorder()),
                items: const [
                  DropdownMenuItem(value: 'RENT_ADVANCE', child: Text('Rent Advance')),
                  DropdownMenuItem(value: 'ELECTRICITY_ADVANCE', child: Text('Electricity Advance')),
                  DropdownMenuItem(value: 'SECURITY_DEPOSIT', child: Text('Security Deposit')),
                ],
                onChanged: (val) {
                  if (val != null) setDialogState(() => destination = val);
                },
              ),
              const SizedBox(height: 12),
              TextField(
                controller: amountCtrl,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Transfer Amount (₹) *', border: OutlineInputBorder()),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: reasonCtrl,
                decoration: const InputDecoration(labelText: 'Authorization Reason *', border: OutlineInputBorder()),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
            FilledButton(
              onPressed: () async {
                final paise = CurrencyHelper.parseRupeesToPaise(amountCtrl.text);
                if (paise <= 0 || source == destination || reasonCtrl.text.trim().isEmpty) return;

                try {
                  await ref.read(advanceLedgerDaoProvider).transferBetweenAccounts(
                    tenancyId: tenant.activeTenancyId!,
                    sourceAccountType: source,
                    destinationAccountType: destination,
                    amountPaise: paise,
                    authorizedReason: reasonCtrl.text,
                  );

                  ref.invalidate(tenancyAdvancesProvider(tenant.activeTenancyId!));
                  ref.invalidate(dashboardSummaryProvider);
                  if (context.mounted) Navigator.pop(context);
                } catch (e) {
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
                }
              },
              child: const Text('Authorize Transfer'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _handleMoveOut(BuildContext context, WidgetRef ref, TenantModel tenant) async {
    final confirmed = await ConfirmDialog.show(
      context,
      title: 'Confirm Tenant Move-Out',
      content: 'Are you sure you want to record move-out for ${tenant.fullName} from ${tenant.activeRoomNumber}? '
          'This will vacate the room while preserving all historical bills, advance accounts, and payment records.',
      confirmText: 'Move-Out',
      isDestructive: true,
    );

    if (confirmed && tenant.activeTenancyId != null) {
      await ref.read(tenantDaoProvider).terminateTenancy(
        tenancyId: tenant.activeTenancyId!,
        moveOutDateEpoch: DateTime.now().millisecondsSinceEpoch,
      );

      ref.invalidate(tenantsListProvider);
      ref.invalidate(tenantDetailProvider(tenant.id));
      ref.invalidate(roomsListProvider);

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Move-out recorded. Room is now vacant.')),
        );
      }
    }
  }
}

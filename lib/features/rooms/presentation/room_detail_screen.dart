import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/utils/currency_helper.dart';
import '../../../core/utils/date_helper.dart';
import '../../../core/widgets/confirm_dialog.dart';
import '../../../core/widgets/status_badge.dart';
import '../providers/rooms_provider.dart';

class RoomDetailScreen extends ConsumerWidget {
  final String roomId;

  const RoomDetailScreen({Key? key, required this.roomId}) : super(key: key);

  Future<void> _deleteRoom(BuildContext context, WidgetRef ref) async {
    final confirmed = await showConfirmDialog(
      context: context,
      title: 'Delete Room',
      message: 'Are you sure you want to delete this room? All meter readings, bills, and history for this room will be deleted.',
      confirmLabel: 'Delete',
      isDestructive: true,
    );

    if (confirmed == true) {
      try {
        await ref.read(roomDaoProvider).deleteRoom(roomId);
        ref.invalidate(roomsListProvider);
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Room deleted successfully')),
          );
          Navigator.pop(context);
        }
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
        }
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final roomAsync = ref.watch(roomDetailProvider(roomId));
    final billsAsync = ref.watch(roomBillsProvider(roomId));
    final paymentsAsync = ref.watch(roomPaymentsProvider(roomId));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Room Details'),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit_outlined),
            onPressed: () => context.push('/rooms/$roomId/edit'),
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline, color: Colors.red),
            tooltip: 'Delete Room',
            onPressed: () => _deleteRoom(context, ref),
          ),
        ],
      ),
      body: roomAsync.when(
        data: (room) {
          if (room == null) {
            return const Center(child: Text('Room not found'));
          }

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              // Header Card
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            room.roomNumber,
                            style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
                          ),
                          StatusBadge(status: room.isOccupied ? 'OCCUPIED' : 'VACANT'),
                        ],
                      ),
                      if (room.description != null && room.description!.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        Text(
                          room.description!,
                          style: TextStyle(color: Colors.grey.shade700, fontSize: 13),
                        ),
                      ],
                      const Divider(height: 24),
                      _buildDetailRow('Default Rent', CurrencyHelper.formatPaise(room.defaultRentPaise)),
                      _buildDetailRow('Electricity Rate', '${CurrencyHelper.formatPaise(room.electricityRatePaise)} / unit'),
                      _buildDetailRow('Sub-Meter', room.meterNumber ?? 'Not Configured'),
                      if (room.latestReadingCentiunits != null)
                        _buildDetailRow('Last Meter Reading', CurrencyHelper.formatCentiunits(room.latestReadingCentiunits!)),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Occupancy Card
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Current Occupancy',
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 12),
                      if (room.isOccupied) ...[
                        ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: const CircleAvatar(
                            backgroundColor: AppColors.primaryContainer,
                            child: Icon(Icons.person, color: AppColors.primary),
                          ),
                          title: Text(room.activeTenantName ?? 'Tenant', style: const TextStyle(fontWeight: FontWeight.bold)),
                          subtitle: Text('Agreed Rent: ${CurrencyHelper.formatPaise(room.agreedRentPaise ?? room.defaultRentPaise)}'),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Expanded(
                              child: FilledButton.icon(
                                onPressed: () => context.push('/bills/generate?roomId=${room.id}'),
                                icon: const Icon(Icons.receipt_long, size: 18),
                                label: const Text('Generate Bill'),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: OutlinedButton.icon(
                                onPressed: () => context.push('/payments/record?tenancyId=${room.activeTenancyId}'),
                                icon: const Icon(Icons.payment, size: 18),
                                label: const Text('Record Payment'),
                              ),
                            ),
                          ],
                        ),
                      ] else ...[
                        const Text('This room is currently vacant.', style: TextStyle(color: Colors.grey)),
                        const SizedBox(height: 12),
                        FilledButton.icon(
                          onPressed: () => context.push('/tenants/assign?roomId=${room.id}'),
                          icon: const Icon(Icons.person_add_outlined),
                          label: const Text('Assign New Tenant'),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Generated Bills Section
              Text(
                'Generated Bills',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              billsAsync.when(
                data: (bills) {
                  if (bills.isEmpty) {
                    return Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Center(
                          child: Text(
                            'No bills generated for this room yet.',
                            style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
                          ),
                        ),
                      ),
                    );
                  }
                  return Card(
                    child: ListView.separated(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: bills.length,
                      separatorBuilder: (_, __) => const Divider(height: 1),
                      itemBuilder: (context, index) {
                        final bill = bills[index];
                        return ListTile(
                          title: Text(
                            DateHelper.formatBillingPeriod(bill.billingMonth, bill.billingYear),
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          subtitle: Text('Invoice: ${bill.billNumber} • Rent: ${CurrencyHelper.formatPaise(bill.rentAmountPaise)}'),
                          trailing: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(
                                CurrencyHelper.formatPaise(bill.remainingBalancePaise > 0 ? bill.remainingBalancePaise : bill.netAmountDuePaise),
                                style: const TextStyle(fontWeight: FontWeight.bold),
                              ),
                              const SizedBox(height: 2),
                              StatusBadge(status: bill.status),
                            ],
                          ),
                          onTap: () => context.push('/bills/${bill.id}'),
                        );
                      },
                    ),
                  );
                },
                loading: () => const LinearProgressIndicator(),
                error: (e, _) => Text('Error loading bills: $e'),
              ),
              const SizedBox(height: 16),

              // Recorded Payments Section
              Text(
                'Payment History',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              paymentsAsync.when(
                data: (payments) {
                  if (payments.isEmpty) {
                    return Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Center(
                          child: Text(
                            'No payments recorded for this room yet.',
                            style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
                          ),
                        ),
                      ),
                    );
                  }
                  return Card(
                    child: ListView.separated(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: payments.length,
                      separatorBuilder: (_, __) => const Divider(height: 1),
                      itemBuilder: (context, index) {
                        final payment = payments[index];
                        return ListTile(
                          leading: const CircleAvatar(
                            backgroundColor: AppColors.primaryContainer,
                            child: Icon(Icons.check, color: AppColors.primary, size: 18),
                          ),
                          title: Text(
                            CurrencyHelper.formatPaise(payment.amountPaise),
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          subtitle: Text('${payment.paymentMethod} • ${DateHelper.formatEpoch(payment.paymentDateEpoch)}'),
                          trailing: Text(
                            payment.receiptNumber,
                            style: const TextStyle(color: Colors.grey, fontSize: 12),
                          ),
                        );
                      },
                    ),
                  );
                },
                loading: () => const LinearProgressIndicator(),
                error: (e, _) => Text('Error loading payments: $e'),
              ),
              const SizedBox(height: 32),
            ],
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, _) => Center(child: Text('Error: $err')),
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: Colors.grey, fontSize: 13)),
          Text(value, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
        ],
      ),
    );
  }
}

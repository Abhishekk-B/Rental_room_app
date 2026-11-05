import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/utils/currency_helper.dart';
import '../../../core/utils/date_helper.dart';
import '../../../core/widgets/confirm_dialog.dart';
import '../../../core/widgets/status_badge.dart';
import '../providers/rooms_provider.dart';

class RoomDetailScreen extends ConsumerStatefulWidget {
  final String roomId;

  const RoomDetailScreen({Key? key, required this.roomId}) : super(key: key);

  @override
  ConsumerState<RoomDetailScreen> createState() => _RoomDetailScreenState();
}

class _RoomDetailScreenState extends ConsumerState<RoomDetailScreen> {
  int? _filterMonth;
  int? _filterYear;

  Future<void> _deleteRoom(BuildContext context) async {
    final confirmed = await showConfirmDialog(
      context: context,
      title: 'Delete Room',
      message: 'Are you sure you want to delete this room? All meter readings, bills, and history for this room will be deleted.',
      confirmLabel: 'Delete',
      isDestructive: true,
    );

    if (confirmed == true) {
      try {
        await ref.read(roomDaoProvider).deleteRoom(widget.roomId);
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
  Widget build(BuildContext context) {
    final roomAsync = ref.watch(roomDetailProvider(widget.roomId));
    final billsAsync = ref.watch(roomBillsProvider(widget.roomId));
    final paymentsAsync = ref.watch(roomPaymentsProvider(widget.roomId));

    final allBills = billsAsync.valueOrNull ?? [];
    final hasGeneratedBills = allBills.isNotEmpty;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Room Details'),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit_outlined),
            onPressed: () => context.push('/rooms/${widget.roomId}/edit'),
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline, color: Colors.red),
            tooltip: 'Delete Room',
            onPressed: () => _deleteRoom(context),
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
                            if (hasGeneratedBills) ...[
                              const SizedBox(width: 8),
                              Expanded(
                                child: OutlinedButton.icon(
                                  onPressed: () => context.push('/payments/record?tenancyId=${room.activeTenancyId}&roomId=${room.id}'),
                                  icon: const Icon(Icons.payment, size: 18),
                                  label: const Text('Record Payment'),
                                ),
                              ),
                            ],
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

              // Month & Year Filter Bar
              Card(
                color: AppColors.surfaceVariant.withOpacity(0.35),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: const [
                              Icon(Icons.filter_list, size: 18, color: AppColors.primary),
                              SizedBox(width: 6),
                              Text(
                                'Filter Bills & Payments',
                                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                              ),
                            ],
                          ),
                          if (_filterMonth != null || _filterYear != null)
                            TextButton(
                              style: TextButton.styleFrom(
                                padding: EdgeInsets.zero,
                                visualDensity: VisualDensity.compact,
                              ),
                              onPressed: () {
                                setState(() {
                                  _filterMonth = null;
                                  _filterYear = null;
                                });
                              },
                              child: const Text('Reset', style: TextStyle(fontSize: 12, color: Colors.red)),
                            ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            flex: 3,
                            child: DropdownButtonFormField<int?>(
                              value: _filterMonth,
                              decoration: const InputDecoration(
                                labelText: 'Month',
                                border: OutlineInputBorder(),
                                contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                isDense: true,
                              ),
                              items: [
                                const DropdownMenuItem(value: null, child: Text('All Months')),
                                ...List.generate(12, (i) {
                                  final m = i + 1;
                                  return DropdownMenuItem(
                                    value: m,
                                    child: Text(DateHelper.getMonthName(m)),
                                  );
                                }),
                              ],
                              onChanged: (val) => setState(() => _filterMonth = val),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            flex: 2,
                            child: DropdownButtonFormField<int?>(
                              value: _filterYear,
                              decoration: const InputDecoration(
                                labelText: 'Year',
                                border: OutlineInputBorder(),
                                contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                isDense: true,
                              ),
                              items: [
                                const DropdownMenuItem(value: null, child: Text('All Years')),
                                ...List.generate(6, (i) {
                                  final y = DateTime.now().year - 2 + i;
                                  return DropdownMenuItem(
                                    value: y,
                                    child: Text('$y'),
                                  );
                                }),
                              ],
                              onChanged: (val) => setState(() => _filterYear = val),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Generated Bills Section
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Generated Bills',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                  ),
                  if (_filterMonth != null || _filterYear != null)
                    Text(
                      'Filtered',
                      style: TextStyle(color: Colors.grey.shade600, fontSize: 12, fontStyle: FontStyle.italic),
                    ),
                ],
              ),
              const SizedBox(height: 8),
              billsAsync.when(
                data: (bills) {
                  final displayedBills = bills.where((b) {
                    if (_filterMonth != null && b.billingMonth != _filterMonth) return false;
                    if (_filterYear != null && b.billingYear != _filterYear) return false;
                    return true;
                  }).toList();

                  if (displayedBills.isEmpty) {
                    return Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Center(
                          child: Text(
                            bills.isEmpty
                                ? 'No bills generated for this room yet.'
                                : 'No bills found for the selected filter.',
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
                      itemCount: displayedBills.length,
                      separatorBuilder: (_, __) => const Divider(height: 1),
                      itemBuilder: (context, index) {
                        final bill = displayedBills[index];
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
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Payment History',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                  ),
                  if (_filterMonth != null || _filterYear != null)
                    Text(
                      'Filtered',
                      style: TextStyle(color: Colors.grey.shade600, fontSize: 12, fontStyle: FontStyle.italic),
                    ),
                ],
              ),
              const SizedBox(height: 8),
              paymentsAsync.when(
                data: (payments) {
                  final displayedPayments = payments.where((p) {
                    final dt = DateTime.fromMillisecondsSinceEpoch(p.paymentDateEpoch);
                    if (_filterMonth != null && dt.month != _filterMonth) return false;
                    if (_filterYear != null && dt.year != _filterYear) return false;
                    return true;
                  }).toList();

                  if (displayedPayments.isEmpty) {
                    return Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Center(
                          child: Text(
                            payments.isEmpty
                                ? 'No payments recorded for this room yet.'
                                : 'No payments found for the selected filter.',
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
                      itemCount: displayedPayments.length,
                      separatorBuilder: (_, __) => const Divider(height: 1),
                      itemBuilder: (context, index) {
                        final payment = displayedPayments[index];
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

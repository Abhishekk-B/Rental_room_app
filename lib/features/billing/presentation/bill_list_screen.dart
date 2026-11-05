import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/utils/currency_helper.dart';
import '../../../core/utils/date_helper.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/status_badge.dart';
import '../../dashboard/providers/dashboard_provider.dart';
import '../providers/billing_provider.dart';

class BillListScreen extends ConsumerWidget {
  const BillListScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final period = ref.watch(selectedPeriodProvider);
    final currentStatus = ref.watch(billStatusFilterProvider);
    final billsAsync = ref.watch(billsListProvider);

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Monthly Rent Bills', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
            Text(
              DateHelper.formatBillingPeriod(period.month, period.year),
              style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.onSurfaceVariant),
            ),
          ],
        ),
      ),
      body: Column(
        children: [
          // Filter Chips
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                _buildFilterChip(ref, 'All', 'ALL', currentStatus),
                const SizedBox(width: 8),
                _buildFilterChip(ref, 'Unpaid', 'UNPAID', currentStatus),
                const SizedBox(width: 8),
                _buildFilterChip(ref, 'Partial', 'PARTIALLY_PAID', currentStatus),
                const SizedBox(width: 8),
                _buildFilterChip(ref, 'Paid', 'PAID', currentStatus),
                const SizedBox(width: 8),
                _buildFilterChip(ref, 'Overdue', 'OVERDUE', currentStatus),
              ],
            ),
          ),
          const Divider(height: 1),

          Expanded(
            child: billsAsync.when(
              data: (bills) {
                if (bills.isEmpty) {
                  return EmptyStateView(
                    icon: Icons.receipt_long_outlined,
                    title: 'No Bills Found',
                    message: 'No bills match the selected filter for ${DateHelper.formatBillingPeriod(period.month, period.year)}.',
                    buttonText: 'Generate Bills',
                    onAction: () => context.push('/bills/generate'),
                  );
                }

                return RefreshIndicator(
                  onRefresh: () async => ref.refresh(billsListProvider),
                  child: ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: bills.length,
                    itemBuilder: (context, index) {
                      final bill = bills[index];
                      return Card(
                        elevation: 0,
                        margin: const EdgeInsets.only(bottom: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                          side: BorderSide(color: Colors.grey.shade300),
                        ),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(16),
                          onTap: () => context.push('/bills/${bill.id}'),
                          child: Padding(
                            padding: const EdgeInsets.all(16.0),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          bill.roomNumber,
                                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                                        ),
                                        Text(
                                          bill.tenantName,
                                          style: const TextStyle(fontSize: 13, color: Colors.grey),
                                        ),
                                      ],
                                    ),
                                    StatusBadge(status: bill.status),
                                  ],
                                ),
                                const SizedBox(height: 12),
                                const Divider(height: 1),
                                const SizedBox(height: 10),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text('Total Due: ${CurrencyHelper.formatPaise(bill.totalDuePaise)}',
                                            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                                        Text('Due: ${DateHelper.formatEpoch(bill.dueDateEpoch)}',
                                            style: const TextStyle(fontSize: 11, color: Colors.grey)),
                                      ],
                                    ),
                                    Column(
                                      crossAxisAlignment: CrossAxisAlignment.end,
                                      children: [
                                        Text(
                                          'Balance: ${CurrencyHelper.formatPaise(bill.remainingBalancePaise)}',
                                          style: TextStyle(
                                            fontSize: 14,
                                            fontWeight: FontWeight.bold,
                                            color: bill.remainingBalancePaise > 0 ? AppColors.error : AppColors.success,
                                          ),
                                        ),
                                        if (bill.amountPaidPaise > 0)
                                          Text(
                                            'Paid: ${CurrencyHelper.formatPaise(bill.amountPaidPaise)}',
                                            style: const TextStyle(fontSize: 11, color: Colors.green),
                                          ),
                                      ],
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (err, _) => Center(child: Text('Error: $err')),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push('/bills/generate'),
        icon: const Icon(Icons.add),
        label: const Text('Generate Bill'),
      ),
    );
  }

  Widget _buildFilterChip(WidgetRef ref, String label, String value, String current) {
    final isSelected = value == current;
    return ChoiceChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (_) => ref.read(billStatusFilterProvider.notifier).state = value,
    );
  }
}

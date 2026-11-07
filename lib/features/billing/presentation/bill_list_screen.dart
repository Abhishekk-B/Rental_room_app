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
    final selectedMonth = ref.watch(billMonthFilterProvider);
    final selectedYear = ref.watch(billYearFilterProvider);
    final currentStatus = ref.watch(billStatusFilterProvider);
    final billsAsync = ref.watch(billsListProvider);

    String periodSubtitle = 'All Billing Periods';
    if (selectedMonth != null && selectedYear != null) {
      periodSubtitle = DateHelper.formatBillingPeriod(selectedMonth, selectedYear);
    } else if (selectedMonth != null) {
      periodSubtitle = DateHelper.getMonthName(selectedMonth);
    } else if (selectedYear != null) {
      periodSubtitle = 'Year $selectedYear';
    }

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Monthly Rent Bills', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
            Text(
              periodSubtitle,
              style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.onSurfaceVariant),
            ),
          ],
        ),
      ),
      body: Column(
        children: [
          // Month & Year Filter Row
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
            child: Row(
              children: [
                Expanded(
                  flex: 3,
                  child: DropdownButtonFormField<int?>(
                    value: selectedMonth,
                    decoration: const InputDecoration(
                      labelText: 'Month',
                      contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      border: OutlineInputBorder(),
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
                    onChanged: (val) {
                      ref.read(billMonthFilterProvider.notifier).state = val;
                    },
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  flex: 2,
                  child: DropdownButtonFormField<int?>(
                    value: selectedYear,
                    decoration: const InputDecoration(
                      labelText: 'Year',
                      contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      border: OutlineInputBorder(),
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
                    onChanged: (val) {
                      ref.read(billYearFilterProvider.notifier).state = val;
                    },
                  ),
                ),
                if (selectedMonth != null || selectedYear != null) ...[
                  const SizedBox(width: 4),
                  IconButton(
                    icon: const Icon(Icons.clear, size: 20, color: Colors.red),
                    tooltip: 'Reset Period Filter',
                    onPressed: () {
                      ref.read(billMonthFilterProvider.notifier).state = null;
                      ref.read(billYearFilterProvider.notifier).state = null;
                    },
                  ),
                ],
              ],
            ),
          ),

          // Status Filter Chips
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
                    message: 'No bills match the selected filter ($periodSubtitle).',
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
                                const SizedBox(height: 10),
                                // Quick View Breakdown (Rent, Electricity, Balance)
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                  decoration: BoxDecoration(
                                    color: AppColors.surfaceVariant.withOpacity(0.35),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      // Rent Amount
                                      Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Row(
                                            children: const [
                                              Icon(Icons.home_outlined, size: 14, color: Colors.grey),
                                              SizedBox(width: 3),
                                              Text('Rent', style: TextStyle(fontSize: 11, color: Colors.grey)),
                                            ],
                                          ),
                                          const SizedBox(height: 2),
                                          Text(
                                            CurrencyHelper.formatPaise(bill.rentAmountPaise),
                                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                                          ),
                                        ],
                                      ),

                                      // Electricity Amount
                                      Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Row(
                                            children: const [
                                              Icon(Icons.bolt, size: 14, color: Colors.amber),
                                              SizedBox(width: 3),
                                              Text('Electricity', style: TextStyle(fontSize: 11, color: Colors.grey)),
                                            ],
                                          ),
                                          const SizedBox(height: 2),
                                          Text(
                                            CurrencyHelper.formatPaise(bill.electricityAmountPaise),
                                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                                          ),
                                        ],
                                      ),

                                      // Remaining Balance
                                      Column(
                                        crossAxisAlignment: CrossAxisAlignment.end,
                                        children: [
                                          const Text('Balance Due', style: TextStyle(fontSize: 11, color: Colors.grey)),
                                          const SizedBox(height: 2),
                                          Text(
                                            CurrencyHelper.formatPaise(bill.remainingBalancePaise),
                                            style: TextStyle(
                                              fontSize: 14,
                                              fontWeight: FontWeight.bold,
                                              color: bill.remainingBalancePaise > 0 ? AppColors.error : AppColors.success,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      '${bill.billNumber} • Due: ${DateHelper.formatEpoch(bill.dueDateEpoch)}',
                                      style: const TextStyle(fontSize: 11, color: Colors.grey),
                                    ),
                                    if (bill.amountPaidPaise > 0)
                                      Text(
                                        'Paid: ${CurrencyHelper.formatPaise(bill.amountPaidPaise)}',
                                        style: const TextStyle(fontSize: 11, color: Colors.green, fontWeight: FontWeight.w600),
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

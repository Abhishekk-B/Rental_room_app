import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/utils/currency_helper.dart';
import '../../../core/utils/date_helper.dart';
import '../../dashboard/providers/dashboard_provider.dart';
import '../providers/reports_provider.dart';

class ReportsScreen extends ConsumerWidget {
  const ReportsScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final period = ref.watch(selectedPeriodProvider);
    final yearlyAsync = ref.watch(yearlyIncomeVsExpenseProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text('Financial Reports (${period.year})', style: const TextStyle(fontWeight: FontWeight.bold)),
      ),
      body: yearlyAsync.when(
        data: (monthlyList) {
          int totalYearCollected = 0;
          int totalYearExpense = 0;
          for (final m in monthlyList) {
            totalYearCollected += m.totalCollectedPaise;
            totalYearExpense += m.totalExpensePaise;
          }
          final int netYearProfit = totalYearCollected - totalYearExpense;

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              // Annual Summary Card
              Card(
                elevation: 0,
                color: Theme.of(context).colorScheme.surface,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                  side: BorderSide(color: Colors.grey.shade300),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Annual Financial Performance (${period.year})',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                      ),
                      const SizedBox(height: 16),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          _buildMetric(
                            'Total Collections',
                            CurrencyHelper.formatPaise(totalYearCollected),
                            Colors.green.shade800,
                          ),
                          _buildMetric(
                            'Total Expenses',
                            CurrencyHelper.formatPaise(totalYearExpense),
                            Colors.red.shade800,
                          ),
                          _buildMetric(
                            'Net Cashflow',
                            CurrencyHelper.formatPaise(netYearProfit),
                            netYearProfit >= 0 ? AppColors.primary : Colors.red.shade900,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),

              Text(
                'MONTH-WISE INCOME & EXPENSE BREAKDOWN',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.grey.shade700),
              ),
              const SizedBox(height: 8),

              Card(
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                  side: BorderSide(color: Colors.grey.shade300),
                ),
                child: ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: monthlyList.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (context, index) {
                    final item = monthlyList[index];
                    final monthName = DateHelper.formatShortBillingPeriod(item.month, item.year);

                    return Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          SizedBox(
                            width: 80,
                            child: Text(monthName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                          ),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(
                                'In: ${CurrencyHelper.formatPaise(item.totalCollectedPaise)}',
                                style: TextStyle(fontSize: 12, color: Colors.green.shade800, fontWeight: FontWeight.w600),
                              ),
                              Text(
                                'Out: ${CurrencyHelper.formatPaise(item.totalExpensePaise)}',
                                style: TextStyle(fontSize: 12, color: Colors.red.shade800),
                              ),
                            ],
                          ),
                          Container(
                            width: 100,
                            alignment: Alignment.centerRight,
                            child: Text(
                              CurrencyHelper.formatPaise(item.netProfitPaise),
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                                color: item.netProfitPaise >= 0 ? AppColors.primary : Colors.red.shade900,
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ],
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, _) => Center(child: Text('Error: $err')),
      ),
    );
  }

  Widget _buildMetric(String label, String value, Color color) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 11, color: Colors.grey)),
        const SizedBox(height: 4),
        Text(value, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: color)),
      ],
    );
  }
}

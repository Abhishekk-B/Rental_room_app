import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/utils/currency_helper.dart';
import '../../../core/utils/date_helper.dart';
import '../../../core/widgets/empty_state.dart';
import '../providers/expenses_provider.dart';

class ExpenseListScreen extends ConsumerWidget {
  const ExpenseListScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final expensesAsync = ref.watch(expensesListProvider);
    final currentCategory = ref.watch(expenseCategoryFilterProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Property Expenses', style: TextStyle(fontWeight: FontWeight.bold)),
      ),
      body: Column(
        children: [
          // Filter Chips
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                _buildCategoryChip(ref, 'All', 'ALL', currentCategory),
                const SizedBox(width: 8),
                _buildCategoryChip(ref, 'Maintenance', 'MAINTENANCE', currentCategory),
                const SizedBox(width: 8),
                _buildCategoryChip(ref, 'Repairs', 'REPAIR', currentCategory),
                const SizedBox(width: 8),
                _buildCategoryChip(ref, 'Common Power', 'ELECTRICITY_COMMON', currentCategory),
                const SizedBox(width: 8),
                _buildCategoryChip(ref, 'Plumbing', 'PLUMBING', currentCategory),
                const SizedBox(width: 8),
                _buildCategoryChip(ref, 'Cleaning', 'CLEANING', currentCategory),
              ],
            ),
          ),
          const Divider(height: 1),

          Expanded(
            child: expensesAsync.when(
              data: (expenses) {
                if (expenses.isEmpty) {
                  return EmptyStateView(
                    icon: Icons.receipt_outlined,
                    title: 'No Expenses Logged',
                    message: 'Record property maintenance, repairs, or cleaning costs to track net rental yield.',
                    buttonText: 'Add Expense',
                    onAction: () => context.push('/expenses/add'),
                  );
                }

                int totalExpensePaise = 0;
                for (final exp in expenses) {
                  totalExpensePaise += exp.amountPaise;
                }

                return ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    // Total Banner
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.red.shade50,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: Colors.red.shade200),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('Total Logged Expenses:', style: TextStyle(fontWeight: FontWeight.w600)),
                          Text(
                            CurrencyHelper.formatPaise(totalExpensePaise),
                            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.red.shade800),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),

                    ListView.separated(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: expenses.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 10),
                      itemBuilder: (context, index) {
                        final exp = expenses[index];
                        return Card(
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                            side: BorderSide(color: Colors.grey.shade300),
                          ),
                          child: ListTile(
                            leading: CircleAvatar(
                              backgroundColor: Colors.red.shade100,
                              child: Icon(_getCategoryIcon(exp.category), color: Colors.red.shade800, size: 20),
                            ),
                            title: Text(exp.description, style: const TextStyle(fontWeight: FontWeight.bold)),
                            subtitle: Text('${DateHelper.formatEpoch(exp.expenseDateEpoch)} • ${exp.category}'),
                            trailing: Text(
                              CurrencyHelper.formatPaise(exp.amountPaise),
                              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Colors.red.shade800),
                            ),
                          ),
                        );
                      },
                    ),
                  ],
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (err, _) => Center(child: Text('Error: $err')),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push('/expenses/add'),
        icon: const Icon(Icons.add),
        label: const Text('Add Expense'),
      ),
    );
  }

  Widget _buildCategoryChip(WidgetRef ref, String label, String value, String current) {
    return ChoiceChip(
      label: Text(label),
      selected: value == current,
      onSelected: (_) => ref.read(expenseCategoryFilterProvider.notifier).state = value,
    );
  }

  IconData _getCategoryIcon(String category) {
    switch (category) {
      case 'MAINTENANCE':
        return Icons.build_outlined;
      case 'REPAIR':
        return Icons.handyman_outlined;
      case 'ELECTRICITY_COMMON':
        return Icons.bolt_outlined;
      case 'PLUMBING':
        return Icons.plumbing_outlined;
      case 'CLEANING':
        return Icons.cleaning_services_outlined;
      default:
        return Icons.receipt_outlined;
    }
  }
}

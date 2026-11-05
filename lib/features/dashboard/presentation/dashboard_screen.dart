import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_strings.dart';
import '../../../core/database/daos/report_dao.dart';
import '../../../core/utils/currency_helper.dart';
import '../../../core/utils/date_helper.dart';
import '../../../core/widgets/stat_card.dart';
import '../providers/dashboard_provider.dart';

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final period = ref.watch(selectedPeriodProvider);
    final summaryAsync = ref.watch(dashboardSummaryProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              AppStrings.appName,
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20),
            ),
            Text(
              DateHelper.formatBillingPeriod(period.month, period.year),
              style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.onSurfaceVariant),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.calendar_month_outlined),
            tooltip: 'Select Billing Month',
            onPressed: () => _showMonthPicker(context, ref, period),
          ),
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            tooltip: 'Settings & Backup',
            onPressed: () => context.push('/settings'),
          ),
        ],
      ),
      body: summaryAsync.when(
        data: (summary) => RefreshIndicator(
          onRefresh: () async => ref.refresh(dashboardSummaryProvider),
          child: ListView(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            children: [
              // Occupancy Overview Bar
              _buildOccupancyBanner(context, summary),
              const SizedBox(height: 16),

              // General Collections & Month Overview
              Text(
                'COLLECTIONS OVERVIEW (${DateHelper.formatShortBillingPeriod(period.month, period.year)})',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.grey.shade700, letterSpacing: 0.5),
              ),
              const SizedBox(height: 8),

              Row(
                children: [
                  Expanded(
                    child: StatCard(
                      title: 'Payments Received',
                      value: CurrencyHelper.formatPaise(summary.totalPaymentsReceivedPaise),
                      icon: Icons.check_circle_outline,
                      color: AppColors.success,
                      onTap: () => context.push('/payments'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: StatCard(
                      title: 'Total Dues Pending',
                      value: CurrencyHelper.formatPaise(summary.totalOutstandingDuesPaise),
                      icon: Icons.warning_amber_rounded,
                      color: summary.totalOutstandingDuesPaise > 0 ? AppColors.error : AppColors.success,
                      onTap: () => context.push('/bills'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // MANDATORY OUTSTANDING DUES BREAKDOWN
              Text(
                'OUTSTANDING DUES BREAKDOWN',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.grey.shade700, letterSpacing: 0.5),
              ),
              const SizedBox(height: 8),

              Row(
                children: [
                  Expanded(
                    child: StatCard(
                      title: 'Outstanding Rent',
                      value: CurrencyHelper.formatPaise(summary.totalOutstandingRentPaise),
                      icon: Icons.home_work_outlined,
                      color: summary.totalOutstandingRentPaise > 0 ? AppColors.error : AppColors.success,
                      onTap: () => context.push('/bills'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: StatCard(
                      title: 'Outstanding Electricity',
                      value: CurrencyHelper.formatPaise(summary.totalOutstandingElectricityPaise),
                      icon: Icons.power_outlined,
                      color: summary.totalOutstandingElectricityPaise > 0 ? Colors.deepOrange : AppColors.success,
                      onTap: () => context.push('/bills'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // MANDATORY ADVANCE & SECURITY DEPOSIT ACCOUNTS SECTION (Moved below Collections Overview)
              Text(
                'ADVANCE & SECURITY DEPOSIT LEDGERS',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.grey.shade700, letterSpacing: 0.5),
              ),
              const SizedBox(height: 8),

              Row(
                children: [
                  Expanded(
                    child: StatCard(
                      title: 'Rent Advance',
                      value: CurrencyHelper.formatPaise(summary.totalRentAdvanceBalancePaise),
                      subtitle: 'Strictly for room rent',
                      icon: Icons.account_balance_wallet_outlined,
                      color: AppColors.primary,
                      onTap: () => context.push('/tenants'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: StatCard(
                      title: 'Elec. Advance',
                      value: CurrencyHelper.formatPaise(summary.totalElectricityAdvanceBalancePaise),
                      subtitle: 'Strictly for electricity',
                      icon: Icons.bolt,
                      color: Colors.amber.shade800,
                      onTap: () => context.push('/tenants'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),

              StatCard(
                title: 'Total Security Deposits Held',
                value: CurrencyHelper.formatPaise(summary.totalSecurityDepositBalancePaise),
                subtitle: 'Refundable deposits held across active tenancies',
                icon: Icons.shield_outlined,
                color: Colors.indigo.shade700,
                onTap: () => context.push('/tenants'),
              ),
              const SizedBox(height: 20),

              // Upcoming Dues Section
              if (summary.upcomingDueDates.isNotEmpty) ...[
                _buildSectionHeader(
                  context,
                  title: 'Upcoming Rent & Dues',
                  actionLabel: 'View Bills',
                  onAction: () => context.push('/bills'),
                ),
                const SizedBox(height: 8),
                Card(
                  elevation: 0,
                  color: Theme.of(context).colorScheme.surface,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                    side: BorderSide(color: Theme.of(context).colorScheme.outlineVariant.withOpacity(0.5)),
                  ),
                  child: ListView.separated(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: summary.upcomingDueDates.length,
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (context, index) {
                      final item = summary.upcomingDueDates[index];
                      return ListTile(
                        leading: CircleAvatar(
                          backgroundColor: AppColors.primaryContainer,
                          child: Text(
                            item.roomNumber.replaceAll('Room ', ''),
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppColors.primary),
                          ),
                        ),
                        title: Text(item.tenantName, style: const TextStyle(fontWeight: FontWeight.w600)),
                        subtitle: Text('Due: ${DateHelper.formatEpoch(item.dueDateEpoch)}'),
                        trailing: Text(
                          CurrencyHelper.formatPaise(item.amountDuePaise),
                          style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.error, fontSize: 14),
                        ),
                        onTap: () => context.push('/bills'),
                      );
                    },
                  ),
                ),
                const SizedBox(height: 20),
              ],

              // Recent Payments Section
              _buildSectionHeader(
                context,
                title: 'Recent Payments',
                actionLabel: 'History',
                onAction: () => context.push('/payments'),
              ),
              const SizedBox(height: 8),
              if (summary.recentPayments.isEmpty)
                Card(
                  elevation: 0,
                  color: Theme.of(context).colorScheme.surface,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                    side: BorderSide(color: Theme.of(context).colorScheme.outlineVariant.withOpacity(0.5)),
                  ),
                  child: const Padding(
                    padding: EdgeInsets.all(24.0),
                    child: Center(
                      child: Text('No payments recorded yet for this period.'),
                    ),
                  ),
                )
              else
                Card(
                  elevation: 0,
                  color: Theme.of(context).colorScheme.surface,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                    side: BorderSide(color: Theme.of(context).colorScheme.outlineVariant.withOpacity(0.5)),
                  ),
                  child: ListView.separated(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: summary.recentPayments.length,
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (context, index) {
                      final p = summary.recentPayments[index];
                      return ListTile(
                        leading: const CircleAvatar(
                          backgroundColor: Color(0xFFE8F5E9),
                          child: Icon(Icons.arrow_downward, color: Color(0xFF2E7D32), size: 20),
                        ),
                        title: Text('${p.tenantName} (${p.roomNumber})', style: const TextStyle(fontWeight: FontWeight.w600)),
                        subtitle: Text('${DateHelper.formatEpoch(p.paymentDateEpoch)} • ${p.paymentMethod}'),
                        trailing: Text(
                          CurrencyHelper.formatPaise(p.amountPaise),
                          style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF2E7D32), fontSize: 14),
                        ),
                      );
                    },
                  ),
                ),
              const SizedBox(height: 32),
            ],
          ),
        ),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, _) => Center(child: Text('Error loading dashboard: $err')),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showQuickActionSheet(context),
        icon: const Icon(Icons.add),
        label: const Text('Quick Action'),
      ),
    );
  }

  Widget _buildOccupancyBanner(BuildContext context, DashboardSummary summary) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: AppColors.primaryContainer.withOpacity(0.4),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.primary.withOpacity(0.15)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildOccupancyItem('Total Rooms', '${summary.totalRooms}', AppColors.primary),
          Container(height: 32, width: 1, color: Colors.grey.shade400),
          _buildOccupancyItem('Occupied', '${summary.occupiedRooms}', AppColors.success),
          Container(height: 32, width: 1, color: Colors.grey.shade400),
          _buildOccupancyItem('Vacant', '${summary.vacantRooms}', Colors.orange.shade800),
        ],
      ),
    );
  }

  Widget _buildOccupancyItem(String label, String count, Color color) {
    return Column(
      children: [
        Text(count, style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: color)),
        const SizedBox(height: 2),
        Text(label, style: const TextStyle(fontSize: 11, color: Colors.black87)),
      ],
    );
  }

  Widget _buildSectionHeader(
    BuildContext context, {
    required String title,
    required String actionLabel,
    required VoidCallback onAction,
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(title, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
        TextButton(onPressed: onAction, child: Text(actionLabel)),
      ],
    );
  }

  void _showMonthPicker(BuildContext context, WidgetRef ref, DashboardFilter current) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) {
        return Container(
          padding: const EdgeInsets.all(20),
          height: 320,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Select Billing Period', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 16),
              Expanded(
                child: ListView.builder(
                  itemCount: 12,
                  itemBuilder: (context, index) {
                    final month = index + 1;
                    final isSelected = month == current.month;
                    return ListTile(
                      title: Text(DateHelper.formatBillingPeriod(month, current.year)),
                      trailing: isSelected ? const Icon(Icons.check, color: AppColors.primary) : null,
                      onTap: () {
                        ref.read(selectedPeriodProvider.notifier).state = current.copyWith(month: month);
                        Navigator.pop(context);
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _showQuickActionSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 16.0),
            child: Wrap(
              children: [
                ListTile(
                  leading: const CircleAvatar(child: Icon(Icons.bolt)),
                  title: const Text('Enter Electricity Reading'),
                  onTap: () {
                    Navigator.pop(context);
                    context.push('/electricity/record');
                  },
                ),
                ListTile(
                  leading: const CircleAvatar(child: Icon(Icons.receipt_long)),
                  title: const Text('Generate Monthly Bill'),
                  onTap: () {
                    Navigator.pop(context);
                    context.push('/bills/generate');
                  },
                ),
                ListTile(
                  leading: const CircleAvatar(child: Icon(Icons.payments)),
                  title: const Text('Record Tenant Payment'),
                  onTap: () {
                    Navigator.pop(context);
                    context.push('/payments/record');
                  },
                ),
                ListTile(
                  leading: const CircleAvatar(child: Icon(Icons.account_balance_wallet)),
                  title: const Text('Manage Advance Accounts'),
                  onTap: () {
                    Navigator.pop(context);
                    context.push('/tenants');
                  },
                ),
                ListTile(
                  leading: const CircleAvatar(child: Icon(Icons.add_shopping_cart)),
                  title: const Text('Add Property Expense'),
                  onTap: () {
                    Navigator.pop(context);
                    context.push('/expenses/add');
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

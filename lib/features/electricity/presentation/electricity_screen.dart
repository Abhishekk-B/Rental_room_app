import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/utils/currency_helper.dart';
import '../../../core/utils/date_helper.dart';
import '../../../core/widgets/empty_state.dart';
import '../../dashboard/providers/dashboard_provider.dart';
import '../providers/electricity_provider.dart';

class ElectricityScreen extends ConsumerWidget {
  const ElectricityScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final period = ref.watch(selectedPeriodProvider);
    final readingsAsync = ref.watch(periodReadingsProvider);

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Electricity Sub-Meters', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
            Text(
              DateHelper.formatBillingPeriod(period.month, period.year),
              style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.onSurfaceVariant),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.pie_chart_outline),
            tooltip: 'Proportional Bill Allocation',
            onPressed: () => context.push('/electricity/allocate'),
          ),
        ],
      ),
      body: readingsAsync.when(
        data: (readings) {
          int totalUnitsCenti = 0;
          for (final r in readings) {
            totalUnitsCenti += r.unitsConsumedCentiunits;
          }

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              // Summary Banner
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.amber.shade50,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.amber.shade300),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Total Consumption',
                          style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.brown),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          CurrencyHelper.formatCentiunits(totalUnitsCenti),
                          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.amber.shade900),
                        ),
                      ],
                    ),
                    FilledButton.tonalIcon(
                      style: FilledButton.styleFrom(
                        backgroundColor: Colors.amber.shade200,
                        foregroundColor: Colors.brown.shade900,
                      ),
                      onPressed: () => context.push('/electricity/allocate'),
                      icon: const Icon(Icons.calculate_outlined, size: 18),
                      label: const Text('Split Master Bill'),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Recorded Sub-Meter Readings',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                  ),
                  TextButton.icon(
                    onPressed: () => context.push('/electricity/record'),
                    icon: const Icon(Icons.add, size: 16),
                    label: const Text('Add Reading'),
                  ),
                ],
              ),
              const SizedBox(height: 8),

              if (readings.isEmpty)
                EmptyStateView(
                  icon: Icons.bolt_outlined,
                  title: 'No Readings for this Month',
                  message: 'Record meter readings for your rooms to calculate tenant consumption.',
                  buttonText: 'Record First Reading',
                  onAction: () => context.push('/electricity/record'),
                )
              else
                ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: readings.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemBuilder: (context, index) {
                    final item = readings[index];
                    return Card(
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                        side: BorderSide(color: Colors.grey.shade300),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Row(
                                  children: [
                                    const CircleAvatar(
                                      radius: 16,
                                      backgroundColor: Color(0xFFFFF8E1),
                                      child: Icon(Icons.bolt, color: Colors.amber, size: 20),
                                    ),
                                    const SizedBox(width: 10),
                                    Text(
                                      item.roomNumber,
                                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                                    ),
                                  ],
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: Colors.amber.shade100,
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Text(
                                    CurrencyHelper.formatCentiunits(item.unitsConsumedCentiunits),
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 13,
                                      color: Colors.amber.shade900,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            const Divider(height: 1),
                            const SizedBox(height: 10),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  'Previous: ${CurrencyHelper.centiunitsToString(item.previousReadingCentiunits)}',
                                  style: const TextStyle(fontSize: 12, color: Colors.grey),
                                ),
                                const Icon(Icons.arrow_forward, size: 14, color: Colors.grey),
                                Text(
                                  'Current: ${CurrencyHelper.centiunitsToString(item.currentReadingCentiunits)}',
                                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                                ),
                                Text(
                                  DateHelper.formatEpoch(item.readingDateEpoch),
                                  style: const TextStyle(fontSize: 11, color: Colors.grey),
                                ),
                              ],
                            ),
                            if (item.isReset) ...[
                              const SizedBox(height: 6),
                              const Text(
                                '⚠️ Meter Reset / Rollover was recorded for this reading',
                                style: TextStyle(fontSize: 11, color: Colors.orange, fontWeight: FontWeight.w600),
                              ),
                            ],
                          ],
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
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push('/electricity/record'),
        icon: const Icon(Icons.bolt),
        label: const Text('Enter Reading'),
      ),
    );
  }
}

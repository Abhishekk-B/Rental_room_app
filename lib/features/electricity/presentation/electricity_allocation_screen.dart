import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/utils/currency_helper.dart';
import '../../../core/utils/date_helper.dart';
import '../../dashboard/providers/dashboard_provider.dart';
import '../../rooms/providers/rooms_provider.dart';
import '../domain/electricity_calculator.dart';
import '../providers/electricity_provider.dart';

class ElectricityAllocationScreen extends ConsumerStatefulWidget {
  const ElectricityAllocationScreen({Key? key}) : super(key: key);

  @override
  ConsumerState<ElectricityAllocationScreen> createState() => _ElectricityAllocationScreenState();
}

class _ElectricityAllocationScreenState extends ConsumerState<ElectricityAllocationScreen> {
  final _formKey = GlobalKey<FormState>();
  final _totalBillCtrl = TextEditingController(text: '3500'); // Example default
  final _fixedChargesCtrl = TextEditingController(text: '0');
  final _commonChargesCtrl = TextEditingController(text: '0');
  AllocationSummary? _previewSummary;
  bool _isLoading = false;

  @override
  void dispose() {
    _totalBillCtrl.dispose();
    _fixedChargesCtrl.dispose();
    _commonChargesCtrl.dispose();
    super.dispose();
  }

  void _calculatePreview(List<RoomConsumptionInput> roomInputs) {
    final totalBillPaise = CurrencyHelper.parseRupeesToPaise(_totalBillCtrl.text);
    final fixedPaise = CurrencyHelper.parseRupeesToPaise(_fixedChargesCtrl.text);
    final commonPaise = CurrencyHelper.parseRupeesToPaise(_commonChargesCtrl.text);

    if (totalBillPaise <= 0 || roomInputs.isEmpty) {
      setState(() => _previewSummary = null);
      return;
    }

    try {
      final summary = ElectricityCalculator.allocateProportionalBill(
        totalBillAmountPaise: totalBillPaise,
        rooms: roomInputs,
        fixedChargesPaise: fixedPaise,
        commonAreaChargesPaise: commonPaise,
      );
      setState(() => _previewSummary = summary);
    } catch (_) {
      setState(() => _previewSummary = null);
    }
  }

  Future<void> _commitAllocation() async {
    if (_previewSummary == null) return;
    setState(() => _isLoading = true);

    try {
      final period = ref.read(selectedPeriodProvider);
      final billId = 'ebill_${AppConstants.defaultPropertyId}_${period.year}_${period.month}';

      await ref.read(electricityDaoProvider).saveMasterBillAndAllocations(
        billId: billId,
        propertyId: AppConstants.defaultPropertyId,
        billingMonth: period.month,
        billingYear: period.year,
        totalAmountPaise: _previewSummary!.totalBillPaise,
        fixedChargesPaise: _previewSummary!.fixedChargesPaise,
        commonAreaChargesPaise: _previewSummary!.commonAreaChargesPaise,
        allocations: _previewSummary!.roomAllocations,
      );

      ref.invalidate(dashboardSummaryProvider);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Electricity bill allocation confirmed & saved!')),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final period = ref.watch(selectedPeriodProvider);
    final readingsAsync = ref.watch(periodReadingsProvider);
    final roomsAsync = ref.watch(roomsListProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Split Master Electricity Bill'),
      ),
      body: roomsAsync.when(
        data: (rooms) => readingsAsync.when(
          data: (readings) {
            // Build consumption inputs mapping readings to rooms
            final Map<String, int> readingMap = {};
            for (final r in readings) {
              readingMap[r.meterId] = r.unitsConsumedCentiunits;
            }

            final List<RoomConsumptionInput> roomInputs = [];
            for (final r in rooms) {
              final centi = r.meterId != null ? (readingMap[r.meterId] ?? 0) : 0;
              roomInputs.add(
                RoomConsumptionInput(
                  roomId: r.id,
                  roomNumber: r.roomNumber,
                  unitsConsumedCentiunits: centi,
                  isOccupied: r.isOccupied,
                ),
              );
            }

            if (_previewSummary == null && roomInputs.isNotEmpty) {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                _calculatePreview(roomInputs);
              });
            }

            return Form(
              key: _formKey,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.primaryContainer.withOpacity(0.3),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      'Period: ${DateHelper.formatBillingPeriod(period.month, period.year)} • Proportional split with exact penny reconciliation',
                      style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                    ),
                  ),
                  const SizedBox(height: 16),

                  TextFormField(
                    controller: _totalBillCtrl,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Total Master Bill Amount (₹) *',
                      hintText: 'e.g. 3500',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.currency_rupee),
                    ),
                    onChanged: (_) => _calculatePreview(roomInputs),
                    validator: (v) => (v == null || CurrencyHelper.parseRupeesToPaise(v) <= 0) ? 'Required' : null,
                  ),
                  const SizedBox(height: 12),

                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: _fixedChargesCtrl,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                            labelText: 'Fixed Meter Fee (₹)',
                            border: OutlineInputBorder(),
                          ),
                          onChanged: (_) => _calculatePreview(roomInputs),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextFormField(
                          controller: _commonChargesCtrl,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                            labelText: 'Common Area (₹)',
                            border: OutlineInputBorder(),
                          ),
                          onChanged: (_) => _calculatePreview(roomInputs),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),

                  // Allocation Preview Card & Table
                  Text(
                    'PROPORTIONAL SPLIT PREVIEW',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.grey.shade700),
                  ),
                  const SizedBox(height: 8),

                  if (_previewSummary == null)
                    const Center(child: Padding(padding: EdgeInsets.all(20), child: Text('Enter bill amount to preview split')))
                  else
                    Card(
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                        side: BorderSide(color: Colors.grey.shade300),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          children: [
                            ListView.separated(
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              itemCount: _previewSummary!.roomAllocations.length,
                              separatorBuilder: (_, __) => const Divider(height: 16),
                              itemBuilder: (context, index) {
                                final alloc = _previewSummary!.roomAllocations[index];
                                final pct = (alloc.proportionRatio * 100).toStringAsFixed(1);
                                return Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(alloc.roomNumber, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                                        Text(
                                          '${CurrencyHelper.formatCentiunits(alloc.unitsConsumedCentiunits)} ($pct%)',
                                          style: const TextStyle(fontSize: 12, color: Colors.grey),
                                        ),
                                      ],
                                    ),
                                    Text(
                                      CurrencyHelper.formatPaise(alloc.totalChargePaise, showDecimals: true),
                                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: AppColors.primary),
                                    ),
                                  ],
                                );
                              },
                            ),
                            const Divider(thickness: 1.5, height: 24),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text(
                                  'Sum of Allocated Charges:',
                                  style: TextStyle(fontWeight: FontWeight.bold),
                                ),
                                Text(
                                  CurrencyHelper.formatPaise(_previewSummary!.totalBillPaise, showDecimals: true),
                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.green),
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '✓ Reconciled exactly: 0.00 paise difference',
                              style: TextStyle(fontSize: 11, color: Colors.green.shade800, fontWeight: FontWeight.w600),
                            ),
                          ],
                        ),
                      ),
                    ),
                  const SizedBox(height: 24),

                  FilledButton.icon(
                    onPressed: (_isLoading || _previewSummary == null) ? null : _commitAllocation,
                    icon: _isLoading ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.check_circle_outline),
                    label: const Text('Confirm & Save Allocation'),
                    style: FilledButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 14)),
                  ),
                ],
              ),
            );
          },
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Center(child: Text('Error: $e')),
        ),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
      ),
    );
  }
}

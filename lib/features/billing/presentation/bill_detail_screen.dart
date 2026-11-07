import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/database/daos/billing_dao.dart';
import '../../../core/services/pdf_invoice_service.dart';
import '../../../core/utils/currency_helper.dart';
import '../../../core/utils/date_helper.dart';
import '../../../core/widgets/confirm_dialog.dart';
import '../../../core/widgets/status_badge.dart';
import '../../dashboard/providers/dashboard_provider.dart';
import '../../electricity/providers/electricity_provider.dart';
import '../../rooms/providers/rooms_provider.dart';
import '../providers/billing_provider.dart';

class BillDetailScreen extends ConsumerStatefulWidget {
  final String billId;

  const BillDetailScreen({Key? key, required this.billId}) : super(key: key);

  @override
  ConsumerState<BillDetailScreen> createState() => _BillDetailScreenState();
}

class _BillDetailScreenState extends ConsumerState<BillDetailScreen> {
  bool _isExporting = false;

  Future<void> _shareFullPdf(MonthlyBillRecord bill) async {
    setState(() => _isExporting = true);
    try {
      final pdfBytes = await PdfInvoiceService.generateMonthlyBillPdf(bill: bill);
      await PdfInvoiceService.sharePdf(pdfBytes, '${bill.billNumber}.pdf');
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to share PDF: $e')));
      }
    } finally {
      if (mounted) setState(() => _isExporting = false);
    }
  }

  Future<void> _shareElectricityPdf(MonthlyBillRecord bill) async {
    setState(() => _isExporting = true);
    try {
      final elecDao = ref.read(electricityDaoProvider);
      final roomDao = ref.read(roomDaoProvider);

      final readingRecord = await elecDao.getReadingForRoomAndPeriod(
        roomId: bill.roomId,
        month: bill.billingMonth,
        year: bill.billingYear,
      );
      final room = await roomDao.getRoomById(bill.roomId);

      int prevReading = readingRecord?.previousReadingCentiunits ?? 0;
      int currReading = readingRecord?.currentReadingCentiunits ?? 0;
      int unitsConsumed = readingRecord?.unitsConsumedCentiunits ?? bill.electricityUnitsCentiunits;

      if (readingRecord == null) {
        unitsConsumed = bill.electricityUnitsCentiunits;
        currReading = room?.latestReadingCentiunits ?? unitsConsumed;
        prevReading = (currReading - unitsConsumed).clamp(0, currReading);
      }

      final ratePaise = unitsConsumed > 0
          ? ((bill.electricityAmountPaise * 100) ~/ unitsConsumed)
          : (room?.electricityRatePaise ?? 1000);

      final pdfBytes = await PdfInvoiceService.generateElectricityBillPdf(
        bill: bill,
        previousReadingCentiunits: prevReading,
        currentReadingCentiunits: currReading,
        unitsConsumedCentiunits: unitsConsumed,
        ratePerUnitPaise: ratePaise,
        subMeterNumber: room?.meterNumber ?? 'Sub-Meter',
      );

      await PdfInvoiceService.sharePdf(pdfBytes, 'ELEC-${bill.billNumber}.pdf');
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to share Electricity PDF: $e')));
      }
    } finally {
      if (mounted) setState(() => _isExporting = false);
    }
  }

  void _showShareOptions(MonthlyBillRecord bill) {
    final hasElectricity = bill.electricityAmountPaise > 0 || bill.electricityUnitsCentiunits > 0;

    if (!hasElectricity) {
      _shareFullPdf(bill);
      return;
    }

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: const [
                    Icon(Icons.print, color: AppColors.primary),
                    SizedBox(width: 8),
                    Text(
                      'Choose Invoice / Receipt to Print or Share',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                ListTile(
                  leading: const CircleAvatar(
                    backgroundColor: AppColors.primaryContainer,
                    child: Icon(Icons.receipt_long, color: AppColors.primary),
                  ),
                  title: const Text('Full Monthly Invoice (Rent + Electricity)', style: TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: const Text('Complete invoice with rent, electricity, previous dues & total balance.'),
                  onTap: () {
                    Navigator.pop(ctx);
                    _shareFullPdf(bill);
                  },
                ),
                const Divider(),
                ListTile(
                  leading: CircleAvatar(
                    backgroundColor: Colors.amber.shade100,
                    child: Icon(Icons.bolt, color: Colors.orange.shade900),
                  ),
                  title: const Text('Electricity-Only Receipt (No Rent)', style: TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: const Text('Shows previous/current units, units consumed, advance applied & net electricity bill.'),
                  onTap: () {
                    Navigator.pop(ctx);
                    _shareElectricityPdf(bill);
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _deleteBill() async {
    final confirmed = await showConfirmDialog(
      context: context,
      title: 'Delete Bill',
      message: 'Are you sure you want to delete this bill? Advance adjustments applied will be undone.',
      confirmLabel: 'Delete',
      isDestructive: true,
    );

    if (confirmed == true && mounted) {
      try {
        await ref.read(billingDaoProvider).deleteMonthlyBill(widget.billId);
        ref.invalidate(billsListProvider);
        ref.invalidate(dashboardSummaryProvider);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Bill deleted successfully')));
          Navigator.pop(context);
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
        }
      }
    }
  }

  void _showEditBillDialog(MonthlyBillRecord bill) {
    final rentCtrl = TextEditingController(text: CurrencyHelper.paiseToRupeesString(bill.rentAmountPaise));
    final elecCtrl = TextEditingController(text: CurrencyHelper.paiseToRupeesString(bill.electricityAmountPaise));
    final addCtrl = TextEditingController(text: CurrencyHelper.paiseToRupeesString(bill.additionalChargesPaise));
    final notesCtrl = TextEditingController(text: bill.notes ?? '');

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Edit Bill (${bill.billNumber})'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: rentCtrl,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Rent Amount (₹)',
                  prefixText: '₹ ',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: elecCtrl,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Electricity Amount (₹)',
                  prefixText: '₹ ',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: addCtrl,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Other Charges (₹)',
                  prefixText: '₹ ',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: notesCtrl,
                maxLines: 2,
                decoration: const InputDecoration(
                  labelText: 'Notes (Optional)',
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () async {
              final newRent = CurrencyHelper.parseRupeesToPaise(rentCtrl.text);
              final newElec = CurrencyHelper.parseRupeesToPaise(elecCtrl.text);
              final newAdd = CurrencyHelper.parseRupeesToPaise(addCtrl.text);

              Navigator.pop(ctx);

              try {
                await ref.read(billingDaoProvider).updateMonthlyBill(
                  billId: bill.id,
                  rentAmountPaise: newRent,
                  electricityAmountPaise: newElec,
                  additionalChargesPaise: newAdd,
                  notes: notesCtrl.text.trim(),
                );

                ref.invalidate(billDetailProvider(widget.billId));
                ref.invalidate(billsListProvider);
                ref.invalidate(dashboardSummaryProvider);

                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Bill updated successfully')),
                  );
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
                }
              }
            },
            child: const Text('Save Changes'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final billAsync = ref.watch(billDetailProvider(widget.billId));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Invoice Details'),
        actions: [
          billAsync.maybeWhen(
            data: (bill) => bill != null
                ? Row(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.edit_outlined),
                        tooltip: 'Edit Bill Amount',
                        onPressed: () => _showEditBillDialog(bill),
                      ),
                      if (bill.electricityAmountPaise > 0 || bill.electricityUnitsCentiunits > 0)
                        IconButton(
                          icon: const Icon(Icons.bolt, color: Colors.amber),
                          tooltip: 'Electricity Only Receipt',
                          onPressed: _isExporting ? null : () => _shareElectricityPdf(bill),
                        ),
                      IconButton(
                        icon: _isExporting
                            ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                            : const Icon(Icons.share_outlined),
                        tooltip: 'Share PDF Invoice',
                        onPressed: () => _showShareOptions(bill),
                      ),
                      IconButton(
                        icon: const Icon(Icons.delete_outline, color: Colors.red),
                        tooltip: 'Delete Bill',
                        onPressed: _deleteBill,
                      ),
                    ],
                  )
                : const SizedBox.shrink(),
            orElse: () => const SizedBox.shrink(),
          ),
        ],
      ),
      body: billAsync.when(
        data: (bill) {
          if (bill == null) return const Center(child: Text('Bill not found.'));

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              // Header Card
              Card(
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                  side: BorderSide(color: Colors.grey.shade300),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(bill.billNumber, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                              const SizedBox(height: 2),
                              Text('Period: ${DateHelper.formatBillingPeriod(bill.billingMonth, bill.billingYear)}',
                                  style: const TextStyle(fontSize: 12, color: Colors.grey)),
                            ],
                          ),
                          StatusBadge(status: bill.status),
                        ],
                      ),
                      const SizedBox(height: 16),
                      const Divider(),
                      const SizedBox(height: 8),
                      _buildRow('Room Number:', bill.roomNumber),
                      _buildRow('Tenant Name:', bill.tenantName),
                      _buildRow('Bill Date:', DateHelper.formatEpoch(bill.billDateEpoch)),
                      _buildRow('Payment Due:', DateHelper.formatEpoch(bill.dueDateEpoch), isDue: true),
                      if (bill.notes != null && bill.notes!.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        _buildRow('Notes:', bill.notes!),
                      ],
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Line Items Breakdown
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'ITEMIZED CHARGES',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.grey.shade700),
                  ),
                  TextButton.icon(
                    onPressed: () => _showEditBillDialog(bill),
                    icon: const Icon(Icons.edit, size: 16),
                    label: const Text('Edit Amounts', style: TextStyle(fontSize: 12)),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Card(
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                  side: BorderSide(color: Colors.grey.shade300),
                ),
                child: ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: bill.lineItems.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (context, index) {
                    final item = bill.lineItems[index];
                    final isElec = item.category == 'ELECTRICITY';

                    return Column(
                      children: [
                        ListTile(
                          title: Text(item.description, style: const TextStyle(fontSize: 14)),
                          subtitle: Text(item.category, style: const TextStyle(fontSize: 11, color: Colors.grey)),
                          trailing: Text(
                            CurrencyHelper.formatPaise(item.amountPaise, showDecimals: true),
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 14,
                              color: item.amountPaise < 0 ? Colors.green.shade700 : null,
                            ),
                          ),
                        ),
                        if (isElec)
                          Padding(
                            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.end,
                              children: [
                                OutlinedButton.icon(
                                  style: OutlinedButton.styleFrom(
                                    visualDensity: VisualDensity.compact,
                                    foregroundColor: Colors.deepOrange.shade800,
                                    side: BorderSide(color: Colors.orange.shade300),
                                  ),
                                  onPressed: () => _shareElectricityPdf(bill),
                                  icon: const Icon(Icons.bolt, size: 16),
                                  label: const Text('Electricity Receipt Only', style: TextStyle(fontSize: 12)),
                                ),
                              ],
                            ),
                          ),
                      ],
                    );
                  },
                ),
              ),
              const SizedBox(height: 16),

              // Totals
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
                    children: [
                      if (bill.previousBalancePaise > 0) ...[
                        _buildTotalRow('Previous Outstanding:', CurrencyHelper.formatPaise(bill.previousBalancePaise),
                            color: AppColors.error),
                        const SizedBox(height: 4),
                      ],
                      _buildTotalRow('Gross Bill Amount:', CurrencyHelper.formatPaise(bill.totalDuePaise),
                          isBold: true, fontSize: 14),
                      if (bill.rentAdvanceAppliedPaise > 0) ...[
                        const SizedBox(height: 4),
                        _buildTotalRow('Rent Advance Applied:', '-${CurrencyHelper.formatPaise(bill.rentAdvanceAppliedPaise)}',
                            color: Colors.green.shade700),
                      ],
                      if (bill.electricityAdvanceAppliedPaise > 0) ...[
                        const SizedBox(height: 4),
                        _buildTotalRow('Elec Advance Applied:', '-${CurrencyHelper.formatPaise(bill.electricityAdvanceAppliedPaise)}',
                            color: Colors.green.shade700),
                      ],
                      const Divider(height: 14),
                      _buildTotalRow('Net Amount Due:', CurrencyHelper.formatPaise(bill.netAmountDuePaise),
                          isBold: true, fontSize: 15),
                      if (bill.amountPaidPaise > 0) ...[
                        const SizedBox(height: 4),
                        _buildTotalRow('Amount Paid:', CurrencyHelper.formatPaise(bill.amountPaidPaise),
                            color: Colors.green),
                      ],
                      const Divider(height: 16),
                      _buildTotalRow(
                        'Remaining Balance:',
                        CurrencyHelper.formatPaise(bill.remainingBalancePaise),
                        isBold: true,
                        fontSize: 16,
                        color: bill.remainingBalancePaise > 0 ? AppColors.error : AppColors.success,
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),

              // Action Buttons
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => _showShareOptions(bill),
                      icon: const Icon(Icons.share),
                      label: const Text('Share PDF'),
                    ),
                  ),
                  if (bill.remainingBalancePaise > 0) ...[
                    const SizedBox(width: 12),
                    Expanded(
                      child: FilledButton.icon(
                        onPressed: () => context.push(
                          '/payments/record?tenancyId=${bill.tenancyId}&billId=${bill.id}&rentAmount=${bill.outstandingRentPaise}&elecAmount=${bill.outstandingElectricityPaise}&amount=${bill.remainingBalancePaise}&roomId=${bill.roomId}',
                        ),
                        icon: const Icon(Icons.payment),
                        label: const Text('Record Payment'),
                      ),
                    ),
                  ],
                ],
              ),
            ],
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, _) => Center(child: Text('Error: $err')),
      ),
    );
  }

  Widget _buildRow(String label, String value, {bool isDue = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontSize: 13, color: Colors.grey)),
          Text(
            value,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: isDue ? AppColors.error : Colors.black87,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTotalRow(String label, String value, {bool isBold = false, double fontSize = 13, Color? color}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: TextStyle(fontSize: fontSize, fontWeight: isBold ? FontWeight.bold : FontWeight.normal)),
        Text(
          value,
          style: TextStyle(
            fontSize: fontSize,
            fontWeight: isBold ? FontWeight.bold : FontWeight.w600,
            color: color ?? Colors.black87,
          ),
        ),
      ],
    );
  }
}

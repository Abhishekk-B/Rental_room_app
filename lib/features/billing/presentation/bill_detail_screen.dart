import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/services/pdf_invoice_service.dart';
import '../../../core/utils/currency_helper.dart';
import '../../../core/utils/date_helper.dart';
import '../../../core/widgets/status_badge.dart';
import '../providers/billing_provider.dart';

class BillDetailScreen extends ConsumerStatefulWidget {
  final String billId;

  const BillDetailScreen({Key? key, required this.billId}) : super(key: key);

  @override
  ConsumerState<BillDetailScreen> createState() => _BillDetailScreenState();
}

class _BillDetailScreenState extends ConsumerState<BillDetailScreen> {
  bool _isExporting = false;

  Future<void> _sharePdf(bill) async {
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

  @override
  Widget build(BuildContext context) {
    final billAsync = ref.watch(billDetailProvider(widget.billId));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Invoice Details'),
        actions: [
          billAsync.maybeWhen(
            data: (bill) => bill != null
                ? IconButton(
                    icon: _isExporting
                        ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                        : const Icon(Icons.share_outlined),
                    tooltip: 'Share PDF Invoice',
                    onPressed: () => _sharePdf(bill),
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
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Line Items Breakdown
              Text(
                'ITEMIZED CHARGES',
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
                  itemCount: bill.lineItems.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (context, index) {
                    final item = bill.lineItems[index];
                    return ListTile(
                      title: Text(item.description, style: const TextStyle(fontSize: 14)),
                      subtitle: Text(item.category, style: const TextStyle(fontSize: 11, color: Colors.grey)),
                      trailing: Text(
                        CurrencyHelper.formatPaise(item.amountPaise, showDecimals: true),
                        style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                      ),
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
                      _buildTotalRow('Total Amount Due:', CurrencyHelper.formatPaise(bill.totalDuePaise),
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
                      onPressed: () => _sharePdf(bill),
                      icon: const Icon(Icons.share),
                      label: const Text('Share PDF'),
                    ),
                  ),
                  if (bill.remainingBalancePaise > 0) ...[
                    const SizedBox(width: 12),
                    Expanded(
                      child: FilledButton.icon(
                        onPressed: () => context.push(
                          '/payments/record?tenancyId=${bill.tenancyId}&billId=${bill.id}&amount=${bill.remainingBalancePaise}',
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

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/services/pdf_invoice_service.dart';
import '../../../core/utils/currency_helper.dart';
import '../../../core/utils/date_helper.dart';
import '../../../core/widgets/empty_state.dart';
import '../providers/payments_provider.dart';

class PaymentListScreen extends ConsumerWidget {
  const PaymentListScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final paymentsAsync = ref.watch(paymentsListProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Payment Receipts', style: TextStyle(fontWeight: FontWeight.bold)),
      ),
      body: paymentsAsync.when(
        data: (payments) {
          if (payments.isEmpty) {
            return EmptyStateView(
              icon: Icons.payments_outlined,
              title: 'No Payments Recorded',
              message: 'Record tenant payments to track collections and clear outstanding dues.',
              buttonText: 'Record Payment',
              onAction: () => context.push('/payments/record'),
            );
          }

          return RefreshIndicator(
            onRefresh: () async => ref.refresh(paymentsListProvider),
            child: ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: payments.length,
              itemBuilder: (context, index) {
                final payment = payments[index];
                return Card(
                  elevation: 0,
                  margin: const EdgeInsets.only(bottom: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                    side: BorderSide(color: Colors.grey.shade300),
                  ),
                  child: ListTile(
                    contentPadding: const EdgeInsets.all(16),
                    leading: const CircleAvatar(
                      backgroundColor: Color(0xFFE8F5E9),
                      child: Icon(Icons.check, color: Color(0xFF2E7D32)),
                    ),
                    title: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          '${payment.tenantName} (${payment.roomNumber})',
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                        ),
                        Text(
                          CurrencyHelper.formatPaise(payment.amountPaise),
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                            color: Color(0xFF2E7D32),
                          ),
                        ),
                      ],
                    ),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 4),
                        Text('Receipt: ${payment.receiptNumber} • ${DateHelper.formatEpoch(payment.paymentDateEpoch)}'),
                        Text('Method: ${payment.paymentMethod}${payment.transactionRef != null ? " (${payment.transactionRef})" : ""}'),
                      ],
                    ),
                    trailing: IconButton(
                      icon: const Icon(Icons.share_outlined, size: 20),
                      tooltip: 'Share Receipt PDF',
                      onPressed: () async {
                        final bytes = await PdfInvoiceService.generatePaymentReceiptPdf(payment: payment);
                        await PdfInvoiceService.sharePdf(bytes, '${payment.receiptNumber}.pdf');
                      },
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
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push('/payments/record'),
        icon: const Icon(Icons.add),
        label: const Text('Record Payment'),
      ),
    );
  }
}

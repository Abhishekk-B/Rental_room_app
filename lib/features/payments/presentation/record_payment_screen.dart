import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/utils/currency_helper.dart';
import '../../../core/utils/date_helper.dart';
import '../../billing/providers/billing_provider.dart';
import '../../dashboard/providers/dashboard_provider.dart';
import '../../tenants/providers/tenants_provider.dart';
import '../providers/payments_provider.dart';

class RecordPaymentScreen extends ConsumerStatefulWidget {
  final String? preselectedTenancyId;
  final String? preselectedBillId;
  final String? prefilledAmountPaise;

  const RecordPaymentScreen({
    Key? key,
    this.preselectedTenancyId,
    this.preselectedBillId,
    this.prefilledAmountPaise,
  }) : super(key: key);

  @override
  ConsumerState<RecordPaymentScreen> createState() => _RecordPaymentScreenState();
}

class _RecordPaymentScreenState extends ConsumerState<RecordPaymentScreen> {
  final _formKey = GlobalKey<FormState>();
  String? _selectedTenancyId;
  final _amountCtrl = TextEditingController();
  final _refCtrl = TextEditingController();
  final _notesCtrl = TextEditingController();
  String _paymentMethod = 'UPI';
  DateTime _paymentDate = DateTime.now();
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _selectedTenancyId = widget.preselectedTenancyId;
    if (widget.prefilledAmountPaise != null) {
      final paise = int.tryParse(widget.prefilledAmountPaise!) ?? 0;
      if (paise > 0) {
        _amountCtrl.text = CurrencyHelper.paiseToRupeesString(paise);
      }
    }
  }

  @override
  void dispose() {
    _amountCtrl.dispose();
    _refCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  Future<void> _record() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedTenancyId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a tenant.')),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final amountPaise = CurrencyHelper.parseRupeesToPaise(_amountCtrl.text);

      final receipt = await ref.read(paymentDaoProvider).recordPayment(
        tenancyId: _selectedTenancyId!,
        amountPaise: amountPaise,
        paymentDateEpoch: _paymentDate.millisecondsSinceEpoch,
        paymentMethod: _paymentMethod,
        transactionRef: _refCtrl.text,
        specificBillId: widget.preselectedBillId,
        notes: _notesCtrl.text,
      );

      ref.invalidate(paymentsListProvider);
      ref.invalidate(billsListProvider);
      ref.invalidate(dashboardSummaryProvider);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Payment recorded! Receipt: $receipt')),
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
    final tenantsAsync = ref.watch(tenantsListProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Record Payment'),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // Select Tenant
            tenantsAsync.when(
              data: (tenants) {
                final activeTenants = tenants.where((t) => t.activeTenancyId != null).toList();
                return DropdownButtonFormField<String>(
                  value: _selectedTenancyId,
                  decoration: const InputDecoration(
                    labelText: 'Tenant (Active Occupants) *',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.person),
                  ),
                  items: activeTenants.map((t) {
                    return DropdownMenuItem(
                      value: t.activeTenancyId,
                      child: Text('${t.fullName} (${t.activeRoomNumber})'),
                    );
                  }).toList(),
                  onChanged: (val) => setState(() => _selectedTenancyId = val),
                  validator: (v) => v == null ? 'Please select a tenant' : null,
                );
              },
              loading: () => const LinearProgressIndicator(),
              error: (e, _) => Text('Error: $e'),
            ),
            const SizedBox(height: 16),

            // Amount Received
            TextFormField(
              controller: _amountCtrl,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Amount Received (₹) *',
                hintText: 'e.g. 8500',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.currency_rupee),
              ),
              validator: (v) => (v == null || CurrencyHelper.parseRupeesToPaise(v) <= 0) ? 'Required' : null,
            ),
            const SizedBox(height: 16),

            // Payment Date
            ListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(4),
                side: BorderSide(color: Colors.grey.shade400),
              ),
              leading: const Icon(Icons.calendar_today),
              title: const Text('Payment Date', style: TextStyle(fontSize: 12, color: Colors.grey)),
              subtitle: Text(DateHelper.formatDate(_paymentDate), style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              trailing: const Icon(Icons.arrow_drop_down),
              onTap: () async {
                final picked = await showDatePicker(
                  context: context,
                  initialDate: _paymentDate,
                  firstDate: DateTime(2020),
                  lastDate: DateTime.now(),
                );
                if (picked != null) setState(() => _paymentDate = picked);
              },
            ),
            const SizedBox(height: 16),

            // Payment Method
            DropdownButtonFormField<String>(
              value: _paymentMethod,
              decoration: const InputDecoration(
                labelText: 'Payment Method *',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.account_balance_wallet_outlined),
              ),
              items: const [
                DropdownMenuItem(value: 'UPI', child: Text('UPI (Google Pay, PhonePe, Paytm)')),
                DropdownMenuItem(value: 'CASH', child: Text('Cash')),
                DropdownMenuItem(value: 'BANK_TRANSFER', child: Text('Bank Transfer (NEFT / IMPS)')),
                DropdownMenuItem(value: 'CHEQUE', child: Text('Cheque')),
                DropdownMenuItem(value: 'OTHER', child: Text('Other')),
              ],
              onChanged: (val) {
                if (val != null) setState(() => _paymentMethod = val);
              },
            ),
            const SizedBox(height: 16),

            // Transaction Ref
            TextFormField(
              controller: _refCtrl,
              decoration: const InputDecoration(
                labelText: 'UPI Ref / Transaction Number (Optional)',
                hintText: 'e.g. 412356789012',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.tag),
              ),
            ),
            const SizedBox(height: 16),

            TextFormField(
              controller: _notesCtrl,
              maxLines: 2,
              decoration: const InputDecoration(
                labelText: 'Remarks / Notes (Optional)',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.note_outlined),
              ),
            ),
            const SizedBox(height: 24),

            FilledButton.icon(
              onPressed: _isLoading ? null : _record,
              icon: _isLoading ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.check),
              label: const Text('Record & Generate Receipt'),
              style: FilledButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 14)),
            ),
          ],
        ),
      ),
    );
  }
}

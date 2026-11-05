import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/utils/currency_helper.dart';
import '../../../core/utils/date_helper.dart';
import '../../billing/providers/billing_provider.dart';
import '../../dashboard/providers/dashboard_provider.dart';
import '../../rooms/providers/rooms_provider.dart';
import '../../tenants/providers/tenants_provider.dart';
import '../providers/payments_provider.dart';

class RecordPaymentScreen extends ConsumerStatefulWidget {
  final String? preselectedTenancyId;
  final String? preselectedBillId;
  final String? prefilledRentAmountPaise;
  final String? prefilledElecAmountPaise;
  final String? prefilledAmountPaise;
  final String? preselectedRoomId;

  const RecordPaymentScreen({
    Key? key,
    this.preselectedTenancyId,
    this.preselectedBillId,
    this.prefilledRentAmountPaise,
    this.prefilledElecAmountPaise,
    this.prefilledAmountPaise,
    this.preselectedRoomId,
  }) : super(key: key);

  @override
  ConsumerState<RecordPaymentScreen> createState() => _RecordPaymentScreenState();
}

class _RecordPaymentScreenState extends ConsumerState<RecordPaymentScreen> {
  final _formKey = GlobalKey<FormState>();
  String? _selectedTenancyId;
  final _rentAmountCtrl = TextEditingController(text: '0');
  final _elecAmountCtrl = TextEditingController(text: '0');
  final _totalAmountCtrl = TextEditingController(text: '0');
  final _refCtrl = TextEditingController();
  final _notesCtrl = TextEditingController();
  String _paymentMethod = 'CASH';
  DateTime _paymentDate = DateTime.now();
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _selectedTenancyId = widget.preselectedTenancyId;
    _paymentMethod = 'CASH';

    if (widget.prefilledRentAmountPaise != null) {
      final rentPaise = int.tryParse(widget.prefilledRentAmountPaise!) ?? 0;
      _rentAmountCtrl.text = CurrencyHelper.paiseToRupeesString(rentPaise);
    }
    if (widget.prefilledElecAmountPaise != null) {
      final elecPaise = int.tryParse(widget.prefilledElecAmountPaise!) ?? 0;
      _elecAmountCtrl.text = CurrencyHelper.paiseToRupeesString(elecPaise);
    }

    if (widget.prefilledRentAmountPaise == null && widget.prefilledElecAmountPaise == null && widget.prefilledAmountPaise != null) {
      final paise = int.tryParse(widget.prefilledAmountPaise!) ?? 0;
      _totalAmountCtrl.text = CurrencyHelper.paiseToRupeesString(paise);
    } else {
      _syncTotalFromCategories();
    }
  }

  @override
  void dispose() {
    _rentAmountCtrl.dispose();
    _elecAmountCtrl.dispose();
    _totalAmountCtrl.dispose();
    _refCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  void _syncTotalFromCategories() {
    final rentPaise = CurrencyHelper.parseRupeesToPaise(_rentAmountCtrl.text);
    final elecPaise = CurrencyHelper.parseRupeesToPaise(_elecAmountCtrl.text);
    final total = rentPaise + elecPaise;
    _totalAmountCtrl.text = CurrencyHelper.paiseToRupeesString(total);
    setState(() {});
  }

  Future<void> _record() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedTenancyId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a tenant.')),
      );
      return;
    }

    final rentPaise = CurrencyHelper.parseRupeesToPaise(_rentAmountCtrl.text);
    final elecPaise = CurrencyHelper.parseRupeesToPaise(_elecAmountCtrl.text);
    int totalPaise = CurrencyHelper.parseRupeesToPaise(_totalAmountCtrl.text);

    if (totalPaise <= 0) {
      totalPaise = rentPaise + elecPaise;
    }

    if (totalPaise <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Payment amount must be greater than ₹0.')),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final receipt = await ref.read(paymentDaoProvider).recordPayment(
        tenancyId: _selectedTenancyId!,
        amountPaise: totalPaise,
        rentAmountPaidPaise: rentPaise,
        electricityAmountPaidPaise: elecPaise,
        paymentDateEpoch: _paymentDate.millisecondsSinceEpoch,
        paymentMethod: _paymentMethod,
        transactionRef: _refCtrl.text,
        specificBillId: widget.preselectedBillId,
        notes: _notesCtrl.text,
      );

      ref.invalidate(paymentsListProvider);
      ref.invalidate(billsListProvider);
      ref.invalidate(dashboardSummaryProvider);

      String? targetRoomId = widget.preselectedRoomId;
      if (targetRoomId == null && _selectedTenancyId != null) {
        final tenants = ref.read(tenantsListProvider).valueOrNull;
        if (tenants != null) {
          final t = tenants.where((element) => element.activeTenancyId == _selectedTenancyId).firstOrNull;
          targetRoomId = t?.activeRoomId;
        }
      }

      if (targetRoomId != null) {
        ref.invalidate(roomBillsProvider(targetRoomId));
        ref.invalidate(roomPaymentsProvider(targetRoomId));
        ref.invalidate(roomDetailProvider(targetRoomId));
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Payment recorded! Receipt: $receipt')),
        );
        if (targetRoomId != null) {
          context.go('/rooms/$targetRoomId');
        } else {
          Navigator.pop(context);
        }
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
            const SizedBox(height: 20),

            // Separate Rent & Electricity Payments Card
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Payment Category Breakdown',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'Enter amounts for rent and/or electricity. Use "Reset to 0" to quickly clear either field.',
                      style: TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                    const Divider(height: 24),

                    // 1. Rent Amount
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: _rentAmountCtrl,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(
                              labelText: 'Room Rent Amount (₹)',
                              prefixText: '₹ ',
                              border: OutlineInputBorder(),
                              prefixIcon: Icon(Icons.home_outlined),
                            ),
                            onChanged: (_) => _syncTotalFromCategories(),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: OutlinedButton(
                            onPressed: () {
                              _rentAmountCtrl.text = '0';
                              _syncTotalFromCategories();
                            },
                            style: OutlinedButton.styleFrom(
                              foregroundColor: Colors.red.shade700,
                              side: BorderSide(color: Colors.red.shade300),
                            ),
                            child: const Text('Reset to 0'),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // 2. Electricity Amount
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: _elecAmountCtrl,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(
                              labelText: 'Electricity Bill Amount (₹)',
                              prefixText: '₹ ',
                              border: OutlineInputBorder(),
                              prefixIcon: Icon(Icons.bolt_outlined),
                            ),
                            onChanged: (_) => _syncTotalFromCategories(),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: OutlinedButton(
                            onPressed: () {
                              _elecAmountCtrl.text = '0';
                              _syncTotalFromCategories();
                            },
                            style: OutlinedButton.styleFrom(
                              foregroundColor: Colors.red.shade700,
                              side: BorderSide(color: Colors.red.shade300),
                            ),
                            child: const Text('Reset to 0'),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // Total Payment Summary Banner
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppColors.primaryContainer.withOpacity(0.3),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('Total Payment Received:', style: TextStyle(fontWeight: FontWeight.w600)),
                          Text(
                            '₹ ${_totalAmountCtrl.text}',
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: AppColors.primary),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
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
                DropdownMenuItem(value: 'CASH', child: Text('Cash')),
                DropdownMenuItem(value: 'UPI', child: Text('UPI (Google Pay, PhonePe, Paytm)')),
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
              icon: _isLoading ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Icon(Icons.check),
              label: const Text('Record & Generate Receipt'),
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(50),
              ),
            ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }
}

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/services/media_storage_service.dart';
import '../../../core/utils/currency_helper.dart';
import '../../../core/utils/date_helper.dart';
import '../providers/expenses_provider.dart';

class AddExpenseScreen extends ConsumerStatefulWidget {
  const AddExpenseScreen({Key? key}) : super(key: key);

  @override
  ConsumerState<AddExpenseScreen> createState() => _AddExpenseScreenState();
}

class _AddExpenseScreenState extends ConsumerState<AddExpenseScreen> {
  final _formKey = GlobalKey<FormState>();
  final _amountCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  String _category = 'MAINTENANCE';
  DateTime _expenseDate = DateTime.now();
  File? _receiptImage;
  bool _isLoading = false;

  @override
  void dispose() {
    _amountCtrl.dispose();
    _descCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickReceipt(ImageSource source) async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(source: source, imageQuality: 75);
    if (picked != null) {
      setState(() => _receiptImage = File(picked.path));
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);

    try {
      final amountPaise = CurrencyHelper.parseRupeesToPaise(_amountCtrl.text);
      String? receiptPath;
      if (_receiptImage != null) {
        receiptPath = await MediaStorageService.saveMediaLocally(_receiptImage!, subfolder: 'receipts');
      }

      final expenseId = 'exp_${DateTime.now().millisecondsSinceEpoch}';

      await ref.read(expenseDaoProvider).addExpense(
        id: expenseId,
        propertyId: AppConstants.defaultPropertyId,
        category: _category,
        amountPaise: amountPaise,
        expenseDateEpoch: _expenseDate.millisecondsSinceEpoch,
        description: _descCtrl.text,
        receiptImagePath: receiptPath,
      );

      ref.invalidate(expensesListProvider);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Expense logged successfully')),
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
    return Scaffold(
      appBar: AppBar(
        title: const Text('Add Property Expense'),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // Category
            DropdownButtonFormField<String>(
              value: _category,
              decoration: const InputDecoration(
                labelText: 'Expense Category *',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.category_outlined),
              ),
              items: const [
                DropdownMenuItem(value: 'MAINTENANCE', child: Text('General Maintenance')),
                DropdownMenuItem(value: 'REPAIR', child: Text('Repairs / Fixes')),
                DropdownMenuItem(value: 'ELECTRICITY_COMMON', child: Text('Common Area Electricity')),
                DropdownMenuItem(value: 'PLUMBING', child: Text('Plumbing Work')),
                DropdownMenuItem(value: 'CLEANING', child: Text('Housekeeping & Cleaning')),
                DropdownMenuItem(value: 'OTHER', child: Text('Other Property Expense')),
              ],
              onChanged: (val) {
                if (val != null) setState(() => _category = val);
              },
            ),
            const SizedBox(height: 16),

            // Amount
            TextFormField(
              controller: _amountCtrl,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Expense Amount (₹) *',
                hintText: 'e.g. 1200',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.currency_rupee),
              ),
              validator: (v) => (v == null || CurrencyHelper.parseRupeesToPaise(v) <= 0) ? 'Required' : null,
            ),
            const SizedBox(height: 16),

            // Description
            TextFormField(
              controller: _descCtrl,
              decoration: const InputDecoration(
                labelText: 'Description / Purpose *',
                hintText: 'e.g. Replaced water motor capacitor',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.description_outlined),
              ),
              validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
            ),
            const SizedBox(height: 16),

            // Date
            ListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(4),
                side: BorderSide(color: Colors.grey.shade400),
              ),
              leading: const Icon(Icons.calendar_today),
              title: const Text('Expense Date', style: TextStyle(fontSize: 12, color: Colors.grey)),
              subtitle: Text(DateHelper.formatDate(_expenseDate), style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              trailing: const Icon(Icons.arrow_drop_down),
              onTap: () async {
                final picked = await showDatePicker(
                  context: context,
                  initialDate: _expenseDate,
                  firstDate: DateTime(2020),
                  lastDate: DateTime.now(),
                );
                if (picked != null) setState(() => _expenseDate = picked);
              },
            ),
            const SizedBox(height: 16),

            // Receipt Photo
            OutlinedButton.icon(
              onPressed: () => _pickReceipt(ImageSource.camera),
              icon: const Icon(Icons.receipt_long_outlined),
              label: Text(_receiptImage == null ? 'Attach Receipt / Bill Photo (Optional)' : 'Receipt Attached ✓'),
            ),
            const SizedBox(height: 24),

            FilledButton.icon(
              onPressed: _isLoading ? null : _save,
              icon: _isLoading ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.save),
              label: const Text('Save Expense'),
              style: FilledButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 14)),
            ),
          ],
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/utils/currency_helper.dart';
import '../../../core/utils/date_helper.dart';
import '../../rooms/providers/rooms_provider.dart';
import '../providers/tenants_provider.dart';

class AssignTenancyScreen extends ConsumerStatefulWidget {
  final String? preselectedRoomId;
  final String? preselectedTenantId;

  const AssignTenancyScreen({
    Key? key,
    this.preselectedRoomId,
    this.preselectedTenantId,
  }) : super(key: key);

  @override
  ConsumerState<AssignTenancyScreen> createState() => _AssignTenancyScreenState();
}

class _AssignTenancyScreenState extends ConsumerState<AssignTenancyScreen> {
  final _formKey = GlobalKey<FormState>();
  String? _selectedRoomId;
  String? _selectedTenantId;
  DateTime _moveInDate = DateTime.now();
  final _agreedRentCtrl = TextEditingController();
  final _depositCtrl = TextEditingController();
  int _billingDueDay = 5; // Default 5th of every month
  bool _isLoading = false;
  bool _prefilledHandled = false;

  @override
  void initState() {
    super.initState();
    _selectedRoomId = widget.preselectedRoomId;
    _selectedTenantId = widget.preselectedTenantId;
  }

  @override
  void dispose() {
    _agreedRentCtrl.dispose();
    _depositCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedRoomId == null || _selectedTenantId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select both a room and a tenant.')),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final rentPaise = CurrencyHelper.parseRupeesToPaise(_agreedRentCtrl.text);
      final depositPaise = CurrencyHelper.parseRupeesToPaise(_depositCtrl.text);
      final tenancyId = 'tenancy_${DateTime.now().millisecondsSinceEpoch}';

      await ref.read(tenantDaoProvider).assignTenancy(
        tenancyId: tenancyId,
        tenantId: _selectedTenantId!,
        roomId: _selectedRoomId!,
        moveInDateEpoch: _moveInDate.millisecondsSinceEpoch,
        agreedRentPaise: rentPaise,
        securityDepositPaise: depositPaise,
        billingDueDay: _billingDueDay,
      );

      ref.invalidate(roomsListProvider);
      ref.invalidate(tenantsListProvider);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Tenant successfully moved in and assigned!')),
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
    final roomsAsync = ref.watch(roomsListProvider);
    final tenantsAsync = ref.watch(tenantsListProvider);

    // Auto-fill rent from preselected room
    roomsAsync.whenData((rooms) {
      if (_selectedRoomId != null && !_prefilledHandled) {
        final match = rooms.where((r) => r.id == _selectedRoomId).firstOrNull;
        if (match != null) {
          _prefilledHandled = true;
          _agreedRentCtrl.text = CurrencyHelper.paiseToRupeesString(match.defaultRentPaise);
          _depositCtrl.text = CurrencyHelper.paiseToRupeesString(match.defaultRentPaise * 2);
        }
      }
    });

    return Scaffold(
      appBar: AppBar(
        title: const Text('Assign Room / Move-In'),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // Select Room
            roomsAsync.when(
              data: (rooms) {
                final vacantRooms = rooms.where((r) => !r.isOccupied || r.id == widget.preselectedRoomId).toList();
                return DropdownButtonFormField<String>(
                  value: _selectedRoomId,
                  decoration: const InputDecoration(
                    labelText: 'Select Room *',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.meeting_room_outlined),
                  ),
                  items: vacantRooms.map((r) {
                    return DropdownMenuItem(
                      value: r.id,
                      child: Text('${r.roomNumber} (Default: ${CurrencyHelper.formatPaise(r.defaultRentPaise)})'),
                    );
                  }).toList(),
                  onChanged: (val) {
                    setState(() {
                      _selectedRoomId = val;
                      final selected = rooms.firstWhere((r) => r.id == val);
                      _agreedRentCtrl.text = CurrencyHelper.paiseToRupeesString(selected.defaultRentPaise);
                      _depositCtrl.text = CurrencyHelper.paiseToRupeesString(selected.defaultRentPaise * 2);
                    });
                  },
                  validator: (v) => v == null ? 'Please select a room' : null,
                );
              },
              loading: () => const LinearProgressIndicator(),
              error: (e, _) => Text('Error loading rooms: $e'),
            ),
            const SizedBox(height: 16),

            // Select Tenant
            tenantsAsync.when(
              data: (tenants) {
                final eligibleTenants = tenants.where((t) => t.activeTenancyId == null || t.id == widget.preselectedTenantId).toList();
                return DropdownButtonFormField<String>(
                  value: _selectedTenantId,
                  decoration: const InputDecoration(
                    labelText: 'Select Tenant *',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.person_outline),
                  ),
                  items: eligibleTenants.map((t) {
                    return DropdownMenuItem(
                      value: t.id,
                      child: Text('${t.fullName} (${t.phoneNumber})'),
                    );
                  }).toList(),
                  onChanged: (val) => setState(() => _selectedTenantId = val),
                  validator: (v) => v == null ? 'Please select a tenant' : null,
                );
              },
              loading: () => const LinearProgressIndicator(),
              error: (e, _) => Text('Error loading tenants: $e'),
            ),
            const SizedBox(height: 16),

            // Move-In Date Picker
            ListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(4),
                side: BorderSide(color: Colors.grey.shade400),
              ),
              leading: const Icon(Icons.calendar_today_outlined),
              title: const Text('Move-In Date', style: TextStyle(fontSize: 12, color: Colors.grey)),
              subtitle: Text(DateHelper.formatDate(_moveInDate), style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              trailing: const Icon(Icons.arrow_drop_down),
              onTap: () async {
                final picked = await showDatePicker(
                  context: context,
                  initialDate: _moveInDate,
                  firstDate: DateTime(2020),
                  lastDate: DateTime(2035),
                );
                if (picked != null) setState(() => _moveInDate = picked);
              },
            ),
            const SizedBox(height: 16),

            // Billing Due Day / Cycle
            DropdownButtonFormField<int>(
              value: _billingDueDay,
              decoration: const InputDecoration(
                labelText: 'Monthly Billing Cycle / Due Day *',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.event_repeat),
              ),
              items: const [
                DropdownMenuItem(value: 1, child: Text('1st of every month')),
                DropdownMenuItem(value: 5, child: Text('5th of every month (Standard)')),
                DropdownMenuItem(value: 10, child: Text('10th of every month')),
                DropdownMenuItem(value: 15, child: Text('15th of every month')),
                DropdownMenuItem(value: 20, child: Text('20th of every month')),
                DropdownMenuItem(value: 0, child: Text('End of month')),
              ],
              onChanged: (val) {
                if (val != null) setState(() => _billingDueDay = val);
              },
            ),
            const SizedBox(height: 16),

            // Agreed Rent
            TextFormField(
              controller: _agreedRentCtrl,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Agreed Monthly Rent (₹) *',
                hintText: 'e.g. 8500',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.currency_rupee),
              ),
              validator: (v) => (v == null || CurrencyHelper.parseRupeesToPaise(v) <= 0) ? 'Enter valid rent' : null,
            ),
            const SizedBox(height: 16),

            // Security Deposit
            TextFormField(
              controller: _depositCtrl,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Security Deposit Paid (₹)',
                hintText: 'e.g. 17000',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.security_outlined),
              ),
            ),
            const SizedBox(height: 24),

            FilledButton.icon(
              onPressed: _isLoading ? null : _submit,
              icon: _isLoading ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Icon(Icons.check),
              label: const Text('Confirm Move-In'),
              style: FilledButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 14)),
            ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }
}

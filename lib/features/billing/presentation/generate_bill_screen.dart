import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/utils/currency_helper.dart';
import '../../../core/utils/date_helper.dart';
import '../../advances/providers/advance_provider.dart';
import '../../dashboard/providers/dashboard_provider.dart';
import '../../electricity/providers/electricity_provider.dart';
import '../../rooms/providers/rooms_provider.dart';
import '../domain/billing_engine.dart';
import '../providers/billing_provider.dart';

class GenerateBillScreen extends ConsumerStatefulWidget {
  final String? preselectedRoomId;

  const GenerateBillScreen({Key? key, this.preselectedRoomId}) : super(key: key);

  @override
  ConsumerState<GenerateBillScreen> createState() => _GenerateBillScreenState();
}

class _GenerateBillScreenState extends ConsumerState<GenerateBillScreen> {
  final _formKey = GlobalKey<FormState>();
  String? _selectedRoomId;
  RoomWithDetails? _selectedRoom;

  final _rentCtrl = TextEditingController();
  final _rentAdvAppliedCtrl = TextEditingController(text: '0');
  int _rentAdvAvailablePaise = 0;

  final _elecAmountCtrl = TextEditingController(text: '0');
  final _elecUnitsCtrl = TextEditingController(text: '0');
  final _elecAdvAppliedCtrl = TextEditingController(text: '0');
  int _elecAdvAvailablePaise = 0;

  final _additionalChargesCtrl = TextEditingController(text: '0');
  int _previousBalancePaise = 0;
  DateTime _dueDate = DateTime.now().add(const Duration(days: 5));
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _selectedRoomId = widget.preselectedRoomId;
  }

  @override
  void dispose() {
    _rentCtrl.dispose();
    _rentAdvAppliedCtrl.dispose();
    _elecAmountCtrl.dispose();
    _elecUnitsCtrl.dispose();
    _elecAdvAppliedCtrl.dispose();
    _additionalChargesCtrl.dispose();
    super.dispose();
  }

  Future<void> _onRoomSelected(RoomWithDetails room) async {
    setState(() {
      _selectedRoom = room;
      _rentCtrl.text = CurrencyHelper.paiseToRupeesString(room.agreedRentPaise ?? room.defaultRentPaise);
    });

    final period = ref.read(selectedPeriodProvider);

    if (room.activeTenancyId != null) {
      // 1. Fetch available Rent Advance & Electricity Advance independently
      final advances = await ref.read(advanceLedgerDaoProvider).getTenancyAdvancesOverview(room.activeTenancyId!);
      setState(() {
        _rentAdvAvailablePaise = advances.rentAdvance.availableBalancePaise;
        _elecAdvAvailablePaise = advances.electricityAdvance.availableBalancePaise;

        // Auto-suggest rent advance applied (up to rent charge)
        final rentPaise = room.agreedRentPaise ?? room.defaultRentPaise;
        final autoRentAdv = _rentAdvAvailablePaise >= rentPaise ? rentPaise : _rentAdvAvailablePaise;
        _rentAdvAppliedCtrl.text = CurrencyHelper.paiseToRupeesString(autoRentAdv);
      });

      // 2. Fetch previous outstanding dues
      final prev = await ref.read(billingDaoProvider).getPreviousOutstandingBalance(
        tenancyId: room.activeTenancyId!,
        month: period.month,
        year: period.year,
      );
      setState(() => _previousBalancePaise = prev);
    }

    // 3. Fetch allocated electricity if available
    final elecPaise = await ref.read(electricityDaoProvider).getAllocatedElectricityForRoom(
      roomId: room.id,
      month: period.month,
      year: period.year,
    );
    if (elecPaise != null) {
      setState(() {
        _elecAmountCtrl.text = CurrencyHelper.paiseToRupeesString(elecPaise);
        final autoElecAdv = _elecAdvAvailablePaise >= elecPaise ? elecPaise : _elecAdvAvailablePaise;
        _elecAdvAppliedCtrl.text = CurrencyHelper.paiseToRupeesString(autoElecAdv);
      });
    }
  }

  Future<void> _generateBill() async {
    if (!_formKey.currentState!.validate() || _selectedRoom == null) return;
    if (_selectedRoom!.activeTenancyId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Cannot generate bill: Room has no active tenant.')),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final period = ref.read(selectedPeriodProvider);
      final rentPaise = CurrencyHelper.parseRupeesToPaise(_rentCtrl.text);
      final rentAdvAppliedPaise = CurrencyHelper.parseRupeesToPaise(_rentAdvAppliedCtrl.text);

      final elecPaise = CurrencyHelper.parseRupeesToPaise(_elecAmountCtrl.text);
      final elecUnitsCenti = CurrencyHelper.parseReadingToCentiunits(_elecUnitsCtrl.text);
      final elecAdvAppliedPaise = CurrencyHelper.parseRupeesToPaise(_elecAdvAppliedCtrl.text);

      final additionalPaise = CurrencyHelper.parseRupeesToPaise(_additionalChargesCtrl.text);

      final input = BillCalculationInput(
        tenancyId: _selectedRoom!.activeTenancyId!,
        tenantName: _selectedRoom!.activeTenantName ?? 'Tenant',
        tenantPhone: _selectedRoom!.activeTenantPhone ?? '',
        roomId: _selectedRoom!.id,
        roomNumber: _selectedRoom!.roomNumber,
        billingMonth: period.month,
        billingYear: period.year,
        rentAmountPaise: rentPaise,
        rentAdvanceAvailablePaise: _rentAdvAvailablePaise,
        rentAdvanceAppliedPaise: rentAdvAppliedPaise,
        electricityUnitsCentiunits: elecUnitsCenti,
        electricityAmountPaise: elecPaise,
        electricityAdvanceAvailablePaise: _elecAdvAvailablePaise,
        electricityAdvanceAppliedPaise: elecAdvAppliedPaise,
        additionalChargesPaise: additionalPaise,
        previousBalancePaise: _previousBalancePaise,
        dueDateEpoch: _dueDate.millisecondsSinceEpoch,
      );

      final calculated = BillingEngine.calculateMonthlyBill(input);

      await ref.read(billingDaoProvider).saveMonthlyBill(calculated);

      ref.invalidate(billsListProvider);
      ref.invalidate(dashboardSummaryProvider);
      ref.invalidate(tenancyAdvancesProvider(_selectedRoom!.activeTenancyId!));

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Bill generated: ${calculated.billNumber}')),
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
    final roomsAsync = ref.watch(roomsListProvider);

    final rentPaise = CurrencyHelper.parseRupeesToPaise(_rentCtrl.text);
    final rentAdvAppliedPaise = CurrencyHelper.parseRupeesToPaise(_rentAdvAppliedCtrl.text).clamp(
      0,
      _rentAdvAvailablePaise < rentPaise ? _rentAdvAvailablePaise : rentPaise,
    );
    final outstandingRentPaise = rentPaise - rentAdvAppliedPaise;
    final remainingRentAdvPaise = _rentAdvAvailablePaise - rentAdvAppliedPaise;

    final elecPaise = CurrencyHelper.parseRupeesToPaise(_elecAmountCtrl.text);
    final elecAdvAppliedPaise = CurrencyHelper.parseRupeesToPaise(_elecAdvAppliedCtrl.text).clamp(
      0,
      _elecAdvAvailablePaise < elecPaise ? _elecAdvAvailablePaise : elecPaise,
    );
    final outstandingElecPaise = elecPaise - elecAdvAppliedPaise;
    final remainingElecAdvPaise = _elecAdvAvailablePaise - elecAdvAppliedPaise;

    final addPaise = CurrencyHelper.parseRupeesToPaise(_additionalChargesCtrl.text);
    final totalCurrentGrossPaise = rentPaise + elecPaise + addPaise;
    final totalAdvAppliedPaise = rentAdvAppliedPaise + elecAdvAppliedPaise;
    final netAmountDuePaise = totalCurrentGrossPaise + _previousBalancePaise - totalAdvAppliedPaise;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Generate Monthly Bill'),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // Period Badge
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.primaryContainer.withOpacity(0.3),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                'Billing Period: ${DateHelper.formatBillingPeriod(period.month, period.year)}',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
              ),
            ),
            const SizedBox(height: 16),

            // Select Occupied Room
            roomsAsync.when(
              data: (rooms) {
                final occupiedRooms = rooms.where((r) => r.isOccupied).toList();
                if (occupiedRooms.isEmpty) {
                  return const Card(
                    child: Padding(
                      padding: EdgeInsets.all(16),
                      child: Text('No occupied rooms available to generate bills for.'),
                    ),
                  );
                }

                return DropdownButtonFormField<String>(
                  value: _selectedRoomId,
                  decoration: const InputDecoration(
                    labelText: 'Select Occupied Room *',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.meeting_room),
                  ),
                  items: occupiedRooms.map((r) {
                    return DropdownMenuItem(
                      value: r.id,
                      child: Text('${r.roomNumber} - ${r.activeTenantName}'),
                    );
                  }).toList(),
                  onChanged: (val) {
                    if (val != null) {
                      _selectedRoomId = val;
                      final r = rooms.firstWhere((item) => item.id == val);
                      _onRoomSelected(r);
                    }
                  },
                  validator: (v) => v == null ? 'Please select a room' : null,
                );
              },
              loading: () => const LinearProgressIndicator(),
              error: (e, _) => Text('Error: $e'),
            ),
            const SizedBox(height: 20),

            // 1. INDEPENDENT ROOM RENT & RENT ADVANCE SECTION
            Card(
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
                side: BorderSide(color: AppColors.primary.withOpacity(0.3)),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('1. Room Rent', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: AppColors.primaryContainer,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            'Available Advance: ${CurrencyHelper.formatPaise(_rentAdvAvailablePaise)}',
                            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.primary),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _rentCtrl,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Monthly Room Rent Charge (₹) *',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.home),
                      ),
                      onChanged: (_) => setState(() {}),
                      validator: (v) => (v == null || CurrencyHelper.parseRupeesToPaise(v) <= 0) ? 'Required' : null,
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: _rentAdvAppliedCtrl,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(
                              labelText: 'Apply Rent Advance (₹)',
                              hintText: 'Deducted from Rent Advance only',
                              border: OutlineInputBorder(),
                              prefixIcon: Icon(Icons.account_balance_wallet_outlined),
                            ),
                            onChanged: (_) => setState(() {}),
                          ),
                        ),
                        const SizedBox(width: 8),
                        TextButton(
                          onPressed: () {
                            final maxApply = _rentAdvAvailablePaise >= rentPaise ? rentPaise : _rentAdvAvailablePaise;
                            _rentAdvAppliedCtrl.text = CurrencyHelper.paiseToRupeesString(maxApply);
                            setState(() {});
                          },
                          child: const Text('Apply Max'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Outstanding Rent: ${CurrencyHelper.formatPaise(outstandingRentPaise)}',
                            style: TextStyle(fontWeight: FontWeight.bold, color: outstandingRentPaise > 0 ? AppColors.error : AppColors.success, fontSize: 13)),
                        Text('Remaining Advance: ${CurrencyHelper.formatPaise(remainingRentAdvPaise)}',
                            style: const TextStyle(fontSize: 12, color: Colors.grey)),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // 2. INDEPENDENT ELECTRICITY & ELECTRICITY ADVANCE SECTION
            Card(
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
                side: BorderSide(color: Colors.amber.shade400),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('2. Electricity Charges', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: Colors.amber.shade100,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            'Available Advance: ${CurrencyHelper.formatPaise(_elecAdvAvailablePaise)}',
                            style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.amber.shade900),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: _elecAmountCtrl,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(
                              labelText: 'Electricity Charge (₹)',
                              border: OutlineInputBorder(),
                              prefixIcon: Icon(Icons.bolt),
                            ),
                            onChanged: (_) => setState(() {}),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextFormField(
                            controller: _elecUnitsCtrl,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(
                              labelText: 'Units Consumed',
                              border: OutlineInputBorder(),
                            ),
                            onChanged: (_) => setState(() {}),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: _elecAdvAppliedCtrl,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(
                              labelText: 'Apply Electricity Advance (₹)',
                              hintText: 'Deducted from Electricity Advance only',
                              border: OutlineInputBorder(),
                              prefixIcon: Icon(Icons.power_outlined),
                            ),
                            onChanged: (_) => setState(() {}),
                          ),
                        ),
                        const SizedBox(width: 8),
                        TextButton(
                          onPressed: () {
                            final maxApply = _elecAdvAvailablePaise >= elecPaise ? elecPaise : _elecAdvAvailablePaise;
                            _elecAdvAppliedCtrl.text = CurrencyHelper.paiseToRupeesString(maxApply);
                            setState(() {});
                          },
                          child: const Text('Apply Max'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Outstanding Electricity: ${CurrencyHelper.formatPaise(outstandingElecPaise)}',
                            style: TextStyle(fontWeight: FontWeight.bold, color: outstandingElecPaise > 0 ? Colors.deepOrange : AppColors.success, fontSize: 13)),
                        Text('Remaining Advance: ${CurrencyHelper.formatPaise(remainingElecAdvPaise)}',
                            style: const TextStyle(fontSize: 12, color: Colors.grey)),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Additional Charges
            TextFormField(
              controller: _additionalChargesCtrl,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Additional Charges (Maintenance, Water, etc.) (₹)',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.playlist_add),
              ),
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 16),

            // Due Date
            ListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(4),
                side: BorderSide(color: Colors.grey.shade400),
              ),
              leading: const Icon(Icons.calendar_today),
              title: const Text('Bill Due Date', style: TextStyle(fontSize: 12, color: Colors.grey)),
              subtitle: Text(DateHelper.formatDate(_dueDate), style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              trailing: const Icon(Icons.arrow_drop_down),
              onTap: () async {
                final picked = await showDatePicker(
                  context: context,
                  initialDate: _dueDate,
                  firstDate: DateTime.now(),
                  lastDate: DateTime(2035),
                );
                if (picked != null) setState(() => _dueDate = picked);
              },
            ),
            const SizedBox(height: 20),

            // Grand Total Bill Summary Card
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
                    _buildSummaryRow('Gross Current Charges:', CurrencyHelper.formatPaise(totalCurrentGrossPaise)),
                    if (_previousBalancePaise > 0)
                      _buildSummaryRow('Previous Dues:', CurrencyHelper.formatPaise(_previousBalancePaise), color: AppColors.error),
                    if (rentAdvAppliedPaise > 0)
                      _buildSummaryRow('Rent Advance Applied:', '- ${CurrencyHelper.formatPaise(rentAdvAppliedPaise)}', color: AppColors.primary),
                    if (elecAdvAppliedPaise > 0)
                      _buildSummaryRow('Electricity Advance Applied:', '- ${CurrencyHelper.formatPaise(elecAdvAppliedPaise)}', color: Colors.amber.shade900),
                    const Divider(height: 16),
                    _buildSummaryRow(
                      'Net Amount Due to Pay:',
                      CurrencyHelper.formatPaise(netAmountDuePaise),
                      isBold: true,
                      color: netAmountDuePaise > 0 ? AppColors.error : AppColors.success,
                      fontSize: 16,
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),

            FilledButton.icon(
              onPressed: _isLoading ? null : _generateBill,
              icon: _isLoading ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.receipt_long),
              label: const Text('Confirm & Generate Bill'),
              style: FilledButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 14)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryRow(String label, String value, {bool isBold = false, Color? color, double fontSize = 13}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2.5),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(fontSize: fontSize, color: Colors.grey.shade800)),
          Text(
            value,
            style: TextStyle(
              fontSize: fontSize,
              fontWeight: isBold ? FontWeight.bold : FontWeight.w600,
              color: color ?? Colors.black87,
            ),
          ),
        ],
      ),
    );
  }
}

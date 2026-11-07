import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/database/daos/room_dao.dart';
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
  bool _preselectedHandled = false;

  late int _billingMonth;
  late int _billingYear;

  // Rent & Advance
  final _rentCtrl = TextEditingController();
  final _rentAdvAppliedCtrl = TextEditingController(text: '0');
  int _rentAdvAvailablePaise = 0;

  // Electricity Sub-Meter Reading & Rate
  final _prevReadingCtrl = TextEditingController(text: '0');
  final _newReadingCtrl = TextEditingController();
  final _elecRateCtrl = TextEditingController(text: '10');
  final _elecAmountCtrl = TextEditingController(text: '0');
  final _elecUnitsCtrl = TextEditingController(text: '0');
  final _elecAdvAppliedCtrl = TextEditingController(text: '0');
  int _elecAdvAvailablePaise = 0;
  int _previousReadingCentiunits = 0;

  // Additional Charges & Due Date
  final _additionalChargesCtrl = TextEditingController(text: '0');
  int _previousBalancePaise = 0;
  DateTime _dueDate = DateTime.now().add(const Duration(days: 5));
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _selectedRoomId = widget.preselectedRoomId;
    final now = DateTime.now();
    _billingMonth = now.month;
    _billingYear = now.year;
  }

  @override
  void dispose() {
    _rentCtrl.dispose();
    _rentAdvAppliedCtrl.dispose();
    _prevReadingCtrl.dispose();
    _newReadingCtrl.dispose();
    _elecRateCtrl.dispose();
    _elecAmountCtrl.dispose();
    _elecUnitsCtrl.dispose();
    _elecAdvAppliedCtrl.dispose();
    _additionalChargesCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadRoomPeriodData(RoomWithDetails room) async {
    setState(() {
      // Set due date according to tenant's billing cycle day if configured
      if (room.billingDueDay != null && room.billingDueDay! > 0) {
        final day = room.billingDueDay!.clamp(1, 28);
        _dueDate = DateTime(_billingYear, _billingMonth, day);
      } else if (room.billingDueDay == 0) {
        // End of month
        _dueDate = DateTime(_billingYear, _billingMonth + 1, 0);
      } else {
        _dueDate = DateTime(_billingYear, _billingMonth, 5);
      }
    });

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
        month: _billingMonth,
        year: _billingYear,
      );
      setState(() => _previousBalancePaise = prev);
    }

    // 3. Fetch pre-allocated electricity if any
    final elecPaise = await ref.read(electricityDaoProvider).getAllocatedElectricityForRoom(
      roomId: room.id,
      month: _billingMonth,
      year: _billingYear,
    );
    if (elecPaise != null && elecPaise > 0) {
      setState(() {
        _elecAmountCtrl.text = CurrencyHelper.paiseToRupeesString(elecPaise);
        final autoElecAdv = _elecAdvAvailablePaise >= elecPaise ? elecPaise : _elecAdvAvailablePaise;
        _elecAdvAppliedCtrl.text = CurrencyHelper.paiseToRupeesString(autoElecAdv);
      });
    }
  }

  Future<void> _onRoomSelected(RoomWithDetails room) async {
    setState(() {
      _selectedRoom = room;
      _selectedRoomId = room.id;
      _rentCtrl.text = CurrencyHelper.paiseToRupeesString(room.agreedRentPaise ?? room.defaultRentPaise);

      // Electricity Sub-meter defaults
      _previousReadingCentiunits = room.latestReadingCentiunits ?? 0;
      _prevReadingCtrl.text = CurrencyHelper.centiunitsToString(_previousReadingCentiunits);
      _elecRateCtrl.text = CurrencyHelper.paiseToRupeesString(room.electricityRatePaise);
    });

    await _loadRoomPeriodData(room);
  }

  void _recalculateElectricity() {
    final prevCenti = _previousReadingCentiunits;
    final text = _newReadingCtrl.text.trim();
    if (text.isEmpty) {
      setState(() {
        _elecUnitsCtrl.text = '0';
        _elecAmountCtrl.text = '0';
      });
      return;
    }

    final val = double.tryParse(text);
    if (val == null || val < 0) {
      setState(() {
        _elecUnitsCtrl.text = '0';
        _elecAmountCtrl.text = '0';
      });
      return;
    }

    final newCenti = CurrencyHelper.parseReadingToCentiunits(text);
    final ratePaise = CurrencyHelper.parseRupeesToPaise(_elecRateCtrl.text);

    if (newCenti >= prevCenti) {
      final unitsCenti = newCenti - prevCenti;
      final chargePaise = ((unitsCenti * ratePaise) + 50) ~/ 100;

      setState(() {
        _elecUnitsCtrl.text = CurrencyHelper.centiunitsToString(unitsCenti);
        _elecAmountCtrl.text = CurrencyHelper.paiseToRupeesString(chargePaise);

        // Auto-suggest electricity advance application
        final autoElecAdv = _elecAdvAvailablePaise >= chargePaise ? chargePaise : _elecAdvAvailablePaise;
        _elecAdvAppliedCtrl.text = CurrencyHelper.paiseToRupeesString(autoElecAdv);
      });
    } else {
      setState(() {
        _elecUnitsCtrl.text = '0';
        _elecAmountCtrl.text = '0';
      });
    }
  }

  Future<void> _generateBill() async {
    if (!_formKey.currentState!.validate() || _selectedRoom == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select an occupied room before generating a bill.')),
      );
      return;
    }

    if (_selectedRoom!.activeTenancyId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Cannot generate bill: Room has no active tenant.')),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
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
        billingMonth: _billingMonth,
        billingYear: _billingYear,
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

      // 1. Save monthly bill
      await ref.read(billingDaoProvider).saveMonthlyBill(calculated);

      // 2. If new meter reading was entered, automatically save to meter_readings table
      final newReadingText = _newReadingCtrl.text.trim();
      if (newReadingText.isNotEmpty && _selectedRoom!.meterId != null) {
        final newReadingCenti = CurrencyHelper.parseReadingToCentiunits(newReadingText);
        if (newReadingCenti >= _previousReadingCentiunits) {
          await ref.read(electricityDaoProvider).recordMeterReading(
            id: 'mr_${_selectedRoom!.meterId}_${_billingYear}_${_billingMonth}',
            meterId: _selectedRoom!.meterId!,
            billingMonth: _billingMonth,
            billingYear: _billingYear,
            readingDateEpoch: DateTime.now().millisecondsSinceEpoch,
            currentReadingCentiunits: newReadingCenti,
            previousReadingCentiunits: _previousReadingCentiunits,
            notes: 'Recorded during bill generation (${calculated.billNumber})',
          );
        }
      }

      ref.invalidate(billsListProvider);
      ref.invalidate(roomsListProvider);
      ref.invalidate(dashboardSummaryProvider);
      ref.invalidate(tenancyAdvancesProvider(_selectedRoom!.activeTenancyId!));
      ref.invalidate(roomBillsProvider(_selectedRoom!.id));

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

    // Auto-select room if passed via preselectedRoomId
    roomsAsync.whenData((rooms) {
      if (_selectedRoomId != null && !_preselectedHandled) {
        final match = rooms.where((r) => r.id == _selectedRoomId && r.isOccupied).firstOrNull;
        if (match != null) {
          _preselectedHandled = true;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted && _selectedRoom == null) {
              _onRoomSelected(match);
            }
          });
        }
      }
    });

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
            // Billing Period Selector (allows current, past or future months)
            Card(
              elevation: 0,
              color: AppColors.primaryContainer.withOpacity(0.25),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: BorderSide(color: AppColors.primary.withOpacity(0.2)),
              ),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.calendar_month, color: AppColors.primary, size: 20),
                        const SizedBox(width: 8),
                        Text(
                          'Billing Cycle / Period',
                          style: Theme.of(context).textTheme.titleSmall?.copyWith(
                                fontWeight: FontWeight.bold,
                                color: AppColors.primary,
                              ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          flex: 3,
                          child: DropdownButtonFormField<int>(
                            value: _billingMonth,
                            decoration: const InputDecoration(
                              labelText: 'Billing Month',
                              border: OutlineInputBorder(),
                              contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                              isDense: true,
                            ),
                            items: List.generate(12, (i) {
                              final m = i + 1;
                              return DropdownMenuItem(
                                value: m,
                                child: Text(DateHelper.getMonthName(m)),
                              );
                            }),
                            onChanged: (m) {
                              if (m != null && m != _billingMonth) {
                                setState(() => _billingMonth = m);
                                if (_selectedRoom != null) {
                                  _loadRoomPeriodData(_selectedRoom!);
                                }
                              }
                            },
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          flex: 2,
                          child: DropdownButtonFormField<int>(
                            value: _billingYear,
                            decoration: const InputDecoration(
                              labelText: 'Year',
                              border: OutlineInputBorder(),
                              contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                              isDense: true,
                            ),
                            items: List.generate(7, (i) {
                              final y = DateTime.now().year - 3 + i;
                              return DropdownMenuItem(
                                value: y,
                                child: Text('$y'),
                              );
                            }),
                            onChanged: (y) {
                              if (y != null && y != _billingYear) {
                                setState(() => _billingYear = y);
                                if (_selectedRoom != null) {
                                  _loadRoomPeriodData(_selectedRoom!);
                                }
                              }
                            },
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Room Selector / Banner
            if (widget.preselectedRoomId != null && _selectedRoom != null) ...[
              // Pre-selected Room Banner (no dropdown needed)
              Card(
                color: AppColors.surfaceVariant.withOpacity(0.5),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      const CircleAvatar(
                        backgroundColor: AppColors.primary,
                        child: Icon(Icons.meeting_room, color: Colors.white),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _selectedRoom!.roomNumber,
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'Tenant: ${_selectedRoom!.activeTenantName ?? "Active Tenant"}',
                              style: TextStyle(color: Colors.grey.shade700, fontSize: 13),
                            ),
                            if (_selectedRoom!.meterNumber != null)
                              Text(
                                'Meter: ${_selectedRoom!.meterNumber} (Last: ${_prevReadingCtrl.text})',
                                style: const TextStyle(color: AppColors.primary, fontSize: 12, fontWeight: FontWeight.w500),
                              ),
                          ],
                        ),
                      ),
                      const Icon(Icons.check_circle, color: AppColors.primary),
                    ],
                  ),
                ),
              ),
            ] else ...[
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
            ],
            const SizedBox(height: 20),

            // 1. INDEPENDENT ROOM RENT & RENT ADVANCE SECTION
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.home, color: AppColors.primary, size: 20),
                        const SizedBox(width: 8),
                        Text(
                          '1. Room Rent',
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                    const Divider(height: 24),
                    TextFormField(
                      controller: _rentCtrl,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Monthly Room Rent Amount (₹) *',
                        prefixText: '₹ ',
                        border: OutlineInputBorder(),
                      ),
                      validator: (v) {
                        if (v == null || v.trim().isEmpty) return 'Rent amount required (or 0)';
                        if (CurrencyHelper.parseRupeesToPaise(v) < 0) return 'Cannot be negative';
                        return null;
                      },
                      onChanged: (_) => setState(() {}),
                    ),
                    const SizedBox(height: 12),

                    // Available Rent Advance Card
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withOpacity(0.06),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: AppColors.primary.withOpacity(0.2)),
                      ),
                      child: Column(
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text('Available Rent Advance:', style: TextStyle(fontSize: 12, color: Colors.grey)),
                              Text(
                                CurrencyHelper.formatPaise(_rentAdvAvailablePaise),
                                style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.primary),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              Expanded(
                                child: TextFormField(
                                  controller: _rentAdvAppliedCtrl,
                                  keyboardType: TextInputType.number,
                                  decoration: const InputDecoration(
                                    labelText: 'Apply Rent Advance (₹)',
                                    prefixText: '₹ ',
                                    isDense: true,
                                    border: OutlineInputBorder(),
                                  ),
                                  onChanged: (_) => setState(() {}),
                                ),
                              ),
                              const SizedBox(width: 8),
                              OutlinedButton(
                                onPressed: _rentAdvAvailablePaise > 0
                                    ? () {
                                        final maxAllowed = _rentAdvAvailablePaise < rentPaise ? _rentAdvAvailablePaise : rentPaise;
                                        setState(() {
                                          _rentAdvAppliedCtrl.text = CurrencyHelper.paiseToRupeesString(maxAllowed);
                                        });
                                      }
                                    : null,
                                child: const Text('Max'),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'Outstanding Rent: ${CurrencyHelper.formatPaise(outstandingRentPaise)}',
                                style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
                              ),
                              Text(
                                'Remaining Advance: ${CurrencyHelper.formatPaise(remainingRentAdvPaise)}',
                                style: const TextStyle(fontSize: 11, color: Colors.grey),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // 2. ELECTRICITY SUB-METER READING & LIVE CALCULATION
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.bolt, color: Colors.amber, size: 20),
                            const SizedBox(width: 8),
                            Text(
                              '2. Electricity Charges',
                              style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                        if (_selectedRoom?.meterNumber != null)
                          Text(
                            _selectedRoom!.meterNumber!,
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.grey),
                          ),
                      ],
                    ),
                    const Divider(height: 24),

                    // Sub-Meter Reading Calculator Row
                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: _prevReadingCtrl,
                            readOnly: true,
                            decoration: const InputDecoration(
                              labelText: 'Last Reading',
                              suffixText: 'units',
                              border: OutlineInputBorder(),
                              filled: true,
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: TextFormField(
                            controller: _newReadingCtrl,
                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                            decoration: const InputDecoration(
                              labelText: 'New Reading *',
                              suffixText: 'units',
                              border: OutlineInputBorder(),
                              hintText: 'e.g. 1050',
                            ),
                            onChanged: (_) => _recalculateElectricity(),
                            validator: (val) {
                              if (val != null && val.trim().isNotEmpty) {
                                final numVal = double.tryParse(val.trim());
                                if (numVal == null) return 'Invalid reading';
                                if (numVal < 0) return 'Cannot be negative';
                                final newCenti = CurrencyHelper.parseReadingToCentiunits(val.trim());
                                if (newCenti < _previousReadingCentiunits) {
                                  return 'Must be ≥ ${_prevReadingCtrl.text}';
                                }
                              }
                              return null;
                            },
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),

                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: _elecRateCtrl,
                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                            decoration: const InputDecoration(
                              labelText: 'Rate per Unit',
                              prefixText: '₹ ',
                              border: OutlineInputBorder(),
                            ),
                            onChanged: (_) => _recalculateElectricity(),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: TextFormField(
                            controller: _elecAmountCtrl,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(
                              labelText: 'Total Elec (₹)',
                              prefixText: '₹ ',
                              border: OutlineInputBorder(),
                            ),
                            onChanged: (_) => setState(() {}),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),

                    // Dynamic Math Indicator
                    if (_newReadingCtrl.text.trim().isNotEmpty) ...[
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: Colors.amber.withOpacity(0.12),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.amber.withOpacity(0.3)),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Units: ${_elecUnitsCtrl.text} units × ₹${_elecRateCtrl.text}',
                              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12),
                            ),
                            Text(
                              'Charge: ${CurrencyHelper.formatPaise(elecPaise)}',
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.brown),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 10),
                    ],

                    // Available Electricity Advance Card
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.amber.withOpacity(0.08),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.amber.withOpacity(0.2)),
                      ),
                      child: Column(
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text('Available Electricity Advance:', style: TextStyle(fontSize: 12, color: Colors.grey)),
                              Text(
                                CurrencyHelper.formatPaise(_elecAdvAvailablePaise),
                                style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.amber),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              Expanded(
                                child: TextFormField(
                                  controller: _elecAdvAppliedCtrl,
                                  keyboardType: TextInputType.number,
                                  decoration: const InputDecoration(
                                    labelText: 'Apply Electricity Advance (₹)',
                                    prefixText: '₹ ',
                                    isDense: true,
                                    border: OutlineInputBorder(),
                                  ),
                                  onChanged: (_) => setState(() {}),
                                ),
                              ),
                              const SizedBox(width: 8),
                              OutlinedButton(
                                onPressed: _elecAdvAvailablePaise > 0
                                    ? () {
                                        final maxAllowed = _elecAdvAvailablePaise < elecPaise ? _elecAdvAvailablePaise : elecPaise;
                                        setState(() {
                                          _elecAdvAppliedCtrl.text = CurrencyHelper.paiseToRupeesString(maxAllowed);
                                        });
                                      }
                                    : null,
                                child: const Text('Max'),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'Outstanding Elec: ${CurrencyHelper.formatPaise(outstandingElecPaise)}',
                                style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
                              ),
                              Text(
                                'Remaining Advance: ${CurrencyHelper.formatPaise(remainingElecAdvPaise)}',
                                style: const TextStyle(fontSize: 11, color: Colors.grey),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // 3. ADDITIONAL CHARGES & PREVIOUS BALANCE
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '3. Additional Items & Due Date',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                    ),
                    const Divider(height: 24),
                    TextFormField(
                      controller: _additionalChargesCtrl,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Maintenance / Other Charges (₹)',
                        prefixText: '₹ ',
                        border: OutlineInputBorder(),
                      ),
                      onChanged: (_) => setState(() {}),
                    ),
                    const SizedBox(height: 12),
                    if (_previousBalancePaise > 0) ...[
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('Previous Outstanding Dues:', style: TextStyle(color: Colors.red)),
                          Text(
                            CurrencyHelper.formatPaise(_previousBalancePaise),
                            style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.red),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                    ],
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Payment Due Date', style: TextStyle(fontSize: 14)),
                      subtitle: Text(DateHelper.formatEpoch(_dueDate.millisecondsSinceEpoch)),
                      trailing: const Icon(Icons.calendar_today, size: 20),
                      onTap: () async {
                        final picked = await showDatePicker(
                          context: context,
                          initialDate: _dueDate,
                          firstDate: DateTime.now().subtract(const Duration(days: 30)),
                          lastDate: DateTime.now().add(const Duration(days: 90)),
                        );
                        if (picked != null) setState(() => _dueDate = picked);
                      },
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),

            // BILL SUMMARY CARD
            Card(
              color: AppColors.primaryContainer.withOpacity(0.2),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Bill Summary',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 12),
                    _buildSummaryRow('Room Rent:', CurrencyHelper.formatPaise(rentPaise)),
                    if (rentAdvAppliedPaise > 0)
                      _buildSummaryRow('Rent Advance Applied:', '-${CurrencyHelper.formatPaise(rentAdvAppliedPaise)}', isGreen: true),
                    _buildSummaryRow('Electricity Charge:', CurrencyHelper.formatPaise(elecPaise)),
                    if (elecAdvAppliedPaise > 0)
                      _buildSummaryRow('Electricity Advance Applied:', '-${CurrencyHelper.formatPaise(elecAdvAppliedPaise)}', isGreen: true),
                    if (addPaise > 0)
                      _buildSummaryRow('Other Charges:', CurrencyHelper.formatPaise(addPaise)),
                    if (_previousBalancePaise > 0)
                      _buildSummaryRow('Previous Dues:', CurrencyHelper.formatPaise(_previousBalancePaise)),
                    const Divider(height: 20),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Net Payable by Tenant:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                        Text(
                          CurrencyHelper.formatPaise(netAmountDuePaise > 0 ? netAmountDuePaise : 0),
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: AppColors.primary),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),

            // Confirm & Generate Button
            FilledButton.icon(
              onPressed: _isLoading ? null : _generateBill,
              icon: _isLoading ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Icon(Icons.check),
              label: Text(_isLoading ? 'Generating Bill...' : 'Confirm & Generate Bill'),
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

  Widget _buildSummaryRow(String label, String value, {bool isGreen = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontSize: 13)),
          Text(
            value,
            style: TextStyle(
              fontWeight: FontWeight.w600,
              fontSize: 13,
              color: isGreen ? Colors.green.shade700 : null,
            ),
          ),
        ],
      ),
    );
  }
}

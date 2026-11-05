import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import '../../../core/services/media_storage_service.dart';
import '../../../core/utils/currency_helper.dart';
import '../../../core/utils/date_helper.dart';
import '../../dashboard/providers/dashboard_provider.dart';
import '../../rooms/providers/rooms_provider.dart';
import '../domain/electricity_calculator.dart';
import '../providers/electricity_provider.dart';

class MeterReadingScreen extends ConsumerStatefulWidget {
  final String? preselectedMeterId;

  const MeterReadingScreen({Key? key, this.preselectedMeterId}) : super(key: key);

  @override
  ConsumerState<MeterReadingScreen> createState() => _MeterReadingScreenState();
}

class _MeterReadingScreenState extends ConsumerState<MeterReadingScreen> {
  final _formKey = GlobalKey<FormState>();
  String? _selectedMeterId;
  int _previousReadingCentiunits = 0;
  final _currentReadingCtrl = TextEditingController();
  final _notesCtrl = TextEditingController();
  bool _isReset = false;
  File? _meterPhoto;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _selectedMeterId = widget.preselectedMeterId;
    if (_selectedMeterId != null) {
      _loadPreviousReading(_selectedMeterId!);
    }
  }

  Future<void> _loadPreviousReading(String meterId) async {
    final dao = ref.read(electricityDaoProvider);
    final prev = await dao.getPreviousReadingCentiunits(meterId);
    setState(() {
      _previousReadingCentiunits = prev;
    });
  }

  @override
  void dispose() {
    _currentReadingCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickPhoto(ImageSource source) async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(source: source, imageQuality: 75);
    if (picked != null) {
      setState(() => _meterPhoto = File(picked.path));
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedMeterId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a room sub-meter.')),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final period = ref.read(selectedPeriodProvider);
      final currentCenti = CurrencyHelper.parseReadingToCentiunits(_currentReadingCtrl.text);

      String? photoPath;
      if (_meterPhoto != null) {
        photoPath = await MediaStorageService.saveMediaLocally(_meterPhoto!, subfolder: 'meters');
      }

      final readingId = 'mr_${_selectedMeterId}_${period.year}_${period.month}';

      await ref.read(electricityDaoProvider).recordMeterReading(
        id: readingId,
        meterId: _selectedMeterId!,
        billingMonth: period.month,
        billingYear: period.year,
        readingDateEpoch: DateTime.now().millisecondsSinceEpoch,
        previousReadingCentiunits: _previousReadingCentiunits,
        currentReadingCentiunits: currentCenti,
        isReset: _isReset,
        photoPath: photoPath,
        notes: _notesCtrl.text,
      );

      ref.invalidate(periodReadingsProvider);
      ref.invalidate(roomsListProvider);
      ref.invalidate(dashboardSummaryProvider);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Meter reading recorded successfully!')),
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

    final currentCenti = CurrencyHelper.parseReadingToCentiunits(_currentReadingCtrl.text);
    int computedUnitsCenti = 0;
    if (_isReset) {
      computedUnitsCenti = currentCenti;
    } else if (currentCenti >= _previousReadingCentiunits) {
      computedUnitsCenti = currentCenti - _previousReadingCentiunits;
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Record Meter Reading'),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // Period Card
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                children: [
                  const Icon(Icons.calendar_month, color: Colors.grey, size: 20),
                  const SizedBox(width: 8),
                  Text(
                    'Billing Period: ${DateHelper.formatBillingPeriod(period.month, period.year)}',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Select Room Meter
            roomsAsync.when(
              data: (rooms) {
                final meterRooms = rooms.where((r) => r.meterId != null).toList();
                return DropdownButtonFormField<String>(
                  value: _selectedMeterId,
                  decoration: const InputDecoration(
                    labelText: 'Select Room / Sub-Meter *',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.bolt),
                  ),
                  items: meterRooms.map((r) {
                    return DropdownMenuItem(
                      value: r.meterId,
                      child: Text('${r.roomNumber} (${r.meterNumber ?? "Meter"})'),
                    );
                  }).toList(),
                  onChanged: (val) {
                    if (val != null) {
                      setState(() => _selectedMeterId = val);
                      _loadPreviousReading(val);
                    }
                  },
                  validator: (v) => v == null ? 'Please select a room meter' : null,
                );
              },
              loading: () => const LinearProgressIndicator(),
              error: (e, _) => Text('Error loading rooms: $e'),
            ),
            const SizedBox(height: 16),

            // Previous Reading Display
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surfaceVariant.withOpacity(0.4),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Previous Valid Reading:', style: TextStyle(fontWeight: FontWeight.w600)),
                  Text(
                    CurrencyHelper.formatCentiunits(_previousReadingCentiunits),
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Current Reading Input
            TextFormField(
              controller: _currentReadingCtrl,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(
                labelText: 'Current Meter Reading (Units) *',
                hintText: 'e.g. 1130.00',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.speed),
              ),
              onChanged: (_) => setState(() {}),
              validator: (v) {
                if (v == null || v.trim().isEmpty) return 'Required';
                final entered = CurrencyHelper.parseReadingToCentiunits(v);
                if (!_isReset && entered < _previousReadingCentiunits) {
                  return 'Current reading cannot be lower than previous (${CurrencyHelper.centiunitsToString(_previousReadingCentiunits)})';
                }
                return null;
              },
            ),
            const SizedBox(height: 12),

            // Units Computed Live Card
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: Colors.green.shade50,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.green.shade200),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Calculated Units Consumed:', style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold)),
                  Text(
                    CurrencyHelper.formatCentiunits(computedUnitsCenti),
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.green.shade900),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),

            // Meter Reset Switch
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Meter Reset / Rollover'),
              subtitle: const Text('Enable only if the meter rolled over from 9999 or was replaced with a new unit'),
              value: _isReset,
              onChanged: (val) => setState(() => _isReset = val),
            ),
            const SizedBox(height: 12),

            // Photo Attachment
            OutlinedButton.icon(
              onPressed: () => _pickPhoto(ImageSource.camera),
              icon: const Icon(Icons.camera_alt_outlined),
              label: Text(_meterPhoto == null ? 'Attach Meter Photo (Optional)' : 'Photo Attached ✓'),
            ),
            const SizedBox(height: 16),

            TextFormField(
              controller: _notesCtrl,
              maxLines: 2,
              decoration: const InputDecoration(
                labelText: 'Notes (Optional)',
                hintText: 'Any meter remarks...',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.note_outlined),
              ),
            ),
            const SizedBox(height: 24),

            FilledButton.icon(
              onPressed: _isLoading ? null : _save,
              icon: _isLoading ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.save),
              label: const Text('Save Reading'),
              style: FilledButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 14)),
            ),
          ],
        ),
      ),
    );
  }
}

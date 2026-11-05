import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/utils/currency_helper.dart';
import '../../../core/widgets/confirm_dialog.dart';
import '../providers/rooms_provider.dart';

class AddEditRoomScreen extends ConsumerStatefulWidget {
  final String? roomId;

  const AddEditRoomScreen({Key? key, this.roomId}) : super(key: key);

  @override
  ConsumerState<AddEditRoomScreen> createState() => _AddEditRoomScreenState();
}

class _AddEditRoomScreenState extends ConsumerState<AddEditRoomScreen> {
  final _formKey = GlobalKey<FormState>();
  final _roomNumberCtrl = TextEditingController();
  final _rentCtrl = TextEditingController();
  final _elecRateCtrl = TextEditingController(text: '10');
  final _descCtrl = TextEditingController();
  final _meterCtrl = TextEditingController();
  final _initialReadingCtrl = TextEditingController(text: '0');
  final _notesCtrl = TextEditingController();
  bool _isActive = true;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    if (widget.roomId != null) {
      _loadExistingRoom();
    }
  }

  Future<void> _loadExistingRoom() async {
    final room = await ref.read(roomDaoProvider).getRoomById(widget.roomId!);
    if (room != null && mounted) {
      setState(() {
        _roomNumberCtrl.text = room.roomNumber;
        _rentCtrl.text = CurrencyHelper.paiseToRupeesString(room.defaultRentPaise);
        _elecRateCtrl.text = CurrencyHelper.paiseToRupeesString(room.electricityRatePaise);
        _descCtrl.text = room.description ?? '';
        _meterCtrl.text = room.meterNumber ?? '';
        _initialReadingCtrl.text = CurrencyHelper.centiunitsToString(room.latestReadingCentiunits ?? 0);
        _notesCtrl.text = room.notes ?? '';
        _isActive = room.isActive;
      });
    }
  }

  @override
  void dispose() {
    _roomNumberCtrl.dispose();
    _rentCtrl.dispose();
    _elecRateCtrl.dispose();
    _descCtrl.dispose();
    _meterCtrl.dispose();
    _initialReadingCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final dao = ref.read(roomDaoProvider);
      final rentPaise = CurrencyHelper.parseRupeesToPaise(_rentCtrl.text);
      final elecRatePaise = CurrencyHelper.parseRupeesToPaise(_elecRateCtrl.text);
      final meterReadingCenti = CurrencyHelper.parseReadingToCentiunits(_initialReadingCtrl.text);

      if (widget.roomId == null) {
        // Create new room
        final newId = 'room_${DateTime.now().millisecondsSinceEpoch}';
        await dao.createRoom(
          id: newId,
          propertyId: AppConstants.defaultPropertyId,
          roomNumber: _roomNumberCtrl.text,
          description: _descCtrl.text,
          defaultRentPaise: rentPaise,
          electricityRatePaise: elecRatePaise > 0 ? elecRatePaise : 1000,
          meterNumber: _meterCtrl.text,
          initialMeterReadingCentiunits: meterReadingCenti,
          notes: _notesCtrl.text,
        );
      } else {
        // Update existing room
        await dao.updateRoom(
          id: widget.roomId!,
          roomNumber: _roomNumberCtrl.text,
          description: _descCtrl.text,
          defaultRentPaise: rentPaise,
          electricityRatePaise: elecRatePaise > 0 ? elecRatePaise : 1000,
          isActive: _isActive,
          notes: _notesCtrl.text,
          meterNumber: _meterCtrl.text,
          meterReadingCentiunits: meterReadingCenti,
        );
      }

      ref.invalidate(roomsListProvider);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(widget.roomId == null ? 'Room created successfully' : 'Room updated successfully')),
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

  Future<void> _deleteRoom() async {
    final confirmed = await showConfirmDialog(
      context: context,
      title: 'Delete Room',
      message: 'Are you sure you want to delete this room? This will also remove any meters and records associated with this room.',
      confirmLabel: 'Delete',
      isDestructive: true,
    );

    if (confirmed == true && mounted) {
      setState(() => _isLoading = true);
      try {
        await ref.read(roomDaoProvider).deleteRoom(widget.roomId!);
        ref.invalidate(roomsListProvider);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Room deleted successfully')),
          );
          Navigator.pop(context); // Pop edit screen
          Navigator.pop(context); // Pop room detail screen if open
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
        }
      } finally {
        if (mounted) setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.roomId != null;

    return Scaffold(
      appBar: AppBar(
        title: Text(isEditing ? 'Edit Room' : 'Add New Room'),
        actions: [
          if (isEditing)
            IconButton(
              icon: const Icon(Icons.delete_outline, color: Colors.red),
              tooltip: 'Delete Room',
              onPressed: _isLoading ? null : _deleteRoom,
            ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            TextFormField(
              controller: _roomNumberCtrl,
              decoration: const InputDecoration(
                labelText: 'Room Name / Number *',
                hintText: 'e.g. Room 101 or 1st Floor Deluxe',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.meeting_room_outlined),
              ),
              validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _rentCtrl,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Monthly Rent (₹) *',
                      hintText: 'e.g. 5000',
                      prefixText: '₹ ',
                      border: OutlineInputBorder(),
                    ),
                    validator: (v) {
                      if (v == null || v.trim().isEmpty) return 'Required';
                      if (CurrencyHelper.parseRupeesToPaise(v) <= 0) return 'Enter valid amount';
                      return null;
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextFormField(
                    controller: _elecRateCtrl,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(
                      labelText: 'Elec Rate / Unit *',
                      hintText: 'e.g. 10.00',
                      prefixText: '₹ ',
                      border: OutlineInputBorder(),
                    ),
                    validator: (v) {
                      if (v == null || v.trim().isEmpty) return 'Required';
                      if (CurrencyHelper.parseRupeesToPaise(v) <= 0) return 'Enter valid rate';
                      return null;
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _meterCtrl,
              decoration: const InputDecoration(
                labelText: 'Electricity Sub-Meter Number (Optional)',
                hintText: 'e.g. MTR-101',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.bolt_outlined),
              ),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _initialReadingCtrl,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: InputDecoration(
                labelText: isEditing ? 'Last / Current Meter Reading (Units)' : 'Initial Meter Reading (Units)',
                hintText: 'e.g. 1000.00',
                border: const OutlineInputBorder(),
                prefixIcon: const Icon(Icons.speed_outlined),
              ),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _descCtrl,
              maxLines: 2,
              decoration: const InputDecoration(
                labelText: 'Description (Optional)',
                hintText: 'Attached bathroom, ground floor, etc.',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.description_outlined),
              ),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _notesCtrl,
              maxLines: 2,
              decoration: const InputDecoration(
                labelText: 'Internal Owner Notes (Optional)',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.note_alt_outlined),
              ),
            ),
            if (isEditing) ...[
              const SizedBox(height: 12),
              SwitchListTile(
                title: const Text('Active Room'),
                subtitle: const Text('Deactivate if under maintenance or unavailable'),
                value: _isActive,
                onChanged: (val) => setState(() => _isActive = val),
              ),
            ],
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: _isLoading ? null : _save,
              icon: _isLoading ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Icon(Icons.save),
              label: Text(isEditing ? 'Save Changes' : 'Create Room'),
              style: FilledButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 14)),
            ),
            if (isEditing) ...[
              const SizedBox(height: 16),
              OutlinedButton.icon(
                onPressed: _isLoading ? null : _deleteRoom,
                icon: const Icon(Icons.delete_outline, color: Colors.red),
                label: const Text('Delete Room', style: TextStyle(color: Colors.red)),
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: Colors.red),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
              ),
            ],
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }
}

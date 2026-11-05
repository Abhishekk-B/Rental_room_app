import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/utils/currency_helper.dart';
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
        _descCtrl.text = room.description ?? '';
        _meterCtrl.text = room.meterNumber ?? '';
        _notesCtrl.text = room.notes ?? '';
        _isActive = room.isActive;
      });
    }
  }

  @override
  void dispose() {
    _roomNumberCtrl.dispose();
    _rentCtrl.dispose();
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

      if (widget.roomId == null) {
        // Create new room
        final newId = 'room_${DateTime.now().millisecondsSinceEpoch}';
        final initialCenti = CurrencyHelper.parseReadingToCentiunits(_initialReadingCtrl.text);
        await dao.createRoom(
          id: newId,
          propertyId: AppConstants.defaultPropertyId,
          roomNumber: _roomNumberCtrl.text,
          description: _descCtrl.text,
          defaultRentPaise: rentPaise,
          meterNumber: _meterCtrl.text,
          initialMeterReadingCentiunits: initialCenti,
          notes: _notesCtrl.text,
        );
      } else {
        // Update existing room
        await dao.updateRoom(
          id: widget.roomId!,
          roomNumber: _roomNumberCtrl.text,
          description: _descCtrl.text,
          defaultRentPaise: rentPaise,
          isActive: _isActive,
          notes: _notesCtrl.text,
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

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.roomId != null;

    return Scaffold(
      appBar: AppBar(
        title: Text(isEditing ? 'Edit Room' : 'Add New Room'),
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
                hintText: 'e.g. Room 104 or Deluxe 2nd Floor',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.meeting_room_outlined),
              ),
              validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _rentCtrl,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Default Monthly Rent (₹) *',
                hintText: 'e.g. 8500',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.currency_rupee),
              ),
              validator: (v) {
                if (v == null || v.trim().isEmpty) return 'Required';
                if (CurrencyHelper.parseRupeesToPaise(v) <= 0) return 'Enter a valid amount';
                return null;
              },
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _descCtrl,
              maxLines: 2,
              decoration: const InputDecoration(
                labelText: 'Description (Optional)',
                hintText: 'Attached bath, private balcony, etc.',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.description_outlined),
              ),
            ),
            const SizedBox(height: 16),
            if (!isEditing) ...[
              TextFormField(
                controller: _meterCtrl,
                decoration: const InputDecoration(
                  labelText: 'Electricity Sub-Meter Number (Optional)',
                  hintText: 'e.g. MTR-104',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.bolt_outlined),
                ),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _initialReadingCtrl,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Initial Meter Reading (Units)',
                  hintText: 'e.g. 1000.00',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.speed_outlined),
                ),
              ),
              const SizedBox(height: 16),
            ],
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
                subtitle: const Text('Deactivate if undergoing repair or unavailable for rent'),
                value: _isActive,
                onChanged: (val) => setState(() => _isActive = val),
              ),
            ],
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: _isLoading ? null : _save,
              icon: _isLoading ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.save),
              label: Text(isEditing ? 'Save Changes' : 'Create Room'),
              style: FilledButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 14)),
            ),
          ],
        ),
      ),
    );
  }
}

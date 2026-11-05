import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/tenants_provider.dart';

class AddEditTenantScreen extends ConsumerStatefulWidget {
  final String? tenantId;

  const AddEditTenantScreen({Key? key, this.tenantId}) : super(key: key);

  @override
  ConsumerState<AddEditTenantScreen> createState() => _AddEditTenantScreenState();
}

class _AddEditTenantScreenState extends ConsumerState<AddEditTenantScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _addressCtrl = TextEditingController();
  final _emergencyCtrl = TextEditingController();
  final _idTypeCtrl = TextEditingController(text: 'Aadhaar Card');
  final _idNumCtrl = TextEditingController();
  final _notesCtrl = TextEditingController();
  bool _isActive = true;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    if (widget.tenantId != null) {
      _loadExistingTenant();
    }
  }

  Future<void> _loadExistingTenant() async {
    final tenant = await ref.read(tenantDaoProvider).getTenantById(widget.tenantId!);
    if (tenant != null && mounted) {
      setState(() {
        _nameCtrl.text = tenant.fullName;
        _phoneCtrl.text = tenant.phoneNumber;
        _emailCtrl.text = tenant.email ?? '';
        _addressCtrl.text = tenant.permanentAddress ?? '';
        _emergencyCtrl.text = tenant.emergencyContact ?? '';
        _idTypeCtrl.text = tenant.idProofType ?? 'Aadhaar Card';
        _idNumCtrl.text = tenant.idProofNumber ?? '';
        _notesCtrl.text = tenant.notes ?? '';
        _isActive = tenant.isActive;
      });
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _phoneCtrl.dispose();
    _emailCtrl.dispose();
    _addressCtrl.dispose();
    _emergencyCtrl.dispose();
    _idTypeCtrl.dispose();
    _idNumCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);

    try {
      final dao = ref.read(tenantDaoProvider);

      if (widget.tenantId == null) {
        final newId = 'tenant_${DateTime.now().millisecondsSinceEpoch}';
        await dao.createTenant(
          id: newId,
          fullName: _nameCtrl.text,
          phoneNumber: _phoneCtrl.text,
          email: _emailCtrl.text,
          permanentAddress: _addressCtrl.text,
          emergencyContact: _emergencyCtrl.text,
          idProofType: _idTypeCtrl.text,
          idProofNumber: _idNumCtrl.text,
          notes: _notesCtrl.text,
        );
      } else {
        await dao.updateTenant(
          id: widget.tenantId!,
          fullName: _nameCtrl.text,
          phoneNumber: _phoneCtrl.text,
          email: _emailCtrl.text,
          permanentAddress: _addressCtrl.text,
          emergencyContact: _emergencyCtrl.text,
          idProofType: _idTypeCtrl.text,
          idProofNumber: _idNumCtrl.text,
          notes: _notesCtrl.text,
          isActive: _isActive,
        );
      }

      ref.invalidate(tenantsListProvider);
      if (widget.tenantId != null) {
        ref.invalidate(tenantDetailProvider(widget.tenantId!));
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(widget.tenantId == null ? 'Tenant created' : 'Tenant updated')),
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
    final isEditing = widget.tenantId != null;

    return Scaffold(
      appBar: AppBar(
        title: Text(isEditing ? 'Edit Tenant' : 'Register New Tenant'),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            TextFormField(
              controller: _nameCtrl,
              decoration: const InputDecoration(
                labelText: 'Full Name *',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.person_outline),
              ),
              validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _phoneCtrl,
              keyboardType: TextInputType.phone,
              decoration: const InputDecoration(
                labelText: 'Phone Number *',
                hintText: '+91 9876543210',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.phone_outlined),
              ),
              validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _emailCtrl,
              keyboardType: TextInputType.emailAddress,
              decoration: const InputDecoration(
                labelText: 'Email Address (Optional)',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.email_outlined),
              ),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _addressCtrl,
              maxLines: 2,
              decoration: const InputDecoration(
                labelText: 'Permanent Address (Optional)',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.home_outlined),
              ),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _emergencyCtrl,
              decoration: const InputDecoration(
                labelText: 'Emergency Contact & Relation (Optional)',
                hintText: 'e.g. +91 9123456789 (Father)',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.contact_phone_outlined),
              ),
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              value: _idTypeCtrl.text.isEmpty ? 'Aadhaar Card' : _idTypeCtrl.text,
              decoration: const InputDecoration(
                labelText: 'ID Proof Type (Optional)',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.badge_outlined),
              ),
              items: const [
                DropdownMenuItem(value: 'Aadhaar Card', child: Text('Aadhaar Card')),
                DropdownMenuItem(value: 'PAN Card', child: Text('PAN Card')),
                DropdownMenuItem(value: 'Passport', child: Text('Passport')),
                DropdownMenuItem(value: 'Driving License', child: Text('Driving License')),
                DropdownMenuItem(value: 'Voter ID', child: Text('Voter ID')),
                DropdownMenuItem(value: 'Other', child: Text('Other')),
              ],
              onChanged: (val) {
                if (val != null) _idTypeCtrl.text = val;
              },
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _idNumCtrl,
              decoration: const InputDecoration(
                labelText: 'ID Document Number / Reference (Optional)',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.numbers_outlined),
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
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: _isLoading ? null : _save,
              icon: _isLoading ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.save),
              label: Text(isEditing ? 'Save Changes' : 'Register Tenant'),
              style: FilledButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 14)),
            ),
          ],
        ),
      ),
    );
  }
}

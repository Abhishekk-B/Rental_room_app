import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/database/daos/settings_dao.dart';
import '../../../core/services/security_service.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({Key? key}) : super(key: key);

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final SettingsDao _settingsDao = SettingsDao();
  final _ownerNameCtrl = TextEditingController();
  final _ownerPhoneCtrl = TextEditingController();
  final _ownerUpiCtrl = TextEditingController();
  bool _pinEnabled = false;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final name = await _settingsDao.getSetting('owner_name') ?? 'Homeowner';
    final phone = await _settingsDao.getSetting('owner_phone') ?? '';
    final upi = await _settingsDao.getSetting('owner_upi_id') ?? '';
    final pin = await SecurityService.isPinEnabled();

    if (mounted) {
      setState(() {
        _ownerNameCtrl.text = name;
        _ownerPhoneCtrl.text = phone;
        _ownerUpiCtrl.text = upi;
        _pinEnabled = pin;
        _isLoading = false;
      });
    }
  }

  Future<void> _saveOwnerProfile() async {
    await _settingsDao.setSetting('owner_name', _ownerNameCtrl.text.trim());
    await _settingsDao.setSetting('owner_phone', _ownerPhoneCtrl.text.trim());
    await _settingsDao.setSetting('owner_upi_id', _ownerUpiCtrl.text.trim());

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Owner profile saved')),
      );
    }
  }

  Future<void> _togglePinLock(bool enabled) async {
    if (enabled) {
      final pinCtrl = TextEditingController();
      final result = await showDialog<String>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Set 4-Digit Local PIN'),
          content: TextField(
            controller: pinCtrl,
            keyboardType: TextInputType.number,
            maxLength: 4,
            obscureText: true,
            decoration: const InputDecoration(labelText: 'Enter 4-digit PIN', border: OutlineInputBorder()),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
            FilledButton(
              onPressed: () => Navigator.pop(context, pinCtrl.text),
              child: const Text('Save PIN'),
            ),
          ],
        ),
      );

      if (result != null && result.length == 4) {
        await SecurityService.setPin(result);
        setState(() => _pinEnabled = true);
      }
    } else {
      await SecurityService.disablePin();
      setState(() => _pinEnabled = false);
    }
  }

  @override
  void dispose() {
    _ownerNameCtrl.dispose();
    _ownerPhoneCtrl.dispose();
    _ownerUpiCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings & Configuration'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Owner Profile Card
          Card(
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: BorderSide(color: Colors.grey.shade300),
            ),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Owner Invoice Details', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  const SizedBox(height: 4),
                  const Text('Printed on tenant PDF bills and receipts', style: TextStyle(fontSize: 12, color: Colors.grey)),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _ownerNameCtrl,
                    decoration: const InputDecoration(labelText: 'Owner / Landlord Name', border: OutlineInputBorder()),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _ownerPhoneCtrl,
                    decoration: const InputDecoration(labelText: 'Contact Phone', border: OutlineInputBorder()),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _ownerUpiCtrl,
                    decoration: const InputDecoration(labelText: 'Default UPI ID for Rent', border: OutlineInputBorder()),
                  ),
                  const SizedBox(height: 16),
                  FilledButton(
                    onPressed: _saveOwnerProfile,
                    child: const Text('Save Profile'),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Security & App Lock Card
          Card(
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: BorderSide(color: Colors.grey.shade300),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Local App PIN Lock', style: TextStyle(fontWeight: FontWeight.bold)),
                subtitle: const Text('Protect tenant records and bills with a 4-digit PIN upon app open'),
                value: _pinEnabled,
                onChanged: _togglePinLock,
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Backup & Restore Navigation Card
          Card(
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: BorderSide(color: Colors.grey.shade300),
            ),
            child: ListTile(
              contentPadding: const EdgeInsets.all(16),
              leading: const CircleAvatar(
                backgroundColor: AppColors.primaryContainer,
                child: Icon(Icons.backup_outlined, color: AppColors.primary),
              ),
              title: const Text('Backup & Restore Data', style: TextStyle(fontWeight: FontWeight.bold)),
              subtitle: const Text('Export all tables & receipts to ZIP or restore database'),
              trailing: const Icon(Icons.arrow_forward_ios, size: 16),
              onTap: () => context.push('/settings/backup'),
            ),
          ),
          const SizedBox(height: 24),

          // App Metadata
          Center(
            child: Column(
              children: [
                Text(
                  'RentPulse v${AppConstants.appVersion}',
                  style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.grey),
                ),
                const SizedBox(height: 4),
                const Text(
                  '100% Offline • Local SQLite • Zero Network Calls',
                  style: TextStyle(fontSize: 11, color: Colors.grey),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

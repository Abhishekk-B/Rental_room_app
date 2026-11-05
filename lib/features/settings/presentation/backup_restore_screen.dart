import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/services/backup_restore_service.dart';
import '../../../core/utils/date_helper.dart';
import '../../../core/widgets/confirm_dialog.dart';

class BackupRestoreScreen extends StatefulWidget {
  const BackupRestoreScreen({Key? key}) : super(key: key);

  @override
  State<BackupRestoreScreen> createState() => _BackupRestoreScreenState();
}

class _BackupRestoreScreenState extends State<BackupRestoreScreen> {
  final BackupRestoreService _backupService = BackupRestoreService();
  bool _isProcessing = false;
  String? _statusMessage;

  Future<void> _exportBackup() async {
    setState(() {
      _isProcessing = true;
      _statusMessage = 'Packaging database and files into ZIP...';
    });

    try {
      final zipPath = await _backupService.createBackupZip();
      setState(() => _statusMessage = 'Opening Android Share Sheet...');
      await _backupService.shareBackup(zipPath);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Backup archive created and ready to save!')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Backup failed: $e')));
      }
    } finally {
      if (mounted) {
        setState(() {
          _isProcessing = false;
          _statusMessage = null;
        });
      }
    }
  }

  Future<void> _importRestore() async {
    final confirmed = await ConfirmDialog.show(
      context,
      title: 'Warning: Restore Database',
      content: 'Restoring a backup will replace your current room, tenant, bill, and payment data with the records from the backup file. '
          'Do you wish to proceed?',
      confirmText: 'Select Backup File',
      isDestructive: true,
    );

    if (!confirmed) return;

    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['zip'],
      );

      if (result == null || result.files.single.path == null) return;

      setState(() {
        _isProcessing = true;
        _statusMessage = 'Validating archive and restoring tables...';
      });

      final manifest = await _backupService.restoreBackupZip(result.files.single.path!);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Successfully restored data! Backup date: ${DateHelper.formatDateTimeEpoch(manifest.backupTimestampEpoch)}',
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Restore failed: $e')));
      }
    } finally {
      if (mounted) {
        setState(() {
          _isProcessing = false;
          _statusMessage = null;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Backup & Restore'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Information Banner
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.primaryContainer.withOpacity(0.4),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.primary.withOpacity(0.2)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: const [
                    Icon(Icons.shield_outlined, color: AppColors.primary),
                    SizedBox(width: 8),
                    Text(
                      '100% Offline Local Backup',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: AppColors.primary),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                const Text(
                  'Your data is stored exclusively on this phone. Create regular backups to keep your room records, '
                  'bills, sub-meter readings, and receipts safe. You can save your backup ZIP to Google Drive, SD Card, or WhatsApp.',
                  style: TextStyle(fontSize: 13, height: 1.4),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Export Card
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
                  const Text('Export Complete Backup', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  const SizedBox(height: 6),
                  const Text(
                    'Packages all rooms, tenants, electricity readings, bills, receipts, and expenses into a secure .zip archive.',
                    style: TextStyle(color: Colors.grey, fontSize: 13),
                  ),
                  const SizedBox(height: 16),
                  FilledButton.icon(
                    onPressed: _isProcessing ? null : _exportBackup,
                    icon: const Icon(Icons.file_upload_outlined),
                    label: const Text('Create & Share Backup ZIP'),
                    style: FilledButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16)),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Restore Card
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
                  const Text('Restore from Backup', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  const SizedBox(height: 6),
                  const Text(
                    'Restore records from a previously exported RentPulse backup ZIP file with automatic validation.',
                    style: TextStyle(color: Colors.grey, fontSize: 13),
                  ),
                  const SizedBox(height: 16),
                  OutlinedButton.icon(
                    onPressed: _isProcessing ? null : _importRestore,
                    icon: const Icon(Icons.file_download_outlined),
                    label: const Text('Select Backup ZIP to Restore'),
                    style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16)),
                  ),
                ],
              ),
            ),
          ),

          if (_statusMessage != null) ...[
            const SizedBox(height: 24),
            Center(
              child: Column(
                children: [
                  const CircularProgressIndicator(),
                  const SizedBox(height: 12),
                  Text(_statusMessage!, style: const TextStyle(fontWeight: FontWeight.w600)),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

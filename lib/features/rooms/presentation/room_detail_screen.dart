import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/utils/currency_helper.dart';
import '../../../core/widgets/status_badge.dart';
import '../providers/rooms_provider.dart';

class RoomDetailScreen extends ConsumerWidget {
  final String roomId;

  const RoomDetailScreen({Key? key, required this.roomId}) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final roomAsync = ref.watch(roomDetailProvider(roomId));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Room Details'),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit_outlined),
            onPressed: () => context.push('/rooms/$roomId/edit'),
          ),
        ],
      ),
      body: roomAsync.when(
        data: (room) {
          if (room == null) {
            return const Center(child: Text('Room not found.'));
          }

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Card(
                elevation: 0,
                color: Theme.of(context).colorScheme.surface,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                  side: BorderSide(color: Theme.of(context).colorScheme.outlineVariant.withOpacity(0.5)),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(20.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            room.roomNumber,
                            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                          ),
                          StatusBadge(status: room.isOccupied ? 'OCCUPIED' : 'VACANT'),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        room.description ?? 'No description provided.',
                        style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant),
                      ),
                      const SizedBox(height: 16),
                      const Divider(),
                      const SizedBox(height: 12),
                      _buildDetailRow('Default Monthly Rent', CurrencyHelper.formatPaise(room.defaultRentPaise)),
                      _buildDetailRow('Status', room.isActive ? 'Active (Rentable)' : 'Inactive / Under Maintenance'),
                      if (room.meterNumber != null) ...[
                        _buildDetailRow('Sub-meter Number', room.meterNumber!),
                        if (room.latestReadingCentiunits != null)
                          _buildDetailRow(
                            'Latest Meter Reading',
                            CurrencyHelper.formatCentiunits(room.latestReadingCentiunits!),
                          ),
                      ],
                      if (room.notes != null && room.notes!.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        Text('Notes:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.grey.shade700)),
                        const SizedBox(height: 4),
                        Text(room.notes!),
                      ],
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20),

              // Current Tenant Section
              Card(
                elevation: 0,
                color: Theme.of(context).colorScheme.surface,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                  side: BorderSide(color: Theme.of(context).colorScheme.outlineVariant.withOpacity(0.5)),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Current Occupancy',
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 12),
                      if (room.isOccupied) ...[
                        ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: const CircleAvatar(
                            backgroundColor: AppColors.primaryContainer,
                            child: Icon(Icons.person, color: AppColors.primary),
                          ),
                          title: Text(room.activeTenantName ?? 'Tenant', style: const TextStyle(fontWeight: FontWeight.bold)),
                          subtitle: Text('Agreed Rent: ${CurrencyHelper.formatPaise(room.agreedRentPaise ?? room.defaultRentPaise)}'),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Expanded(
                              child: OutlinedButton.icon(
                                onPressed: () => context.push('/bills/generate?roomId=${room.id}'),
                                icon: const Icon(Icons.receipt_long, size: 18),
                                label: const Text('Generate Bill'),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: FilledButton.tonalIcon(
                                onPressed: () => context.push('/electricity/record?meterId=${room.meterId}'),
                                icon: const Icon(Icons.bolt, size: 18),
                                label: const Text('Add Reading'),
                              ),
                            ),
                          ],
                        ),
                      ] else ...[
                        const Text('This room is currently vacant.'),
                        const SizedBox(height: 12),
                        FilledButton.icon(
                          onPressed: () => context.push('/tenants/assign?roomId=${room.id}'),
                          icon: const Icon(Icons.person_add_outlined),
                          label: const Text('Assign New Tenant'),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ],
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, _) => Center(child: Text('Error: $err')),
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: Colors.grey, fontSize: 13)),
          Text(value, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
        ],
      ),
    );
  }
}

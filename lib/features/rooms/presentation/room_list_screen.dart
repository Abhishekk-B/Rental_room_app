import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/utils/currency_helper.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/status_badge.dart';
import '../providers/rooms_provider.dart';

class RoomListScreen extends ConsumerWidget {
  const RoomListScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final roomsAsync = ref.watch(roomsListProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Rooms Management', style: TextStyle(fontWeight: FontWeight.bold)),
      ),
      body: roomsAsync.when(
        data: (rooms) {
          if (rooms.isEmpty) {
            return EmptyStateView(
              icon: Icons.meeting_room_outlined,
              title: 'No Rooms Found',
              message: 'Add your rental rooms to start tracking tenants and sub-meters.',
              buttonText: 'Add First Room',
              onAction: () => context.push('/rooms/add'),
            );
          }

          return RefreshIndicator(
            onRefresh: () async => ref.refresh(roomsListProvider),
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              itemCount: rooms.length,
              itemBuilder: (context, index) {
                final room = rooms[index];
                return Card(
                  elevation: 0,
                  margin: const EdgeInsets.only(bottom: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                    side: BorderSide(color: Theme.of(context).colorScheme.outlineVariant.withOpacity(0.5)),
                  ),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(16),
                    onTap: () => context.push('/rooms/${room.id}'),
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Row(
                                children: [
                                  CircleAvatar(
                                    backgroundColor: AppColors.primaryContainer,
                                    child: Icon(Icons.meeting_room, color: AppColors.primary, size: 20),
                                  ),
                                  const SizedBox(width: 12),
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        room.roomNumber,
                                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                                      ),
                                      Text(
                                        'Default Rent: ${CurrencyHelper.formatPaise(room.defaultRentPaise)}/mo',
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                              StatusBadge(status: room.isOccupied ? 'OCCUPIED' : 'VACANT'),
                            ],
                          ),
                          const SizedBox(height: 12),
                          const Divider(height: 1),
                          const SizedBox(height: 10),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Row(
                                children: [
                                  const Icon(Icons.person_outline, size: 16, color: Colors.grey),
                                  const SizedBox(width: 6),
                                  Text(
                                    room.isOccupied ? (room.activeTenantName ?? 'Tenant') : 'Vacant (Ready to rent)',
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: room.isOccupied ? FontWeight.w600 : FontWeight.normal,
                                      color: room.isOccupied ? Colors.black87 : Colors.grey.shade600,
                                    ),
                                  ),
                                ],
                              ),
                              if (room.meterNumber != null)
                                Row(
                                  children: [
                                    const Icon(Icons.bolt, size: 16, color: Colors.amber),
                                    const SizedBox(width: 4),
                                    Text(
                                      room.meterNumber!,
                                      style: const TextStyle(fontSize: 12, color: Colors.grey),
                                    ),
                                  ],
                                ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, _) => Center(child: Text('Error: $err')),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push('/rooms/add'),
        icon: const Icon(Icons.add),
        label: const Text('Add Room'),
      ),
    );
  }
}

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/database/daos/room_dao.dart';

final roomDaoProvider = Provider<RoomDao>((ref) => RoomDao());

final roomsListProvider = FutureProvider.autoDispose<List<RoomWithDetails>>((ref) async {
  final dao = ref.watch(roomDaoProvider);
  return await dao.getAllRoomsWithDetails();
});

final roomDetailProvider = FutureProvider.autoDispose.family<RoomWithDetails?, String>((ref, roomId) async {
  final dao = ref.watch(roomDaoProvider);
  return await dao.getRoomById(roomId);
});

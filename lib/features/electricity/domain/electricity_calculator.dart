class RoomConsumptionInput {
  final String roomId;
  final String roomNumber;
  final int unitsConsumedCentiunits; // e.g. 130 units = 13000 centiunits
  final bool isOccupied;

  RoomConsumptionInput({
    required this.roomId,
    required this.roomNumber,
    required this.unitsConsumedCentiunits,
    this.isOccupied = true,
  });
}

class RoomAllocationResult {
  final String roomId;
  final String roomNumber;
  final int unitsConsumedCentiunits;
  final int variableChargePaise;
  final int commonChargePaise;
  final int totalChargePaise;
  final double proportionRatio;

  RoomAllocationResult({
    required this.roomId,
    required this.roomNumber,
    required this.unitsConsumedCentiunits,
    required this.variableChargePaise,
    required this.commonChargePaise,
    required this.totalChargePaise,
    required this.proportionRatio,
  });
}

class AllocationSummary {
  final int totalBillPaise;
  final int fixedChargesPaise;
  final int commonAreaChargesPaise;
  final int variablePoolPaise;
  final int totalUnitsConsumedCentiunits;
  final List<RoomAllocationResult> roomAllocations;
  final int reconciliationAdjustmentPaise; // Extra paise adjusted to balance exact total

  AllocationSummary({
    required this.totalBillPaise,
    required this.fixedChargesPaise,
    required this.commonAreaChargesPaise,
    required this.variablePoolPaise,
    required this.totalUnitsConsumedCentiunits,
    required this.roomAllocations,
    required this.reconciliationAdjustmentPaise,
  });
}

class ElectricityCalculator {
  /// 1. Fixed Rate Calculation
  /// Units = (Current - Previous) / 100
  /// Charge (Paise) = (Units * RateInPaise)
  static int calculateFixedCharge({
    required int previousReadingCentiunits,
    required int currentReadingCentiunits,
    required int ratePerUnitPaise,
    bool isReset = false,
  }) {
    if (!isReset && currentReadingCentiunits < previousReadingCentiunits) {
      throw ArgumentError(
        'Current reading cannot be lower than previous reading without meter reset.',
      );
    }

    final int unitsCentiunits = isReset
        ? currentReadingCentiunits
        : (currentReadingCentiunits - previousReadingCentiunits);

    // Charge in paise = (unitsCentiunits * ratePerUnitPaise) / 100
    // Rounded to nearest paise
    final int chargePaise = ((unitsCentiunits * ratePerUnitPaise) + 50) ~/ 100;
    return chargePaise > 0 ? chargePaise : 0;
  }

  /// Calculates units consumed between two readings
  static int calculateUnitsCentiunits({
    required int previousReadingCentiunits,
    required int currentReadingCentiunits,
    bool isReset = false,
  }) {
    if (!isReset && currentReadingCentiunits < previousReadingCentiunits) {
      throw ArgumentError(
        'Current reading ($currentReadingCentiunits) is lower than previous reading ($previousReadingCentiunits).',
      );
    }
    if (isReset) {
      return currentReadingCentiunits;
    }
    return currentReadingCentiunits - previousReadingCentiunits;
  }

  /// 2. Proportional Master Bill Allocation
  /// Allocates total electricity bill proportionally across occupied rooms based on unit consumption,
  /// adds fixed/common area charges, and guarantees exact penny-reconciliation (zero leakage).
  static AllocationSummary allocateProportionalBill({
    required int totalBillAmountPaise,
    required List<RoomConsumptionInput> rooms,
    int fixedChargesPaise = 0,
    int commonAreaChargesPaise = 0,
    bool splitCommonChargesEqually = true,
  }) {
    if (rooms.isEmpty) {
      throw ArgumentError('At least one room is required for allocation.');
    }

    if (totalBillAmountPaise < (fixedChargesPaise + commonAreaChargesPaise)) {
      throw ArgumentError('Total bill cannot be less than fixed plus common area charges.');
    }

    final int variablePoolPaise = totalBillAmountPaise - fixedChargesPaise - commonAreaChargesPaise;
    final int commonTotalPaise = fixedChargesPaise + commonAreaChargesPaise;

    // Filter active/occupied rooms for common share
    final List<RoomConsumptionInput> activeRooms = rooms.where((r) => r.isOccupied).toList();
    final int activeCount = activeRooms.isEmpty ? rooms.length : activeRooms.length;

    // Total units consumed across all rooms
    int totalUnitsCentiunits = 0;
    for (final room in rooms) {
      totalUnitsCentiunits += room.unitsConsumedCentiunits;
    }

    // Base common charge per room
    final int baseCommonPerRoomPaise = commonTotalPaise ~/ activeCount;
    int commonRemainderPaise = commonTotalPaise % activeCount;

    final List<RoomAllocationResult> provisionalAllocations = [];
    int sumAllocatedVariable = 0;
    int sumAllocatedCommon = 0;

    for (int i = 0; i < rooms.length; i++) {
      final room = rooms[i];
      int roomCommonPaise = 0;
      if (room.isOccupied) {
        roomCommonPaise = baseCommonPerRoomPaise;
        if (commonRemainderPaise > 0) {
          roomCommonPaise += 1;
          commonRemainderPaise -= 1;
        }
      }
      sumAllocatedCommon += roomCommonPaise;

      int roomVariablePaise = 0;
      double proportionRatio = 0.0;

      if (totalUnitsCentiunits > 0 && room.unitsConsumedCentiunits > 0) {
        proportionRatio = room.unitsConsumedCentiunits / totalUnitsCentiunits;
        // Floor integer arithmetic to prevent over-allocation
        roomVariablePaise = ((variablePoolPaise * room.unitsConsumedCentiunits) ~/ totalUnitsCentiunits);
      } else if (totalUnitsCentiunits == 0) {
        // Zero total consumption: variable is zero, cost is purely common
        proportionRatio = 1.0 / rooms.length;
        roomVariablePaise = 0;
      }

      sumAllocatedVariable += roomVariablePaise;

      provisionalAllocations.add(
        RoomAllocationResult(
          roomId: room.roomId,
          roomNumber: room.roomNumber,
          unitsConsumedCentiunits: room.unitsConsumedCentiunits,
          variableChargePaise: roomVariablePaise,
          commonChargePaise: roomCommonPaise,
          totalChargePaise: roomVariablePaise + roomCommonPaise,
          proportionRatio: proportionRatio,
        ),
      );
    }

    // Exact Penny Reconciliation:
    // The variable remainder (due to integer truncation) must be distributed to guarantee:
    // sum(totalChargePaise) == totalBillAmountPaise exactly.
    int variableRemainderPaise = variablePoolPaise - sumAllocatedVariable;

    // Sort room indices by consumption descending so highest consumer receives the fractional paise adjustment
    final List<int> sortedIndices = List.generate(rooms.length, (index) => index);
    sortedIndices.sort((a, b) => rooms[b].unitsConsumedCentiunits.compareTo(rooms[a].unitsConsumedCentiunits));

    final List<RoomAllocationResult> finalAllocations = List.from(provisionalAllocations);

    int idx = 0;
    while (variableRemainderPaise > 0 && sortedIndices.isNotEmpty) {
      final targetRoomIndex = sortedIndices[idx % sortedIndices.length];
      final current = finalAllocations[targetRoomIndex];
      finalAllocations[targetRoomIndex] = RoomAllocationResult(
        roomId: current.roomId,
        roomNumber: current.roomNumber,
        unitsConsumedCentiunits: current.unitsConsumedCentiunits,
        variableChargePaise: current.variableChargePaise + 1,
        commonChargePaise: current.commonChargePaise,
        totalChargePaise: current.totalChargePaise + 1,
        proportionRatio: current.proportionRatio,
      );
      variableRemainderPaise -= 1;
      idx++;
    }

    // Verify exact reconciliation
    int finalSum = 0;
    for (final alloc in finalAllocations) {
      finalSum += alloc.totalChargePaise;
    }

    assert(
      finalSum == totalBillAmountPaise,
      'Reconciliation failed: Final sum $finalSum does not equal total bill $totalBillAmountPaise',
    );

    return AllocationSummary(
      totalBillPaise: totalBillAmountPaise,
      fixedChargesPaise: fixedChargesPaise,
      commonAreaChargesPaise: commonAreaChargesPaise,
      variablePoolPaise: variablePoolPaise,
      totalUnitsConsumedCentiunits: totalUnitsCentiunits,
      roomAllocations: finalAllocations,
      reconciliationAdjustmentPaise: (variablePoolPaise - sumAllocatedVariable),
    );
  }
}

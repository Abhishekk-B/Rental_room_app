class BillCalculationInput {
  final String tenancyId;
  final String tenantName;
  final String tenantPhone;
  final String roomId;
  final String roomNumber;
  final int billingMonth;
  final int billingYear;
  final int rentAmountPaise;
  final int rentAdvanceAvailablePaise;
  final int rentAdvanceAppliedPaise;
  final int electricityUnitsCentiunits;
  final int electricityAmountPaise;
  final int electricityAdvanceAvailablePaise;
  final int electricityAdvanceAppliedPaise;
  final int additionalChargesPaise;
  final int previousBalancePaise;
  final List<LineItemInput> customLineItems;
  final int dueDateEpoch;

  BillCalculationInput({
    required this.tenancyId,
    required this.tenantName,
    required this.tenantPhone,
    required this.roomId,
    required this.roomNumber,
    required this.billingMonth,
    required this.billingYear,
    required this.rentAmountPaise,
    this.rentAdvanceAvailablePaise = 0,
    this.rentAdvanceAppliedPaise = 0,
    required this.electricityUnitsCentiunits,
    required this.electricityAmountPaise,
    this.electricityAdvanceAvailablePaise = 0,
    this.electricityAdvanceAppliedPaise = 0,
    this.additionalChargesPaise = 0,
    this.previousBalancePaise = 0,
    this.customLineItems = const [],
    required this.dueDateEpoch,
  });
}

class LineItemInput {
  final String description;
  final String category; // 'RENT', 'ELECTRICITY', 'ADVANCE_ADJUSTMENT', 'MAINTENANCE', 'WATER', 'DISCOUNT', 'OTHER'
  final int amountPaise;

  LineItemInput({
    required this.description,
    required this.category,
    required this.amountPaise,
  });
}

class CalculatedBillResult {
  final String billNumber;
  final String tenancyId;
  final String tenantName;
  final String tenantPhone;
  final String roomId;
  final String roomNumber;
  final int billingMonth;
  final int billingYear;
  final int rentAmountPaise;
  final int rentAdvanceAppliedPaise;
  final int outstandingRentPaise;
  final int electricityUnitsCentiunits;
  final int electricityAmountPaise;
  final int electricityAdvanceAppliedPaise;
  final int outstandingElectricityPaise;
  final int additionalChargesPaise;
  final int totalCurrentChargesPaise;
  final int previousBalancePaise;
  final int totalDuePaise;
  final int totalAdvanceAppliedPaise;
  final int netAmountDuePaise;
  final int amountPaidPaise;
  final int remainingBalancePaise;
  final int billDateEpoch;
  final int dueDateEpoch;
  final String status; // 'UNPAID', 'PARTIALLY_PAID', 'PAID', 'OVERDUE'
  final List<LineItemInput> lineItems;

  CalculatedBillResult({
    required this.billNumber,
    required this.tenancyId,
    required this.tenantName,
    required this.tenantPhone,
    required this.roomId,
    required this.roomNumber,
    required this.billingMonth,
    required this.billingYear,
    required this.rentAmountPaise,
    required this.rentAdvanceAppliedPaise,
    required this.outstandingRentPaise,
    required this.electricityUnitsCentiunits,
    required this.electricityAmountPaise,
    required this.electricityAdvanceAppliedPaise,
    required this.outstandingElectricityPaise,
    required this.additionalChargesPaise,
    required this.totalCurrentChargesPaise,
    required this.previousBalancePaise,
    required this.totalDuePaise,
    required this.totalAdvanceAppliedPaise,
    required this.netAmountDuePaise,
    required this.amountPaidPaise,
    required this.remainingBalancePaise,
    required this.billDateEpoch,
    required this.dueDateEpoch,
    required this.status,
    required this.lineItems,
  });
}

class BillingEngine {
  /// Generates a unique human-friendly Bill Number (e.g. "BILL-202611-R101")
  static String generateBillNumber({
    required int year,
    required int month,
    required String roomNumber,
  }) {
    final String cleanRoom = roomNumber.replaceAll(' ', '').toUpperCase();
    final String m = month.toString().padLeft(2, '0');
    return 'BILL-$year$m-$cleanRoom';
  }

  /// Calculates a monthly bill with independent rent & electricity advance deductions
  static CalculatedBillResult calculateMonthlyBill(
    BillCalculationInput input, {
    int? currentEpoch,
    int initialAmountPaidPaise = 0,
  }) {
    final now = currentEpoch ?? DateTime.now().millisecondsSinceEpoch;

    // Strict validation: advance applied cannot exceed available balance or charge
    final int effectiveRentAdvApplied = input.rentAdvanceAppliedPaise.clamp(
      0,
      input.rentAdvanceAvailablePaise < input.rentAmountPaise
          ? input.rentAdvanceAvailablePaise
          : input.rentAmountPaise,
    );

    final int effectiveElecAdvApplied = input.electricityAdvanceAppliedPaise.clamp(
      0,
      input.electricityAdvanceAvailablePaise < input.electricityAmountPaise
          ? input.electricityAdvanceAvailablePaise
          : input.electricityAmountPaise,
    );

    // Outstanding calculations per category
    final int outstandingRentPaise = input.rentAmountPaise - effectiveRentAdvApplied;
    final int outstandingElectricityPaise = input.electricityAmountPaise - effectiveElecAdvApplied;

    // Build standard line items
    final List<LineItemInput> items = [];

    // 1. Rent Line Item
    items.add(
      LineItemInput(
        description: 'Room Rent (${input.roomNumber})',
        category: 'RENT',
        amountPaise: input.rentAmountPaise,
      ),
    );

    // 1b. Rent Advance Deduction Item (if applied)
    if (effectiveRentAdvApplied > 0) {
      items.add(
        LineItemInput(
          description: 'Rent Advance Applied',
          category: 'ADVANCE_ADJUSTMENT',
          amountPaise: -effectiveRentAdvApplied,
        ),
      );
    }

    // 2. Electricity Line Item
    if (input.electricityAmountPaise > 0 || input.electricityUnitsCentiunits > 0) {
      final double units = input.electricityUnitsCentiunits / 100.0;
      final String unitLabel = input.electricityUnitsCentiunits % 100 == 0
          ? '${units.toInt()}'
          : units.toStringAsFixed(2);
      items.add(
        LineItemInput(
          description: 'Electricity Charges ($unitLabel units)',
          category: 'ELECTRICITY',
          amountPaise: input.electricityAmountPaise,
        ),
      );

      // 2b. Electricity Advance Deduction Item (if applied)
      if (effectiveElecAdvApplied > 0) {
        items.add(
          LineItemInput(
            description: 'Electricity Advance Applied',
            category: 'ADVANCE_ADJUSTMENT',
            amountPaise: -effectiveElecAdvApplied,
          ),
        );
      }
    }

    // 3. Additional Custom Line items
    for (final customItem in input.customLineItems) {
      items.add(customItem);
    }

    int customAdditions = 0;
    for (final item in input.customLineItems) {
      customAdditions += item.amountPaise;
    }
    final int effectiveAdditional = input.additionalChargesPaise + customAdditions;

    final int totalCurrentChargesPaise =
        input.rentAmountPaise + input.electricityAmountPaise + effectiveAdditional;

    final int totalDuePaise = input.previousBalancePaise + totalCurrentChargesPaise;
    final int totalAdvanceAppliedPaise = effectiveRentAdvApplied + effectiveElecAdvApplied;
    final int netAmountDuePaise = totalDuePaise - totalAdvanceAppliedPaise;

    final int remainingBalancePaise = netAmountDuePaise - initialAmountPaidPaise;

    final String status = determineBillStatus(
      totalDuePaise: netAmountDuePaise,
      amountPaidPaise: initialAmountPaidPaise,
      remainingBalancePaise: remainingBalancePaise,
      dueDateEpoch: input.dueDateEpoch,
      currentEpoch: now,
    );

    return CalculatedBillResult(
      billNumber: generateBillNumber(
        year: input.billingYear,
        month: input.billingMonth,
        roomNumber: input.roomNumber,
      ),
      tenancyId: input.tenancyId,
      tenantName: input.tenantName,
      tenantPhone: input.tenantPhone,
      roomId: input.roomId,
      roomNumber: input.roomNumber,
      billingMonth: input.billingMonth,
      billingYear: input.billingYear,
      rentAmountPaise: input.rentAmountPaise,
      rentAdvanceAppliedPaise: effectiveRentAdvApplied,
      outstandingRentPaise: outstandingRentPaise,
      electricityUnitsCentiunits: input.electricityUnitsCentiunits,
      electricityAmountPaise: input.electricityAmountPaise,
      electricityAdvanceAppliedPaise: effectiveElecAdvApplied,
      outstandingElectricityPaise: outstandingElectricityPaise,
      additionalChargesPaise: effectiveAdditional,
      totalCurrentChargesPaise: totalCurrentChargesPaise,
      previousBalancePaise: input.previousBalancePaise,
      totalDuePaise: totalDuePaise,
      totalAdvanceAppliedPaise: totalAdvanceAppliedPaise,
      netAmountDuePaise: netAmountDuePaise,
      amountPaidPaise: initialAmountPaidPaise,
      remainingBalancePaise: remainingBalancePaise,
      billDateEpoch: now,
      dueDateEpoch: input.dueDateEpoch,
      status: status,
      lineItems: items,
    );
  }

  /// Determines bill status based on net balance and due date
  static String determineBillStatus({
    required int totalDuePaise,
    required int amountPaidPaise,
    required int remainingBalancePaise,
    required int dueDateEpoch,
    required int currentEpoch,
  }) {
    if (totalDuePaise <= 0 || remainingBalancePaise <= 0) {
      return 'PAID';
    }
    if (amountPaidPaise > 0) {
      if (currentEpoch > dueDateEpoch) {
        return 'OVERDUE';
      }
      return 'PARTIALLY_PAID';
    }
    if (currentEpoch > dueDateEpoch) {
      return 'OVERDUE';
    }
    return 'UNPAID';
  }
}

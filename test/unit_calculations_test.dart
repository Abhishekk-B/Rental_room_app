import 'dart:io';

// Directly include and test the calculator and engine classes
import '../lib/core/utils/currency_helper.dart';
import '../lib/features/electricity/domain/electricity_calculator.dart';
import '../lib/features/billing/domain/billing_engine.dart';

void main() {
  int passed = 0;
  int failed = 0;

  void test(String name, void Function() body) {
    try {
      body();
      print('  ✓ $name');
      passed++;
    } catch (e, stack) {
      print('  ✗ $name');
      print('    Error: $e');
      print('    Stack: $stack');
      failed++;
    }
  }

  void expect(dynamic actual, dynamic expected, [String? message]) {
    if (actual != expected) {
      throw Exception('${message ?? "Assertion failed"}: Expected "$expected", got "$actual"');
    }
  }

  print('\n=== Running RentPulse Calculation & Domain Engine Tests ===\n');

  print('1. Currency & Precision Tests:');
  test('Parses rupee strings with decimals and symbols accurately', () {
    expect(CurrencyHelper.parseRupeesToPaise('3500'), 350000);
    expect(CurrencyHelper.parseRupeesToPaise('3,500.50'), 350050);
    expect(CurrencyHelper.parseRupeesToPaise('₹ 12,450.75'), 1245075);
    expect(CurrencyHelper.parseRupeesToPaise('8.5'), 850);
    expect(CurrencyHelper.parseRupeesToPaise(''), 0);
  });

  test('Formats paise to rupee strings', () {
    expect(CurrencyHelper.paiseToRupeesString(350000), '3500');
    expect(CurrencyHelper.paiseToRupeesString(350050), '3500.50');
    expect(CurrencyHelper.formatCentiunits(13000), '130 units');
    expect(CurrencyHelper.formatCentiunits(13050), '130.50 units');
  });

  print('\n2. Electricity Meter & Fixed Rate Tests:');
  test('Calculates units and fixed charges accurately', () {
    // 130.00 units consumed at ₹8.50 per unit (850 paise)
    final units = ElectricityCalculator.calculateUnitsCentiunits(
      previousReadingCentiunits: 100000, // 1000.00
      currentReadingCentiunits: 113000,  // 1130.00
    );
    expect(units, 13000); // 130.00 units

    final charge = ElectricityCalculator.calculateFixedCharge(
      previousReadingCentiunits: 100000,
      currentReadingCentiunits: 113000,
      ratePerUnitPaise: 850,
    );
    // 130 * 850 paise = 110500 paise (₹1,105.00)
    expect(charge, 110500);
  });

  test('Rejects lower current reading without meter reset', () {
    bool threw = false;
    try {
      ElectricityCalculator.calculateUnitsCentiunits(
        previousReadingCentiunits: 50000,
        currentReadingCentiunits: 48000,
      );
    } catch (_) {
      threw = true;
    }
    expect(threw, true, 'Expected exception on monotonic violation');
  });

  test('Accepts lower current reading when isReset=true (meter rollover / replacement)', () {
    final units = ElectricityCalculator.calculateUnitsCentiunits(
      previousReadingCentiunits: 999900,
      currentReadingCentiunits: 5000,
      isReset: true,
    );
    expect(units, 5000);
  });

  print('\n3. Proportional Actual Bill Allocation Tests:');
  test('Allocates ₹3,500 bill across 3 rooms (130, 110, 125 units) with exact paise reconciliation', () {
    // Exact user scenario:
    // Total bill = ₹3,500 = 350000 paise
    // Room 1 = 130 units (13000 centiunits)
    // Room 2 = 110 units (11000 centiunits)
    // Room 3 = 125 units (12500 centiunits)
    // Total units = 365 units
    final rooms = [
      RoomConsumptionInput(roomId: 'r1', roomNumber: 'Room 101', unitsConsumedCentiunits: 13000),
      RoomConsumptionInput(roomId: 'r2', roomNumber: 'Room 102', unitsConsumedCentiunits: 11000),
      RoomConsumptionInput(roomId: 'r3', roomNumber: 'Room 103', unitsConsumedCentiunits: 12500),
    ];

    final summary = ElectricityCalculator.allocateProportionalBill(
      totalBillAmountPaise: 350000,
      rooms: rooms,
    );

    expect(summary.totalBillPaise, 350000);
    expect(summary.totalUnitsConsumedCentiunits, 36500);

    // Verify sum of allocations matches exactly 350,000 paise
    int totalAllocated = 0;
    for (final alloc in summary.roomAllocations) {
      totalAllocated += alloc.totalChargePaise;
      print('    ${alloc.roomNumber}: ${alloc.unitsConsumedCentiunits ~/ 100} units -> ₹${(alloc.totalChargePaise / 100).toStringAsFixed(2)}');
    }

    expect(totalAllocated, 350000, 'Sum of room allocations must equal 350,000 paise exactly');
    // Room 1 (highest consumption: 130 units) receives the reconciliation adjustment if any
    expect(summary.roomAllocations[0].totalChargePaise >= summary.roomAllocations[2].totalChargePaise, true);
    expect(summary.roomAllocations[2].totalChargePaise >= summary.roomAllocations[1].totalChargePaise, true);
  });

  test('Handles fixed and common-area charges alongside variable allocation', () {
    final rooms = [
      RoomConsumptionInput(roomId: 'r1', roomNumber: 'Room 101', unitsConsumedCentiunits: 10000),
      RoomConsumptionInput(roomId: 'r2', roomNumber: 'Room 102', unitsConsumedCentiunits: 20000),
    ];

    // Total: ₹3,000 (300000 paise). Fixed: ₹500 (50000 paise), Common: ₹400 (40000 paise)
    // Variable pool = 3000 - 900 = ₹2,100 (210000 paise)
    // Split: 100 vs 200 units -> Room 1 gets 1/3 (₹700) + half of common (₹450) = ₹1,150
    // Room 2 gets 2/3 (₹1,400) + half of common (₹450) = ₹1,850
    final summary = ElectricityCalculator.allocateProportionalBill(
      totalBillAmountPaise: 300000,
      rooms: rooms,
      fixedChargesPaise: 50000,
      commonAreaChargesPaise: 40000,
    );

    expect(summary.roomAllocations[0].totalChargePaise, 115000);
    expect(summary.roomAllocations[1].totalChargePaise, 185000);
    expect(summary.roomAllocations[0].totalChargePaise + summary.roomAllocations[1].totalChargePaise, 300000);
  });

  test('Handles zero total consumption without division by zero', () {
    final rooms = [
      RoomConsumptionInput(roomId: 'r1', roomNumber: 'Room 101', unitsConsumedCentiunits: 0),
      RoomConsumptionInput(roomId: 'r2', roomNumber: 'Room 102', unitsConsumedCentiunits: 0),
    ];

    // Master bill is purely fixed charge ₹600 (60000 paise)
    final summary = ElectricityCalculator.allocateProportionalBill(
      totalBillAmountPaise: 60000,
      rooms: rooms,
      fixedChargesPaise: 60000,
      commonAreaChargesPaise: 0,
    );

    expect(summary.roomAllocations[0].totalChargePaise, 30000);
    expect(summary.roomAllocations[1].totalChargePaise, 30000);
  });

  print('\n4. Monthly Billing Engine Tests:');
  test('Calculates full bill with previous balance, rent, electricity and line items', () {
    final now = DateTime(2026, 11, 5).millisecondsSinceEpoch;
    final dueDate = DateTime(2026, 11, 10).millisecondsSinceEpoch;

    final input = BillCalculationInput(
      tenancyId: 'ten_01',
      tenantName: 'Rahul Sharma',
      tenantPhone: '+91 9876543210',
      roomId: 'room_01',
      roomNumber: 'Room 101',
      billingMonth: 11,
      billingYear: 2026,
      rentAmountPaise: 800000,            // ₹8,000
      electricityUnitsCentiunits: 13000,  // 130 units
      electricityAmountPaise: 110500,     // ₹1,105
      previousBalancePaise: 50000,        // ₹500 outstanding
      additionalChargesPaise: 20000,      // ₹200 cleaning
      dueDateEpoch: dueDate,
    );

    final bill = BillingEngine.calculateMonthlyBill(input, currentEpoch: now);

    expect(bill.billNumber, 'BILL-202611-ROOM101');
    expect(bill.rentAmountPaise, 800000);
    expect(bill.electricityAmountPaise, 110500);
    expect(bill.totalCurrentChargesPaise, 930500); // 8000 + 1105 + 200 = 9305
    expect(bill.totalDuePaise, 980500); // 9305 + 500 = 9805 (₹9,805.00)
    expect(bill.remainingBalancePaise, 980500);
    expect(bill.status, 'UNPAID');
    expect(bill.lineItems.length >= 2, true);
  });

  test('Updates status to PARTIALLY_PAID and PAID appropriately', () {
    final dueDate = DateTime(2026, 11, 10).millisecondsSinceEpoch;
    final nowBeforeDue = DateTime(2026, 11, 5).millisecondsSinceEpoch;
    final nowAfterDue = DateTime(2026, 11, 15).millisecondsSinceEpoch;

    // Partial payment before due date
    expect(
      BillingEngine.determineBillStatus(
        totalDuePaise: 100000,
        amountPaidPaise: 40000,
        remainingBalancePaise: 60000,
        dueDateEpoch: dueDate,
        currentEpoch: nowBeforeDue,
      ),
      'PARTIALLY_PAID',
    );

    // Overdue unpaid
    expect(
      BillingEngine.determineBillStatus(
        totalDuePaise: 100000,
        amountPaidPaise: 0,
        remainingBalancePaise: 100000,
        dueDateEpoch: dueDate,
        currentEpoch: nowAfterDue,
      ),
      'OVERDUE',
    );

    // Overdue partially paid
    expect(
      BillingEngine.determineBillStatus(
        totalDuePaise: 100000,
        amountPaidPaise: 50000,
        remainingBalancePaise: 50000,
        dueDateEpoch: dueDate,
        currentEpoch: nowAfterDue,
      ),
      'OVERDUE',
    );

    // Fully paid
    expect(
      BillingEngine.determineBillStatus(
        totalDuePaise: 100000,
        amountPaidPaise: 100000,
        remainingBalancePaise: 0,
        dueDateEpoch: dueDate,
        currentEpoch: nowAfterDue,
      ),
      'PAID',
    );
  });

  print('\n=== Test Summary: $passed Passed, $failed Failed ===\n');
  if (failed > 0) {
    exit(1);
  }
}

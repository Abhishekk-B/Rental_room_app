import 'dart:io';

import '../lib/core/utils/currency_helper.dart';
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

  print('\n=== Running Independent Rent & Electricity Advance Account Tests ===\n');

  print('1. Exact User Scenario: Independent Full Advance Deductions');
  test('Rent ₹5,000 with ₹10,000 advance & Elec ₹1,040 with ₹2,000 advance', () {
    // Exact user scenario:
    // Rent charge: ₹5,000 (500000 paise)
    // Rent advance available: ₹10,000 (1000000 paise)
    // Rent advance applied: ₹5,000 (500000 paise)
    // -> Outstanding rent: ₹0
    // -> Remaining rent advance: ₹5,000
    //
    // Electricity charge: ₹1,040 (104000 paise)
    // Electricity advance available: ₹2,000 (200000 paise)
    // Electricity advance applied: ₹1,040 (104000 paise)
    // -> Outstanding electricity: ₹0
    // -> Remaining electricity advance: ₹960 (96000 paise)

    final dueDate = DateTime(2026, 11, 10).millisecondsSinceEpoch;

    final input = BillCalculationInput(
      tenancyId: 'ten_01',
      tenantName: 'Rahul Sharma',
      tenantPhone: '+91 9876543210',
      roomId: 'room_01',
      roomNumber: 'Room 101',
      billingMonth: 11,
      billingYear: 2026,
      rentAmountPaise: 500000,
      rentAdvanceAvailablePaise: 1000000,
      rentAdvanceAppliedPaise: 500000,
      electricityUnitsCentiunits: 12000,
      electricityAmountPaise: 104000,
      electricityAdvanceAvailablePaise: 200000,
      electricityAdvanceAppliedPaise: 104000,
      previousBalancePaise: 0,
      additionalChargesPaise: 0,
      dueDateEpoch: dueDate,
    );

    final bill = BillingEngine.calculateMonthlyBill(input);

    expect(bill.outstandingRentPaise, 0, 'Outstanding rent must be ₹0');
    expect(bill.rentAdvanceAppliedPaise, 500000, 'Rent advance applied must be ₹5,000');
    expect(input.rentAdvanceAvailablePaise - bill.rentAdvanceAppliedPaise, 500000, 'Remaining rent advance must be ₹5,000');

    expect(bill.outstandingElectricityPaise, 0, 'Outstanding electricity must be ₹0');
    expect(bill.electricityAdvanceAppliedPaise, 104000, 'Electricity advance applied must be ₹1,040');
    expect(input.electricityAdvanceAvailablePaise - bill.electricityAdvanceAppliedPaise, 96000, 'Remaining electricity advance must be ₹960');

    expect(bill.totalDuePaise, 604000, 'Gross total charge must be ₹6,040');
    expect(bill.totalAdvanceAppliedPaise, 604000, 'Total advances applied must be ₹6,040');
    expect(bill.netAmountDuePaise, 0, 'Net amount due must be ₹0');
    expect(bill.status, 'PAID', 'Bill status must be fully PAID due to advances applied');
  });

  print('\n2. Partial Advance Adjustments');
  test('Partial Rent Advance (Rent ₹8,000, Advance ₹3,000) & Partial Elec (Charge ₹1,500, Advance ₹500)', () {
    final dueDate = DateTime(2026, 11, 10).millisecondsSinceEpoch;

    final input = BillCalculationInput(
      tenancyId: 'ten_02',
      tenantName: 'Priya Verma',
      tenantPhone: '+91 9811223344',
      roomId: 'room_02',
      roomNumber: 'Room 102',
      billingMonth: 11,
      billingYear: 2026,
      rentAmountPaise: 800000,
      rentAdvanceAvailablePaise: 300000,
      rentAdvanceAppliedPaise: 300000,
      electricityUnitsCentiunits: 15000,
      electricityAmountPaise: 150000,
      electricityAdvanceAvailablePaise: 50000,
      electricityAdvanceAppliedPaise: 50000,
      previousBalancePaise: 0,
      additionalChargesPaise: 0,
      dueDateEpoch: dueDate,
    );

    final bill = BillingEngine.calculateMonthlyBill(input);

    expect(bill.rentAmountPaise, 800000);
    expect(bill.rentAdvanceAppliedPaise, 300000);
    expect(bill.outstandingRentPaise, 500000, 'Outstanding rent should be ₹5,000');

    expect(bill.electricityAmountPaise, 150000);
    expect(bill.electricityAdvanceAppliedPaise, 50000);
    expect(bill.outstandingElectricityPaise, 100000, 'Outstanding electricity should be ₹1,000');

    // Total gross: 8000 + 1500 = 9500 (950000 paise)
    // Advance applied: 3000 + 500 = 3500 (350000 paise)
    // Net amount due to pay: 9500 - 3500 = 6000 (600000 paise)
    expect(bill.totalDuePaise, 950000);
    expect(bill.totalAdvanceAppliedPaise, 350000);
    expect(bill.netAmountDuePaise, 600000, 'Net amount due must be ₹6,000');
    expect(bill.remainingBalancePaise, 600000);
    expect(bill.status, 'UNPAID');
  });

  print('\n3. Strict Separation Safety Enforcements');
  test('Clamps advance applied so rent advance never exceeds rent or available balance', () {
    final dueDate = DateTime(2026, 11, 10).millisecondsSinceEpoch;

    // Attemping to over-apply rent advance
    final input = BillCalculationInput(
      tenancyId: 'ten_01',
      tenantName: 'Rahul',
      tenantPhone: '',
      roomId: 'room_01',
      roomNumber: '101',
      billingMonth: 11,
      billingYear: 2026,
      rentAmountPaise: 500000,          // Rent is ₹5,000
      rentAdvanceAvailablePaise: 400000,// Only ₹4,000 advance available
      rentAdvanceAppliedPaise: 600000,  // Requesting to apply ₹6,000 (invalid over-application)
      electricityUnitsCentiunits: 0,
      electricityAmountPaise: 0,
      dueDateEpoch: dueDate,
    );

    final bill = BillingEngine.calculateMonthlyBill(input);
    // Must be clamped to available balance of ₹4,000!
    expect(bill.rentAdvanceAppliedPaise, 400000, 'Applied rent advance must be clamped to available balance');
    expect(bill.outstandingRentPaise, 100000, 'Remaining outstanding rent is ₹1,000');
  });

  test('Preserves line item snapshot for auditability', () {
    final dueDate = DateTime(2026, 11, 10).millisecondsSinceEpoch;

    final input = BillCalculationInput(
      tenancyId: 'ten_01',
      tenantName: 'Rahul',
      tenantPhone: '',
      roomId: 'room_01',
      roomNumber: '101',
      billingMonth: 11,
      billingYear: 2026,
      rentAmountPaise: 500000,
      rentAdvanceAvailablePaise: 500000,
      rentAdvanceAppliedPaise: 500000,
      electricityUnitsCentiunits: 10000,
      electricityAmountPaise: 100000,
      electricityAdvanceAvailablePaise: 100000,
      electricityAdvanceAppliedPaise: 100000,
      dueDateEpoch: dueDate,
    );

    final bill = BillingEngine.calculateMonthlyBill(input);
    expect(bill.lineItems.length >= 4, true, 'Must contain Rent, Rent Advance, Elec, and Elec Advance line items');
    expect(bill.lineItems[1].amountPaise, -500000, 'Rent advance deduction line item must be negative ₹5,000');
    expect(bill.lineItems[3].amountPaise, -100000, 'Elec advance deduction line item must be negative ₹1,000');
  });

  print('\n=== Advance Account Test Summary: $passed Passed, $failed Failed ===\n');
  if (failed > 0) exit(1);
}

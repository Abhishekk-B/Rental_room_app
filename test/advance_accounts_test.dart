import 'package:flutter_test/flutter_test.dart';

import 'package:rental_room_app/features/billing/domain/billing_engine.dart';

void main() {
  group('1. Exact User Scenario: Independent Full Advance Deductions', () {
    test('Rent ₹5,000 with ₹10,000 advance & Elec ₹1,040 with ₹2,000 advance', () {
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

      expect(bill.outstandingRentPaise, 0);
      expect(bill.rentAdvanceAppliedPaise, 500000);
      expect(input.rentAdvanceAvailablePaise - bill.rentAdvanceAppliedPaise, 500000);

      expect(bill.outstandingElectricityPaise, 0);
      expect(bill.electricityAdvanceAppliedPaise, 104000);
      expect(input.electricityAdvanceAvailablePaise - bill.electricityAdvanceAppliedPaise, 96000);

      expect(bill.totalDuePaise, 604000);
      expect(bill.totalAdvanceAppliedPaise, 604000);
      expect(bill.netAmountDuePaise, 0);
      expect(bill.status, 'PAID');
    });
  });

  group('2. Partial Advance Adjustments', () {
    test('Partial Rent Advance & Partial Elec Advance', () {
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
      expect(bill.outstandingRentPaise, 500000);

      expect(bill.electricityAmountPaise, 150000);
      expect(bill.electricityAdvanceAppliedPaise, 50000);
      expect(bill.outstandingElectricityPaise, 100000);

      expect(bill.totalDuePaise, 950000);
      expect(bill.totalAdvanceAppliedPaise, 350000);
      expect(bill.netAmountDuePaise, 600000);
      expect(bill.remainingBalancePaise, 600000);
      expect(bill.status, 'UNPAID');
    });
  });

  group('3. Strict Separation Safety Enforcements', () {
    test('Clamps advance applied so rent advance never exceeds rent or available balance', () {
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
        rentAdvanceAvailablePaise: 400000,
        rentAdvanceAppliedPaise: 600000,
        electricityUnitsCentiunits: 0,
        electricityAmountPaise: 0,
        dueDateEpoch: dueDate,
      );

      final bill = BillingEngine.calculateMonthlyBill(input);
      expect(bill.rentAdvanceAppliedPaise, 400000);
      expect(bill.outstandingRentPaise, 100000);
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
      expect(bill.lineItems.length >= 4, true);
      expect(bill.lineItems[1].amountPaise, -500000);
      expect(bill.lineItems[3].amountPaise, -100000);
    });
  });
}

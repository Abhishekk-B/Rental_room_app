import 'package:flutter_test/flutter_test.dart';

import 'package:rental_room_app/core/utils/currency_helper.dart';
import 'package:rental_room_app/features/electricity/domain/electricity_calculator.dart';
import 'package:rental_room_app/features/billing/domain/billing_engine.dart';

void main() {
  group('1. Currency & Precision Tests', () {
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
  });

  group('2. Electricity Meter & Fixed Rate Tests', () {
    test('Calculates units and fixed charges accurately', () {
      final units = ElectricityCalculator.calculateUnitsCentiunits(
        previousReadingCentiunits: 100000,
        currentReadingCentiunits: 113000,
      );
      expect(units, 13000); // 130.00 units

      final charge = ElectricityCalculator.calculateFixedCharge(
        previousReadingCentiunits: 100000,
        currentReadingCentiunits: 113000,
        ratePerUnitPaise: 850,
      );
      expect(charge, 110500); // 130 * 850 paise = 110500 paise (₹1,105.00)
    });

    test('Rejects lower current reading without meter reset', () {
      expect(
        () => ElectricityCalculator.calculateUnitsCentiunits(
          previousReadingCentiunits: 50000,
          currentReadingCentiunits: 48000,
        ),
        throwsA(isA<Exception>()),
      );
    });

    test('Accepts lower current reading when isReset=true', () {
      final units = ElectricityCalculator.calculateUnitsCentiunits(
        previousReadingCentiunits: 999900,
        currentReadingCentiunits: 5000,
        isReset: true,
      );
      expect(units, 5000);
    });
  });

  group('3. Proportional Actual Bill Allocation Tests', () {
    test('Allocates ₹3,500 bill across 3 rooms with exact paise reconciliation', () {
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

      int totalAllocated = 0;
      for (final alloc in summary.roomAllocations) {
        totalAllocated += alloc.totalChargePaise;
      }

      expect(totalAllocated, 350000);
      expect(summary.roomAllocations[0].totalChargePaise >= summary.roomAllocations[2].totalChargePaise, true);
      expect(summary.roomAllocations[2].totalChargePaise >= summary.roomAllocations[1].totalChargePaise, true);
    });

    test('Handles fixed and common-area charges alongside variable allocation', () {
      final rooms = [
        RoomConsumptionInput(roomId: 'r1', roomNumber: 'Room 101', unitsConsumedCentiunits: 10000),
        RoomConsumptionInput(roomId: 'r2', roomNumber: 'Room 102', unitsConsumedCentiunits: 20000),
      ];

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

      final summary = ElectricityCalculator.allocateProportionalBill(
        totalBillAmountPaise: 60000,
        rooms: rooms,
        fixedChargesPaise: 60000,
        commonAreaChargesPaise: 0,
      );

      expect(summary.roomAllocations[0].totalChargePaise, 30000);
      expect(summary.roomAllocations[1].totalChargePaise, 30000);
    });
  });

  group('4. Monthly Billing Engine Tests', () {
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
        rentAmountPaise: 800000,
        electricityUnitsCentiunits: 13000,
        electricityAmountPaise: 110500,
        previousBalancePaise: 50000,
        additionalChargesPaise: 20000,
        dueDateEpoch: dueDate,
      );

      final bill = BillingEngine.calculateMonthlyBill(input, currentEpoch: now);

      expect(bill.billNumber, 'BILL-202611-ROOM101');
      expect(bill.rentAmountPaise, 800000);
      expect(bill.electricityAmountPaise, 110500);
      expect(bill.totalCurrentChargesPaise, 930500);
      expect(bill.totalDuePaise, 980500);
      expect(bill.remainingBalancePaise, 980500);
      expect(bill.status, 'UNPAID');
      expect(bill.lineItems.length >= 2, true);
    });

    test('Updates status to PARTIALLY_PAID and PAID appropriately', () {
      final dueDate = DateTime(2026, 11, 10).millisecondsSinceEpoch;
      final nowBeforeDue = DateTime(2026, 11, 5).millisecondsSinceEpoch;
      final nowAfterDue = DateTime(2026, 11, 15).millisecondsSinceEpoch;

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
  });
}

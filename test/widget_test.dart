import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rental_room_app/core/utils/currency_helper.dart';
import 'package:rental_room_app/core/widgets/stat_card.dart';
import 'package:rental_room_app/core/widgets/status_badge.dart';

void main() {
  group('Widget & UI Formatting Tests', () {
    testWidgets('StatCard renders title, value and icon correctly', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: StatCard(
              title: 'Total Rent',
              value: CurrencyHelper.formatPaise(2400000), // ₹24,000
              icon: Icons.home,
            ),
          ),
        ),
      );

      expect(find.text('Total Rent'), findsOneWidget);
      expect(find.text('₹24,000'), findsOneWidget);
      expect(find.byIcon(Icons.home), findsOneWidget);
    });

    testWidgets('StatusBadge renders appropriate labels and colors', (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: Column(
              children: [
                StatusBadge(status: 'PAID'),
                StatusBadge(status: 'PARTIALLY_PAID'),
                StatusBadge(status: 'OVERDUE'),
                StatusBadge(status: 'ACTIVE'),
              ],
            ),
          ),
        ),
      );

      expect(find.text('Paid'), findsOneWidget);
      expect(find.text('Partial'), findsOneWidget);
      expect(find.text('Overdue'), findsOneWidget);
      expect(find.text('Active'), findsOneWidget);
    });
  });
}

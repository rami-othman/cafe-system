import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:windows_application/features/inventory/models/inventory_models.dart';
import 'package:windows_application/features/inventory/views/inventory_screens.dart';

void main() {
  testWidgets('shows compact RTL analytics at 1440x900', (
    WidgetTester tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1440, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    int? selectedDays;

    await tester.pumpWidget(
      MaterialApp(
        home: Directionality(
          textDirection: TextDirection.rtl,
          child: Scaffold(
            body: SingleChildScrollView(
              child: InventoryDashboardAnalyticsSection(
                loading: false,
                selectedTrendDays: 30,
                onTrendDaysChanged: (int value) => selectedDays = value,
                trend: const InventoryStockValueTrend(
                  available: true,
                  points: <InventoryStockValueTrendPoint>[
                    InventoryStockValueTrendPoint(
                      date: '2026-08-23',
                      value: '120.00',
                    ),
                    InventoryStockValueTrendPoint(
                      date: '2026-08-24',
                      value: '125.50',
                    ),
                  ],
                ),
                waste: const InventoryWasteSummary(
                  todayCost: '3.50',
                  weekCost: '12.75',
                  movementCount: 2,
                  topItems: <InventoryAnalyticsTopItem>[
                    InventoryAnalyticsTopItem(
                      itemId: 1,
                      itemName: 'Milk',
                      quantity: '2.000',
                      unit: 'l',
                      cost: '3.50',
                    ),
                  ],
                ),
                consumption: const InventoryConsumptionSummary(
                  totalCost: '14.25',
                  topItems: <InventoryAnalyticsTopItem>[
                    InventoryAnalyticsTopItem(
                      itemId: 2,
                      itemName: 'Coffee beans',
                      quantity: '1.000',
                      unit: 'kg',
                      cost: '14.25',
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );

    expect(find.text('تغير قيمة المخزون'), findsOneWidget);
    expect(find.text('تحليل الهدر'), findsOneWidget);
    expect(find.text('الاستهلاك'), findsOneWidget);
    expect(find.text('Milk'), findsOneWidget);
    expect(find.text('Coffee beans'), findsOneWidget);
    expect(find.text('7 يوم'), findsOneWidget);

    await tester.tap(find.text('7 يوم'));
    expect(selectedDays, 7);
  });

  testWidgets('keeps empty analytics cards within their compact height', (
    WidgetTester tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1440, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      MaterialApp(
        home: Directionality(
          textDirection: TextDirection.rtl,
          child: Scaffold(
            body: InventoryDashboardAnalyticsSection(
              loading: false,
              selectedTrendDays: 30,
              onTrendDaysChanged: (_) {},
              trend: const InventoryStockValueTrend(
                available: false,
                points: <InventoryStockValueTrendPoint>[],
              ),
              waste: const InventoryWasteSummary(
                todayCost: '0.00',
                weekCost: '0.00',
                movementCount: 0,
                topItems: <InventoryAnalyticsTopItem>[],
              ),
              consumption: const InventoryConsumptionSummary(
                totalCost: '0.00',
                topItems: <InventoryAnalyticsTopItem>[],
              ),
            ),
          ),
        ),
      ),
    );

    expect(find.text('لا تتوفر بيانات هدر'), findsOneWidget);
    expect(find.text('لا تتوفر بيانات استهلاك'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

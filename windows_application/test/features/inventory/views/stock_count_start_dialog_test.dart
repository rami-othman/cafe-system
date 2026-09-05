import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:windows_application/features/finance_inventory_setup/models/finance_setup_models.dart';
import 'package:windows_application/features/inventory/views/inventory_screens.dart';

void main() {
  const WarehouseLocation warehouse = WarehouseLocation(
    id: 1,
    name: 'المستودع الرئيسي',
    displayName: 'المستودع الرئيسي',
    code: 'MAIN',
    type: 'central',
    typeLabel: 'رئيسي',
    isActive: true,
    isLegacy: false,
  );

  testWidgets(
    'cycle count reveals real category chips and validates selection',
    (WidgetTester tester) async {
      await tester.binding.setSurfaceSize(const Size(1440, 900));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(
        MaterialApp(
          home: Directionality(
            textDirection: TextDirection.rtl,
            child: Builder(
              builder: (BuildContext context) => Center(
                child: FilledButton(
                  onPressed: () => showDialog<StockCountStartRequest>(
                    context: context,
                    builder: (_) => const StockCountStartDialog(
                      warehouses: <WarehouseLocation>[warehouse],
                      categories: <String>['قهوة', 'ألبان'],
                    ),
                  ),
                  child: const Text('فتح'),
                ),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('فتح'));
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<FilledButton>(
              find.widgetWithText(FilledButton, 'بدء الجرد'),
            )
            .onPressed,
        isNull,
      );
      await tester.tap(find.byType(DropdownButtonFormField<int>));
      await tester.pumpAndSettle();
      await tester.tap(find.text(warehouse.displayName).last);
      await tester.pumpAndSettle();
      await tester.tap(find.text('جرد دوري / جزئي'));
      await tester.pumpAndSettle();

      expect(find.text('الفئات المراد جردها'), findsOneWidget);
      expect(find.text('قهوة'), findsOneWidget);
      expect(find.text('ألبان'), findsOneWidget);
      expect(
        tester
            .widget<FilledButton>(
              find.widgetWithText(FilledButton, 'بدء الجرد'),
            )
            .onPressed,
        isNull,
      );

      await tester.tap(find.text('قهوة'));
      await tester.pump();
      expect(
        tester
            .widget<FilledButton>(
              find.widgetWithText(FilledButton, 'بدء الجرد'),
            )
            .onPressed,
        isNotNull,
      );
      expect(tester.takeException(), isNull);
    },
  );
}

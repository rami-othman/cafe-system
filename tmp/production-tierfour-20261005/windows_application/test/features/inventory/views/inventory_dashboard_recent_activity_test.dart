import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:windows_application/features/inventory/models/inventory_models.dart';
import 'package:windows_application/features/inventory/views/inventory_screens.dart';

void main() {
  const InventoryMovement activity = InventoryMovement(
    id: 18,
    itemId: 9,
    itemName: 'حبوب القهوة',
    warehouseId: 4,
    warehouseName: 'الفرع الرئيسي — البار',
    warehouseTypeLabel: 'Bar',
    unit: 'kg',
    type: 'sale_consumption',
    dashboardType: 'recipe_consumption',
    quantityIn: '0.000',
    quantityOut: '1.000',
    unitCost: '14.2500',
    totalCost: '14.25',
    reason: '',
    occurredAt: '2026-08-24T10:00:00Z',
    createdAt: '2026-08-24T10:00:00Z',
    employee: 'مدير الفرع',
    reference: 'order #18',
  );

  testWidgets(
    'shows a compact RTL recent-activity dashboard feed at 1440x900',
    (WidgetTester tester) async {
      await tester.binding.setSurfaceSize(const Size(1440, 900));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      bool viewAllPressed = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Directionality(
            textDirection: TextDirection.rtl,
            child: Scaffold(
              body: SingleChildScrollView(
                child: InventoryDashboardRecentActivityFeed(
                  items: const <InventoryMovement>[activity],
                  selectedType: '',
                  onTypeChanged: (_) {},
                  onViewAll: () => viewAllPressed = true,
                ),
              ),
            ),
          ),
        ),
      );

      expect(find.text('النشاط الأخير للمخزون'), findsOneWidget);
      expect(find.text('استهلاك بيع'), findsOneWidget);
      expect(find.text('حبوب القهوة'), findsOneWidget);
      expect(find.text('order #18'), findsOneWidget);
      expect(find.text('مدير الفرع'), findsOneWidget);

      await tester.tap(find.text('عرض كل الحركات'));
      expect(viewAllPressed, isTrue);
      expect(find.byType(DropdownButtonFormField<String>), findsOneWidget);
    },
  );
}

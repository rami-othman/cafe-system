import 'package:flutter_test/flutter_test.dart';
import 'package:windows_application/features/inventory/models/inventory_models.dart';

void main() {
  test('parses server-derived Inventory Dashboard management data', () {
    final InventoryDashboard dashboard = InventoryDashboard.fromJson(
      <String, dynamic>{
        'kpis': <String, dynamic>{
          'totalInventoryValue': <String, dynamic>{'value': '125.50'},
          'totalItems': <String, dynamic>{'value': '7'},
          'lowStockItems': <String, dynamic>{'value': '2'},
          'outOfStockItems': <String, dynamic>{'value': '1'},
          'todayConsumptionCost': <String, dynamic>{'value': '14.25'},
          'todayWasteCost': <String, dynamic>{'value': '3.50'},
        },
        'stockValueByWarehouse': <Map<String, dynamic>>[
          <String, dynamic>{
            'warehouseId': 4,
            'warehouseName': 'Downtown · Main warehouse',
            'value': '125.50',
            'itemCount': 7,
            'alertsCount': 3,
            'warehouseTypeLabel': 'Bar',
            'lastMovementAt': '2026-08-24T09:50:00Z',
            'healthPercentage': 57,
            'status': 'attention',
          },
        ],
        'lowStockAlerts': <Map<String, dynamic>>[
          <String, dynamic>{
            'itemId': 9,
            'itemName': 'Coffee beans',
            'warehouseName': 'Downtown · Main warehouse',
            'quantity': '2.000',
            'minimumLevel': '5.000',
            'missingQuantity': '3.000',
            'suggestedReorderQuantity': '8.000',
            'severity': 'critical',
            'unit': 'kg',
            'outOfStock': false,
          },
        ],
        'inventoryAlertsSummary': <String, dynamic>{
          'critical': 1,
          'low': 2,
          'total': 3,
        },
        'recentMovements': <Map<String, dynamic>>[
          <String, dynamic>{
            'id': 18,
            'itemId': 9,
            'itemNameEn': 'Coffee beans',
            'warehouseId': 4,
            'warehouseName': 'Downtown · Main warehouse',
            'warehouseTypeLabel': 'Main warehouse',
            'unit': 'kg',
            'type': 'sale_consumption',
            'dashboardType': 'recipe_consumption',
            'quantityIn': '0.000',
            'quantityOut': '1.000',
            'unitCost': '14.2500',
            'totalCost': '14.25',
            'reference': 'order #18',
            'userName': 'Branch manager',
            'occurredAt': '2026-08-24T10:00:00Z',
            'createdAt': '2026-08-24T10:00:00Z',
          },
        ],
        'stockValueTrend': <String, dynamic>{
          'available': true,
          'points': <Map<String, dynamic>>[
            <String, dynamic>{'date': '2026-08-24', 'value': '125.50'},
          ],
        },
        'wasteSummary': <String, dynamic>{
          'todayCost': '3.50',
          'weekCost': '12.75',
          'movementCount': 2,
          'topItems': <Map<String, dynamic>>[
            <String, dynamic>{
              'itemId': 9,
              'itemName': 'Milk',
              'quantity': '2.000',
              'unit': 'l',
              'cost': '3.50',
            },
          ],
        },
        'consumptionSummary': <String, dynamic>{
          'totalCost': '14.25',
          'topItems': <Map<String, dynamic>>[
            <String, dynamic>{
              'itemId': 9,
              'itemName': 'Coffee beans',
              'quantity': '1.000',
              'unit': 'kg',
              'cost': '14.25',
            },
          ],
        },
      },
    );

    expect(dashboard.kpis.totalItems.value, '7');
    expect(dashboard.kpis.todayConsumption.value, '14.25');
    expect(dashboard.warehouses.single.alertsCount, 3);
    expect(dashboard.warehouses.single.healthPercentage, 57);
    expect(dashboard.alerts.single.suggestedReorderQuantity, '8.000');
    expect(dashboard.alerts.single.missingQuantity, '3.000');
    expect(dashboard.alertSummary.total, 3);
    expect(dashboard.recent.single.dashboardType, 'recipe_consumption');
    expect(dashboard.recent.single.reference, 'order #18');
    expect(dashboard.recent.single.employee, 'Branch manager');
    expect(dashboard.stockValueTrend.points.single.value, '125.50');
    expect(dashboard.wasteSummary.weekCost, '12.75');
    expect(dashboard.wasteSummary.topItems.single.itemName, 'Milk');
    expect(dashboard.consumptionSummary.totalCost, '14.25');
  });
}

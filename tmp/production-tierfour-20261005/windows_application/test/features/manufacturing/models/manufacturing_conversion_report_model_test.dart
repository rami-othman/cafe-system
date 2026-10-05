import 'package:flutter_test/flutter_test.dart';
import 'package:windows_application/features/manufacturing/models/manufacturing_conversion_models.dart';
import 'package:windows_application/features/manufacturing/models/manufacturing_report_models.dart';

void main() {
  group('ManufacturingConversionResult.fromJson', () {
    test('parses a conversion result defensively', () {
      final ManufacturingConversionResult result =
          ManufacturingConversionResult.fromJson(<String, dynamic>{
            'id': 'CV-1',
            'warehouseId': 2,
            'sourceItemId': 10,
            'sourceQty': '5.000',
            'targetItemId': 11,
            'resultQty': '4.500',
            'sourceItemName': 'حليب كامل',
            'targetItemName': 'حليب مقشود',
            'resultUnitCost': '1.2000',
            'totalCost': '5.40',
            'date': '2026-01-02',
          });

      expect(result.id, 'CV-1');
      expect(result.sourceItemName, 'حليب كامل');
      expect(result.resultUnitCost, '1.2000');
    });

    test('missing optional fields degrade to null, not crash', () {
      final ManufacturingConversionResult result =
          ManufacturingConversionResult.fromJson(<String, dynamic>{
            'id': 'CV-2',
            'warehouseId': 2,
            'sourceItemId': 10,
            'sourceQty': '5.000',
            'targetItemId': 11,
            'resultQty': '4.500',
          });

      expect(result.sourceItemName, isNull);
      expect(result.resultUnitCost, isNull);
      expect(result.totalCost, isNull);
    });
  });

  group('ManufacturingReportsData.fromJson', () {
    test('parses kpis and every list section using the real backend keys', () {
      final ManufacturingReportsData data = ManufacturingReportsData.fromJson(
        <String, dynamic>{
          'kpis': <String, dynamic>{
            'totalQty': 100.0,
            'totalCost': 500.0,
            'avgUnitCost': 5.0,
            'avgEfficiency': 92.5,
            'totalWasteEvents': 3,
          },
          'costByProduct': <Map<String, dynamic>>[
            <String, dynamic>{'product': 'لاتيه', 'qty': 40.0, 'cost': 200.0},
          ],
          'expectedVsActual': <Map<String, dynamic>>[
            <String, dynamic>{
              'id': 'PR-1',
              'product': 'لاتيه',
              'expected': 100.0,
              'actual': 95.0,
            },
          ],
          'waste': <Map<String, dynamic>>[
            <String, dynamic>{
              'id': 'PR-1',
              'product': 'لاتيه',
              'qty': '1.000',
              'unit': 'piece',
              'reason': 'كسر',
            },
          ],
          'materialConsumption': <Map<String, dynamic>>[
            <String, dynamic>{'name': 'حليب', 'unit': 'liter', 'qty': 20.0},
          ],
          'byProduct': <Map<String, dynamic>>[
            <String, dynamic>{'product': 'لاتيه', 'qty': 40.0, 'cost': 200.0},
          ],
          'byWarehouse': <Map<String, dynamic>>[
            <String, dynamic>{'warehouse': 'المخزن الرئيسي', 'qty': 100.0},
          ],
          'hasData': true,
        },
      );

      expect(data.hasData, isTrue);
      expect(data.kpis.totalQty, 100.0);
      expect(data.costByProduct.single.product, 'لاتيه');
      expect(data.byWarehouse.single.warehouse, 'المخزن الرئيسي');
      expect(data.materialConsumption.single.qty, 20.0);
    });

    test('a response with no completed orders parses as hasData=false, not a crash', () {
      final ManufacturingReportsData data = ManufacturingReportsData.fromJson(
        <String, dynamic>{
          'kpis': <String, dynamic>{
            'totalQty': 0,
            'totalCost': 0,
            'avgUnitCost': 0,
            'avgEfficiency': 0,
            'totalWasteEvents': 0,
          },
          'hasData': false,
        },
      );

      expect(data.hasData, isFalse);
      expect(data.byProduct, isEmpty);
      expect(data.waste, isEmpty);
    });
  });
}

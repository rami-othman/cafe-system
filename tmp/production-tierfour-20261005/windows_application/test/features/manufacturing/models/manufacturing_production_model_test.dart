import 'package:flutter_test/flutter_test.dart';
import 'package:windows_application/features/manufacturing/models/manufacturing_production_models.dart';

void main() {
  group('ManufacturingProductionPreview.fromJson', () {
    test('parses insufficient-stock rows with a conversion issue flag', () {
      final ManufacturingProductionPreview preview =
          ManufacturingProductionPreview.fromJson(<String, dynamic>{
            'recipeId': 4,
            'qty': 10.0,
            'hasConversionIssue': true,
            'hasInsufficient': true,
            'batchCost': null,
            'unitCost': null,
            'rows': <Map<String, dynamic>>[
              <String, dynamic>{
                'materialId': 1,
                'name': 'سكر',
                'semiFinished': false,
                'baseUnit': 'kilogram',
                'reqBase': null,
                'available': null,
                'after': null,
                'status': 'إعداد وحدة مطلوب',
                'level': 'danger',
                'convError': true,
                'deficit': 0,
              },
              <String, dynamic>{
                'materialId': 2,
                'name': 'حليب',
                'semiFinished': false,
                'baseUnit': 'liter',
                'reqBase': '5.000',
                'available': 2.0,
                'after': -3.0,
                'status': 'غير كافٍ',
                'level': 'danger',
                'convError': false,
                'deficit': 3.0,
              },
            ],
          });

      expect(preview.hasConversionIssue, isTrue);
      expect(preview.hasInsufficient, isTrue);
      expect(preview.batchCost, isNull);
      expect(preview.rows, hasLength(2));
      expect(preview.rows[0].convError, isTrue);
      expect(preview.rows[1].after, -3.0);
      expect(preview.rows[1].level, 'danger');
    });
  });

  group('ManufacturingProductionDraft.fromJson', () {
    test('parses the nested preview block and consumption lines', () {
      final ManufacturingProductionDraft draft =
          ManufacturingProductionDraft.fromJson(<String, dynamic>{
            'id': 501,
            'recipeId': 4,
            'warehouseId': 2,
            'qty': '10.000',
            'date': '2026-01-01',
            'preview': <String, dynamic>{'batchCost': 12.5, 'unitCost': 1.25},
            'consumption': <Map<String, dynamic>>[
              <String, dynamic>{
                'materialId': 1,
                'planned': '2.000',
                'actual': '2.000',
                'unit': 'kilogram',
              },
            ],
          });

      expect(draft.id, 501);
      expect(draft.batchCost, 12.5);
      expect(draft.unitCost, 1.25);
      expect(draft.consumption.single.materialId, 1);
    });
  });

  group('ManufacturingProductionOrder.fromJson', () {
    test('parses a completed order with waste and batch fields', () {
      final ManufacturingProductionOrder order =
          ManufacturingProductionOrder.fromJson(<String, dynamic>{
            'id': 'PR-2001',
            'recordId': 501,
            'recipeId': 4,
            'product': 'كيك',
            'type': 'finished_good',
            'warehouseId': 2,
            'planned': '10.000',
            'actual': '9.500',
            'unit': 'piece',
            'plannedCost': '12.50',
            'actualCost': '11.90',
            'date': '2026-01-01',
            'status': 'completed',
            'soldQty': 3.0,
            'recipeVersion': 'v2',
            'waste': <String, dynamic>{
              'qty': '0.500',
              'unit': 'piece',
              'reason': 'كسر',
            },
            'batch': <String, dynamic>{
              'ref': 'PR-2001',
              'mfgDate': '2026-01-01',
              'shelfLife': '3 أيام',
              'expiry': '2026-01-04',
            },
            'materialsConsumed': <Map<String, dynamic>>[
              <String, dynamic>{
                'materialId': 1,
                'name': 'طحين',
                'planned': '2.000',
                'actual': '2.000',
                'unit': 'kilogram',
              },
            ],
          });

      expect(order.isCompleted, isTrue);
      expect(order.isReversed, isFalse);
      expect(order.waste?.reason, 'كسر');
      expect(order.batch?.expiry, '2026-01-04');
      expect(order.materialsConsumed.single.name, 'طحين');
    });

    test('a reversed order exposes its reverseReason', () {
      final ManufacturingProductionOrder order =
          ManufacturingProductionOrder.fromJson(<String, dynamic>{
            'id': 'PR-2001',
            'recordId': 501,
            'recipeId': 4,
            'product': 'كيك',
            'type': 'finished_good',
            'warehouseId': 2,
            'planned': '10.000',
            'unit': 'piece',
            'status': 'reversed',
            'soldQty': 0,
            'reverseReason': 'خطأ في التسجيل',
            'materialsConsumed': <Map<String, dynamic>>[],
          });

      expect(order.isReversed, isTrue);
      expect(order.reverseReason, 'خطأ في التسجيل');
    });
  });
}

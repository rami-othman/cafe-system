import 'package:flutter_test/flutter_test.dart';
import 'package:windows_application/features/manufacturing/models/manufacturing_recipe_models.dart';

void main() {
  group('ManufacturingRecipeSummary.fromJson', () {
    test('parses a fully populated row', () {
      final ManufacturingRecipeSummary summary =
          ManufacturingRecipeSummary.fromJson(<String, dynamic>{
            'id': 12,
            'productItemId': 55,
            'name': 'لاتيه',
            'type': 'finished_good',
            'status': 'active',
            'yield': '1.000',
            'yieldUnit': 'piece',
            'version': 2,
            'updatedAt': '2026-01-01',
            'materialsCost': 3.5,
            'unitCost': 3.5,
          });

      expect(summary.id, 12);
      expect(summary.productItemId, 55);
      expect(summary.isActive, isTrue);
      expect(summary.version, 2);
      expect(summary.materialsCost, 3.5);
    });

    test('a null materialsCost/unitCost means "backend could not price it", not zero', () {
      final ManufacturingRecipeSummary summary =
          ManufacturingRecipeSummary.fromJson(<String, dynamic>{
            'id': 1,
            'productItemId': 1,
            'name': 'كرواسون',
            'type': 'finished_good',
            'status': 'inactive',
            'yield': '10',
            'yieldUnit': 'piece',
            'version': 1,
          });

      expect(summary.materialsCost, isNull);
      expect(summary.unitCost, isNull);
      expect(summary.isActive, isFalse);
    });
  });

  group('ManufacturingRecipeDetail.fromJson', () {
    test('parses rows, a missing-cost line, and history', () {
      final ManufacturingRecipeDetail detail =
          ManufacturingRecipeDetail.fromJson(<String, dynamic>{
            'id': 7,
            'productItemId': 20,
            'name': 'كيك الشوكولاتة',
            'type': 'finished_good',
            'status': 'active',
            'version': 3,
            'yield': '1',
            'yieldUnit': 'piece',
            'shelfLife': true,
            'shelfValue': 3,
            'shelfUnit': 'days',
            'hasMissingCost': true,
            'materialsCost': null,
            'unitCost': null,
            'rows': <Map<String, dynamic>>[
              <String, dynamic>{
                'materialId': 1,
                'name': 'دقيق',
                'semiFinished': false,
                'qty': '0.5',
                'unit': 'kilogram',
                'cost': 2.0,
              },
              <String, dynamic>{
                'materialId': 2,
                'name': 'كريمة نصف مصنعة',
                'semiFinished': true,
                'qty': '0.2',
                'unit': 'kilogram',
                'cost': null,
                'error': 'missing-cost',
              },
            ],
            'history': <Map<String, dynamic>>[
              <String, dynamic>{
                'id': 'PR-1001',
                'planned': '1',
                'actual': '0.95',
                'status': 'completed',
                'date': '2026-01-05',
              },
            ],
          });

      expect(detail.hasMissingCost, isTrue);
      expect(detail.materialsCost, isNull);
      expect(detail.rows, hasLength(2));
      expect(detail.rows[1].semiFinished, isTrue);
      expect(detail.rows[1].error, 'missing-cost');
      expect(detail.rows[1].cost, isNull);
      expect(detail.history.single.id, 'PR-1001');
      expect(detail.shelfValue, 3);
    });
  });
}

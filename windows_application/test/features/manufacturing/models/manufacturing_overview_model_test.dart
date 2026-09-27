import 'package:flutter_test/flutter_test.dart';
import 'package:windows_application/features/manufacturing/models/manufacturing_models.dart';

void main() {
  group('ManufacturingOverview.fromJson', () {
    test('parses a full, server-derived overview response', () {
      final ManufacturingOverview overview = ManufacturingOverview.fromJson(
        <String, dynamic>{
          'kpis': <String, dynamic>{
            'producedToday': 42.5,
            'productionCostToday': 187.25,
            'avgEfficiency': 93.4,
            'wasteToday': 2,
            'attentionCount': 1,
            'expiringCount': 1,
          },
          'recent': <Map<String, dynamic>>[
            <String, dynamic>{
              'id': 'MO-0012',
              'product': 'Croissant dough',
              'actual': '40.000',
              'unit': 'kg',
              'actualCost': '180.00',
              'date': '2026-09-26T08:00:00Z',
              'status': 'completed',
            },
          ],
          'attention': <Map<String, dynamic>>[
            <String, dynamic>{
              'name': 'Butter',
              'available': '2.000 kg',
              'need': 'الحد الأدنى 5.000 kg',
              'status': 'مخزون منخفض',
              'level': 'warning',
            },
          ],
          'expiring': <Map<String, dynamic>>[
            <String, dynamic>{
              'id': 'MO-0009',
              'product': 'Whipped cream',
              'batch': 'MO-0009',
              'remaining': '3.500 kg',
              'date': '2026-09-28',
            },
          ],
          'topCost': <Map<String, dynamic>>[
            <String, dynamic>{
              'product': 'Croissant dough',
              'cost': 180.0,
              'pct': 100,
            },
          ],
        },
      );

      expect(overview.kpis.producedToday, '42.5');
      expect(overview.kpis.productionCostToday, '187.25');
      expect(overview.kpis.avgEfficiency, '93.4');
      expect(overview.kpis.wasteToday, 2);
      expect(overview.kpis.attentionCount, 1);
      expect(overview.kpis.expiringCount, 1);
      expect(overview.recent.single.product, 'Croissant dough');
      expect(overview.recent.single.status, 'completed');
      expect(overview.attention.single.status, 'مخزون منخفض');
      expect(overview.attention.single.level, 'warning');
      expect(overview.expiring.single.remaining, '3.500 kg');
      expect(overview.topCost.single.pct, 100);
    });

    test('a missing kpis section and empty lists parse without crashing', () {
      final ManufacturingOverview overview = ManufacturingOverview.fromJson(
        const <String, dynamic>{},
      );

      expect(overview.kpis.producedToday, '0');
      expect(overview.kpis.productionCostToday, '0');
      expect(overview.kpis.avgEfficiency, isNull);
      expect(overview.kpis.wasteToday, 0);
      expect(overview.recent, isEmpty);
      expect(overview.attention, isEmpty);
      expect(overview.expiring, isEmpty);
      expect(overview.topCost, isEmpty);
    });

    test('a null avgEfficiency (no eligible completed orders today) stays null', () {
      final ManufacturingOverviewKpis kpis = ManufacturingOverviewKpis.fromJson(
        <String, dynamic>{
          'producedToday': 0,
          'productionCostToday': 0,
          'avgEfficiency': null,
          'wasteToday': 0,
          'attentionCount': 0,
          'expiringCount': 0,
        },
      );

      expect(kpis.avgEfficiency, isNull);
    });

    test('a recent order with null actual/actualCost/date parses safely', () {
      final ManufacturingRecentOrder order = ManufacturingRecentOrder.fromJson(
        <String, dynamic>{
          'id': 'draft_5',
          'product': 'Croissant dough',
          'unit': 'kg',
          'status': 'draft',
        },
      );

      expect(order.actual, isNull);
      expect(order.actualCost, isNull);
      expect(order.date, isNull);
    });
  });
}

import '../../pos/models/json_helpers.dart';

/// The `/manufacturing/overview` response, as returned by
/// `ManufacturingReportService::overview()` on the backend: a set of
/// today-scoped KPIs plus a handful of small lists (recent production,
/// low-material attention items, expiring batches, and the highest-cost
/// manufactured products). Every field is optional-safe - a missing or
/// malformed section renders as empty rather than crashing the screen.
class ManufacturingOverview {
  const ManufacturingOverview({
    required this.kpis,
    this.recent = const <ManufacturingRecentOrder>[],
    this.attention = const <ManufacturingAttentionItem>[],
    this.expiring = const <ManufacturingExpiringBatch>[],
    this.topCost = const <ManufacturingTopCostProduct>[],
  });

  final ManufacturingOverviewKpis kpis;
  final List<ManufacturingRecentOrder> recent;
  final List<ManufacturingAttentionItem> attention;
  final List<ManufacturingExpiringBatch> expiring;
  final List<ManufacturingTopCostProduct> topCost;

  factory ManufacturingOverview.fromJson(Map<String, dynamic> json) =>
      ManufacturingOverview(
        kpis: ManufacturingOverviewKpis.fromJson(
          Map<String, dynamic>.from(
            json['kpis'] as Map? ?? const <String, dynamic>{},
          ),
        ),
        recent: readMapList(
          json['recent'],
        ).map(ManufacturingRecentOrder.fromJson).toList(growable: false),
        attention: readMapList(
          json['attention'],
        ).map(ManufacturingAttentionItem.fromJson).toList(growable: false),
        expiring: readMapList(
          json['expiring'],
        ).map(ManufacturingExpiringBatch.fromJson).toList(growable: false),
        topCost: readMapList(
          json['topCost'],
        ).map(ManufacturingTopCostProduct.fromJson).toList(growable: false),
      );
}

/// `producedToday`/`productionCostToday` are raw numeric fields from the
/// backend (not fixed-point money strings like Inventory's contract), so
/// they are parsed as strings via [readString] to keep formatting under the
/// view layer's control without risking float precision loss along the way.
class ManufacturingOverviewKpis {
  const ManufacturingOverviewKpis({
    required this.producedToday,
    required this.productionCostToday,
    required this.wasteToday,
    required this.attentionCount,
    required this.expiringCount,
    this.avgEfficiency,
  });

  final String producedToday;
  final String productionCostToday;
  final int wasteToday;
  final int attentionCount;
  final int expiringCount;

  /// Null when the backend has no completed orders with a planned quantity
  /// to average today (`avgEfficiency` is `null` in the JSON body).
  final String? avgEfficiency;

  factory ManufacturingOverviewKpis.fromJson(Map<String, dynamic> json) =>
      ManufacturingOverviewKpis(
        producedToday: readString(json['producedToday'], fallback: '0'),
        productionCostToday: readString(
          json['productionCostToday'],
          fallback: '0',
        ),
        wasteToday: readInt(json['wasteToday']) ?? 0,
        attentionCount: readInt(json['attentionCount']) ?? 0,
        expiringCount: readInt(json['expiringCount']) ?? 0,
        avgEfficiency: json['avgEfficiency'] == null
            ? null
            : readString(json['avgEfficiency']),
      );
}

/// One row of the overview's "recent production" list. `status` is the
/// backend's raw English order status (e.g. `completed`, `draft`) - render
/// it through a status-label helper at the widget layer rather than
/// comparing against Arabic text here.
class ManufacturingRecentOrder {
  const ManufacturingRecentOrder({
    required this.id,
    required this.product,
    required this.unit,
    required this.status,
    this.actual,
    this.actualCost,
    this.date,
  });

  final String id;
  final String product;
  final String unit;
  final String status;
  final String? actual;
  final String? actualCost;
  final String? date;

  factory ManufacturingRecentOrder.fromJson(Map<String, dynamic> json) =>
      ManufacturingRecentOrder(
        id: readString(json['id']),
        product: readString(json['product'], fallback: 'Manufactured item'),
        unit: readString(json['unit']),
        status: readString(json['status'], fallback: 'draft'),
        actual: json['actual'] == null ? null : readString(json['actual']),
        actualCost: json['actualCost'] == null
            ? null
            : readString(json['actualCost']),
        date: readString(json['date']).isEmpty
            ? null
            : readString(json['date']),
      );
}

/// A low-material-stock alert. The backend already formats `available`,
/// `need`, and `status` as ready-to-display Arabic text (they are not
/// enums), so they are treated as opaque display strings; only `level`
/// (e.g. `warning`) is a real severity enum kept in English for styling.
class ManufacturingAttentionItem {
  const ManufacturingAttentionItem({
    required this.name,
    required this.available,
    required this.need,
    required this.status,
    required this.level,
  });

  final String name;
  final String available;
  final String need;
  final String status;
  final String level;

  factory ManufacturingAttentionItem.fromJson(Map<String, dynamic> json) =>
      ManufacturingAttentionItem(
        name: readString(json['name'], fallback: 'Material'),
        available: readString(json['available']),
        need: readString(json['need']),
        status: readString(json['status']),
        level: readString(json['level'], fallback: 'warning'),
      );
}

class ManufacturingExpiringBatch {
  const ManufacturingExpiringBatch({
    required this.id,
    required this.product,
    required this.remaining,
    this.batch,
    this.date,
  });

  final String id;
  final String product;
  final String remaining;
  final String? batch;
  final String? date;

  factory ManufacturingExpiringBatch.fromJson(
    Map<String, dynamic> json,
  ) => ManufacturingExpiringBatch(
    id: readString(json['id']),
    product: readString(json['product'], fallback: 'Manufactured item'),
    remaining: readString(json['remaining']),
    batch: readString(json['batch']).isEmpty ? null : readString(json['batch']),
    date: readString(json['date']).isEmpty ? null : readString(json['date']),
  );
}

class ManufacturingTopCostProduct {
  const ManufacturingTopCostProduct({
    required this.product,
    required this.cost,
    required this.pct,
  });

  final String product;
  final String cost;
  final int pct;

  factory ManufacturingTopCostProduct.fromJson(Map<String, dynamic> json) =>
      ManufacturingTopCostProduct(
        product: readString(json['product'], fallback: 'Manufactured item'),
        cost: readString(json['cost'], fallback: '0'),
        pct: readInt(json['pct']) ?? 0,
      );
}

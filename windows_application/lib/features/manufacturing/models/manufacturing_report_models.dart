import '../../pos/models/json_helpers.dart';

/// `GET /manufacturing/reports` response (`ManufacturingReportService::reports()`).
/// Every section mirrors the backend's real keys exactly (`byProduct`,
/// `byWarehouse`, `costByProduct`, `expectedVsActual`, `waste`,
/// `materialConsumption`) - no additional KPI is invented on the client.
class ManufacturingReportsData {
  const ManufacturingReportsData({
    required this.kpis,
    this.costByProduct = const <ManufacturingReportProductCost>[],
    this.expectedVsActual = const <ManufacturingReportExpectedVsActual>[],
    this.waste = const <ManufacturingReportWasteEntry>[],
    this.materialConsumption = const <ManufacturingReportMaterialConsumption>[],
    this.byProduct = const <ManufacturingReportProductCost>[],
    this.byWarehouse = const <ManufacturingReportWarehouseQty>[],
    this.hasData = false,
  });

  final ManufacturingReportKpis kpis;
  final List<ManufacturingReportProductCost> costByProduct;
  final List<ManufacturingReportExpectedVsActual> expectedVsActual;
  final List<ManufacturingReportWasteEntry> waste;
  final List<ManufacturingReportMaterialConsumption> materialConsumption;
  final List<ManufacturingReportProductCost> byProduct;
  final List<ManufacturingReportWarehouseQty> byWarehouse;
  final bool hasData;

  factory ManufacturingReportsData.fromJson(Map<String, dynamic> json) =>
      ManufacturingReportsData(
        kpis: ManufacturingReportKpis.fromJson(
          Map<String, dynamic>.from(
            json['kpis'] as Map? ?? const <String, dynamic>{},
          ),
        ),
        costByProduct: readMapList(
          json['costByProduct'],
        ).map(ManufacturingReportProductCost.fromJson).toList(growable: false),
        expectedVsActual: readMapList(json['expectedVsActual'])
            .map(ManufacturingReportExpectedVsActual.fromJson)
            .toList(growable: false),
        waste: readMapList(
          json['waste'],
        ).map(ManufacturingReportWasteEntry.fromJson).toList(growable: false),
        materialConsumption: readMapList(json['materialConsumption'])
            .map(ManufacturingReportMaterialConsumption.fromJson)
            .toList(growable: false),
        byProduct: readMapList(
          json['byProduct'],
        ).map(ManufacturingReportProductCost.fromJson).toList(growable: false),
        byWarehouse: readMapList(
          json['byWarehouse'],
        ).map(ManufacturingReportWarehouseQty.fromJson).toList(growable: false),
        hasData: readBool(json['hasData']),
      );
}

class ManufacturingReportKpis {
  const ManufacturingReportKpis({
    required this.totalQty,
    required this.totalCost,
    required this.avgUnitCost,
    required this.avgEfficiency,
    required this.totalWasteEvents,
  });

  final double totalQty;
  final double totalCost;
  final double avgUnitCost;
  final double avgEfficiency;
  final int totalWasteEvents;

  factory ManufacturingReportKpis.fromJson(Map<String, dynamic> json) =>
      ManufacturingReportKpis(
        totalQty: readDouble(json['totalQty']),
        totalCost: readDouble(json['totalCost']),
        avgUnitCost: readDouble(json['avgUnitCost']),
        avgEfficiency: readDouble(json['avgEfficiency']),
        totalWasteEvents: readInt(json['totalWasteEvents']) ?? 0,
      );
}

class ManufacturingReportProductCost {
  const ManufacturingReportProductCost({
    required this.product,
    required this.qty,
    required this.cost,
  });

  final String product;
  final double qty;
  final double cost;

  factory ManufacturingReportProductCost.fromJson(Map<String, dynamic> json) =>
      ManufacturingReportProductCost(
        product: readString(json['product'], fallback: 'Manufactured item'),
        qty: readDouble(json['qty']),
        cost: readDouble(json['cost']),
      );
}

class ManufacturingReportExpectedVsActual {
  const ManufacturingReportExpectedVsActual({
    required this.id,
    required this.product,
    required this.expected,
    required this.actual,
  });

  final String id;
  final String product;
  final double expected;
  final double actual;

  factory ManufacturingReportExpectedVsActual.fromJson(
    Map<String, dynamic> json,
  ) => ManufacturingReportExpectedVsActual(
    id: readString(json['id']),
    product: readString(json['product'], fallback: 'Manufactured item'),
    expected: readDouble(json['expected']),
    actual: readDouble(json['actual']),
  );
}

class ManufacturingReportWasteEntry {
  const ManufacturingReportWasteEntry({
    required this.id,
    required this.product,
    required this.qty,
    required this.unit,
    this.reason,
  });

  final String id;
  final String product;
  final String qty;
  final String unit;
  final String? reason;

  factory ManufacturingReportWasteEntry.fromJson(Map<String, dynamic> json) =>
      ManufacturingReportWasteEntry(
        id: readString(json['id']),
        product: readString(json['product'], fallback: 'Manufactured item'),
        qty: readString(json['qty'], fallback: '0'),
        unit: readString(json['unit']),
        reason: readString(json['reason']).isEmpty
            ? null
            : readString(json['reason']),
      );
}

class ManufacturingReportMaterialConsumption {
  const ManufacturingReportMaterialConsumption({
    required this.name,
    required this.unit,
    required this.qty,
  });

  final String name;
  final String unit;
  final double qty;

  factory ManufacturingReportMaterialConsumption.fromJson(
    Map<String, dynamic> json,
  ) => ManufacturingReportMaterialConsumption(
    name: readString(json['name'], fallback: 'Material'),
    unit: readString(json['unit']),
    qty: readDouble(json['qty']),
  );
}

class ManufacturingReportWarehouseQty {
  const ManufacturingReportWarehouseQty({
    required this.warehouse,
    required this.qty,
  });

  final String warehouse;
  final double qty;

  factory ManufacturingReportWarehouseQty.fromJson(Map<String, dynamic> json) =>
      ManufacturingReportWarehouseQty(
        warehouse: readString(json['warehouse'], fallback: 'Warehouse'),
        qty: readDouble(json['qty']),
      );
}

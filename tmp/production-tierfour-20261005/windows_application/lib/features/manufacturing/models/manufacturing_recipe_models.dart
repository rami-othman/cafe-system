import '../../pos/models/json_helpers.dart';

/// One row of `GET /manufacturing/recipes` (`ManufacturingRecipeService::summarize()`).
/// `materialsCost`/`unitCost` are `null` when the backend could not price
/// every line (missing cost or missing unit conversion) - render that as
/// "unavailable" rather than `0`.
class ManufacturingRecipeSummary {
  const ManufacturingRecipeSummary({
    required this.id,
    required this.productItemId,
    required this.name,
    required this.type,
    required this.status,
    required this.yieldQuantity,
    required this.yieldUnit,
    required this.version,
    this.updatedAt,
    this.materialsCost,
    this.unitCost,
  });

  final int id;
  final int productItemId;
  final String name;
  final String type;
  final String status;
  final String yieldQuantity;
  final String yieldUnit;
  final int version;
  final String? updatedAt;
  final double? materialsCost;
  final double? unitCost;

  bool get isActive => status == 'active';

  factory ManufacturingRecipeSummary.fromJson(Map<String, dynamic> json) =>
      ManufacturingRecipeSummary(
        id: readInt(json['id']) ?? 0,
        productItemId: readInt(json['productItemId']) ?? 0,
        name: readString(json['name'], fallback: 'Manufactured item'),
        type: readString(json['type']),
        status: readString(json['status'], fallback: 'active'),
        yieldQuantity: readString(json['yield'], fallback: '0'),
        yieldUnit: readString(json['yieldUnit']),
        version: readInt(json['version']) ?? 1,
        updatedAt: readString(json['updatedAt']).isEmpty
            ? null
            : readString(json['updatedAt']),
        materialsCost: json['materialsCost'] == null
            ? null
            : readDouble(json['materialsCost']),
        unitCost: json['unitCost'] == null
            ? null
            : readDouble(json['unitCost']),
      );
}

/// `GET /manufacturing/recipes/{id}` detail (`ManufacturingRecipeService::detail()`).
class ManufacturingRecipeDetail {
  const ManufacturingRecipeDetail({
    required this.id,
    required this.productItemId,
    required this.name,
    required this.type,
    required this.status,
    required this.version,
    required this.yieldQuantity,
    required this.yieldUnit,
    required this.shelfLife,
    required this.rows,
    required this.hasMissingCost,
    required this.history,
    this.shelfValue,
    this.shelfUnit,
    this.updatedAt,
    this.materialsCost,
    this.unitCost,
    this.extraCost = 0,
  });

  final int id;
  final int productItemId;
  final String name;
  final String type;
  final String status;
  final int version;
  final String yieldQuantity;
  final String yieldUnit;
  final bool shelfLife;
  final int? shelfValue;
  final String? shelfUnit;
  final String? updatedAt;
  final List<ManufacturingRecipeLine> rows;
  final bool hasMissingCost;
  final double? materialsCost;
  final double? unitCost;
  final double extraCost;
  final List<ManufacturingRecipeHistoryEntry> history;

  bool get isActive => status == 'active';

  factory ManufacturingRecipeDetail.fromJson(Map<String, dynamic> json) =>
      ManufacturingRecipeDetail(
        id: readInt(json['id']) ?? 0,
        productItemId: readInt(json['productItemId']) ?? 0,
        name: readString(json['name'], fallback: 'Manufactured item'),
        type: readString(json['type']),
        status: readString(json['status'], fallback: 'active'),
        version: readInt(json['version']) ?? 1,
        yieldQuantity: readString(json['yield'], fallback: '0'),
        yieldUnit: readString(json['yieldUnit']),
        shelfLife: readBool(json['shelfLife']),
        shelfValue: readInt(json['shelfValue']),
        shelfUnit: readString(json['shelfUnit']).isEmpty
            ? null
            : readString(json['shelfUnit']),
        updatedAt: readString(json['updatedAt']).isEmpty
            ? null
            : readString(json['updatedAt']),
        rows: readMapList(
          json['rows'],
        ).map(ManufacturingRecipeLine.fromJson).toList(growable: false),
        hasMissingCost: readBool(json['hasMissingCost']),
        materialsCost: json['materialsCost'] == null
            ? null
            : readDouble(json['materialsCost']),
        unitCost: json['unitCost'] == null
            ? null
            : readDouble(json['unitCost']),
        extraCost: readDouble(json['extraCost']),
        history: readMapList(
          json['history'],
        ).map(ManufacturingRecipeHistoryEntry.fromJson).toList(growable: false),
      );
}

class ManufacturingRecipeLine {
  const ManufacturingRecipeLine({
    required this.materialId,
    required this.name,
    required this.semiFinished,
    required this.quantity,
    required this.unit,
    this.cost,
    this.error,
  });

  final int materialId;
  final String name;
  final bool semiFinished;
  final String quantity;
  final String unit;
  final double? cost;

  /// Raw backend error code for this line (`missing-cost` / `conversion`) -
  /// render through a switch at the view layer, never compare Arabic text.
  final String? error;

  factory ManufacturingRecipeLine.fromJson(Map<String, dynamic> json) =>
      ManufacturingRecipeLine(
        materialId: readInt(json['materialId']) ?? 0,
        name: readString(json['name'], fallback: 'Material'),
        semiFinished: readBool(json['semiFinished']),
        quantity: readString(json['qty'], fallback: '0'),
        unit: readString(json['unit']),
        cost: json['cost'] == null ? null : readDouble(json['cost']),
        error: readString(json['error']).isEmpty
            ? null
            : readString(json['error']),
      );

  Map<String, dynamic> toRequestJson() => <String, dynamic>{
    'inventoryItemId': materialId,
    'quantity': quantity,
    'unit': unit,
  };
}

class ManufacturingRecipeHistoryEntry {
  const ManufacturingRecipeHistoryEntry({
    required this.id,
    required this.planned,
    required this.status,
    this.actual,
    this.date,
  });

  final String id;
  final String planned;
  final String status;
  final String? actual;
  final String? date;

  factory ManufacturingRecipeHistoryEntry.fromJson(Map<String, dynamic> json) =>
      ManufacturingRecipeHistoryEntry(
        id: readString(json['id']),
        planned: readString(json['planned'], fallback: '0'),
        status: readString(json['status'], fallback: 'draft'),
        actual: json['actual'] == null ? null : readString(json['actual']),
        date: readString(json['date']).isEmpty
            ? null
            : readString(json['date']),
      );
}

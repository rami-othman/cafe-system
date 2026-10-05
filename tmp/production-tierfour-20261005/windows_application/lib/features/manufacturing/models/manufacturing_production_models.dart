import '../../pos/models/json_helpers.dart';

/// `GET /manufacturing/production/preview` response
/// (`ManufacturingProductionService::computeScaledLines()`). Every number here
/// is backend-calculated - this screen only renders it.
class ManufacturingProductionPreview {
  const ManufacturingProductionPreview({
    required this.recipeId,
    required this.qty,
    required this.rows,
    required this.hasConversionIssue,
    required this.hasInsufficient,
    this.batchCost,
    this.unitCost,
  });

  final int recipeId;
  final double qty;
  final List<ManufacturingProductionPreviewRow> rows;
  final bool hasConversionIssue;
  final bool hasInsufficient;
  final double? batchCost;
  final double? unitCost;

  factory ManufacturingProductionPreview.fromJson(
    Map<String, dynamic> json,
  ) => ManufacturingProductionPreview(
    recipeId: readInt(json['recipeId']) ?? 0,
    qty: readDouble(json['qty']),
    rows: readMapList(
      json['rows'],
    ).map(ManufacturingProductionPreviewRow.fromJson).toList(growable: false),
    hasConversionIssue: readBool(json['hasConversionIssue']),
    hasInsufficient: readBool(json['hasInsufficient']),
    batchCost: json['batchCost'] == null ? null : readDouble(json['batchCost']),
    unitCost: json['unitCost'] == null ? null : readDouble(json['unitCost']),
  );
}

class ManufacturingProductionPreviewRow {
  const ManufacturingProductionPreviewRow({
    required this.materialId,
    required this.name,
    required this.semiFinished,
    required this.baseUnit,
    required this.status,
    required this.level,
    this.reqBase,
    this.available,
    this.after,
    this.convError = false,
    this.deficit = 0,
  });

  final int materialId;
  final String name;
  final bool semiFinished;
  final String baseUnit;

  /// Backend Arabic display text (e.g. "متوفر", "غير كافٍ") - already
  /// human-readable, not an enum to translate.
  final String status;

  /// Severity enum kept in English for styling (`ok`/`warning`/`danger`/`neutral`).
  final String level;
  final String? reqBase;
  final double? available;
  final double? after;
  final bool convError;
  final double deficit;

  factory ManufacturingProductionPreviewRow.fromJson(
    Map<String, dynamic> json,
  ) => ManufacturingProductionPreviewRow(
    materialId: readInt(json['materialId']) ?? 0,
    name: readString(json['name'], fallback: 'Material'),
    semiFinished: readBool(json['semiFinished']),
    baseUnit: readString(json['baseUnit']),
    status: readString(json['status']),
    level: readString(json['level'], fallback: 'neutral'),
    reqBase: json['reqBase'] == null ? null : readString(json['reqBase']),
    available: json['available'] == null ? null : readDouble(json['available']),
    after: json['after'] == null ? null : readDouble(json['after']),
    convError: readBool(json['convError']),
    deficit: readDouble(json['deficit']),
  );
}

/// `POST /manufacturing/production/drafts` and `GET .../drafts/{id}` response
/// (`ManufacturingProductionService::getDraft()`).
class ManufacturingProductionDraft {
  const ManufacturingProductionDraft({
    required this.id,
    required this.recipeId,
    required this.warehouseId,
    required this.qty,
    required this.consumption,
    this.date,
    this.batchCost,
    this.unitCost,
    this.unit = '',
  });

  final int id;
  final int recipeId;
  final int warehouseId;
  final String unit;
  final String qty;
  final String? date;
  final double? batchCost;
  final double? unitCost;
  final List<ManufacturingDraftConsumptionLine> consumption;

  factory ManufacturingProductionDraft.fromJson(Map<String, dynamic> json) {
    final Map<String, dynamic> preview = Map<String, dynamic>.from(
      json['preview'] as Map? ?? const <String, dynamic>{},
    );
    return ManufacturingProductionDraft(
      id: readInt(json['id']) ?? 0,
      recipeId: readInt(json['recipeId']) ?? 0,
      warehouseId: readInt(json['warehouseId']) ?? 0,
      unit: readString(json['unit']),
      qty: readString(json['qty'], fallback: '0'),
      date: readString(json['date']).isEmpty ? null : readString(json['date']),
      batchCost: preview['batchCost'] == null
          ? null
          : readDouble(preview['batchCost']),
      unitCost: preview['unitCost'] == null
          ? null
          : readDouble(preview['unitCost']),
      consumption: readMapList(
        json['consumption'],
      ).map(ManufacturingDraftConsumptionLine.fromJson).toList(growable: false),
    );
  }
}

class ManufacturingDraftConsumptionLine {
  const ManufacturingDraftConsumptionLine({
    required this.materialId,
    required this.planned,
    required this.actual,
    required this.unit,
    this.name = '',
  });

  final int materialId;
  final String name;
  final String planned;
  final String actual;
  final String unit;

  factory ManufacturingDraftConsumptionLine.fromJson(
    Map<String, dynamic> json,
  ) => ManufacturingDraftConsumptionLine(
    materialId: readInt(json['materialId']) ?? 0,
    name: readString(json['name']),
    planned: readString(json['planned'], fallback: '0'),
    actual: readString(json['actual'], fallback: '0'),
    unit: readString(json['unit']),
  );
}

/// A row of `GET /manufacturing/production` (`ManufacturingProductionService::list()`).
class ManufacturingProductionListItem {
  const ManufacturingProductionListItem({
    required this.id,
    required this.recordId,
    required this.product,
    required this.type,
    required this.warehouseId,
    required this.planned,
    required this.unit,
    required this.status,
    this.warehouse,
    this.actual,
    this.plannedCost,
    this.actualCost,
    this.date,
  });

  final String id;
  final int recordId;
  final String product;
  final String type;
  final int warehouseId;
  final String? warehouse;
  final String planned;
  final String? actual;
  final String unit;
  final String? plannedCost;
  final String? actualCost;
  final String status;
  final String? date;

  factory ManufacturingProductionListItem.fromJson(Map<String, dynamic> json) =>
      ManufacturingProductionListItem(
        id: readString(json['id']),
        recordId: readInt(json['recordId']) ?? 0,
        product: readString(json['product'], fallback: 'Manufactured item'),
        type: readString(json['type']),
        warehouseId: readInt(json['warehouseId']) ?? 0,
        warehouse: readString(json['warehouse']).isEmpty
            ? null
            : readString(json['warehouse']),
        planned: readString(json['planned'], fallback: '0'),
        actual: json['actual'] == null ? null : readString(json['actual']),
        unit: readString(json['unit']),
        plannedCost: json['plannedCost'] == null
            ? null
            : readString(json['plannedCost']),
        actualCost: json['actualCost'] == null
            ? null
            : readString(json['actualCost']),
        status: readString(json['status'], fallback: 'draft'),
        date: readString(json['date']).isEmpty
            ? null
            : readString(json['date']),
      );
}

/// `GET /manufacturing/production/{id}` full detail
/// (`ManufacturingProductionService::serializeOrder()`), also returned by
/// completion and reversal.
class ManufacturingProductionOrder {
  const ManufacturingProductionOrder({
    required this.id,
    required this.recordId,
    required this.recipeId,
    required this.product,
    required this.type,
    required this.warehouseId,
    required this.planned,
    required this.unit,
    required this.status,
    required this.materialsConsumed,
    required this.soldQty,
    this.actual,
    this.plannedCost,
    this.actualCost,
    this.actualUnitCost,
    this.additionalCostTotal,
    this.fullCost,
    this.fullUnitCost,
    this.date,
    this.user,
    this.recipeVersion,
    this.waste,
    this.batch,
    this.reverseReason,
  });

  final String id;
  final int recordId;
  final int recipeId;
  final String product;
  final String type;
  final int warehouseId;
  final String planned;
  final String? actual;
  final String unit;
  final String? plannedCost;
  final String? actualCost;
  final String? actualUnitCost;
  final String? additionalCostTotal;
  final String? fullCost;
  final String? fullUnitCost;
  final String? date;
  final String? user;
  final String? recipeVersion;
  final String status;
  final double soldQty;
  final ManufacturingProductionWaste? waste;
  final ManufacturingProductionBatch? batch;
  final String? reverseReason;
  final List<ManufacturingOrderConsumedLine> materialsConsumed;

  bool get isCompleted => status == 'completed';
  bool get isReversed => status == 'reversed';

  factory ManufacturingProductionOrder.fromJson(
    Map<String, dynamic> json,
  ) => ManufacturingProductionOrder(
    id: readString(json['id']),
    recordId: readInt(json['recordId']) ?? 0,
    recipeId: readInt(json['recipeId']) ?? 0,
    product: readString(json['product'], fallback: 'Manufactured item'),
    type: readString(json['type']),
    warehouseId: readInt(json['warehouseId']) ?? 0,
    planned: readString(json['planned'], fallback: '0'),
    actual: json['actual'] == null ? null : readString(json['actual']),
    unit: readString(json['unit']),
    plannedCost: json['plannedCost'] == null
        ? null
        : readString(json['plannedCost']),
    actualCost: json['actualCost'] == null
        ? null
        : readString(json['actualCost']),
    actualUnitCost: json['actualUnitCost']?.toString(),
    additionalCostTotal: json['additionalCostTotal']?.toString(),
    fullCost: json['fullCost']?.toString(),
    fullUnitCost: json['fullUnitCost']?.toString(),
    date: readString(json['date']).isEmpty ? null : readString(json['date']),
    user: readString(json['user']).isEmpty ? null : readString(json['user']),
    recipeVersion: readString(json['recipeVersion']).isEmpty
        ? null
        : readString(json['recipeVersion']),
    status: readString(json['status'], fallback: 'draft'),
    soldQty: readDouble(json['soldQty']),
    waste: json['waste'] == null
        ? null
        : ManufacturingProductionWaste.fromJson(
            Map<String, dynamic>.from(json['waste'] as Map),
          ),
    batch: json['batch'] == null
        ? null
        : ManufacturingProductionBatch.fromJson(
            Map<String, dynamic>.from(json['batch'] as Map),
          ),
    reverseReason: readString(json['reverseReason']).isEmpty
        ? null
        : readString(json['reverseReason']),
    materialsConsumed: readMapList(
      json['materialsConsumed'],
    ).map(ManufacturingOrderConsumedLine.fromJson).toList(growable: false),
  );
}

class ManufacturingOrderConsumedLine {
  const ManufacturingOrderConsumedLine({
    required this.materialId,
    required this.name,
    required this.planned,
    required this.unit,
    this.actual,
    this.unitCost,
  });

  final int materialId;
  final String name;
  final String planned;
  final String? actual;
  final String unit;
  final String? unitCost;

  factory ManufacturingOrderConsumedLine.fromJson(Map<String, dynamic> json) =>
      ManufacturingOrderConsumedLine(
        materialId: readInt(json['materialId']) ?? 0,
        name: readString(json['name'], fallback: 'Material'),
        planned: readString(json['planned'], fallback: '0'),
        actual: json['actual'] == null ? null : readString(json['actual']),
        unit: readString(json['unit']),
        unitCost: json['unitCost'] == null
            ? null
            : readString(json['unitCost']),
      );
}

class ManufacturingProductionWaste {
  const ManufacturingProductionWaste({
    required this.qty,
    required this.unit,
    this.reason,
    this.note,
  });

  final String qty;
  final String unit;
  final String? reason;
  final String? note;

  factory ManufacturingProductionWaste.fromJson(Map<String, dynamic> json) =>
      ManufacturingProductionWaste(
        qty: readString(json['qty'], fallback: '0'),
        unit: readString(json['unit']),
        reason: readString(json['reason']).isEmpty
            ? null
            : readString(json['reason']),
        note: readString(json['note']).isEmpty
            ? null
            : readString(json['note']),
      );
}

/// Batch/expiry info for a completed production order, exactly as the backend
/// returns it. NOTE: this is a summary block built from the order's own
/// `expiry_date`/`reference` fields (see `serializeOrder()`), not from
/// `manufacturing_batches.remaining_quantity` directly - the batch's true
/// remaining quantity is only reflected in the Overview "expiring" list and
/// in the reversal conflict's `remainingQty` metadata, not here.
class ManufacturingProductionBatch {
  const ManufacturingProductionBatch({
    this.ref,
    this.mfgDate,
    this.shelfLife,
    this.expiry,
  });

  final String? ref;
  final String? mfgDate;
  final String? shelfLife;
  final String? expiry;

  factory ManufacturingProductionBatch.fromJson(Map<String, dynamic> json) =>
      ManufacturingProductionBatch(
        ref: readString(json['ref']).isEmpty ? null : readString(json['ref']),
        mfgDate: readString(json['mfgDate']).isEmpty
            ? null
            : readString(json['mfgDate']),
        shelfLife: readString(json['shelfLife']).isEmpty
            ? null
            : readString(json['shelfLife']),
        expiry: readString(json['expiry']).isEmpty
            ? null
            : readString(json['expiry']),
      );
}

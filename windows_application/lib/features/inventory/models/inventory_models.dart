import '../../pos/models/json_helpers.dart';

class BarCheckTemplate {
  const BarCheckTemplate({required this.id, required this.name, required this.branchId, required this.warehouseId, required this.active, required this.requiredForShiftClose, this.branchName, this.warehouseName, this.lines = const <BarCheckTemplateLine>[]});
  final int id; final String name; final int branchId; final int warehouseId; final bool active; final bool requiredForShiftClose; final String? branchName; final String? warehouseName; final List<BarCheckTemplateLine> lines;
  factory BarCheckTemplate.fromJson(Map<String, dynamic> json) => BarCheckTemplate(id: readInt(json['id']) ?? 0, name: readString(json['name']), branchId: readInt(json['branchId']) ?? 0, warehouseId: readInt(json['warehouseId']) ?? 0, active: readBool(json['active']), requiredForShiftClose: readBool(json['requiredForShiftClose']), branchName: readString(json['branchName']).isEmpty ? null : readString(json['branchName']), warehouseName: readString(json['warehouseName']).isEmpty ? null : readString(json['warehouseName']), lines: readMapList(json['lines']).map(BarCheckTemplateLine.fromJson).toList(growable: false));
}

class BarCheckTemplateLine {
  const BarCheckTemplateLine({required this.itemId, required this.itemName, required this.sku, required this.countUnit, required this.required, required this.toleranceType, required this.tolerance, required this.requiresReviewWhenExceeded});
  final int itemId; final String itemName; final String sku; final String countUnit; final bool required; final String toleranceType; final String tolerance; final bool requiresReviewWhenExceeded;
  factory BarCheckTemplateLine.fromJson(Map<String, dynamic> json) => BarCheckTemplateLine(itemId: readInt(json['itemId']) ?? 0, itemName: readString(json['itemName']), sku: readString(json['sku']), countUnit: readString(json['countUnit']), required: readBool(json['required']), toleranceType: readString(json['toleranceType'], fallback: 'quantity'), tolerance: readString(json['tolerance'], fallback: '0'), requiresReviewWhenExceeded: readBool(json['requiresReviewWhenExceeded']));
  Map<String, dynamic> toJson() => <String, dynamic>{'itemId': itemId, 'countUnit': countUnit, 'required': required, 'toleranceType': toleranceType, 'tolerance': tolerance, 'requiresReviewWhenExceeded': requiresReviewWhenExceeded};
}

class WarehouseTransfer {
  const WarehouseTransfer({required this.id, required this.number, required this.sourceWarehouseId, required this.sourceWarehouseName, required this.destinationWarehouseId, required this.destinationWarehouseName, required this.status, required this.lines, this.notes, this.createdAt, this.submittedAt, this.approvedAt, this.dispatchedAt, this.receivedAt});
  final int id; final String number; final int sourceWarehouseId; final String sourceWarehouseName; final int destinationWarehouseId; final String destinationWarehouseName; final String status; final List<WarehouseTransferLine> lines; final String? notes; final String? createdAt; final String? submittedAt; final String? approvedAt; final String? dispatchedAt; final String? receivedAt;
  factory WarehouseTransfer.fromJson(Map<String, dynamic> json) => WarehouseTransfer(id: readInt(json['id']) ?? 0, number: readString(json['number']), sourceWarehouseId: readInt(json['sourceWarehouseId']) ?? 0, sourceWarehouseName: readString(json['sourceWarehouseName']), destinationWarehouseId: readInt(json['destinationWarehouseId']) ?? 0, destinationWarehouseName: readString(json['destinationWarehouseName']), status: readString(json['status']), lines: readMapList(json['lines']).map(WarehouseTransferLine.fromJson).toList(growable: false), notes: readString(json['notes']).isEmpty ? null : readString(json['notes']), createdAt: readString(json['createdAt']).isEmpty ? null : readString(json['createdAt']), submittedAt: readString(json['submittedAt']).isEmpty ? null : readString(json['submittedAt']), approvedAt: readString(json['approvedAt']).isEmpty ? null : readString(json['approvedAt']), dispatchedAt: readString(json['dispatchedAt']).isEmpty ? null : readString(json['dispatchedAt']), receivedAt: readString(json['receivedAt']).isEmpty ? null : readString(json['receivedAt']));
}

class WarehouseTransferLine {
  const WarehouseTransferLine({required this.itemId, required this.itemName, required this.sku, required this.unit, required this.requestedQuantity, required this.dispatchedQuantity, required this.receivedQuantity, required this.availableQuantity, required this.discrepancyQuantity});
  final int itemId; final String itemName; final String sku; final String unit; final String requestedQuantity; final String dispatchedQuantity; final String receivedQuantity; final String availableQuantity; final String discrepancyQuantity;
  factory WarehouseTransferLine.fromJson(Map<String, dynamic> json) => WarehouseTransferLine(itemId: readInt(json['itemId']) ?? 0, itemName: readString(json['itemName']), sku: readString(json['sku']), unit: readString(json['unit']), requestedQuantity: readString(json['requestedQuantity'], fallback: '0'), dispatchedQuantity: readString(json['dispatchedQuantity'], fallback: '0'), receivedQuantity: readString(json['receivedQuantity'], fallback: '0'), availableQuantity: readString(json['availableQuantity'], fallback: '0'), discrepancyQuantity: readString(json['discrepancyQuantity'], fallback: '0'));
}

class InventoryUnit {
  const InventoryUnit({required this.code, required this.label});
  final String code;
  final String label;

  factory InventoryUnit.fromJson(Map<String, dynamic> json) => InventoryUnit(
    code: readString(json['code']),
    label: readString(json['label']),
  );

  static const List<InventoryUnit> fallback = <InventoryUnit>[
    InventoryUnit(code: 'piece', label: 'Piece'),
    InventoryUnit(code: 'pack', label: 'Pack'),
    InventoryUnit(code: 'box', label: 'Box'),
    InventoryUnit(code: 'carton', label: 'Carton'),
    InventoryUnit(code: 'bag', label: 'Bag'),
    InventoryUnit(code: 'bottle', label: 'Bottle'),
    InventoryUnit(code: 'can', label: 'Can'),
    InventoryUnit(code: 'gram', label: 'Gram'),
    InventoryUnit(code: 'kilogram', label: 'Kilogram'),
    InventoryUnit(code: 'milliliter', label: 'Milliliter'),
    InventoryUnit(code: 'liter', label: 'Liter'),
  ];

  static String labelFor(String code) {
    for (final InventoryUnit unit in fallback) {
      if (unit.code == code) return unit.label;
    }
    return code;
  }
}

class InventoryItemUnitConversion {
  const InventoryItemUnitConversion({
    required this.id,
    required this.itemId,
    required this.sourceUnit,
    required this.sourceLabel,
    required this.targetUnit,
    required this.targetLabel,
    required this.factor,
    required this.active,
  });

  final int id;
  final int itemId;
  final String sourceUnit;
  final String sourceLabel;
  final String targetUnit;
  final String targetLabel;
  final String factor;
  final bool active;

  factory InventoryItemUnitConversion.fromJson(Map<String, dynamic> json) =>
      InventoryItemUnitConversion(
        id: readInt(json['id']) ?? 0,
        itemId: readInt(json['itemId']) ?? 0,
        sourceUnit: readString(json['sourceUnit']),
        sourceLabel: readString(json['sourceLabel']),
        targetUnit: readString(json['targetUnit']),
        targetLabel: readString(json['targetLabel']),
        factor: readString(json['factor'], fallback: '0'),
        active: readBool(json['isActive']),
      );
}

class InventoryItem {
  const InventoryItem({
    required this.id,
    required this.name,
    required this.sku,
    required this.unit,
    required this.itemType,
    required this.category,
    required this.quantity,
    required this.availableQuantity,
    required this.cost,
    required this.reorderLevel,
    required this.minimumStock,
    required this.active,
    this.totalValue = '0.00',
    this.recentMovements = const <InventoryMovement>[],
    this.barcode = '',
    this.notes = '',
    this.purchaseUnit = '',
    this.consumptionUnit = '',
    this.lastPurchaseCost = '0.0000',
    this.preferredSupplierName = '',
    this.trackExpiry = false,
    this.trackBatch = false,
    this.stockStatus = 'active',
    this.lastUpdatedAt = '',
    this.warehouseIds = const <int>[],
    this.balances = const <InventoryBalance>[],
  });

  final int id;
  final String name;
  final String sku;
  final String unit;
  final String itemType;
  final String category;
  final String quantity;
  final String availableQuantity;
  final String cost;
  final String reorderLevel;
  final String minimumStock;
  final bool active;
  final String totalValue;
  final List<InventoryMovement> recentMovements;
  final String barcode;
  final String notes;
  final String purchaseUnit;
  final String consumptionUnit;
  final String lastPurchaseCost;
  final String preferredSupplierName;
  final bool trackExpiry;
  final bool trackBatch;
  final String stockStatus;
  final String lastUpdatedAt;
  final List<int> warehouseIds;
  final List<InventoryBalance> balances;

  factory InventoryItem.fromJson(Map<String, dynamic> json) => InventoryItem(
    id: readInt(json['id']) ?? 0,
    name: readString(json['displayName'], fallback: readString(json['nameEn'])),
    sku: readString(json['sku']),
    unit: readString(json['unit'], fallback: 'unit'),
    itemType: readString(json['itemType']),
    category: readString(json['category']),
    quantity: readString(json['totalQuantity'], fallback: '0.000'),
    availableQuantity: readString(json['availableQuantity'], fallback: '0.000'),
    cost: readString(json['latestUnitCost'], fallback: '0.0000'),
    reorderLevel: readString(json['reorderLevel'], fallback: '0.000'),
    minimumStock: readString(json['minimumStock'], fallback: '0.000'),
    active: readBool(json['isActive']),
    totalValue: readString(json['totalValue'], fallback: '0.00'),
    recentMovements: readMapList(
      json['recentMovements'],
    ).map(InventoryMovement.fromJson).toList(growable: false),
    barcode: readString(json['barcode']),
    notes: readString(json['notes']),
    purchaseUnit: readString(json['purchaseUnit']),
    consumptionUnit: readString(json['consumptionUnit']),
    lastPurchaseCost: readString(json['lastPurchaseCost'], fallback: '0.0000'),
    preferredSupplierName: readString(json['preferredSupplierName']),
    trackExpiry: readBool(json['trackExpiry']),
    trackBatch: readBool(json['trackBatch']),
    stockStatus: readString(json['stockStatus'], fallback: 'active'),
    lastUpdatedAt: readString(json['lastUpdatedAt']),
    warehouseIds: (json['warehouseIds'] as List? ?? const <dynamic>[])
        .map((dynamic value) => readInt(value) ?? 0)
        .where((int value) => value > 0)
        .toList(growable: false),
    balances: readMapList(
      json['stockByWarehouse'],
    ).map(InventoryBalance.fromJson).toList(growable: false),
  );
}

class InventoryItemsPage {
  const InventoryItemsPage({
    required this.items,
    required this.currentPage,
    required this.lastPage,
    required this.total,
    required this.categories,
  });

  final List<InventoryItem> items;
  final int currentPage;
  final int lastPage;
  final int total;
  final List<String> categories;

  factory InventoryItemsPage.fromJson(Map<String, dynamic> json) {
    final Map<String, dynamic> meta = Map<String, dynamic>.from(
      json['meta'] as Map? ?? const <String, dynamic>{},
    );
    final Map<String, dynamic> filters = Map<String, dynamic>.from(
      json['filters'] as Map? ?? const <String, dynamic>{},
    );
    return InventoryItemsPage(
      items: readMapList(
        json['items'],
      ).map(InventoryItem.fromJson).toList(growable: false),
      currentPage: readInt(meta['currentPage']) ?? 1,
      lastPage: readInt(meta['lastPage']) ?? 1,
      total: readInt(meta['total']) ?? 0,
      categories: (filters['categories'] as List? ?? const <dynamic>[])
          .map((dynamic value) => readString(value))
          .where((String value) => value.isNotEmpty)
          .toList(growable: false),
    );
  }
}

class InventoryMovementsPage {
  const InventoryMovementsPage({
    required this.movements,
    required this.currentPage,
    required this.lastPage,
    required this.total,
  });

  final List<InventoryMovement> movements;
  final int currentPage;
  final int lastPage;
  final int total;

  factory InventoryMovementsPage.fromJson(Map<String, dynamic> json) {
    final Map<String, dynamic> meta = Map<String, dynamic>.from(
      json['meta'] as Map? ?? const <String, dynamic>{},
    );
    return InventoryMovementsPage(
      movements: readMapList(
        json['data'],
      ).map(InventoryMovement.fromJson).toList(growable: false),
      currentPage: readInt(meta['currentPage']) ?? 1,
      lastPage: readInt(meta['lastPage']) ?? 1,
      total: readInt(meta['total']) ?? 0,
    );
  }
}

class InventoryBalance {
  const InventoryBalance({
    required this.itemId,
    required this.itemName,
    required this.warehouseId,
    required this.warehouseName,
    required this.branchName,
    required this.warehouseTypeLabel,
    required this.unit,
    required this.quantity,
    required this.available,
    required this.cost,
    required this.value,
    required this.low,
    this.lastMovementAt,
  });
  final int itemId;
  final String itemName;
  final int warehouseId;
  final String warehouseName;
  final String branchName;
  final String warehouseTypeLabel;
  final String unit;
  final String quantity;
  final String available;
  final String cost;
  final String value;
  final bool low;
  final String? lastMovementAt;

  factory InventoryBalance.fromJson(Map<String, dynamic> json) =>
      InventoryBalance(
        itemId: readInt(json['itemId']) ?? 0,
        itemName: readString(
          json['itemNameEn'],
          fallback: readString(json['sku']),
        ),
        warehouseId: readInt(json['warehouseId']) ?? 0,
        warehouseName: readString(
          json['displayWarehouseName'],
          fallback: readString(json['warehouseCode']),
        ),
        branchName: readString(json['branchName']),
        warehouseTypeLabel: readString(
          json['warehouseTypeLabel'],
          fallback: 'Warehouse',
        ),
        unit: readString(json['unit'], fallback: 'unit'),
        quantity: readString(json['quantityOnHand'], fallback: '0.000'),
        available: readString(json['availableQuantity'], fallback: '0.000'),
        cost: readString(json['averageUnitCost'], fallback: '0.0000'),
        value: readString(json['totalValue'], fallback: '0.00'),
        low: readBool(json['isLowStock']),
        lastMovementAt: readString(json['lastMovementAt']).isEmpty
            ? null
            : readString(json['lastMovementAt']),
      );
}

class InventoryMovement {
  const InventoryMovement({
    required this.id,
    required this.itemId,
    required this.itemName,
    required this.warehouseId,
    required this.warehouseName,
    required this.warehouseTypeLabel,
    required this.unit,
    required this.type,
    required this.dashboardType,
    required this.quantityIn,
    required this.quantityOut,
    required this.unitCost,
    required this.totalCost,
    required this.reason,
    required this.occurredAt,
    this.createdAt,
    this.employee,
    this.reference,
  });
  final int id;
  final int itemId;
  final String itemName;
  final int warehouseId;
  final String warehouseName;
  final String warehouseTypeLabel;
  final String unit;
  final String type;
  final String dashboardType;
  final String quantityIn;
  final String quantityOut;
  final String unitCost;
  final String totalCost;
  final String reason;
  final String occurredAt;
  final String? createdAt;
  final String? employee;
  final String? reference;

  double get quantity {
    final double incoming = double.tryParse(quantityIn) ?? 0;
    return incoming > 0 ? incoming : -(double.tryParse(quantityOut) ?? 0);
  }

  factory InventoryMovement.fromJson(Map<String, dynamic> json) =>
      InventoryMovement(
        id: readInt(json['id']) ?? 0,
        itemId: readInt(json['itemId']) ?? 0,
        itemName: readString(
          json['itemNameEn'],
          fallback: readString(json['itemNameAr']),
        ),
        warehouseId: readInt(json['warehouseId']) ?? 0,
        warehouseName: readString(json['warehouseName']),
        warehouseTypeLabel: readString(
          json['warehouseTypeLabel'],
          fallback: 'Warehouse',
        ),
        unit: readString(json['unit'], fallback: 'unit'),
        type: readString(json['type']),
        dashboardType: readString(json['dashboardType']),
        quantityIn: readString(json['quantityIn'], fallback: '0.000'),
        quantityOut: readString(json['quantityOut'], fallback: '0.000'),
        unitCost: readString(json['unitCost'], fallback: '0.0000'),
        totalCost: readString(json['totalCost'], fallback: '0.00'),
        reason: readString(json['reason']),
        occurredAt: readString(json['occurredAt']),
        createdAt: readString(json['createdAt']).isEmpty
            ? null
            : readString(json['createdAt']),
        employee: readString(json['userName']).isEmpty
            ? null
            : readString(json['userName']),
        reference:
            readString(
              json['reference'],
              fallback: readString(json['referenceType']),
            ).isEmpty
            ? null
            : readString(
                json['reference'],
                fallback: readString(json['referenceType']),
              ),
      );
}

class InventoryWarehouseValue {
  const InventoryWarehouseValue({
    required this.id,
    required this.name,
    required this.value,
    required this.itemCount,
    required this.alertsCount,
    required this.warehouseTypeLabel,
    required this.lastMovementAt,
    required this.healthPercentage,
    required this.status,
  });
  final int id;
  final String name;
  final String value;
  final int itemCount;
  final int alertsCount;
  final String warehouseTypeLabel;
  final String? lastMovementAt;
  final int healthPercentage;
  final String status;
  factory InventoryWarehouseValue.fromJson(Map<String, dynamic> json) =>
      InventoryWarehouseValue(
        id: readInt(json['warehouseId']) ?? 0,
        name: readString(json['warehouseName'], fallback: 'Warehouse'),
        value: readString(json['value'], fallback: '0.00'),
        itemCount: readInt(json['itemCount']) ?? 0,
        alertsCount: readInt(json['alertsCount']) ?? 0,
        warehouseTypeLabel: readString(
          json['warehouseTypeLabel'],
          fallback: 'Warehouse',
        ),
        lastMovementAt: readString(json['lastMovementAt']).isEmpty
            ? null
            : readString(json['lastMovementAt']),
        healthPercentage: readInt(json['healthPercentage']) ?? 0,
        status: readString(json['status'], fallback: 'healthy'),
      );
}

class InventoryStockValueTrend {
  const InventoryStockValueTrend({
    required this.available,
    required this.points,
  });
  final bool available;
  final List<InventoryStockValueTrendPoint> points;
  factory InventoryStockValueTrend.fromJson(Map<String, dynamic> json) =>
      InventoryStockValueTrend(
        available: readBool(json['available']),
        points: readMapList(
          json['points'],
        ).map(InventoryStockValueTrendPoint.fromJson).toList(growable: false),
      );
}

class InventoryStockValueTrendPoint {
  const InventoryStockValueTrendPoint({
    required this.date,
    required this.value,
  });
  final String date;
  final String value;
  factory InventoryStockValueTrendPoint.fromJson(Map<String, dynamic> json) =>
      InventoryStockValueTrendPoint(
        date: readString(json['date']),
        value: readString(json['value'], fallback: '0.00'),
      );
}

class InventoryAnalyticsTopItem {
  const InventoryAnalyticsTopItem({
    required this.itemId,
    required this.itemName,
    required this.quantity,
    required this.unit,
    required this.cost,
  });

  final int itemId;
  final String itemName;
  final String quantity;
  final String unit;
  final String cost;

  factory InventoryAnalyticsTopItem.fromJson(Map<String, dynamic> json) =>
      InventoryAnalyticsTopItem(
        itemId: readInt(json['itemId']) ?? 0,
        itemName: readString(json['itemName'], fallback: 'Inventory item'),
        quantity: readString(json['quantity'], fallback: '0.000'),
        unit: readString(json['unit'], fallback: 'unit'),
        cost: readString(json['cost'], fallback: '0.00'),
      );
}

class InventoryWasteSummary {
  const InventoryWasteSummary({
    required this.todayCost,
    required this.weekCost,
    required this.movementCount,
    required this.topItems,
  });

  final String todayCost;
  final String weekCost;
  final int movementCount;
  final List<InventoryAnalyticsTopItem> topItems;

  factory InventoryWasteSummary.fromJson(Map<String, dynamic> json) =>
      InventoryWasteSummary(
        todayCost: readString(json['todayCost'], fallback: '0.00'),
        weekCost: readString(json['weekCost'], fallback: '0.00'),
        movementCount: readInt(json['movementCount']) ?? 0,
        topItems: readMapList(
          json['topItems'],
        ).map(InventoryAnalyticsTopItem.fromJson).toList(growable: false),
      );
}

class InventoryConsumptionSummary {
  const InventoryConsumptionSummary({
    required this.totalCost,
    required this.topItems,
  });

  final String totalCost;
  final List<InventoryAnalyticsTopItem> topItems;

  factory InventoryConsumptionSummary.fromJson(Map<String, dynamic> json) =>
      InventoryConsumptionSummary(
        totalCost: readString(json['totalCost'], fallback: '0.00'),
        topItems: readMapList(
          json['topItems'],
        ).map(InventoryAnalyticsTopItem.fromJson).toList(growable: false),
      );
}

class InventoryCountsPage {
  const InventoryCountsPage({
    required this.items,
    required this.currentPage,
    required this.lastPage,
    required this.total,
    required this.summary,
    required this.creators,
  });

  final List<InventoryCount> items;
  final int currentPage;
  final int lastPage;
  final int total;
  final InventoryCountSummary summary;
  final List<InventoryCountCreator> creators;

  factory InventoryCountsPage.fromJson(Map<String, dynamic> json) {
    final Map<String, dynamic> meta = Map<String, dynamic>.from(
      json['meta'] as Map? ?? const <String, dynamic>{},
    );
    final Map<String, dynamic> filterOptions = Map<String, dynamic>.from(
      meta['filterOptions'] as Map? ?? const <String, dynamic>{},
    );
    return InventoryCountsPage(
      items: readMapList(json['data'])
          .map(InventoryCount.fromJson)
          .toList(growable: false),
      currentPage: readInt(meta['currentPage']) ?? 1,
      lastPage: readInt(meta['lastPage']) ?? 1,
      total: readInt(meta['total']) ?? 0,
      summary: InventoryCountSummary.fromJson(
        Map<String, dynamic>.from(
          meta['summary'] as Map? ?? const <String, dynamic>{},
        ),
      ),
      creators: readMapList(filterOptions['createdBy'])
          .map(InventoryCountCreator.fromJson)
          .toList(growable: false),
    );
  }
}

class InventoryCountSummary {
  const InventoryCountSummary({
    this.drafts = 0,
    this.inProgress = 0,
    this.submitted = 0,
    this.approved = 0,
  });

  final int drafts;
  final int inProgress;
  final int submitted;
  final int approved;

  factory InventoryCountSummary.fromJson(Map<String, dynamic> json) =>
      InventoryCountSummary(
        drafts: readInt(json['drafts']) ?? 0,
        inProgress: readInt(json['inProgress']) ?? 0,
        submitted: readInt(json['submitted']) ?? 0,
        approved: readInt(json['approved']) ?? 0,
      );
}

class InventoryCountCreator {
  const InventoryCountCreator({required this.id, required this.name});

  final int id;
  final String name;

  factory InventoryCountCreator.fromJson(Map<String, dynamic> json) =>
      InventoryCountCreator(
        id: readInt(json['id']) ?? 0,
        name: readString(json['name']),
      );
}

class InventoryCount {
  const InventoryCount({
    required this.id,
    required this.number,
    required this.warehouseId,
    required this.warehouseName,
    required this.date,
    required this.countType,
    required this.status,
    this.totalItems = 0,
    this.countedItems = 0,
    this.varianceItems = 0,
    this.varianceValue = '0.00',
    this.createdByName,
    this.notes,
    this.lines = const <InventoryCountLine>[],
  });
  final int id;
  final String number;
  final int warehouseId;
  final String warehouseName;
  final String date;
  final String countType;
  final String status;
  final int totalItems;
  final int countedItems;
  final int varianceItems;
  final String varianceValue;
  final String? createdByName;
  final String? notes;
  final List<InventoryCountLine> lines;
  factory InventoryCount.fromJson(Map<String, dynamic> json) => InventoryCount(
    id: readInt(json['id']) ?? 0,
    number: readString(json['number'], fallback: 'SC-${readInt(json['id']) ?? 0}'),
    warehouseId: readInt(json['warehouseId']) ?? 0,
    warehouseName: readString(
      json['displayWarehouseName'],
      fallback: readString(json['warehouseName'], fallback: 'Warehouse'),
    ),
    date: readString(json['countDate']),
    countType: readString(json['countType'], fallback: 'full'),
    status: readString(json['status']),
    totalItems: readInt(json['totalItems']) ?? 0,
    countedItems: readInt(json['countedItems']) ?? 0,
    varianceItems: readInt(json['varianceItems']) ?? 0,
    varianceValue: readString(json['varianceValue'], fallback: '0.00'),
    createdByName: readString(json['createdByName']).isEmpty
        ? null
        : readString(json['createdByName']),
    notes: readString(json['notes']).isEmpty ? null : readString(json['notes']),
    lines: readMapList(
      json['lines'],
    ).map(InventoryCountLine.fromJson).toList(growable: false),
  );
}

class InventoryCountLine {
  const InventoryCountLine({
    required this.itemId,
    required this.itemName,
    required this.sku,
    required this.unit,
    required this.expectedQuantity,
    required this.countedQuantity,
    required this.varianceQuantity,
    required this.averageUnitCost,
    required this.varianceValue,
    required this.isCounted,
    this.reason,
  });
  final int itemId;
  final String itemName;
  final String sku;
  final String unit;
  final String expectedQuantity;
  final String countedQuantity;
  final String varianceQuantity;
  final String averageUnitCost;
  final String varianceValue;
  final bool isCounted;
  final String? reason;

  factory InventoryCountLine.fromJson(
    Map<String, dynamic> json,
  ) => InventoryCountLine(
    itemId: readInt(json['itemId']) ?? 0,
    itemName: readString(
      json['itemNameEn'],
      fallback: readString(json['itemNameAr'], fallback: 'Inventory item'),
    ),
    sku: readString(json['sku']),
    unit: readString(json['unit'], fallback: 'unit'),
    expectedQuantity: readString(json['expectedQuantity'], fallback: '0.000'),
    countedQuantity: readString(json['countedQuantity'], fallback: '0.000'),
    varianceQuantity: readString(json['varianceQuantity'], fallback: '0.000'),
    averageUnitCost: readString(json['averageUnitCost'], fallback: '0.0000'),
    varianceValue: readString(json['varianceValue'], fallback: '0.00'),
    isCounted: readBool(json['isCounted']),
    reason: readString(json['reason']).isEmpty
        ? null
        : readString(json['reason']),
  );
}

class InventoryDashboard {
  const InventoryDashboard({
    required this.kpis,
    required this.branches,
    required this.warehouses,
    required this.recent,
    required this.alerts,
    required this.alertSummary,
    required this.stockValueTrend,
    required this.wasteSummary,
    required this.consumptionSummary,
  });
  final InventoryDashboardKpis kpis;
  final List<InventoryDashboardBranch> branches;
  final List<InventoryWarehouseValue> warehouses;
  final List<InventoryMovement> recent;
  final List<InventoryLowStockAlert> alerts;
  final InventoryAlertSummary alertSummary;
  final InventoryStockValueTrend stockValueTrend;
  final InventoryWasteSummary wasteSummary;
  final InventoryConsumptionSummary consumptionSummary;
  factory InventoryDashboard.fromJson(Map<String, dynamic> json) =>
      InventoryDashboard(
        kpis: InventoryDashboardKpis.fromJson(
          Map<String, dynamic>.from(
            json['kpis'] as Map? ?? const <String, dynamic>{},
          ),
          json,
        ),
        branches: readMapList(
          json['branches'],
        ).map(InventoryDashboardBranch.fromJson).toList(growable: false),
        warehouses: readMapList(
          json['stockValueByWarehouse'],
        ).map(InventoryWarehouseValue.fromJson).toList(growable: false),
        recent: readMapList(
          json['recentMovements'],
        ).map(InventoryMovement.fromJson).toList(growable: false),
        alerts: readMapList(
          json['lowStockAlerts'],
        ).map(InventoryLowStockAlert.fromJson).toList(growable: false),
        alertSummary: InventoryAlertSummary.fromJson(
          Map<String, dynamic>.from(
            json['inventoryAlertsSummary'] as Map? ?? const <String, dynamic>{},
          ),
        ),
        stockValueTrend: InventoryStockValueTrend.fromJson(
          Map<String, dynamic>.from(
            json['stockValueTrend'] as Map? ?? const <String, dynamic>{},
          ),
        ),
        wasteSummary: InventoryWasteSummary.fromJson(
          Map<String, dynamic>.from(
            json['wasteSummary'] as Map? ?? const <String, dynamic>{},
          ),
        ),
        consumptionSummary: InventoryConsumptionSummary.fromJson(
          Map<String, dynamic>.from(
            json['consumptionSummary'] as Map? ?? const <String, dynamic>{},
          ),
        ),
      );
}

class InventoryDashboardMetric {
  const InventoryDashboardMetric({required this.value, this.previousValue});
  final String value;
  final String? previousValue;
  factory InventoryDashboardMetric.fromJson(
    Map<String, dynamic> json,
    String fallback,
  ) => InventoryDashboardMetric(
    value: readString(json['value'], fallback: fallback),
    previousValue: readString(json['previousValue']).isEmpty
        ? null
        : readString(json['previousValue']),
  );
}

class InventoryDashboardKpis {
  const InventoryDashboardKpis({
    required this.totalValue,
    required this.totalItems,
    required this.lowStock,
    required this.outOfStock,
    required this.todayConsumption,
    required this.todayWaste,
  });
  final InventoryDashboardMetric totalValue;
  final InventoryDashboardMetric totalItems;
  final InventoryDashboardMetric lowStock;
  final InventoryDashboardMetric outOfStock;
  final InventoryDashboardMetric todayConsumption;
  final InventoryDashboardMetric todayWaste;
  factory InventoryDashboardKpis.fromJson(
    Map<String, dynamic> json,
    Map<String, dynamic> root,
  ) => InventoryDashboardKpis(
    totalValue: InventoryDashboardMetric.fromJson(
      Map<String, dynamic>.from(
        json['totalInventoryValue'] as Map? ?? const <String, dynamic>{},
      ),
      readString(root['totalInventoryValue'], fallback: '0.00'),
    ),
    totalItems: InventoryDashboardMetric.fromJson(
      Map<String, dynamic>.from(
        json['totalItems'] as Map? ?? const <String, dynamic>{},
      ),
      '0',
    ),
    lowStock: InventoryDashboardMetric.fromJson(
      Map<String, dynamic>.from(
        json['lowStockItems'] as Map? ?? const <String, dynamic>{},
      ),
      '${readInt(root['lowStockItemCount']) ?? 0}',
    ),
    outOfStock: InventoryDashboardMetric.fromJson(
      Map<String, dynamic>.from(
        json['outOfStockItems'] as Map? ?? const <String, dynamic>{},
      ),
      '${readInt(root['outOfStockItemCount']) ?? 0}',
    ),
    todayConsumption: InventoryDashboardMetric.fromJson(
      Map<String, dynamic>.from(
        json['todayConsumptionCost'] as Map? ?? const <String, dynamic>{},
      ),
      '0.00',
    ),
    todayWaste: InventoryDashboardMetric.fromJson(
      Map<String, dynamic>.from(
        json['todayWasteCost'] as Map? ?? const <String, dynamic>{},
      ),
      readString(root['wasteValue'], fallback: '0.00'),
    ),
  );
}

class InventoryDashboardBranch {
  const InventoryDashboardBranch({required this.id, required this.name});
  final int id;
  final String name;
  factory InventoryDashboardBranch.fromJson(Map<String, dynamic> json) =>
      InventoryDashboardBranch(
        id: readInt(json['id']) ?? 0,
        name: readString(json['name']),
      );
}

class InventoryLowStockAlert {
  const InventoryLowStockAlert({
    required this.itemId,
    required this.itemName,
    required this.warehouseName,
    required this.quantity,
    required this.minimumLevel,
    required this.missingQuantity,
    required this.suggestedReorderQuantity,
    required this.severity,
    required this.unit,
    required this.outOfStock,
  });
  final int itemId;
  final String itemName;
  final String warehouseName;
  final String quantity;
  final String minimumLevel;
  final String missingQuantity;
  final String suggestedReorderQuantity;
  final String severity;
  final String unit;
  final bool outOfStock;
  factory InventoryLowStockAlert.fromJson(Map<String, dynamic> json) =>
      InventoryLowStockAlert(
        itemId: readInt(json['itemId']) ?? 0,
        itemName: readString(json['itemName'], fallback: 'Inventory item'),
        warehouseName: readString(json['warehouseName'], fallback: 'Warehouse'),
        quantity: readString(json['quantity'], fallback: '0.000'),
        minimumLevel: readString(json['minimumLevel'], fallback: '0.000'),
        missingQuantity: readString(json['missingQuantity'], fallback: '0.000'),
        suggestedReorderQuantity: readString(
          json['suggestedReorderQuantity'],
          fallback: '0.000',
        ),
        severity: readString(json['severity'], fallback: 'low'),
        unit: readString(json['unit'], fallback: 'unit'),
        outOfStock: readBool(json['outOfStock']),
      );
}

class InventoryAlertSummary {
  const InventoryAlertSummary({
    required this.critical,
    required this.low,
    required this.total,
  });
  final int critical;
  final int low;
  final int total;
  factory InventoryAlertSummary.fromJson(Map<String, dynamic> json) =>
      InventoryAlertSummary(
        critical: readInt(json['critical']) ?? 0,
        low: readInt(json['low']) ?? 0,
        total: readInt(json['total']) ?? 0,
      );
}

import '../../pos/models/json_helpers.dart';

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
    required this.quantityIn,
    required this.quantityOut,
    required this.unitCost,
    required this.totalCost,
    required this.reason,
    required this.occurredAt,
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
  final String quantityIn;
  final String quantityOut;
  final String unitCost;
  final String totalCost;
  final String reason;
  final String occurredAt;
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
        quantityIn: readString(json['quantityIn'], fallback: '0.000'),
        quantityOut: readString(json['quantityOut'], fallback: '0.000'),
        unitCost: readString(json['unitCost'], fallback: '0.0000'),
        totalCost: readString(json['totalCost'], fallback: '0.00'),
        reason: readString(json['reason']),
        occurredAt: readString(json['occurredAt']),
        employee: readString(json['userName']).isEmpty
            ? null
            : readString(json['userName']),
        reference: readString(json['referenceType']).isEmpty
            ? null
            : readString(json['referenceType']),
      );
}

class InventoryWarehouseValue {
  const InventoryWarehouseValue({
    required this.id,
    required this.name,
    required this.value,
  });
  final int id;
  final String name;
  final String value;
  factory InventoryWarehouseValue.fromJson(Map<String, dynamic> json) =>
      InventoryWarehouseValue(
        id: readInt(json['warehouseId']) ?? 0,
        name: readString(json['warehouseName'], fallback: 'Warehouse'),
        value: readString(json['value'], fallback: '0.00'),
      );
}

class InventoryCount {
  const InventoryCount({
    required this.id,
    required this.warehouseId,
    required this.warehouseName,
    required this.date,
    required this.status,
    this.notes,
    this.lines = const <InventoryCountLine>[],
  });
  final int id;
  final int warehouseId;
  final String warehouseName;
  final String date;
  final String status;
  final String? notes;
  final List<InventoryCountLine> lines;
  factory InventoryCount.fromJson(Map<String, dynamic> json) => InventoryCount(
    id: readInt(json['id']) ?? 0,
    warehouseId: readInt(json['warehouseId']) ?? 0,
    warehouseName: readString(
      json['displayWarehouseName'],
      fallback: readString(json['warehouseName'], fallback: 'Warehouse'),
    ),
    date: readString(json['countDate']),
    status: readString(json['status']),
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
    required this.unit,
    required this.expectedQuantity,
    required this.countedQuantity,
    required this.varianceQuantity,
    this.reason,
  });
  final int itemId;
  final String itemName;
  final String unit;
  final String expectedQuantity;
  final String countedQuantity;
  final String varianceQuantity;
  final String? reason;

  factory InventoryCountLine.fromJson(
    Map<String, dynamic> json,
  ) => InventoryCountLine(
    itemId: readInt(json['itemId']) ?? 0,
    itemName: readString(
      json['itemNameEn'],
      fallback: readString(json['itemNameAr'], fallback: 'Inventory item'),
    ),
    unit: readString(json['unit'], fallback: 'unit'),
    expectedQuantity: readString(json['expectedQuantity'], fallback: '0.000'),
    countedQuantity: readString(json['countedQuantity'], fallback: '0.000'),
    varianceQuantity: readString(json['varianceQuantity'], fallback: '0.000'),
    reason: readString(json['reason']).isEmpty
        ? null
        : readString(json['reason']),
  );
}

class InventoryDashboard {
  const InventoryDashboard({
    required this.kpis,
    required this.branches,
    required this.totalValue,
    required this.low,
    required this.out,
    required this.waste,
    required this.recent,
    required this.warehouseValues,
    required this.alerts,
  });
  final InventoryDashboardKpis kpis;
  final List<InventoryDashboardBranch> branches;
  final String totalValue;
  final int low;
  final int out;
  final String waste;
  final List<InventoryMovement> recent;
  final List<InventoryWarehouseValue> warehouseValues;
  final List<InventoryLowStockAlert> alerts;
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
        totalValue: readString(json['totalInventoryValue'], fallback: '0.00'),
        low: readInt(json['lowStockItemCount']) ?? 0,
        out: readInt(json['outOfStockItemCount']) ?? 0,
        waste: readString(json['wasteValue'], fallback: '0.00'),
        recent: readMapList(
          json['recentMovements'],
        ).map(InventoryMovement.fromJson).toList(growable: false),
        warehouseValues: readMapList(
          json['stockValueByWarehouse'],
        ).map(InventoryWarehouseValue.fromJson).toList(growable: false),
        alerts: readMapList(
          json['lowStockAlerts'],
        ).map(InventoryLowStockAlert.fromJson).toList(growable: false),
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
    required this.lowStock,
    required this.outOfStock,
    required this.wasteValue,
  });
  final InventoryDashboardMetric totalValue;
  final InventoryDashboardMetric lowStock;
  final InventoryDashboardMetric outOfStock;
  final InventoryDashboardMetric wasteValue;
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
    wasteValue: InventoryDashboardMetric.fromJson(
      Map<String, dynamic>.from(
        json['wasteValue'] as Map? ?? const <String, dynamic>{},
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
    required this.unit,
    required this.outOfStock,
  });
  final int itemId;
  final String itemName;
  final String warehouseName;
  final String quantity;
  final String unit;
  final bool outOfStock;
  factory InventoryLowStockAlert.fromJson(Map<String, dynamic> json) =>
      InventoryLowStockAlert(
        itemId: readInt(json['itemId']) ?? 0,
        itemName: readString(json['itemName'], fallback: 'Inventory item'),
        warehouseName: readString(json['warehouseName'], fallback: 'Warehouse'),
        quantity: readString(json['quantity'], fallback: '0.000'),
        unit: readString(json['unit'], fallback: 'unit'),
        outOfStock: readBool(json['outOfStock']),
      );
}

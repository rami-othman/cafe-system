import 'package:equatable/equatable.dart';

class InventoryReport extends Equatable {
  const InventoryReport({
    required this.currency,
    required this.branches,
    required this.locations,
    required this.categories,
    required this.kpis,
    required this.valueByLocation,
    required this.movements,
    required this.stockHealth,
    required this.stockRows,
    required this.consumption,
    required this.waste,
    required this.variances,
    required this.locationComparison,
    required this.exceptions,
  });
  factory InventoryReport.empty() => const InventoryReport(
    currency: 'SYP',
    branches: <InventoryFilterOption>[],
    locations: <InventoryFilterOption>[],
    categories: <InventoryFilterOption>[],
    kpis: InventoryReportKpis.empty(),
    valueByLocation: <InventoryValueByLocation>[],
    movements: <InventoryMovementPoint>[],
    stockHealth: <StockHealthSummary>[],
    stockRows: <StockHealthRow>[],
    consumption: <InventoryConsumptionRow>[],
    waste: <InventoryWasteRow>[],
    variances: <InventoryCountVarianceRow>[],
    locationComparison: <InventoryLocationComparisonRow>[],
    exceptions: <InventoryReportException>[],
  );
  final String currency;
  final List<InventoryFilterOption> branches, locations, categories;
  final InventoryReportKpis kpis;
  final List<InventoryValueByLocation> valueByLocation;
  final List<InventoryMovementPoint> movements;
  final List<StockHealthSummary> stockHealth;
  final List<StockHealthRow> stockRows;
  final List<InventoryConsumptionRow> consumption;
  final List<InventoryWasteRow> waste;
  final List<InventoryCountVarianceRow> variances;
  final List<InventoryLocationComparisonRow> locationComparison;
  final List<InventoryReportException> exceptions;
  @override
  List<Object?> get props => <Object?>[
    currency,
    branches,
    locations,
    categories,
    kpis,
    valueByLocation,
    movements,
    stockHealth,
    stockRows,
    consumption,
    waste,
    variances,
    locationComparison,
    exceptions,
  ];
}

class InventoryFilterOption extends Equatable {
  const InventoryFilterOption({required this.id, required this.name});
  final int id;
  final String name;
  @override
  List<Object?> get props => <Object?>[id, name];
}

class InventoryMetric extends Equatable {
  const InventoryMetric({this.value, this.previousValue});
  const InventoryMetric.unavailable() : value = null, previousValue = null;
  final double? value, previousValue;
  bool get available => value != null;
  @override
  List<Object?> get props => <Object?>[value, previousValue];
}

class InventoryReportKpis extends Equatable {
  const InventoryReportKpis({
    required this.currentValue,
    required this.lowStock,
    required this.outOfStock,
    required this.wasteValue,
    required this.countVariance,
    required this.consumption,
    required this.received,
    required this.transfers,
  });
  const InventoryReportKpis.empty()
    : currentValue = const InventoryMetric.unavailable(),
      lowStock = const InventoryMetric.unavailable(),
      outOfStock = const InventoryMetric.unavailable(),
      wasteValue = const InventoryMetric.unavailable(),
      countVariance = const InventoryMetric.unavailable(),
      consumption = const InventoryMetric.unavailable(),
      received = const InventoryMetric.unavailable(),
      transfers = const InventoryMetric.unavailable();
  final InventoryMetric currentValue,
      lowStock,
      outOfStock,
      wasteValue,
      countVariance,
      consumption,
      received,
      transfers;
  @override
  List<Object?> get props => <Object?>[
    currentValue,
    lowStock,
    outOfStock,
    wasteValue,
    countVariance,
    consumption,
    received,
    transfers,
  ];
}

class InventoryValueByLocation extends Equatable {
  const InventoryValueByLocation({
    required this.name,
    required this.value,
    this.itemCount,
  });
  final String name;
  final double value;
  final int? itemCount;
  @override
  List<Object?> get props => <Object?>[name, value, itemCount];
}

class InventoryMovementPoint extends Equatable {
  const InventoryMovementPoint({
    required this.date,
    required this.label,
    required this.value,
  });
  final DateTime date;
  final String label;
  final double value;
  @override
  List<Object?> get props => <Object?>[date, label, value];
}

enum InventoryHealth { available, low, out, overstock }

class StockHealthSummary extends Equatable {
  const StockHealthSummary({required this.health, required this.count});
  final InventoryHealth health;
  final int count;
  @override
  List<Object?> get props => <Object?>[health, count];
}

class StockHealthRow extends Equatable {
  const StockHealthRow({
    required this.name,
    required this.category,
    required this.location,
    required this.quantity,
    required this.minimum,
    required this.unit,
    required this.health,
  });
  final String name, category, location, unit;
  final double quantity, minimum;
  final InventoryHealth health;
  @override
  List<Object?> get props => <Object?>[
    name,
    category,
    location,
    quantity,
    minimum,
    unit,
    health,
  ];
}

class InventoryConsumptionRow extends Equatable {
  const InventoryConsumptionRow({
    required this.name,
    required this.category,
    required this.quantity,
    required this.unit,
    this.value,
  });
  final String name, category, unit;
  final double quantity;
  final double? value;
  @override
  List<Object?> get props => <Object?>[name, category, quantity, unit, value];
}

class InventoryWasteRow extends Equatable {
  const InventoryWasteRow({
    required this.name,
    required this.quantity,
    required this.unit,
    required this.value,
    required this.reason,
    required this.location,
  });
  final String name, unit, reason, location;
  final double quantity, value;
  @override
  List<Object?> get props => <Object?>[
    name,
    quantity,
    unit,
    value,
    reason,
    location,
  ];
}

enum InventoryVarianceStatus { matched, shortage, overage }

class InventoryCountVarianceRow extends Equatable {
  const InventoryCountVarianceRow({
    required this.location,
    required this.expected,
    required this.counted,
    required this.value,
    required this.status,
    this.countedAt,
  });
  final String location;
  final double expected, counted, value;
  final InventoryVarianceStatus status;
  final DateTime? countedAt;
  double get difference => counted - expected;
  @override
  List<Object?> get props => <Object?>[
    location,
    expected,
    counted,
    value,
    status,
    countedAt,
  ];
}

class InventoryLocationComparisonRow extends Equatable {
  const InventoryLocationComparisonRow({
    required this.name,
    this.value,
    this.items,
    this.lowStock,
    this.outOfStock,
    this.waste,
    this.variance,
  });
  final String name;
  final double? value, waste, variance;
  final int? items, lowStock, outOfStock;
  @override
  List<Object?> get props => <Object?>[
    name,
    value,
    items,
    lowStock,
    outOfStock,
    waste,
    variance,
  ];
}

enum InventoryExceptionSeverity { critical, warning, info }

class InventoryReportException extends Equatable {
  const InventoryReportException({
    required this.description,
    required this.context,
    required this.severity,
  });
  final String description, context;
  final InventoryExceptionSeverity severity;
  @override
  List<Object?> get props => <Object?>[description, context, severity];
}

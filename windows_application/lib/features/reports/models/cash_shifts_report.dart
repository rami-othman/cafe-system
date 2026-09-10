import 'package:equatable/equatable.dart';

class CashShiftsReport extends Equatable {
  const CashShiftsReport({
    required this.currency,
    required this.branches,
    required this.cashiers,
    required this.kpis,
    required this.reconciliation,
    required this.shifts,
    required this.payments,
    required this.trend,
    required this.topShifts,
    required this.exceptions,
  });
  factory CashShiftsReport.empty() => const CashShiftsReport(
    currency: 'SYP',
    branches: <ReportFilterOption>[],
    cashiers: <ReportFilterOption>[],
    kpis: CashShiftKpis.empty(),
    reconciliation: null,
    shifts: <ShiftPerformanceRow>[],
    payments: <PaymentMethodBreakdownRow>[],
    trend: <ShiftTrendPoint>[],
    topShifts: <TopShiftRow>[],
    exceptions: <CashShiftException>[],
  );
  final String currency;
  final List<ReportFilterOption> branches;
  final List<ReportFilterOption> cashiers;
  final CashShiftKpis kpis;
  final CashReconciliationSummary? reconciliation;
  final List<ShiftPerformanceRow> shifts;
  final List<PaymentMethodBreakdownRow> payments;
  final List<ShiftTrendPoint> trend;
  final List<TopShiftRow> topShifts;
  final List<CashShiftException> exceptions;
  @override
  List<Object?> get props => <Object?>[
    currency,
    branches,
    cashiers,
    kpis,
    reconciliation,
    shifts,
    payments,
    trend,
    topShifts,
    exceptions,
  ];
}

class ReportFilterOption extends Equatable {
  const ReportFilterOption({required this.id, required this.name});
  final int id;
  final String name;
  @override
  List<Object?> get props => <Object?>[id, name];
}

class CashShiftMetric extends Equatable {
  const CashShiftMetric({this.value, this.previousValue});
  const CashShiftMetric.unavailable() : value = null, previousValue = null;
  final double? value;
  final double? previousValue;
  bool get available => value != null;
  @override
  List<Object?> get props => <Object?>[value, previousValue];
}

class CashShiftKpis extends Equatable {
  const CashShiftKpis({
    required this.totalSales,
    required this.expectedCash,
    required this.actualCash,
    required this.cashDifference,
    required this.closedShifts,
    required this.openShifts,
    required this.averageShiftSales,
  });
  const CashShiftKpis.empty()
    : totalSales = const CashShiftMetric.unavailable(),
      expectedCash = const CashShiftMetric.unavailable(),
      actualCash = const CashShiftMetric.unavailable(),
      cashDifference = const CashShiftMetric.unavailable(),
      closedShifts = const CashShiftMetric.unavailable(),
      openShifts = const CashShiftMetric.unavailable(),
      averageShiftSales = const CashShiftMetric.unavailable();
  final CashShiftMetric totalSales,
      expectedCash,
      actualCash,
      cashDifference,
      closedShifts,
      openShifts,
      averageShiftSales;
  @override
  List<Object?> get props => <Object?>[
    totalSales,
    expectedCash,
    actualCash,
    cashDifference,
    closedShifts,
    openShifts,
    averageShiftSales,
  ];
}

enum CashReconciliationStatus { matched, minorDifference, needsReview }

class CashReconciliationSummary extends Equatable {
  const CashReconciliationSummary({
    required this.expected,
    required this.actual,
    required this.difference,
    required this.status,
  });
  final double expected, actual, difference;
  final CashReconciliationStatus status;
  @override
  List<Object?> get props => <Object?>[expected, actual, difference, status];
}

enum ShiftStatus { open, closed }

class ShiftPerformanceRow extends Equatable {
  const ShiftPerformanceRow({
    required this.name,
    required this.employee,
    this.openedAt,
    this.closedAt,
    required this.orders,
    required this.sales,
    required this.refunds,
    required this.discounts,
    this.expectedCash,
    this.actualCash,
    this.difference,
    required this.status,
  });
  final String name, employee;
  final DateTime? openedAt, closedAt;
  final int orders;
  final double sales, refunds, discounts;
  final double? expectedCash, actualCash, difference;
  final ShiftStatus status;
  @override
  List<Object?> get props => <Object?>[
    name,
    employee,
    openedAt,
    closedAt,
    orders,
    sales,
    refunds,
    discounts,
    expectedCash,
    actualCash,
    difference,
    status,
  ];
}

class PaymentMethodBreakdownRow extends Equatable {
  const PaymentMethodBreakdownRow({
    required this.name,
    required this.amount,
    required this.percent,
  });
  final String name;
  final double amount, percent;
  @override
  List<Object?> get props => <Object?>[name, amount, percent];
}

class ShiftTrendPoint extends Equatable {
  const ShiftTrendPoint({required this.date, required this.sales});
  final DateTime date;
  final double sales;
  @override
  List<Object?> get props => <Object?>[date, sales];
}

class TopShiftRow extends Equatable {
  const TopShiftRow({
    required this.name,
    required this.sales,
    required this.orders,
    required this.averageOrder,
  });
  final String name;
  final double sales, averageOrder;
  final int orders;
  @override
  List<Object?> get props => <Object?>[name, sales, orders, averageOrder];
}

enum CashShiftExceptionSeverity { critical, warning, info }

class CashShiftException extends Equatable {
  const CashShiftException({
    required this.description,
    required this.context,
    required this.severity,
  });
  final String description, context;
  final CashShiftExceptionSeverity severity;
  @override
  List<Object?> get props => <Object?>[description, context, severity];
}

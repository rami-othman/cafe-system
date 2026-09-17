import 'package:equatable/equatable.dart';

/// Tolerance for float comparisons on counted quantities and cash amounts.
const double kShiftEpsilon = 1e-9;

enum ShiftLifecycle { open, closed }

/// Who/where/when a shift belongs to. Rendered by `ShiftIdentityHeader` and
/// repeated verbatim at the top of the closing report.
class ShiftIdentity extends Equatable {
  const ShiftIdentity({
    this.id = 0,
    required this.shiftNumber,
    required this.branchName,
    required this.cashierName,
    required this.cashierCode,
    required this.openedAt,
    required this.openedBy,
    required this.lifecycle,
    this.closedAt,
    this.closedBy,
  });

  /// Database identifier used only for lifecycle mutations; reports use the
  /// human-readable [shiftNumber]. Zero keeps the legacy UI fixtures valid.
  final int id;
  final String shiftNumber;
  final String branchName;
  final String cashierName;

  /// Employee number shown next to the cashier name.
  final String cashierCode;
  final DateTime openedAt;
  final String openedBy;
  final ShiftLifecycle lifecycle;
  final DateTime? closedAt;
  final String? closedBy;

  bool get isOpen => lifecycle == ShiftLifecycle.open;

  /// Elapsed time against [now] for an open shift, or the sealed duration of
  /// a closed one.
  Duration elapsedAt(DateTime now) =>
      (closedAt ?? now).difference(openedAt).abs();

  ShiftIdentity copyWith({
    ShiftLifecycle? lifecycle,
    DateTime? closedAt,
    String? closedBy,
  }) => ShiftIdentity(
    id: id,
    shiftNumber: shiftNumber,
    branchName: branchName,
    cashierName: cashierName,
    cashierCode: cashierCode,
    openedAt: openedAt,
    openedBy: openedBy,
    lifecycle: lifecycle ?? this.lifecycle,
    closedAt: closedAt ?? this.closedAt,
    closedBy: closedBy ?? this.closedBy,
  );

  @override
  List<Object?> get props => <Object?>[
    shiftNumber,
    id,
    branchName,
    cashierName,
    cashierCode,
    openedAt,
    openedBy,
    lifecycle,
    closedAt,
    closedBy,
  ];
}

class ShiftSalesSummary extends Equatable {
  const ShiftSalesSummary({
    required this.grossSales,
    required this.discounts,
    required this.refunds,
    required this.refundCount,
    required this.orderCount,
    required this.cancelledOrderCount,
    required this.discountPolicyCount,
  });

  final double grossSales;
  final double discounts;
  final double refunds;
  final int refundCount;

  /// Completed, revenue-bearing orders — cancelled orders are excluded.
  final int orderCount;
  final int cancelledOrderCount;
  final int discountPolicyCount;

  double get netSales => grossSales - discounts - refunds;

  double get averageOrderValue =>
      orderCount == 0 ? 0 : netSales / orderCount;

  double get discountRatio => grossSales == 0 ? 0 : discounts / grossSales;

  double get refundRatio => grossSales == 0 ? 0 : refunds / grossSales;

  @override
  List<Object?> get props => <Object?>[
    grossSales,
    discounts,
    refunds,
    refundCount,
    orderCount,
    cancelledOrderCount,
    discountPolicyCount,
  ];
}

enum PaymentChannel { cash, card, transfer, customerCredit, other }

class PaymentBreakdownLine extends Equatable {
  const PaymentBreakdownLine({
    required this.channel,
    required this.amount,
    required this.transactionCount,
  });

  final PaymentChannel channel;
  final double amount;
  final int transactionCount;

  @override
  List<Object?> get props => <Object?>[channel, amount, transactionCount];
}

class PaymentBreakdown extends Equatable {
  const PaymentBreakdown({required this.lines});

  final List<PaymentBreakdownLine> lines;

  double get total =>
      lines.fold(0, (double sum, PaymentBreakdownLine l) => sum + l.amount);

  int get transactionCount =>
      lines.fold(0, (int sum, PaymentBreakdownLine l) => sum + l.transactionCount);

  double amountFor(PaymentChannel channel) => lines
      .where((PaymentBreakdownLine l) => l.channel == channel)
      .fold(0, (double sum, PaymentBreakdownLine l) => sum + l.amount);

  int transactionsFor(PaymentChannel channel) => lines
      .where((PaymentBreakdownLine l) => l.channel == channel)
      .fold(0, (int sum, PaymentBreakdownLine l) => sum + l.transactionCount);

  double ratioFor(PaymentChannel channel) =>
      total == 0 ? 0 : amountFor(channel) / total;

  /// Lines that actually carry money, in descending amount order. Channels a
  /// branch never used stay out of the card instead of rendering as zeros.
  List<PaymentBreakdownLine> get usedLines {
    final List<PaymentBreakdownLine> used = lines
        .where((PaymentBreakdownLine l) => l.amount.abs() > kShiftEpsilon)
        .toList();
    used.sort(
      (PaymentBreakdownLine a, PaymentBreakdownLine b) =>
          b.amount.compareTo(a.amount),
    );
    return used;
  }

  @override
  List<Object?> get props => <Object?>[lines];
}

/// A still-open order that blocks (or merely warns about) closing.
class OpenOrderRef extends Equatable {
  const OpenOrderRef({
    required this.orderNumber,
    required this.amount,
    required this.stateLabel,
  });

  final String orderNumber;
  final double amount;
  final String stateLabel;

  @override
  List<Object?> get props => <Object?>[orderNumber, amount, stateLabel];
}

class OrdersStatusSummary extends Equatable {
  const OrdersStatusSummary({
    required this.completed,
    required this.paid,
    required this.preparing,
    required this.open,
    required this.cancelled,
    required this.partiallyRefunded,
    required this.fullyRefunded,
    this.openOrders = const <OpenOrderRef>[],
  });

  final int completed;
  final int paid;
  final int preparing;
  final int open;
  final int cancelled;
  final int partiallyRefunded;
  final int fullyRefunded;
  final List<OpenOrderRef> openOrders;

  /// Orders that must be settled before the shift can close: anything still
  /// open or on the pass.
  int get unfinished => open + preparing;

  bool get hasUnfinished => unfinished > 0;

  @override
  List<Object?> get props => <Object?>[
    completed,
    paid,
    preparing,
    open,
    cancelled,
    partiallyRefunded,
    fullyRefunded,
    openOrders,
  ];
}

enum CashMovementKind {
  openingFloat,
  cashSale,
  cashRefund,
  withdrawal,
  deposit,
  expense,
}

class CashMovement extends Equatable {
  const CashMovement({
    required this.kind,
    required this.occurredAt,
    required this.description,
    required this.amount,
  });

  final CashMovementKind kind;
  final DateTime occurredAt;
  final String description;

  /// Signed against the drawer: sales/deposits add, refunds/withdrawals and
  /// expenses subtract.
  final double amount;

  @override
  List<Object?> get props => <Object?>[kind, occurredAt, description, amount];
}

/// Everything the drawer should contain, before anyone counts it.
class CashDrawerSnapshot extends Equatable {
  const CashDrawerSnapshot({
    required this.openingFloat,
    required this.cashSales,
    required this.cashRefunds,
    required this.withdrawals,
    required this.deposits,
    required this.expenses,
    required this.movements,
  });

  final double openingFloat;
  final double cashSales;
  final double cashRefunds;
  final double withdrawals;
  final double deposits;
  final double expenses;
  final List<CashMovement> movements;

  double get expected =>
      openingFloat + cashSales + deposits - cashRefunds - withdrawals - expenses;

  @override
  List<Object?> get props => <Object?>[
    openingFloat,
    cashSales,
    cashRefunds,
    withdrawals,
    deposits,
    expenses,
    movements,
  ];
}

enum BarCountStatus { uncounted, match, shortage, surplus }

/// One counted material. [counted] stays null until the cashier enters a
/// quantity, which is what separates "not counted yet" from "counted zero".
class BarCountLine extends Equatable {
  const BarCountLine({
    required this.id,
    required this.name,
    required this.sku,
    required this.category,
    required this.unit,
    required this.decimals,
    required this.theoretical,
    required this.unitCost,
    this.counted,
    this.note = '',
  });

  final String id;
  final String name;
  final String sku;
  final String category;
  final String unit;

  /// Decimal precision the unit allows: 0 for pieces, 2 for kg/litre.
  final int decimals;

  /// System quantity. May be negative — negative stock is allowed and must
  /// never block the count.
  final double theoretical;
  final double unitCost;
  final double? counted;
  final String note;

  bool get isCounted => counted != null;

  bool get hasNegativeTheoretical => theoretical < -kShiftEpsilon;

  double? get difference =>
      counted == null ? null : counted! - theoretical;

  /// Approximate monetary impact of the variance, for reporting only.
  double? get differenceValue {
    final double? diff = difference;
    return diff == null ? null : diff * unitCost;
  }

  BarCountStatus get status {
    final double? diff = difference;
    if (diff == null) return BarCountStatus.uncounted;
    if (diff.abs() <= kShiftEpsilon) return BarCountStatus.match;
    return diff < 0 ? BarCountStatus.shortage : BarCountStatus.surplus;
  }

  bool get hasDifference =>
      status == BarCountStatus.shortage || status == BarCountStatus.surplus;

  BarCountLine copyWith({
    double? counted,
    bool clearCounted = false,
    String? note,
  }) => BarCountLine(
    id: id,
    name: name,
    sku: sku,
    category: category,
    unit: unit,
    decimals: decimals,
    theoretical: theoretical,
    unitCost: unitCost,
    counted: clearCounted ? null : counted ?? this.counted,
    note: note ?? this.note,
  );

  @override
  List<Object?> get props => <Object?>[
    id,
    name,
    sku,
    category,
    unit,
    decimals,
    theoretical,
    unitCost,
    counted,
    note,
  ];
}

class BarCountTemplate extends Equatable {
  const BarCountTemplate({
    required this.warehouseName,
    required this.lines,
    this.lastCountedAt,
  });

  final String warehouseName;
  final List<BarCountLine> lines;
  final DateTime? lastCountedAt;

  int get totalItems => lines.length;

  int get countedItems =>
      lines.where((BarCountLine l) => l.isCounted).length;

  int get uncountedItems => totalItems - countedItems;

  int get matchedItems => lines
      .where((BarCountLine l) => l.status == BarCountStatus.match)
      .length;

  int get shortageItems => lines
      .where((BarCountLine l) => l.status == BarCountStatus.shortage)
      .length;

  int get surplusItems => lines
      .where((BarCountLine l) => l.status == BarCountStatus.surplus)
      .length;

  int get differenceItems => shortageItems + surplusItems;

  bool get isComplete => totalItems > 0 && uncountedItems == 0;

  bool get isStarted => countedItems > 0;

  double get progress => totalItems == 0 ? 0 : countedItems / totalItems;

  /// Net monetary impact of every counted variance.
  double get differenceValue => lines.fold(
    0,
    (double sum, BarCountLine l) => sum + (l.differenceValue ?? 0),
  );

  List<BarCountLine> get differenceLines =>
      lines.where((BarCountLine l) => l.hasDifference).toList();

  BarCountTemplate copyWith({List<BarCountLine>? lines}) => BarCountTemplate(
    warehouseName: warehouseName,
    lines: lines ?? this.lines,
    lastCountedAt: lastCountedAt,
  );

  @override
  List<Object?> get props => <Object?>[warehouseName, lines, lastCountedAt];
}

/// A refund recorded during the shift, listed in the closing report.
class ShiftRefundEntry extends Equatable {
  const ShiftRefundEntry({
    required this.orderNumber,
    required this.occurredAt,
    required this.amount,
    required this.reason,
    required this.channel,
  });

  final String orderNumber;
  final DateTime occurredAt;
  final double amount;
  final String reason;
  final PaymentChannel channel;

  @override
  List<Object?> get props => <Object?>[
    orderNumber,
    occurredAt,
    amount,
    reason,
    channel,
  ];
}

/// A discount policy applied during the shift.
class ShiftDiscountEntry extends Equatable {
  const ShiftDiscountEntry({
    required this.policyName,
    required this.appliedCount,
    required this.amount,
  });

  final String policyName;
  final int appliedCount;
  final double amount;

  @override
  List<Object?> get props => <Object?>[policyName, appliedCount, amount];
}

enum PendingOperationKind {
  refundApproval,
  expenseApproval,
  customerPayment,
  cashTransfer,
  barCount,
}

class PendingOperation extends Equatable {
  const PendingOperation({
    required this.kind,
    required this.reference,
    required this.detail,
    required this.blocking,
    this.amount,
  });

  final PendingOperationKind kind;
  final String reference;
  final String detail;

  /// Blocking items disable the close action; non-blocking ones only warn.
  final bool blocking;
  final double? amount;

  @override
  List<Object?> get props => <Object?>[
    kind,
    reference,
    detail,
    blocking,
    amount,
  ];
}

enum ShiftAlertSeverity { success, info, warning, blocker }

class ShiftAlert extends Equatable {
  const ShiftAlert({
    required this.severity,
    required this.title,
    this.detail,
    this.actionLabel,
  });

  final ShiftAlertSeverity severity;
  final String title;
  final String? detail;
  final String? actionLabel;

  @override
  List<Object?> get props => <Object?>[severity, title, detail, actionLabel];
}

enum ShiftReadinessStatus { done, pending, warning, blocked }

class ShiftReadinessItem extends Equatable {
  const ShiftReadinessItem({
    required this.status,
    required this.label,
    this.detail,
  });

  final ShiftReadinessStatus status;
  final String label;
  final String? detail;

  @override
  List<Object?> get props => <Object?>[status, label, detail];
}

enum ShiftStage {
  opened,
  selling,
  operationsReview,
  cashCount,
  barCount,
  finalReview,
  closed,
}

enum ShiftStageStatus { done, current, pending, warning }

class ShiftStageStep extends Equatable {
  const ShiftStageStep({
    required this.stage,
    required this.label,
    required this.status,
  });

  final ShiftStage stage;
  final String label;
  final ShiftStageStatus status;

  @override
  List<Object?> get props => <Object?>[stage, label, status];
}

/// The complete read model a shift screen needs. One object keeps the
/// overview, the closing wizard and the report reading identical numbers.
class ShiftSnapshot extends Equatable {
  const ShiftSnapshot({
    required this.identity,
    required this.sales,
    required this.payments,
    required this.orders,
    required this.drawer,
    required this.barCount,
    required this.pendingOperations,
    required this.refunds,
    required this.discounts,
    this.openingNote = '',
  });

  final ShiftIdentity identity;
  final ShiftSalesSummary sales;
  final PaymentBreakdown payments;
  final OrdersStatusSummary orders;
  final CashDrawerSnapshot drawer;
  final BarCountTemplate barCount;
  final List<PendingOperation> pendingOperations;
  final List<ShiftRefundEntry> refunds;
  final List<ShiftDiscountEntry> discounts;
  final String openingNote;

  bool get hasBlockingOperation =>
      orders.hasUnfinished ||
      pendingOperations.any((PendingOperation o) => o.blocking);

  ShiftSnapshot copyWith({
    ShiftIdentity? identity,
    BarCountTemplate? barCount,
  }) => ShiftSnapshot(
    identity: identity ?? this.identity,
    sales: sales,
    payments: payments,
    orders: orders,
    drawer: drawer,
    barCount: barCount ?? this.barCount,
    pendingOperations: pendingOperations,
    refunds: refunds,
    discounts: discounts,
    openingNote: openingNote,
  );

  @override
  List<Object?> get props => <Object?>[
    identity,
    sales,
    payments,
    orders,
    drawer,
    barCount,
    pendingOperations,
    refunds,
    discounts,
    openingNote,
  ];
}

enum CashDifferenceReason {
  changeError,
  unrecordedTransaction,
  unrecordedWithdrawal,
  unrecordedExpense,
  unknownSurplus,
  unknownShortage,
  other,
}

/// The cashier's counted result, produced by step 2 of the wizard.
class CashCountResult extends Equatable {
  const CashCountResult({
    required this.expected,
    required this.actual,
    this.reason,
    this.reasonDetail = '',
  });

  final double expected;
  final double actual;
  final CashDifferenceReason? reason;
  final String reasonDetail;

  double get difference => actual - expected;

  bool get isBalanced => difference.abs() <= 0.5;

  bool get isShortage => difference < -0.5;

  bool get isSurplus => difference > 0.5;

  @override
  List<Object?> get props => <Object?>[
    expected,
    actual,
    reason,
    reasonDetail,
  ];
}

/// The sealed outcome of a closed shift: what the report renders.
class ShiftClosingResult extends Equatable {
  const ShiftClosingResult({
    required this.snapshot,
    required this.cash,
    required this.closingNotes,
    required this.closedAt,
    required this.closedBy,
    required this.reportNumber,
  });

  final ShiftSnapshot snapshot;
  final CashCountResult cash;
  final String closingNotes;
  final DateTime closedAt;
  final String closedBy;
  final String reportNumber;

  Duration get duration => closedAt.difference(snapshot.identity.openedAt);

  @override
  List<Object?> get props => <Object?>[
    snapshot,
    cash,
    closingNotes,
    closedAt,
    closedBy,
    reportNumber,
  ];
}

enum ShiftHistoryStatus { closed, closedWithDifference, reopened }

class ShiftHistoryEntry extends Equatable {
  const ShiftHistoryEntry({
    required this.shiftNumber,
    required this.date,
    required this.cashierName,
    required this.branchName,
    required this.openedAt,
    required this.closedAt,
    required this.orderCount,
    required this.netSales,
    required this.cashSales,
    required this.cashDifference,
    required this.barDifferenceCount,
    required this.status,
  });

  final String shiftNumber;
  final DateTime date;
  final String cashierName;
  final String branchName;
  final DateTime openedAt;
  final DateTime closedAt;
  final int orderCount;
  final double netSales;
  final double cashSales;
  final double cashDifference;
  final int barDifferenceCount;
  final ShiftHistoryStatus status;

  Duration get duration => closedAt.difference(openedAt);

  bool get isBalanced => cashDifference.abs() <= 0.5;

  bool get isShortage => cashDifference < -0.5;

  bool get isSurplus => cashDifference > 0.5;

  @override
  List<Object?> get props => <Object?>[
    shiftNumber,
    date,
    cashierName,
    branchName,
    openedAt,
    closedAt,
    orderCount,
    netSales,
    cashSales,
    cashDifference,
    barDifferenceCount,
    status,
  ];
}

/// Aggregates recomputed over whatever the history filters currently match.
class ShiftHistorySummary extends Equatable {
  const ShiftHistorySummary({
    required this.shiftCount,
    required this.totalNetSales,
    required this.totalCashDifference,
    required this.averageDuration,
  });

  factory ShiftHistorySummary.from(List<ShiftHistoryEntry> entries) {
    if (entries.isEmpty) {
      return const ShiftHistorySummary(
        shiftCount: 0,
        totalNetSales: 0,
        totalCashDifference: 0,
        averageDuration: Duration.zero,
      );
    }
    final double net = entries.fold(
      0,
      (double sum, ShiftHistoryEntry e) => sum + e.netSales,
    );
    final double diff = entries.fold(
      0,
      (double sum, ShiftHistoryEntry e) => sum + e.cashDifference,
    );
    final int minutes = entries.fold(
      0,
      (int sum, ShiftHistoryEntry e) => sum + e.duration.inMinutes,
    );
    return ShiftHistorySummary(
      shiftCount: entries.length,
      totalNetSales: net,
      totalCashDifference: diff,
      averageDuration: Duration(minutes: (minutes / entries.length).round()),
    );
  }

  final int shiftCount;
  final double totalNetSales;
  final double totalCashDifference;
  final Duration averageDuration;

  @override
  List<Object?> get props => <Object?>[
    shiftCount,
    totalNetSales,
    totalCashDifference,
    averageDuration,
  ];
}

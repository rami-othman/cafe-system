import 'package:equatable/equatable.dart';

import '../widgets/shift_format.dart';
import '../widgets/shift_strings.dart';
import 'shift_models.dart';

/// Derives every "can this shift close?" signal from a snapshot plus whatever
/// the cashier has counted so far.
///
/// Alerts, the readiness checklist and the stage track are all projections of
/// the same facts, so they are computed once here instead of three times
/// across the overview, the wizard and the confirmation dialog — which is how
/// a checklist and a button end up disagreeing.
class ShiftAssessment extends Equatable {
  const ShiftAssessment({
    required this.alerts,
    required this.readiness,
    required this.stages,
    required this.blockers,
    required this.warnings,
  });

  factory ShiftAssessment.build({
    required ShiftSnapshot snapshot,
    CashCountResult? cash,
    bool barCountSubmitted = false,
    ShiftStage currentStage = ShiftStage.selling,
    bool closed = false,
  }) {
    final OrdersStatusSummary orders = snapshot.orders;
    final BarCountTemplate bar = snapshot.barCount;

    final List<ShiftAlert> alerts = <ShiftAlert>[];
    final List<String> blockers = <String>[];
    final List<String> warnings = <String>[];

    // Blocking: unfinished orders.
    if (orders.hasUnfinished) {
      final String title = ShiftStrings.unfinishedOrdersWarning(
        orders.unfinished,
      );
      final String detail = orders.openOrders.isEmpty
          ? ShiftStrings.blockedByOpenOrders
          : orders.openOrders
                .map(
                  (OpenOrderRef o) =>
                      '${o.orderNumber} — ${ShiftFormat.money(o.amount)} (${o.stateLabel})',
                )
                .join('\n');
      alerts.add(
        ShiftAlert(
          severity: ShiftAlertSeverity.blocker,
          title: title,
          detail: detail,
          actionLabel: ShiftStrings.viewOpenOrders,
        ),
      );
      blockers.add(title);
    }

    // Blocking pending operations (e.g. an open cash transfer).
    for (final PendingOperation operation in snapshot.pendingOperations) {
      final String label = _pendingLabel(operation.kind);
      final String title = '$label — ${operation.reference}';
      alerts.add(
        ShiftAlert(
          severity: operation.blocking
              ? ShiftAlertSeverity.blocker
              : ShiftAlertSeverity.warning,
          title: title,
          detail: operation.detail,
        ),
      );
      (operation.blocking ? blockers : warnings).add(title);
    }

    // Cash variance.
    if (cash != null && !cash.isBalanced) {
      final String title =
          '${ShiftStrings.cashDifference}: ${ShiftFormat.signedMoney(cash.difference)}';
      alerts.add(
        ShiftAlert(
          severity: ShiftAlertSeverity.warning,
          title: title,
          detail: cash.isShortage
              ? ShiftStrings.cashShortage
              : ShiftStrings.cashSurplus,
        ),
      );
      warnings.add(title);
    }

    // Stock variance.
    if (bar.differenceItems > 0) {
      final String title = _barDifferenceTitle(bar.differenceItems);
      alerts.add(
        ShiftAlert(
          severity: ShiftAlertSeverity.warning,
          title: title,
          detail:
              '${ShiftStrings.statusShortage}: ${ShiftFormat.count(bar.shortageItems)}'
              '  •  '
              '${ShiftStrings.statusSurplus}: ${ShiftFormat.count(bar.surplusItems)}',
        ),
      );
      warnings.add(title);
    }

    // An incomplete count warns; it does not block, so a manager can still
    // close a shift after acknowledging it in the final review.
    if (barCountSubmitted && !bar.isComplete) {
      final String title = ShiftStrings.uncountedRemaining(bar.uncountedItems);
      alerts.add(
        ShiftAlert(
          severity: ShiftAlertSeverity.warning,
          title: title,
          detail: ShiftStrings.pendingBarCount,
        ),
      );
      warnings.add(title);
    }

    if (alerts.isEmpty) {
      alerts.add(
        const ShiftAlert(
          severity: ShiftAlertSeverity.success,
          title: ShiftStrings.noBlockingIssues,
          detail: ShiftStrings.allOrdersSettled,
        ),
      );
    }

    return ShiftAssessment(
      alerts: alerts,
      blockers: blockers,
      warnings: warnings,
      readiness: _readiness(
        snapshot: snapshot,
        cash: cash,
        barCountSubmitted: barCountSubmitted,
      ),
      stages: _stages(
        current: currentStage,
        closed: closed,
        hasBlocker: blockers.isNotEmpty,
        cashCounted: cash != null,
        barCountSubmitted: barCountSubmitted,
      ),
    );
  }

  final List<ShiftAlert> alerts;
  final List<ShiftReadinessItem> readiness;
  final List<ShiftStageStep> stages;

  /// Human-readable blockers; non-empty means the close action is disabled.
  final List<String> blockers;
  final List<String> warnings;

  bool get canClose => blockers.isEmpty;

  bool get hasWarnings => warnings.isNotEmpty;

  ShiftAlertSeverity get worstSeverity {
    if (blockers.isNotEmpty) return ShiftAlertSeverity.blocker;
    if (warnings.isNotEmpty) return ShiftAlertSeverity.warning;
    return ShiftAlertSeverity.success;
  }

  static List<ShiftReadinessItem> _readiness({
    required ShiftSnapshot snapshot,
    required CashCountResult? cash,
    required bool barCountSubmitted,
  }) {
    final OrdersStatusSummary orders = snapshot.orders;
    final BarCountTemplate bar = snapshot.barCount;
    final bool paymentsMatch =
        (snapshot.payments.total -
                (snapshot.sales.grossSales - snapshot.sales.discounts))
            .abs() <=
        1;

    return <ShiftReadinessItem>[
      ShiftReadinessItem(
        status: orders.hasUnfinished
            ? ShiftReadinessStatus.blocked
            : ShiftReadinessStatus.done,
        label: 'جميع الطلبات مكتملة',
        detail: orders.hasUnfinished
            ? ShiftStrings.unfinishedOrdersWarning(orders.unfinished)
            : null,
      ),
      ShiftReadinessItem(
        status: paymentsMatch
            ? ShiftReadinessStatus.done
            : ShiftReadinessStatus.warning,
        label: 'تمت مطابقة المدفوعات',
        detail: paymentsMatch
            ? null
            : 'إجمالي المدفوعات لا يطابق صافي المبيعات',
      ),
      ShiftReadinessItem(
        status: snapshot.pendingOperations.isEmpty
            ? ShiftReadinessStatus.done
            : snapshot.pendingOperations.any((PendingOperation o) => o.blocking)
            ? ShiftReadinessStatus.blocked
            : ShiftReadinessStatus.warning,
        label: 'لا توجد عمليات معلقة',
        detail: snapshot.pendingOperations.isEmpty
            ? null
            : snapshot.pendingOperations
                  .map(
                    (PendingOperation o) =>
                        '${_pendingLabel(o.kind)} (${o.reference})',
                  )
                  .join('، '),
      ),
      ShiftReadinessItem(
        status: cash == null
            ? ShiftReadinessStatus.pending
            : cash.isBalanced
            ? ShiftReadinessStatus.done
            : ShiftReadinessStatus.warning,
        label: 'تم جرد الصندوق',
        detail: cash == null
            ? 'لم يتم إدخال المبلغ الفعلي بعد'
            : cash.isBalanced
            ? ShiftStrings.cashMatched
            : '${ShiftStrings.cashDifference} ${ShiftFormat.signedMoney(cash.difference)}',
      ),
      ShiftReadinessItem(
        status: !barCountSubmitted
            ? ShiftReadinessStatus.pending
            : !bar.isComplete
            ? ShiftReadinessStatus.warning
            : bar.differenceItems > 0
            ? ShiftReadinessStatus.warning
            : ShiftReadinessStatus.done,
        label: 'تم جرد جميع مواد البار',
        detail: !barCountSubmitted
            ? ShiftStrings.barCountNotStarted
            : !bar.isComplete
            ? ShiftStrings.uncountedRemaining(bar.uncountedItems)
            : bar.differenceItems > 0
            ? _barDifferenceTitle(bar.differenceItems)
            : ShiftStrings.barCountComplete,
      ),
    ];
  }

  static List<ShiftStageStep> _stages({
    required ShiftStage current,
    required bool closed,
    required bool hasBlocker,
    required bool cashCounted,
    required bool barCountSubmitted,
  }) {
    const List<(ShiftStage, String)> definitions = <(ShiftStage, String)>[
      (ShiftStage.opened, ShiftStrings.stageOpened),
      (ShiftStage.selling, ShiftStrings.stageSelling),
      (ShiftStage.operationsReview, ShiftStrings.stageOperations),
      (ShiftStage.cashCount, ShiftStrings.stageCashCount),
      (ShiftStage.barCount, ShiftStrings.stageBarCount),
      (ShiftStage.finalReview, ShiftStrings.stageFinalReview),
      (ShiftStage.closed, ShiftStrings.stageClosed),
    ];

    final int currentIndex = definitions.indexWhere(
      ((ShiftStage, String) d) => d.$1 == current,
    );

    return <ShiftStageStep>[
      for (int i = 0; i < definitions.length; i++)
        ShiftStageStep(
          stage: definitions[i].$1,
          label: definitions[i].$2,
          status: _stageStatus(
            index: i,
            currentIndex: currentIndex,
            stage: definitions[i].$1,
            closed: closed,
            hasBlocker: hasBlocker,
            cashCounted: cashCounted,
            barCountSubmitted: barCountSubmitted,
          ),
        ),
    ];
  }

  static ShiftStageStatus _stageStatus({
    required int index,
    required int currentIndex,
    required ShiftStage stage,
    required bool closed,
    required bool hasBlocker,
    required bool cashCounted,
    required bool barCountSubmitted,
  }) {
    if (closed) return ShiftStageStatus.done;
    if (stage == ShiftStage.operationsReview && hasBlocker && index <= currentIndex) {
      return ShiftStageStatus.warning;
    }
    if (stage == ShiftStage.cashCount && index < currentIndex && !cashCounted) {
      return ShiftStageStatus.warning;
    }
    if (stage == ShiftStage.barCount &&
        index < currentIndex &&
        !barCountSubmitted) {
      return ShiftStageStatus.warning;
    }
    if (index < currentIndex) return ShiftStageStatus.done;
    if (index == currentIndex) return ShiftStageStatus.current;
    return ShiftStageStatus.pending;
  }

  static String _barDifferenceTitle(int count) => switch (count) {
    1 => 'مادة واحدة بها فرق في جرد البار',
    2 => 'مادتان بهما فروقات في جرد البار',
    _ => '$count مواد بها فروقات في جرد البار',
  };

  static String _pendingLabel(PendingOperationKind kind) => switch (kind) {
    PendingOperationKind.refundApproval => ShiftStrings.pendingRefund,
    PendingOperationKind.expenseApproval => ShiftStrings.pendingExpense,
    PendingOperationKind.customerPayment => ShiftStrings.pendingCustomerPayment,
    PendingOperationKind.cashTransfer => ShiftStrings.pendingCashTransfer,
    PendingOperationKind.barCount => ShiftStrings.pendingBarCount,
  };

  /// Exposed so the pending-operations list can label rows with the same
  /// wording the alerts use.
  static String pendingLabel(PendingOperationKind kind) => _pendingLabel(kind);

  static String barDifferenceTitle(int count) => _barDifferenceTitle(count);

  @override
  List<Object?> get props => <Object?>[
    alerts,
    readiness,
    stages,
    blockers,
    warnings,
  ];
}

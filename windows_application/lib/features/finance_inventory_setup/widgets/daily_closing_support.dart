import '../../../l10n/app_localizations.dart';
import '../models/finance_setup_models.dart';
import 'finance_design.dart';

enum DailyClosingReadinessState { ready, warning, blocked, closed }

DailyClosingReadinessState dailyClosingReadinessState(
  String readiness,
  int warningsCount,
) {
  if (readiness == 'closed') return DailyClosingReadinessState.closed;
  if (readiness == 'blocked') return DailyClosingReadinessState.blocked;
  if (warningsCount > 0) return DailyClosingReadinessState.warning;
  return DailyClosingReadinessState.ready;
}

String dailyClosingReadinessLabel(
  AppLocalizations l10n,
  DailyClosingReadinessState state,
) => switch (state) {
  DailyClosingReadinessState.ready => l10n.financeStatusReady,
  DailyClosingReadinessState.warning => l10n.financeStatusWarning,
  DailyClosingReadinessState.blocked => l10n.financeStatusBlocked,
  DailyClosingReadinessState.closed => l10n.financeStatusClosed,
};

FinanceTone dailyClosingReadinessTone(DailyClosingReadinessState state) =>
    switch (state) {
      DailyClosingReadinessState.ready => FinanceTone.success,
      DailyClosingReadinessState.warning => FinanceTone.warning,
      DailyClosingReadinessState.blocked => FinanceTone.danger,
      DailyClosingReadinessState.closed => FinanceTone.neutral,
    };

/// Converts known backend readiness codes to safe, domain-specific UI text.
/// Unknown codes retain no backend wording and use a localized fallback.
String dailyClosingIssueLabel(AppLocalizations l10n, DailyClosingIssue issue) {
  final Map<String, dynamic> raw = issue.raw;
  final int count = raw['count'] is int
      ? raw['count'] as int
      : int.tryParse('${raw['count'] ?? ''}') ?? 0;
  final String amount = '${raw['amount'] ?? '—'}';
  return switch (issue.code) {
    'OPEN_SHIFTS' => l10n.financeDailyClosingIssueOpenShifts(count),
    'PENDING_EXPENSE_APPROVAL' =>
      l10n.financeDailyClosingIssuePendingExpenseApproval(count),
    'MISSING_ACTUAL_CASH' => l10n.financeDailyClosingIssueMissingActualCash,
    'CASH_DIFFERENCE' => l10n.financeDailyClosingIssueCashDifference(amount),
    'DRAFT_JOURNALS' => l10n.financeDailyClosingIssueDraftJournals(count),
    'UNPOSTED_INVENTORY_FINANCIAL_EVENT' =>
      l10n.financeDailyClosingIssueUnpostedInventoryEvent(count),
    'CASH_RECONCILIATION_INCOMPLETE' =>
      l10n.financeDailyClosingIssueCashReconciliationIncomplete,
    'CARD_RECONCILIATION_INCOMPLETE' =>
      l10n.financeDailyClosingIssueCardReconciliationIncomplete,
    'BANK_RECONCILIATION_INCOMPLETE' =>
      l10n.financeDailyClosingIssueBankReconciliationIncomplete,
    _ => l10n.financeDailyClosingIssueUnknown,
  };
}

String? dailyClosingIssueRoute(DailyClosingIssue issue) => switch (issue.code) {
  'PENDING_EXPENSE_APPROVAL' => '/finance/expenses',
  'DRAFT_JOURNALS' => '/finance/journal-entries',
  'UNPOSTED_INVENTORY_FINANCIAL_EVENT' => '/inventory/movements',
  'CASH_RECONCILIATION_INCOMPLETE' ||
  'CARD_RECONCILIATION_INCOMPLETE' ||
  'BANK_RECONCILIATION_INCOMPLETE' => '/finance/reconciliation',
  _ => null,
};

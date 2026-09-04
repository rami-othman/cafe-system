import '../models/finance_setup_models.dart';
import 'finance_design.dart';

/// Daily Closing readiness is purely a presentation split of backend truth:
/// `readiness` ('ready' | 'blocked' | 'closed') comes straight from
/// `DailyClosingReadinessService`; a non-blocking "warning" state is only
/// ever shown when the backend itself reports open (non-blocking) warnings
/// alongside a 'ready' readiness. Flutter never invents a blocker/warning.
enum DailyClosingReadinessState { ready, warning, blocked, closed }

DailyClosingReadinessState dailyClosingReadinessState(String readiness, int warningsCount) {
  if (readiness == 'closed') return DailyClosingReadinessState.closed;
  if (readiness == 'blocked') return DailyClosingReadinessState.blocked;
  if (warningsCount > 0) return DailyClosingReadinessState.warning;
  return DailyClosingReadinessState.ready;
}

String dailyClosingReadinessLabel(DailyClosingReadinessState state) => switch (state) {
  DailyClosingReadinessState.ready => 'جاهزة',
  DailyClosingReadinessState.warning => 'تحذير',
  DailyClosingReadinessState.blocked => 'محظورة',
  DailyClosingReadinessState.closed => 'مغلق',
};

FinanceTone dailyClosingReadinessTone(DailyClosingReadinessState state) => switch (state) {
  DailyClosingReadinessState.ready => FinanceTone.success,
  DailyClosingReadinessState.warning => FinanceTone.warning,
  DailyClosingReadinessState.blocked => FinanceTone.danger,
  DailyClosingReadinessState.closed => FinanceTone.neutral,
};

/// A one-line Arabic description for a backend blocker/warning row. Only the
/// text is derived here — the condition and every count/amount inside it are
/// the backend's own `code`/extra fields, never recomputed.
String dailyClosingIssueLabel(DailyClosingIssue issue) {
  final Map<String, dynamic> raw = issue.raw;
  switch (issue.code) {
    case 'OPEN_SHIFTS':
      return 'يوجد ${raw['count'] ?? ''} وردية مفتوحة يجب إغلاقها';
    case 'PENDING_EXPENSE_APPROVAL':
      return 'يوجد ${raw['count'] ?? ''} مصروف بانتظار الاعتماد';
    case 'MISSING_ACTUAL_CASH':
      return 'لم يتم إدخال النقد الفعلي بعد';
    case 'CASH_DIFFERENCE':
      return 'يوجد فرق نقدي بقيمة ${raw['amount'] ?? '—'}';
    case 'DRAFT_JOURNALS':
      return 'يوجد ${raw['count'] ?? ''} قيد مسودة لهذا اليوم';
    case 'UNPOSTED_INVENTORY_FINANCIAL_EVENT':
      return 'يوجد ${raw['count'] ?? ''} حركة مخزون بلا ترحيل محاسبي';
    case 'CASH_RECONCILIATION_INCOMPLETE':
      return 'تسوية الصندوق النقدي غير مكتملة لهذا اليوم';
    case 'CARD_RECONCILIATION_INCOMPLETE':
      return 'تسوية بطاقة غير مكتملة لهذا اليوم';
    case 'BANK_RECONCILIATION_INCOMPLETE':
      return 'تسوية بنكية غير مكتملة لهذا اليوم';
    default:
      return issue.code;
  }
}

/// Route to navigate to for a given blocker/warning code, or null when there
/// is no dedicated resource to open (e.g. `OPEN_SHIFTS`, which is a count with
/// no addressable shift record, or `MISSING_ACTUAL_CASH`/`CASH_DIFFERENCE`,
/// which are resolved in-place via "تحديث النقد الفعلي").
String? dailyClosingIssueRoute(DailyClosingIssue issue) => switch (issue.code) {
  'PENDING_EXPENSE_APPROVAL' => '/finance/expenses',
  'DRAFT_JOURNALS' => '/finance/journal-entries',
  'UNPOSTED_INVENTORY_FINANCIAL_EVENT' => '/inventory/movements',
  'CASH_RECONCILIATION_INCOMPLETE' || 'CARD_RECONCILIATION_INCOMPLETE' || 'BANK_RECONCILIATION_INCOMPLETE' =>
    '/finance/reconciliation',
  _ => null,
};

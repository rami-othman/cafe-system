import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../app/app_router.dart';
import '../../../shared/layouts/desktop_page_layout.dart';
import '../controllers/finance_setup_cubit.dart';
import '../models/finance_setup_models.dart';
import '../repositories/finance_setup_repository.dart';
import '../widgets/daily_closing_support.dart';
import '../widgets/finance_components.dart';
import '../widgets/finance_design.dart';
import '../widgets/finance_journal_drawer.dart';
import '../widgets/finance_shell.dart';

/// Daily Closing detail workspace (`/finance/daily-closing/:id`). Every
/// figure, readiness signal, blocker, warning, and late-activity row is
/// `DailyClosingService::present()` output — this screen only renders it and
/// decomposes backend actions (update actual cash, close) into real API
/// calls. It never computes expected cash, readiness, or closing eligibility
/// itself, and a closed day is rendered strictly read-only.
class DailyClosingWorkspaceScreen extends StatefulWidget {
  const DailyClosingWorkspaceScreen({super.key, required this.closingId});
  final int closingId;

  @override
  State<DailyClosingWorkspaceScreen> createState() => _DailyClosingWorkspaceScreenState();
}

class _DailyClosingWorkspaceScreenState extends State<DailyClosingWorkspaceScreen> {
  DailyClosingDetail? _detail;
  bool _loading = true;
  Object? _error;

  bool _relatedLoading = false;
  Object? _relatedError;
  List<ExpenseRecord> _expenses = const <ExpenseRecord>[];
  List<SupplierPayment> _supplierPayments = const <SupplierPayment>[];

  bool _updatingCash = false;
  bool _closing = false;

  FinanceSetupRepository get _repository => context.read<FinanceSetupCubit>().repository;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final DailyClosingDetail detail = await _repository.getDailyClosing(widget.closingId);
      if (!mounted) return;
      setState(() {
        _detail = detail;
        _loading = false;
      });
      unawaited(_loadRelated(detail));
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error;
        _loading = false;
      });
    }
  }

  Future<void> _loadRelated(DailyClosingDetail detail) async {
    setState(() {
      _relatedLoading = true;
      _relatedError = null;
    });
    try {
      final Map<String, dynamic> filters = <String, dynamic>{
        'branchId': detail.branchId,
        'from': detail.businessDate,
        'to': detail.businessDate,
        'perPage': 100,
      };
      final List<dynamic> results = await Future.wait<dynamic>(<Future<dynamic>>[
        _repository.getExpenses(filters: filters),
        _repository.getSupplierPayments(filters: filters),
      ]);
      if (!mounted) return;
      setState(() {
        _expenses = results[0] as List<ExpenseRecord>;
        _supplierPayments = results[1] as List<SupplierPayment>;
        _relatedLoading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _relatedError = error;
        _relatedLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) => Directionality(
    textDirection: TextDirection.rtl,
    child: DesktopPageLayout(
      padding: EdgeInsets.zero,
      child: FinanceShell(
        currentSection: 'الإغلاق اليومي',
        title: 'الإغلاق اليومي',
        subtitle: 'تفاصيل إغلاق اليوم التشغيلي',
        showContext: false,
        actions: <Widget>[
          IconButton(
            tooltip: 'العودة إلى الإغلاق اليومي',
            icon: const Icon(Icons.arrow_forward),
            onPressed: () => context.go(AppRoutes.financeDailyClosingCanonical),
          ),
        ],
        child: _buildBody(),
      ),
    ),
  );

  Widget _buildBody() {
    if (_loading) return const FinanceLoadingState(label: 'جارٍ تحميل الإغلاق اليومي…');
    if (_error != null) {
      return FinanceErrorState(message: 'تعذّر تحميل الإغلاق اليومي. $_error', onRetry: _load);
    }
    final DailyClosingDetail? detail = _detail;
    if (detail == null) return const FinanceErrorState(message: 'تعذّر إيجاد الإغلاق اليومي المطلوب.');

    final DailyClosingReadinessState state = dailyClosingReadinessState(detail.readiness, detail.warnings.length);
    final bool closed = detail.isClosed;

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          FinanceEntityHeader(
            title: detail.businessDate,
            reference: '${detail.branchName} · ${detail.reference}',
            actions: <Widget>[FinanceStatusBadgeCustom(label: dailyClosingReadinessLabel(state), tone: dailyClosingReadinessTone(state))],
          ),
          const SizedBox(height: FinanceSpace.lg),
          FinanceKpiGrid(
            items: <FinanceKpiData>[
              FinanceKpiData(label: 'صافي المبيعات', value: detail.sales.netSales),
              FinanceKpiData(label: 'المرتجعات', value: detail.sales.refunds, tone: FinanceTone.danger),
              FinanceKpiData(label: 'النقد المتوقع', value: detail.cash.expectedCash),
              FinanceKpiData(label: 'النقد الفعلي', value: detail.cash.actualCash ?? '—'),
              FinanceKpiData(
                label: 'فرق الصندوق',
                value: detail.cash.difference ?? '—',
                tone: detail.cash.differenceState == 'balanced' ? FinanceTone.success : FinanceTone.danger,
              ),
              FinanceKpiData(label: 'المصروفات المرتبطة', value: '${_expenses.length}'),
              FinanceKpiData(label: 'دفعات الموردين', value: '${_supplierPayments.length}'),
            ],
          ),
          const SizedBox(height: FinanceSpace.lg),
          if (closed)
            FinanceAlertBanner(
              tone: FinanceTone.success,
              message:
                  'تم إغلاق هذا اليوم في ${detail.closedAt ?? '—'} — صافي المبيعات ${detail.sales.netSales}، النقد المتوقع ${detail.cash.expectedCash}، الفعلي ${detail.cash.actualCash ?? '—'}، الفرق ${detail.cash.difference ?? '—'}.',
            )
          else
            _ReadinessPanel(detail: detail, state: state, onNavigate: (String path) => context.go(path)),
          const SizedBox(height: FinanceSpace.lg),
          if (!closed)
            Align(
              alignment: AlignmentDirectional.centerEnd,
              child: OutlinedButton.icon(
                onPressed: _updatingCash ? null : _openActualCashDialog,
                icon: const Icon(Icons.payments_outlined, size: 18),
                label: const Text('تحديث النقد الفعلي'),
              ),
            ),
          const SizedBox(height: FinanceSpace.md),
          _CashBreakdown(cash: detail.cash),
          const SizedBox(height: FinanceSpace.lg),
          Text('ملخص المبيعات', style: FinanceText.page),
          const SizedBox(height: FinanceSpace.sm),
          FinanceTable(
            headers: const <String>['الإجمالي', 'الخصومات', 'المرتجعات', 'صافي المبيعات'],
            minWidth: 700,
            rows: <List<Widget>>[
              <Widget>[
                FinanceAmount(value: detail.sales.grossSales),
                FinanceAmount(value: detail.sales.discounts),
                Text(
                  detail.sales.refunds,
                  style: FinanceText.body.copyWith(color: FinanceColors.danger),
                ),
                Text(detail.sales.netSales, style: FinanceText.body.copyWith(fontWeight: FontWeight.w700)),
              ],
            ],
          ),
          const SizedBox(height: FinanceSpace.lg),
          Text('توزيع طرق الدفع', style: FinanceText.page),
          const SizedBox(height: FinanceSpace.sm),
          _PaymentBreakdown(rows: detail.paymentBreakdown),
          const SizedBox(height: FinanceSpace.lg),
          Text('حالة التسويات', style: FinanceText.page),
          const SizedBox(height: FinanceSpace.sm),
          _ReconciliationStatus(
            reconciliation: detail.reconciliation,
            onOpen: () => context.go(AppRoutes.financeReconciliationCanonical),
          ),
          const SizedBox(height: FinanceSpace.lg),
          Text('المصروفات', style: FinanceText.page),
          const SizedBox(height: FinanceSpace.sm),
          _ExpensesSection(
            loading: _relatedLoading,
            error: _relatedError,
            expenses: _expenses,
            onRetry: () => _loadRelated(detail),
            onOpen: (ExpenseRecord e) => context.go('/finance/expenses?expenseId=${e.id}'),
          ),
          const SizedBox(height: FinanceSpace.lg),
          Text('دفعات الموردين', style: FinanceText.page),
          const SizedBox(height: FinanceSpace.sm),
          _SupplierPaymentsSection(
            loading: _relatedLoading,
            error: _relatedError,
            payments: _supplierPayments,
            onRetry: () => _loadRelated(detail),
            onOpen: (SupplierPayment p) => context.go('/finance/suppliers?paymentId=${p.id}'),
          ),
          const SizedBox(height: FinanceSpace.lg),
          Text('الأثر المالي للمخزون', style: FinanceText.page),
          const SizedBox(height: FinanceSpace.sm),
          _InventoryImpactSection(
            operations: detail.operations,
            issues: <DailyClosingIssue>[
              ...detail.blockers.where((DailyClosingIssue i) => i.code == 'UNPOSTED_INVENTORY_FINANCIAL_EVENT'),
              ...detail.warnings.where((DailyClosingIssue i) => i.code == 'UNPOSTED_INVENTORY_FINANCIAL_EVENT'),
            ],
            onOpenInventory: () => context.go('/inventory/movements'),
          ),
          if (closed && detail.lateActivity.isNotEmpty) ...<Widget>[
            const SizedBox(height: FinanceSpace.lg),
            Text('نشاط بعد الإغلاق', style: FinanceText.page),
            const SizedBox(height: FinanceSpace.sm),
            FinanceAlertBanner(tone: FinanceTone.warning, message: 'تم تسجيل نشاط مالي بعد الإغلاق'),
            const SizedBox(height: FinanceSpace.sm),
            _LateActivityTable(items: detail.lateActivity, onOpenJournal: _openJournalDrawer),
          ],
          const SizedBox(height: FinanceSpace.xl),
          if (!closed)
            _CloseOperationalBar(
              detail: detail,
              closing: _closing,
              onClose: _confirmClose,
            )
          else
            const _ClosedNotice(),
          const SizedBox(height: FinanceSpace.xl),
        ],
      ),
    );
  }

  Future<void> _openActualCashDialog() async {
    final DailyClosingDetail? detail = _detail;
    if (detail == null) return;
    final String? value = await showDialog<String>(
      context: context,
      builder: (BuildContext dialog) => _ActualCashDialog(expectedCash: detail.cash.expectedCash),
    );
    if (value == null) return;
    setState(() => _updatingCash = true);
    try {
      final DailyClosingDetail updated = await _repository.updateDailyClosing(widget.closingId, <String, dynamic>{
        'actualCash': value,
      });
      if (!mounted) return;
      setState(() {
        _detail = updated;
        _updatingCash = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() => _updatingCash = false);
      _showError('تعذّر تحديث النقد الفعلي: $error');
    }
  }

  Future<void> _confirmClose() async {
    if (_closing) return;
    await _load();
    if (!mounted) return;
    final DailyClosingDetail? detail = _detail;
    if (detail == null || detail.isClosed) return;
    if (!detail.canClose) {
      _showError('لا يمكن إغلاق اليوم — يوجد حاجز يجب حسمه أولاً.');
      return;
    }
    final bool hasWarnings = detail.warnings.isNotEmpty;
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext dialog) => AlertDialog(
        title: const Text('إغلاق اليوم'),
        content: Text(
          hasWarnings
              ? 'يمكن إغلاق اليوم مع وجود تحذيرات غير حاجبة. بعد الإغلاق تصبح اللقطة للقراءة فقط ولا يمكن التراجع.'
              : 'كل الفحوصات جاهزة. بعد الإغلاق تصبح اللقطة للقراءة فقط ولا يمكن التراجع.',
        ),
        actions: <Widget>[
          TextButton(onPressed: () => Navigator.pop(dialog, false), child: const Text('إلغاء')),
          ElevatedButton(
            onPressed: () => Navigator.pop(dialog, true),
            style: ElevatedButton.styleFrom(backgroundColor: FinanceColors.primary, foregroundColor: Colors.white),
            child: const Text('تأكيد الإغلاق'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() => _closing = true);
    try {
      final DailyClosingDetail closed = await _repository.closeDailyClosing(widget.closingId, const <String, dynamic>{});
      if (!mounted) return;
      setState(() {
        _detail = closed;
        _closing = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() => _closing = false);
      _showError('تعذّر إغلاق اليوم: $error');
    }
  }

  void _openJournalDrawer(int journalId) {
    showGeneralDialog<void>(
      context: context,
      barrierLabel: 'إغلاق',
      barrierDismissible: true,
      barrierColor: Colors.black.withValues(alpha: 0.35),
      transitionDuration: const Duration(milliseconds: 220),
      pageBuilder: (BuildContext dialogContext, _, _) => Align(
        alignment: AlignmentDirectional.centerEnd,
        child: FinanceJournalDrawer(
          child: FinanceJournalDrawerBody(
            loader: () => _repository.getFinanceMap('finance/transactions/$journalId'),
            onNavigate: (String path) {
              Navigator.of(dialogContext).pop();
              context.go(path);
            },
          ),
        ),
      ),
      transitionBuilder: (BuildContext context, Animation<double> animation, _, Widget child) => SlideTransition(
        position: Tween<Offset>(begin: const Offset(1, 0), end: Offset.zero).animate(animation),
        child: child,
      ),
    );
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }
}

class _ReadinessPanel extends StatelessWidget {
  const _ReadinessPanel({required this.detail, required this.state, required this.onNavigate});
  final DailyClosingDetail detail;
  final DailyClosingReadinessState state;
  final ValueChanged<String> onNavigate;

  @override
  Widget build(BuildContext context) {
    final colors = financeTone(dailyClosingReadinessTone(state));
    return Container(
      padding: const EdgeInsets.all(FinanceSpace.lg),
      decoration: BoxDecoration(
        color: colors.background,
        border: Border.all(color: colors.border),
        borderRadius: BorderRadius.circular(FinanceRadius.card),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            state == DailyClosingReadinessState.blocked
                ? 'محظورة عن الإغلاق'
                : state == DailyClosingReadinessState.warning
                ? 'جاهزة مع وجود تحذيرات'
                : 'جاهزة للإغلاق',
            style: FinanceText.body.copyWith(fontWeight: FontWeight.w700, color: colors.foreground),
          ),
          if (detail.blockers.isNotEmpty) ...<Widget>[
            const SizedBox(height: FinanceSpace.sm),
            ...detail.blockers.map((DailyClosingIssue issue) => _IssueRow(issue: issue, onNavigate: onNavigate)),
          ],
          if (detail.warnings.isNotEmpty) ...<Widget>[
            const SizedBox(height: FinanceSpace.sm),
            ...detail.warnings.map((DailyClosingIssue issue) => _IssueRow(issue: issue, onNavigate: onNavigate)),
          ],
        ],
      ),
    );
  }
}

class _IssueRow extends StatelessWidget {
  const _IssueRow({required this.issue, required this.onNavigate});
  final DailyClosingIssue issue;
  final ValueChanged<String> onNavigate;

  @override
  Widget build(BuildContext context) {
    final String? route = dailyClosingIssueRoute(issue);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Expanded(child: Text('• ${dailyClosingIssueLabel(issue)}', style: FinanceText.small)),
          if (route != null)
            TextButton(onPressed: () => onNavigate(route), child: const Text('عرض')),
        ],
      ),
    );
  }
}

class _CashBreakdown extends StatelessWidget {
  const _CashBreakdown({required this.cash});
  final DailyClosingCashFigures cash;

  @override
  Widget build(BuildContext context) => FinanceInfoGrid(
    items: <FinanceInfoItem>[
      FinanceInfoItem('الرصيد الافتتاحي', cash.openingCash),
      FinanceInfoItem('+ مبيعات نقدية', cash.cashSales),
      FinanceInfoItem('- مرتجعات نقدية', cash.cashRefunds),
      FinanceInfoItem('- مصروفات نقدية', cash.expensesCash),
      FinanceInfoItem('- دفعات موردين نقدية', cash.supplierPaymentsCash),
      FinanceInfoItem('- تحويلات خارجة', cash.transfersOut),
      FinanceInfoItem('+ تحويلات داخلة', cash.transfersIn),
      FinanceInfoItem('= النقد المتوقع', cash.expectedCash),
    ],
  );
}

class _PaymentBreakdown extends StatelessWidget {
  const _PaymentBreakdown({required this.rows});
  final List<Map<String, dynamic>> rows;

  @override
  Widget build(BuildContext context) {
    if (rows.isEmpty) {
      return const FinanceEmptyState(message: 'لا توجد مدفوعات مسجّلة لهذا اليوم');
    }
    return FinanceTable(
      headers: const <String>['طريقة الدفع', 'الإجمالي', 'المرتجع', 'الصافي'],
      minWidth: 700,
      rows: rows
          .map(
            (Map<String, dynamic> row) => <Widget>[
              Text('${row['method'] ?? '—'}', style: FinanceText.body.copyWith(fontWeight: FontWeight.w600)),
              FinanceAmount(value: '${row['gross'] ?? '0.00'}'),
              Text('${row['refunded'] ?? '0.00'}', style: FinanceText.body.copyWith(color: FinanceColors.danger)),
              Text(
                '${row['net'] ?? '0.00'}',
                style: FinanceText.body.copyWith(fontWeight: FontWeight.w700),
              ),
            ],
          )
          .toList(),
    );
  }
}

class _ReconciliationStatus extends StatelessWidget {
  const _ReconciliationStatus({required this.reconciliation, required this.onOpen});
  final DailyClosingReconciliationSummary reconciliation;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    if (!reconciliation.required_) {
      return const FinanceEmptyState(message: 'لا توجد تسويات مطلوبة لهذا اليوم.');
    }
    return Container(
      padding: const EdgeInsets.all(FinanceSpace.lg),
      decoration: BoxDecoration(
        color: FinanceColors.card,
        border: Border.all(color: FinanceColors.border),
        borderRadius: BorderRadius.circular(FinanceRadius.card),
      ),
      child: Row(
        children: <Widget>[
          Expanded(
            child: Text(
              reconciliation.complete
                  ? 'تمت تسوية جميع الحسابات المطلوبة لهذا اليوم (${reconciliation.completedCount}/${reconciliation.requiredCount}).'
                  : 'يوجد ${reconciliation.unresolvedCount} حساب بحاجة تسوية من أصل ${reconciliation.requiredCount}.',
              style: FinanceText.body,
            ),
          ),
          OutlinedButton(onPressed: onOpen, child: const Text('مراجعة التسويات')),
        ],
      ),
    );
  }
}

class _ExpensesSection extends StatelessWidget {
  const _ExpensesSection({
    required this.loading,
    required this.error,
    required this.expenses,
    required this.onRetry,
    required this.onOpen,
  });
  final bool loading;
  final Object? error;
  final List<ExpenseRecord> expenses;
  final VoidCallback onRetry;
  final ValueChanged<ExpenseRecord> onOpen;

  @override
  Widget build(BuildContext context) {
    if (loading) return const SizedBox(height: 96, child: FinanceLoadingState(label: 'جارٍ تحميل المصروفات…'));
    if (error != null) return FinanceErrorState(message: 'تعذّر تحميل المصروفات.', onRetry: onRetry);
    if (expenses.isEmpty) return const FinanceEmptyState(message: 'لا توجد مصروفات مرتبطة بهذا اليوم.');
    return FinanceTable(
      headers: const <String>['المرجع', 'الوصف', 'الفئة', 'المبلغ', 'الحالة'],
      minWidth: 900,
      onRowTap: (int index) => onOpen(expenses[index]),
      rows: expenses
          .map(
            (ExpenseRecord e) => <Widget>[
              FinanceReference(reference: e.expenseNumber),
              Text(e.description, style: FinanceText.body),
              Text(e.expenseCategoryName, style: FinanceText.body),
              FinanceAmount(value: e.totalAmount),
              FinanceStatusBadge(status: e.status),
            ],
          )
          .toList(),
    );
  }
}

class _SupplierPaymentsSection extends StatelessWidget {
  const _SupplierPaymentsSection({
    required this.loading,
    required this.error,
    required this.payments,
    required this.onRetry,
    required this.onOpen,
  });
  final bool loading;
  final Object? error;
  final List<SupplierPayment> payments;
  final VoidCallback onRetry;
  final ValueChanged<SupplierPayment> onOpen;

  @override
  Widget build(BuildContext context) {
    if (loading) return const SizedBox(height: 96, child: FinanceLoadingState(label: 'جارٍ تحميل دفعات الموردين…'));
    if (error != null) return FinanceErrorState(message: 'تعذّر تحميل دفعات الموردين.', onRetry: onRetry);
    if (payments.isEmpty) return const FinanceEmptyState(message: 'لا توجد دفعات موردين مرتبطة بهذا اليوم.');
    return FinanceTable(
      headers: const <String>['المورد', 'المرجع', 'المبلغ', 'مصدر الدفع'],
      minWidth: 800,
      onRowTap: (int index) => onOpen(payments[index]),
      rows: payments
          .map(
            (SupplierPayment p) => <Widget>[
              Text(p.supplierName, style: FinanceText.body.copyWith(fontWeight: FontWeight.w600)),
              FinanceReference(reference: p.paymentNumber),
              FinanceAmount(value: p.amount),
              Text(p.financialLocationName, style: FinanceText.body),
            ],
          )
          .toList(),
    );
  }
}

class _InventoryImpactSection extends StatelessWidget {
  const _InventoryImpactSection({required this.operations, required this.issues, required this.onOpenInventory});
  final DailyClosingOperations operations;
  final List<DailyClosingIssue> issues;
  final VoidCallback onOpenInventory;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: <Widget>[
      FinanceInfoGrid(
        items: <FinanceInfoItem>[
          FinanceInfoItem('قيمة الهدر', operations.wasteValue),
          FinanceInfoItem('عجز الجرد', operations.stockShortageValue),
          FinanceInfoItem('فائض الجرد', operations.stockSurplusValue),
        ],
      ),
      if (issues.isNotEmpty) ...<Widget>[
        const SizedBox(height: FinanceSpace.md),
        FinanceTable(
          headers: const <String>['الصنف', 'النوع', 'المبلغ', 'حالة الترحيل'],
          minWidth: 800,
          onRowTap: (int _) => onOpenInventory(),
          rows: issues
              .map(
                (DailyClosingIssue issue) => <Widget>[
                  Text('${issue.raw['item'] ?? '—'}', style: FinanceText.body),
                  Text('${issue.raw['type'] ?? '—'}', style: FinanceText.body),
                  FinanceAmount(value: '${issue.raw['amount'] ?? '0.00'}'),
                  FinanceStatusBadgeCustom(
                    label: '${issue.raw['financeStatus'] ?? '—'}',
                    tone: FinanceTone.danger,
                  ),
                ],
              )
              .toList(),
        ),
      ],
    ],
  );
}

class _LateActivityTable extends StatelessWidget {
  const _LateActivityTable({required this.items, required this.onOpenJournal});
  final List<DailyClosingLateActivity> items;
  final ValueChanged<int> onOpenJournal;

  @override
  Widget build(BuildContext context) => FinanceTable(
    headers: const <String>['المرجع', 'المصدر', 'المبلغ', 'وقت الترحيل'],
    minWidth: 800,
    onRowTap: (int index) => onOpenJournal(items[index].journalId),
    rows: items
        .map(
          (DailyClosingLateActivity item) => <Widget>[
            FinanceReference(reference: item.reference),
            Text(item.sourceType ?? '—', style: FinanceText.body),
            FinanceAmount(value: item.amount ?? '0.00'),
            Text(item.postedAt, style: FinanceText.body),
          ],
        )
        .toList(),
  );
}

class _CloseOperationalBar extends StatelessWidget {
  const _CloseOperationalBar({required this.detail, required this.closing, required this.onClose});
  final DailyClosingDetail detail;
  final bool closing;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) => Wrap(
    spacing: FinanceSpace.sm,
    runSpacing: FinanceSpace.sm,
    crossAxisAlignment: WrapCrossAlignment.center,
    children: <Widget>[
      Text(
        detail.canClose
            ? (detail.warnings.isNotEmpty ? 'يمكن إغلاق اليوم مع وجود تحذيرات غير حاجبة.' : 'كل الفحوصات جاهزة — يمكن إغلاق اليوم.')
            : 'لا يمكن إغلاق اليوم — يوجد حاجز يجب حسمه أعلاه.',
        style: FinanceText.body,
      ),
      ElevatedButton(
        onPressed: detail.canClose && !closing ? onClose : null,
        style: ElevatedButton.styleFrom(backgroundColor: FinanceColors.primary, foregroundColor: Colors.white),
        child: closing
            ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
            : const Text('إغلاق اليوم'),
      ),
    ],
  );
}

class _ClosedNotice extends StatelessWidget {
  const _ClosedNotice();
  @override
  Widget build(BuildContext context) => const FinanceAlertBanner(
    tone: FinanceTone.neutral,
    message: 'هذا الإغلاق مغلق — اللقطة للقراءة فقط ولا يمكن تعديل أي قيمة فيها.',
  );
}

class _ActualCashDialog extends StatefulWidget {
  const _ActualCashDialog({required this.expectedCash});
  final String expectedCash;
  @override
  State<_ActualCashDialog> createState() => _ActualCashDialogState();
}

class _ActualCashDialogState extends State<_ActualCashDialog> {
  final TextEditingController _controller = TextEditingController();
  String? _error;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  double get _expected => double.tryParse(widget.expectedCash.replaceAll(',', '')) ?? 0;
  double? get _actual => double.tryParse(_controller.text.trim());

  void _submit() {
    if (!RegExp(r'^\d+(?:\.\d{1,2})?$').hasMatch(_controller.text.trim())) {
      setState(() => _error = 'أدخل مبلغاً صالحاً.');
      return;
    }
    Navigator.pop(context, _controller.text.trim());
  }

  @override
  Widget build(BuildContext context) {
    final double? actual = _actual;
    final double? diff = actual == null ? null : actual - _expected;
    return FinanceDialogShell(
      title: 'تحديث النقد الفعلي',
      actions: <Widget>[
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('إلغاء')),
        ElevatedButton(
          onPressed: _submit,
          style: ElevatedButton.styleFrom(backgroundColor: FinanceColors.primary, foregroundColor: Colors.white),
          child: const Text('حفظ'),
        ),
      ],
      child: SizedBox(
        width: 360,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            InputDecorator(
              decoration: const InputDecoration(labelText: 'النقد المتوقع'),
              child: Text(widget.expectedCash),
            ),
            const SizedBox(height: FinanceSpace.md),
            TextField(
              controller: _controller,
              autofocus: true,
              onChanged: (_) => setState(() {}),
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(labelText: 'النقد الفعلي'),
            ),
            if (diff != null) ...<Widget>[
              const SizedBox(height: FinanceSpace.sm),
              Text(
                'الفرق المتوقع (لأغراض العرض فقط): ${diff.toStringAsFixed(2)}',
                style: FinanceText.small.copyWith(
                  color: diff.abs() < 0.005 ? FinanceColors.success : FinanceColors.danger,
                ),
              ),
            ],
            if (_error != null) ...<Widget>[
              const SizedBox(height: FinanceSpace.sm),
              Text(_error!, style: const TextStyle(color: FinanceColors.danger)),
            ],
          ],
        ),
      ),
    );
  }
}

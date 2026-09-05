import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/services/service_locator.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../shared/layouts/desktop_page_layout.dart';
import '../models/finance_setup_models.dart';
import '../repositories/finance_setup_repository.dart';
import '../widgets/finance_components.dart';
import '../widgets/finance_design.dart';
import '../widgets/finance_journal_drawer.dart';
import '../widgets/finance_pagination.dart';
import '../widgets/finance_period.dart';
import '../widgets/finance_shell.dart';

/// Local, screen-only filters. Kept separate from the global period/branch
/// context so clearing them never resets the shared Finance context.
class ExpenseFilters {
  const ExpenseFilters({this.status, this.categoryId, this.search});
  final String? status;
  final int? categoryId;
  final String? search;

  bool get isEmpty =>
      status == null && categoryId == null && (search == null || search!.isEmpty);
}

class ExpensesQuery {
  const ExpensesQuery({
    required this.dateFrom,
    required this.dateTo,
    this.branchId,
    this.filters = const ExpenseFilters(),
    this.page = 1,
  });
  final DateTime dateFrom;
  final DateTime dateTo;
  final int? branchId;
  final ExpenseFilters filters;
  final int page;

  Map<String, dynamic> get parameters => <String, dynamic>{
    'from': FinancePeriod.format(dateFrom),
    'to': FinancePeriod.format(dateTo),
    if (branchId != null) 'branchId': branchId,
    if (filters.status != null) 'status': filters.status,
    if (filters.categoryId != null) 'expenseCategoryId': filters.categoryId,
    if (filters.search != null && filters.search!.isNotEmpty)
      'search': filters.search,
    'page': page,
    'perPage': 10,
  };
}

const Map<String, String> _kStatusLabels = <String, String>{
  'draft': 'مسودة',
  'pending_approval': 'بانتظار الموافقة',
  'approved': 'معتمد',
  'paid': 'مدفوع',
  'rejected': 'مرفوض',
  'reversed': 'معكوس',
};

/// Canonical Financial Expenses screen (`/finance/expenses`). Laravel
/// supplies every summary total, filtered page, allowed-action list, and
/// journal detail; this widget only presents that already-authorized
/// payload and basic form validation — it never computes totals, decides
/// which lifecycle transitions are valid, or posts accounting entries.
class ExpensesScreen extends StatefulWidget {
  const ExpensesScreen({super.key});
  @override
  State<ExpensesScreen> createState() => _ExpensesScreenState();
}

class _ExpensesScreenState extends State<ExpensesScreen> {
  late final FinanceSetupRepository _repository;

  late DateTime _dateFrom;
  late DateTime _dateTo;
  int? _branchId;
  ExpenseFilters _filters = const ExpenseFilters();
  int _page = 1;
  final TextEditingController _searchController = TextEditingController();
  Timer? _debounce;

  int _requestId = 0;
  Map<String, dynamic>? _summary;
  FinancePage<ExpenseRecord>? _pageData;
  Object? _error;
  bool _loading = false;
  bool _consumedExpenseIdQuery = false;

  List<FinanceBranchOption> _branches = const <FinanceBranchOption>[];
  List<ExpenseCategory> _categories = const <ExpenseCategory>[];

  @override
  void initState() {
    super.initState();
    _repository = serviceLocator<FinanceSetupRepository>();
    final DateTime today = DateUtils.dateOnly(DateTime.now());
    _dateFrom = DateTime(today.year, today.month);
    _dateTo = today;
    _load();
    _repository.getFinanceMap('finance/expenses/branches').then((
      Map<String, dynamic> response,
    ) {
      if (!mounted) return;
      setState(
        () => _branches = _list(response['branches'])
            .map(
              (Map<String, dynamic> row) => FinanceBranchOption(
                id: _int(row['id']),
                name: '${row['name'] ?? ''}',
              ),
            )
            .toList(growable: false),
      );
    });
    _repository.getExpenseCategories().then((List<ExpenseCategory> categories) {
      if (!mounted) return;
      setState(() => _categories = categories);
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_consumedExpenseIdQuery) return;
    _consumedExpenseIdQuery = true;
    // Only present when this screen is mounted under a GoRouter route (as
    // it always is in production); widget tests that render it standalone
    // must not crash for lacking that ancestor.
    if (GoRouter.maybeOf(context) == null) return;
    final String? raw = GoRouterState.of(context).uri.queryParameters['expenseId'];
    final int? id = raw == null ? null : int.tryParse(raw);
    if (id != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _openDetailById(id);
      });
    }
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  ExpensesQuery get _query => ExpensesQuery(
    dateFrom: _dateFrom,
    dateTo: _dateTo,
    branchId: _branchId,
    filters: _filters,
    page: _page,
  );

  Future<void> _load() async {
    final int requestId = ++_requestId;
    setState(() => _loading = true);
    try {
      final List<dynamic> results = await Future.wait<dynamic>(<Future<dynamic>>[
        _repository.getFinanceMap(
          'finance/expenses/summary',
          queryParameters: _query.parameters,
        ),
        _repository.getFinancePage(
          'finance/expenses',
          queryParameters: _query.parameters,
        ),
      ]);
      if (!mounted || requestId != _requestId) return;
      final FinancePage<Map<String, dynamic>> raw =
          results[1] as FinancePage<Map<String, dynamic>>;
      setState(() {
        _summary = results[0] as Map<String, dynamic>;
        _pageData = FinancePage<ExpenseRecord>(
          items: raw.items.map(ExpenseRecord.fromJson).toList(growable: false),
          meta: raw.meta,
        );
        _error = null;
        _loading = false;
      });
    } catch (error) {
      if (!mounted || requestId != _requestId) return;
      setState(() {
        _error = error;
        _loading = false;
      });
    }
  }

  Future<void> _applyPeriod(String period) async {
    if (period == 'مخصص') {
      final DateTimeRange? range = await showDateRangePicker(
        context: context,
        firstDate: DateTime(2020),
        lastDate: DateTime(_dateTo.year + 1),
        initialDateRange: DateTimeRange(start: _dateFrom, end: _dateTo),
        helpText: 'اختيار فترة مالية',
      );
      if (range == null || !mounted) return;
      setState(() {
        _dateFrom = range.start;
        _dateTo = range.end;
        _page = 1;
      });
      _load();
      return;
    }
    final DateTimeRange range = FinancePeriod.presetRange(period);
    setState(() {
      _dateFrom = range.start;
      _dateTo = range.end;
      _page = 1;
    });
    _load();
  }

  void _applyBranch(int? branchId) {
    setState(() {
      _branchId = branchId;
      _page = 1;
    });
    _load();
  }

  void _applyFilters(ExpenseFilters next) {
    setState(() {
      _filters = next;
      _page = 1;
    });
    _load();
  }

  void _onSearchChanged(String value) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 400), () {
      if (!mounted) return;
      _applyFilters(
        ExpenseFilters(
          status: _filters.status,
          categoryId: _filters.categoryId,
          search: value.trim().isEmpty ? null : value.trim(),
        ),
      );
    });
  }

  void _clearFilters() {
    _debounce?.cancel();
    _searchController.clear();
    _applyFilters(const ExpenseFilters());
  }

  void _changePage(int page) {
    setState(() => _page = page);
    _load();
  }

  Future<void> _openDetailById(int id) async {
    try {
      final ExpenseRecord record = await _repository.getExpense(id);
      if (mounted) _openDetail(record);
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('$error')));
      }
    }
  }

  Future<void> _openDetail(ExpenseRecord record) async {
    await showDialog<void>(
      context: context,
      builder: (BuildContext dialog) => _ExpenseDetailDialog(
        expense: record,
        categories: _categories,
        reload: () => _repository.getExpense(record.id),
        onOpenJournal: _openJournalDrawer,
        onAfterMutation: _load,
        onEdit: (ExpenseRecord current) {
          Navigator.of(dialog).pop();
          _openExpenseForm(current);
        },
      ),
    );
  }

  Future<void> _openExpenseForm([ExpenseRecord? current]) async {
    final bool? saved = await showDialog<bool>(
      context: context,
      builder: (BuildContext dialog) => _ExpenseFormDialog(
        current: current,
        categories: _categories,
        branches: _branches,
        onSubmit: (Map<String, dynamic> payload) => _repository.saveExpense(
          payload,
          id: current?.id,
        ),
      ),
    );
    if (saved == true) await _load();
  }

  void _openJournalDrawer(int journalEntryId) {
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
            loader: () =>
                _repository.getFinanceMap('finance/transactions/$journalEntryId'),
            onNavigate: (String path) {
              Navigator.of(dialogContext).pop();
              context.go(path);
            },
          ),
        ),
      ),
      transitionBuilder:
          (
            BuildContext context,
            Animation<double> animation,
            _,
            Widget child,
          ) => SlideTransition(
            position:
                Tween<Offset>(
                  begin: const Offset(1, 0),
                  end: Offset.zero,
                ).animate(
                  CurvedAnimation(parent: animation, curve: Curves.easeOutCubic),
                ),
            child: child,
          ),
    );
  }

  @override
  Widget build(BuildContext context) => Directionality(
    textDirection: TextDirection.rtl,
    child: DesktopPageLayout(
      padding: EdgeInsets.zero,
      child: FinanceShell(
        currentSection: 'المصروفات',
        title: 'المصروفات',
        subtitle: 'تسجيل ومتابعة اعتماد المصروفات التشغيلية',
        showContext: false,
        actions: <Widget>[
          ElevatedButton.icon(
            onPressed: _categories.any((ExpenseCategory c) => c.isActive)
                ? () => _openExpenseForm()
                : null,
            style: ElevatedButton.styleFrom(
              minimumSize: const Size(0, 36),
              backgroundColor: FinanceColors.primary,
              foregroundColor: Colors.white,
              disabledBackgroundColor: FinanceColors.disabled,
            ),
            icon: const Icon(Icons.add, size: 18),
            label: const Text('إضافة مصروف'),
          ),
        ],
        child: _buildBody(),
      ),
    ),
  );

  Widget _buildBody() {
    if (_pageData == null && _error == null) {
      return const FinanceLoadingState(label: 'جارٍ تحميل المصروفات…');
    }
    if (_pageData == null) {
      return FinanceErrorState(
        message: 'تعذّر تحميل المصروفات. لم يتم اعتبار الخطأ صفراً.',
        onRetry: _load,
      );
    }
    final FinancePage<ExpenseRecord> page = _pageData!;
    return SingleChildScrollView(
      child: Opacity(
        opacity: _loading ? 0.6 : 1,
        child: IgnorePointer(
          ignoring: _loading,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              FinanceGlobalContext(
                selectedPeriod: FinancePeriod.labelFor(_dateFrom, _dateTo),
                onPeriod: _applyPeriod,
                branches: _branches,
                selectedBranchId: _branchId,
                onBranch: _applyBranch,
                showCompare: false,
              ),
              const SizedBox(height: FinanceSpace.lg),
              _SummaryGrid(summary: _summary ?? const <String, dynamic>{}),
              const SizedBox(height: FinanceSpace.lg),
              FinanceFilterBar(
                onReset: _filters.isEmpty ? null : _clearFilters,
                children: <Widget>[
                  _FilterDropdown<String>(
                    label: 'الحالة',
                    value: _filters.status,
                    items: _kStatusLabels.entries
                        .map(
                          (MapEntry<String, String> e) => DropdownMenuItem<String>(
                            value: e.key,
                            child: Text(e.value),
                          ),
                        )
                        .toList(),
                    onChanged: (String? v) => _applyFilters(
                      ExpenseFilters(
                        status: v,
                        categoryId: _filters.categoryId,
                        search: _filters.search,
                      ),
                    ),
                  ),
                  _FilterDropdown<int>(
                    label: 'الفئة',
                    value: _filters.categoryId,
                    items: _categories
                        .map(
                          (ExpenseCategory c) => DropdownMenuItem<int>(
                            value: c.id,
                            child: Text(c.name),
                          ),
                        )
                        .toList(),
                    onChanged: (int? v) => _applyFilters(
                      ExpenseFilters(
                        status: _filters.status,
                        categoryId: v,
                        search: _filters.search,
                      ),
                    ),
                  ),
                  SizedBox(
                    width: 240,
                    height: 34,
                    child: TextField(
                      controller: _searchController,
                      onChanged: _onSearchChanged,
                      style: FinanceText.body,
                      decoration: InputDecoration(
                        isDense: true,
                        hintText: 'بحث بالوصف أو المرجع…',
                        prefixIcon: const Icon(Icons.search, size: 18),
                        filled: true,
                        fillColor: FinanceColors.workspace,
                        contentPadding: const EdgeInsets.symmetric(vertical: 6),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(
                            FinanceRadius.control,
                          ),
                          borderSide: const BorderSide(color: FinanceColors.border),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: FinanceSpace.lg),
              if (_error != null) ...<Widget>[
                FinanceAlertBanner(
                  message: 'تعذّر تحديث المصروفات لهذه الفلاتر. تُعرض آخر بيانات محمّلة.',
                  tone: FinanceTone.warning,
                  action: TextButton(onPressed: _load, child: const Text('إعادة المحاولة')),
                ),
                const SizedBox(height: FinanceSpace.md),
              ],
              if (page.items.isEmpty)
                SizedBox(
                  height: 220,
                  child: FinanceEmptyState(
                    message: _filters.isEmpty
                        ? 'لا توجد مصروفات مسجلة للفترة المحددة'
                        : 'لا توجد مصروفات مطابقة للفلاتر المحددة',
                    action: _filters.isEmpty
                        ? null
                        : TextButton(
                            onPressed: _clearFilters,
                            child: const Text('إعادة تعيين الفلاتر'),
                          ),
                  ),
                )
              else ...<Widget>[
                _ExpensesTable(rows: page.items, onOpen: _openDetail),
                FinancePagination(meta: page.meta, onPageChanged: _changePage),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _SummaryGrid extends StatelessWidget {
  const _SummaryGrid({required this.summary});
  final Map<String, dynamic> summary;

  @override
  Widget build(BuildContext context) => FinanceKpiGrid(
    items: <FinanceKpiData>[
      FinanceKpiData(
        label: 'إجمالي المصروفات',
        value: _money(summary['totalAmount']),
        icon: Icons.receipt_long_outlined,
      ),
      FinanceKpiData(
        label: 'بانتظار الموافقة',
        value: _money(summary['pendingApprovalAmount']),
        icon: Icons.pending_actions_outlined,
        tone: FinanceTone.warning,
      ),
      FinanceKpiData(
        label: 'مرفوضة',
        value: _money(summary['rejectedAmount']),
        icon: Icons.block_outlined,
        tone: FinanceTone.danger,
      ),
      FinanceKpiData(
        label: 'متوسط المصروف',
        value: _money(summary['averageAmount']),
        icon: Icons.calculate_outlined,
      ),
    ],
  );
}

class _FilterDropdown<T> extends StatelessWidget {
  const _FilterDropdown({
    required this.label,
    required this.value,
    required this.items,
    required this.onChanged,
  });
  final String label;
  final T? value;
  final List<DropdownMenuItem<T>> items;
  final ValueChanged<T?> onChanged;

  @override
  Widget build(BuildContext context) => Container(
    height: 34,
    constraints: const BoxConstraints(minWidth: 150),
    padding: const EdgeInsetsDirectional.only(start: FinanceSpace.sm),
    decoration: BoxDecoration(
      color: FinanceColors.workspace,
      border: Border.all(color: FinanceColors.border),
      borderRadius: BorderRadius.circular(FinanceRadius.control),
    ),
    child: DropdownButtonHideUnderline(
      child: DropdownButton<T>(
        value: value,
        hint: Text(label, style: FinanceText.small),
        icon: const Icon(Icons.keyboard_arrow_down, size: 18),
        style: FinanceText.body,
        isDense: true,
        onChanged: onChanged,
        items: <DropdownMenuItem<T>>[
          DropdownMenuItem<T>(value: null, child: Text('$label: الكل')),
          ...items,
        ],
      ),
    ),
  );
}

class _ExpensesTable extends StatelessWidget {
  const _ExpensesTable({required this.rows, required this.onOpen});
  final List<ExpenseRecord> rows;
  final ValueChanged<ExpenseRecord> onOpen;

  @override
  Widget build(BuildContext context) => FinanceTable(
    headers: const <String>[
      'التاريخ',
      'المرجع',
      'الوصف',
      'الفئة',
      'الفرع',
      'المبلغ',
      'الحالة',
    ],
    minWidth: 1080,
    onRowTap: (int index) => onOpen(rows[index]),
    rows: rows
        .map(
          (ExpenseRecord e) => <Widget>[
            Text(e.expenseDate, style: FinanceText.small),
            FinanceReference(reference: e.expenseNumber),
            Text(e.description, style: FinanceText.body),
            Text(e.expenseCategoryName, style: FinanceText.small),
            Text(e.branchName ?? 'عام', style: FinanceText.small),
            FinanceAmount(value: e.totalAmount),
            FinanceStatusBadge(status: e.status),
          ],
        )
        .toList(),
  );
}

/// Backend-computed transitions, mapped to the Claude action labels. The
/// key set is deliberately small and closed — an unrecognized action string
/// from a future backend change simply renders no button rather than
/// guessing at a label/handler for it.
class _ExpenseDetailDialog extends StatefulWidget {
  const _ExpenseDetailDialog({
    required this.expense,
    required this.categories,
    required this.reload,
    required this.onOpenJournal,
    required this.onAfterMutation,
    required this.onEdit,
  });
  final ExpenseRecord expense;
  final List<ExpenseCategory> categories;
  final Future<ExpenseRecord> Function() reload;
  final ValueChanged<int> onOpenJournal;
  final VoidCallback onAfterMutation;
  final ValueChanged<ExpenseRecord> onEdit;

  @override
  State<_ExpenseDetailDialog> createState() => _ExpenseDetailDialogState();
}

class _ExpenseDetailDialogState extends State<_ExpenseDetailDialog> {
  late ExpenseRecord _expense;
  bool _busy = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _expense = widget.expense;
  }

  Future<void> _refresh() async {
    try {
      final ExpenseRecord fresh = await widget.reload();
      if (mounted) setState(() => _expense = fresh);
      widget.onAfterMutation();
    } catch (_) {
      // The dialog keeps showing the last known state; the list refresh
      // (triggered separately) will surface any persistent failure.
    }
  }

  Future<void> _run(Future<void> Function() action) async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await action();
      await _refresh();
    } catch (error) {
      if (mounted) {
        setState(() {
          _error = '$error';
          _busy = false;
        });
      }
      return;
    }
    if (mounted) setState(() => _busy = false);
  }

  Future<void> _submit() => _run(
    () => serviceLocator<FinanceSetupRepository>().expenseAction(
      _expense.id,
      'submit',
    ),
  );
  Future<void> _approve() => _run(
    () => serviceLocator<FinanceSetupRepository>().expenseAction(
      _expense.id,
      'approve',
    ),
  );
  Future<void> _reverse() => _run(
    () => serviceLocator<FinanceSetupRepository>().expenseAction(
      _expense.id,
      'reverse',
    ),
  );

  Future<void> _reject() async {
    final TextEditingController reason = TextEditingController();
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext dialog) => StatefulBuilder(
        builder: (BuildContext context, StateSetter setDialogState) => AlertDialog(
          title: const Text('رفض المصروف'),
          content: TextField(
            controller: reason,
            autofocus: true,
            onChanged: (_) => setDialogState(() {}),
            decoration: const InputDecoration(labelText: 'سبب الرفض'),
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.pop(dialog, false),
              child: const Text('إلغاء'),
            ),
            TextButton(
              onPressed: reason.text.trim().isEmpty
                  ? null
                  : () => Navigator.pop(dialog, true),
              child: const Text('رفض'),
            ),
          ],
        ),
      ),
    );
    if (confirmed != true) return;
    await _run(
      () => serviceLocator<FinanceSetupRepository>().expenseAction(
        _expense.id,
        'reject',
        <String, dynamic>{'rejectionReason': reason.text.trim()},
      ),
    );
  }

  Future<void> _pay() async {
    final bool? paid = await showDialog<bool>(
      context: context,
      builder: (BuildContext dialog) => _ExpensePaymentDialog(
        expense: _expense,
        category: widget.categories
            .where((ExpenseCategory c) => c.id == _expense.expenseCategoryId)
            .firstOrNull,
        onSubmit: (Map<String, dynamic> payload) => serviceLocator<
          FinanceSetupRepository
        >().payExpense(_expense.id, payload),
      ),
    );
    if (paid == true) await _refresh();
  }

  @override
  Widget build(BuildContext context) {
    final ExpenseRecord e = _expense;
    final ExpenseCategory? category = widget.categories
        .where((ExpenseCategory c) => c.id == e.expenseCategoryId)
        .firstOrNull;
    final String ledger = category == null
        ? e.expenseCategoryName
        : '${category.financialAccountCode} — ${category.financialAccountName ?? e.expenseCategoryName}';
    final String? note = e.status == 'rejected'
        ? e.rejectionReason
        : e.status == 'reversed'
        ? 'تم عكس هذا المصروف. استخدم الأزرار أدناه لعرض القيد الأصلي وقيد العكس.'
        : null;

    return Dialog(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 700, maxHeight: 700),
        child: Padding(
          padding: const EdgeInsets.all(FinanceSpace.xl),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Row(
                  children: <Widget>[
                    Expanded(
                      child: Text(
                        '${e.expenseNumber} — ${e.description}',
                        style: FinanceText.page,
                      ),
                    ),
                    IconButton(
                      tooltip: 'إغلاق',
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(Icons.close),
                    ),
                  ],
                ),
                const SizedBox(height: FinanceSpace.md),
                FinanceEntityHeader(
                  title: e.expenseCategoryName,
                  reference:
                      '${e.branchName ?? 'كل الفروع'}${e.createdByName != null ? ' · قدّمه ${e.createdByName}' : ''}',
                  status: e.status,
                ),
                if (note != null && note.isNotEmpty) ...<Widget>[
                  const SizedBox(height: FinanceSpace.sm),
                  FinanceAlertBanner(
                    message: note,
                    tone: e.status == 'rejected'
                        ? FinanceTone.danger
                        : FinanceTone.neutral,
                  ),
                ],
                const SizedBox(height: FinanceSpace.md),
                FinanceKpiGrid(
                  items: <FinanceKpiData>[
                    FinanceKpiData(label: 'المبلغ', value: _money(e.totalAmount)),
                    FinanceKpiData(label: 'الفرع', value: e.branchName ?? 'عام'),
                    FinanceKpiData(label: 'تاريخ التقديم', value: e.expenseDate),
                  ],
                ),
                const SizedBox(height: FinanceSpace.md),
                FinanceInfoGrid(
                  items: <FinanceInfoItem>[
                    FinanceInfoItem('حساب الأستاذ', ledger),
                    FinanceInfoItem('المبلغ قبل الضريبة', _money(e.amount)),
                    FinanceInfoItem('الضريبة', _money(e.taxAmount)),
                    if (e.notes != null) FinanceInfoItem('ملاحظات', e.notes!),
                    if (e.paymentMethodName != null)
                      FinanceInfoItem('طريقة الدفع', e.paymentMethodName!),
                    if (e.financialLocationName != null)
                      FinanceInfoItem('حساب الدفع', e.financialLocationName!),
                    if (e.approvedAt != null)
                      FinanceInfoItem('اعتُمد في', e.approvedAt!),
                    if (e.paidAt != null) FinanceInfoItem('دُفع في', e.paidAt!),
                  ],
                ),
                if (_error != null) ...<Widget>[
                  const SizedBox(height: FinanceSpace.md),
                  FinanceAlertBanner(message: _error!, tone: FinanceTone.danger),
                ],
                const SizedBox(height: FinanceSpace.lg),
                Wrap(
                  spacing: FinanceSpace.sm,
                  runSpacing: FinanceSpace.sm,
                  children: <Widget>[
                    if (e.allowedActions.contains('submit'))
                      _PrimaryAction(
                        label: 'إرسال للموافقة',
                        busy: _busy,
                        onPressed: _submit,
                      ),
                    if (e.allowedActions.contains('edit'))
                      _OutlineAction(
                        label: 'تعديل',
                        busy: _busy,
                        onPressed: () => widget.onEdit(e),
                      ),
                    if (e.allowedActions.contains('approve'))
                      _PrimaryAction(
                        label: 'اعتماد',
                        busy: _busy,
                        onPressed: _approve,
                      ),
                    if (e.allowedActions.contains('reject'))
                      _OutlineAction(label: 'رفض', busy: _busy, onPressed: _reject),
                    if (e.allowedActions.contains('pay'))
                      _PrimaryAction(
                        label: 'تسجيل دفعة',
                        busy: _busy,
                        onPressed: _pay,
                      ),
                    if (e.allowedActions.contains('reverse'))
                      _OutlineAction(
                        label: 'عكس المصروف',
                        busy: _busy,
                        onPressed: _reverse,
                      ),
                    if (e.journalEntryId != null)
                      OutlinedButton(
                        onPressed: () => widget.onOpenJournal(e.journalEntryId!),
                        child: const Text('عرض القيد'),
                      ),
                    if (e.reversalJournalEntryId != null)
                      OutlinedButton(
                        onPressed: () =>
                            widget.onOpenJournal(e.reversalJournalEntryId!),
                        child: const Text('عرض قيد العكس'),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _PrimaryAction extends StatelessWidget {
  const _PrimaryAction({
    required this.label,
    required this.busy,
    required this.onPressed,
  });
  final String label;
  final bool busy;
  final VoidCallback onPressed;
  @override
  Widget build(BuildContext context) => ElevatedButton(
    onPressed: busy ? null : onPressed,
    style: ElevatedButton.styleFrom(
      backgroundColor: FinanceColors.primary,
      foregroundColor: Colors.white,
    ),
    child: Text(label),
  );
}

class _OutlineAction extends StatelessWidget {
  const _OutlineAction({
    required this.label,
    required this.busy,
    required this.onPressed,
  });
  final String label;
  final bool busy;
  final VoidCallback onPressed;
  @override
  Widget build(BuildContext context) =>
      OutlinedButton(onPressed: busy ? null : onPressed, child: Text(label));
}

class _ExpensePaymentDialog extends StatefulWidget {
  const _ExpensePaymentDialog({
    required this.expense,
    required this.category,
    required this.onSubmit,
  });
  final ExpenseRecord expense;
  final ExpenseCategory? category;
  final Future<void> Function(Map<String, dynamic> payload) onSubmit;

  @override
  State<_ExpensePaymentDialog> createState() => _ExpensePaymentDialogState();
}

class _ExpensePaymentDialogState extends State<_ExpensePaymentDialog> {
  List<PaymentMethodSetting> _methods = const <PaymentMethodSetting>[];
  List<FinancialLocation> _locations = const <FinancialLocation>[];
  bool _loadingOptions = true;
  int? _methodId;
  int? _locationId;
  final TextEditingController _notes = TextEditingController();
  String? _error;
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    _loadOptions();
  }

  Future<void> _loadOptions() async {
    final FinanceSetupRepository repository =
        serviceLocator<FinanceSetupRepository>();
    try {
      final List<dynamic> results = await Future.wait<dynamic>(<Future<dynamic>>[
        repository.getPaymentMethods(),
        repository.getFinancialLocations('cash'),
        repository.getFinancialLocations('bank'),
      ]);
      if (!mounted) return;
      setState(() {
        _methods = (results[0] as List<PaymentMethodSetting>)
            .where((PaymentMethodSetting m) => m.isActive)
            .toList(growable: false);
        _locations = <FinancialLocation>[
          ...results[1] as List<FinancialLocation>,
          ...results[2] as List<FinancialLocation>,
        ].where((FinancialLocation l) => l.isActive).toList(growable: false);
        _methodId = _methods.isEmpty ? null : _methods.first.id;
        _locationId = _locations.isEmpty ? null : _locations.first.id;
        _loadingOptions = false;
      });
    } catch (error) {
      if (mounted) {
        setState(() {
          _error = '$error';
          _loadingOptions = false;
        });
      }
    }
  }

  @override
  void dispose() {
    _notes.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_methodId == null || _locationId == null) {
      setState(() => _error = 'اختر طريقة دفع وحساباً نقدياً أو بنكياً نشطاً.');
      return;
    }
    setState(() {
      _submitting = true;
      _error = null;
    });
    try {
      await widget.onSubmit(<String, dynamic>{
        'paymentMethodId': _methodId,
        'financialLocationId': _locationId,
        'paymentDate': DateTime.now().toIso8601String().substring(0, 10),
        if (_notes.text.trim().isNotEmpty) 'description': _notes.text.trim(),
        'idempotencyKey':
            'expense-payment-${widget.expense.id}-${DateTime.now().microsecondsSinceEpoch}',
      });
      if (mounted) Navigator.of(context).pop(true);
    } catch (error) {
      if (mounted) {
        setState(() {
          _error = '$error';
          _submitting = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final FinancialLocation? location = _locationId == null
        ? null
        : _locations.where((FinancialLocation l) => l.id == _locationId).firstOrNull;
    return FinanceDialogShell(
      title: 'دفع ${widget.expense.expenseNumber}',
      actions: <Widget>[
        TextButton(
          onPressed: _submitting ? null : () => Navigator.pop(context, false),
          child: const Text('إلغاء'),
        ),
        ElevatedButton(
          onPressed: _submitting || _loadingOptions ? null : _submit,
          style: ElevatedButton.styleFrom(
            backgroundColor: FinanceColors.primary,
            foregroundColor: Colors.white,
          ),
          child: _submitting
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                )
              : const Text('ترحيل الدفع'),
        ),
      ],
      child: _loadingOptions
          ? const SizedBox(
              height: 120,
              child: FinanceLoadingState(label: 'جارٍ تحميل خيارات الدفع…'),
            )
          : (_methods.isEmpty || _locations.isEmpty)
          ? const FinanceAlertBanner(
              message:
                  'لا توجد طريقة دفع أو حساب نقدي/بنكي نشط. أضف واحداً من إعدادات المالية أولاً.',
              tone: FinanceTone.warning,
            )
          : SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text('المبلغ: ${_money(widget.expense.totalAmount)}', style: FinanceText.body),
                  const SizedBox(height: FinanceSpace.md),
                  DropdownButtonFormField<int>(
                    initialValue: _methodId,
                    decoration: const InputDecoration(labelText: 'طريقة الدفع'),
                    items: _methods
                        .map(
                          (PaymentMethodSetting m) =>
                              DropdownMenuItem<int>(value: m.id, child: Text(m.name)),
                        )
                        .toList(),
                    onChanged: (int? v) => setState(() => _methodId = v),
                  ),
                  const SizedBox(height: FinanceSpace.md),
                  DropdownButtonFormField<int>(
                    initialValue: _locationId,
                    decoration: const InputDecoration(labelText: 'الحساب النقدي/البنكي'),
                    items: _locations
                        .map(
                          (FinancialLocation l) =>
                              DropdownMenuItem<int>(value: l.id, child: Text(l.name)),
                        )
                        .toList(),
                    onChanged: (int? v) => setState(() => _locationId = v),
                  ),
                  const SizedBox(height: FinanceSpace.md),
                  TextField(
                    controller: _notes,
                    decoration: const InputDecoration(labelText: 'ملاحظات (اختياري)'),
                  ),
                  if (widget.category != null && location != null) ...<Widget>[
                    const SizedBox(height: FinanceSpace.lg),
                    FinanceAccountImpactPreview(
                      toLabel:
                          '${widget.category!.financialAccountCode} — ${widget.category!.financialAccountName ?? widget.category!.name}',
                      fromLabel: location.name,
                      amount: widget.expense.totalAmount,
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

class _ExpenseFormDialog extends StatefulWidget {
  const _ExpenseFormDialog({
    required this.current,
    required this.categories,
    required this.branches,
    required this.onSubmit,
  });
  final ExpenseRecord? current;
  final List<ExpenseCategory> categories;
  final List<FinanceBranchOption> branches;
  final Future<void> Function(Map<String, dynamic> payload) onSubmit;

  @override
  State<_ExpenseFormDialog> createState() => _ExpenseFormDialogState();
}

class _ExpenseFormDialogState extends State<_ExpenseFormDialog> {
  late final TextEditingController _amount;
  late final TextEditingController _tax;
  late final TextEditingController _description;
  late final TextEditingController _notes;
  int? _categoryId;
  int? _branchId;
  late String _date;
  String? _error;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final ExpenseRecord? current = widget.current;
    _amount = TextEditingController(text: current?.amount);
    _tax = TextEditingController(text: current?.taxAmount ?? '0.00');
    _description = TextEditingController(text: current?.description);
    _notes = TextEditingController(text: current?.notes);
    final List<ExpenseCategory> active = widget.categories
        .where((ExpenseCategory c) => c.isActive)
        .toList();
    _categoryId = current?.expenseCategoryId ??
        (active.isEmpty ? null : active.first.id);
    _branchId = current?.branchId;
    _date = current?.expenseDate ??
        DateTime.now().toIso8601String().substring(0, 10);
  }

  @override
  void dispose() {
    _amount.dispose();
    _tax.dispose();
    _description.dispose();
    _notes.dispose();
    super.dispose();
  }

  bool _money(String value) =>
      RegExp(r'^\d+(?:\.\d{1,2})?$').hasMatch(value.trim());

  Future<void> _pickDate() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime.tryParse(_date) ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime(2035),
    );
    if (picked != null) {
      setState(() => _date = picked.toIso8601String().substring(0, 10));
    }
  }

  Future<void> _save() async {
    if (!_money(_amount.text) ||
        !_money(_tax.text) ||
        _description.text.trim().isEmpty ||
        _categoryId == null) {
      setState(() => _error = 'أدخل مبلغاً صالحاً، فئة، ووصفاً.');
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await widget.onSubmit(<String, dynamic>{
        'branchId': _branchId,
        'expenseCategoryId': _categoryId,
        'amount': _amount.text.trim(),
        'taxAmount': _tax.text.trim(),
        'expenseDate': _date,
        'description': _description.text.trim(),
        'notes': _notes.text.trim().isEmpty ? null : _notes.text.trim(),
        if (widget.current == null)
          'idempotencyKey': 'expense-${DateTime.now().microsecondsSinceEpoch}',
      });
      if (mounted) Navigator.of(context).pop(true);
    } catch (error) {
      if (mounted) {
        setState(() {
          _error = '$error';
          _saving = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool isEdit = widget.current != null;
    final double total =
        (double.tryParse(_amount.text.trim()) ?? 0) +
        (double.tryParse(_tax.text.trim()) ?? 0);
    return FinanceDialogShell(
      title: isEdit ? 'تعديل مصروف' : 'إضافة مصروف',
      actions: <Widget>[
        TextButton(
          onPressed: _saving ? null : () => Navigator.pop(context, false),
          child: const Text('إلغاء'),
        ),
        ElevatedButton(
          onPressed: _saving ? null : _save,
          style: ElevatedButton.styleFrom(
            backgroundColor: FinanceColors.primary,
            foregroundColor: Colors.white,
          ),
          child: _saving
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                )
              : const Text('حفظ'),
        ),
      ],
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            DropdownButtonFormField<int>(
              initialValue: _categoryId,
              decoration: const InputDecoration(labelText: 'الفئة'),
              items: widget.categories
                  .where((ExpenseCategory c) => c.isActive)
                  .map(
                    (ExpenseCategory c) => DropdownMenuItem<int>(
                      value: c.id,
                      child: Text('${c.code} — ${c.name}'),
                    ),
                  )
                  .toList(),
              onChanged: (int? v) => setState(() => _categoryId = v),
            ),
            const SizedBox(height: FinanceSpace.md),
            DropdownButtonFormField<int?>(
              initialValue: _branchId,
              decoration: const InputDecoration(labelText: 'الفرع (اختياري)'),
              items: <DropdownMenuItem<int?>>[
                const DropdownMenuItem<int?>(value: null, child: Text('عام (كل الفروع)')),
                ...widget.branches.map(
                  (FinanceBranchOption b) =>
                      DropdownMenuItem<int?>(value: b.id, child: Text(b.name)),
                ),
              ],
              onChanged: (int? v) => setState(() => _branchId = v),
            ),
            const SizedBox(height: FinanceSpace.md),
            InkWell(
              onTap: _pickDate,
              child: InputDecorator(
                decoration: const InputDecoration(labelText: 'التاريخ'),
                child: Text(_date),
              ),
            ),
            const SizedBox(height: FinanceSpace.md),
            TextField(
              controller: _amount,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              onChanged: (_) => setState(() {}),
              decoration: const InputDecoration(labelText: 'المبلغ'),
            ),
            const SizedBox(height: FinanceSpace.md),
            TextField(
              controller: _tax,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              onChanged: (_) => setState(() {}),
              decoration: const InputDecoration(labelText: 'الضريبة'),
            ),
            const SizedBox(height: FinanceSpace.md),
            InputDecorator(
              decoration: const InputDecoration(labelText: 'الإجمالي'),
              child: Text(total.toStringAsFixed(2)),
            ),
            const SizedBox(height: FinanceSpace.md),
            TextField(
              controller: _description,
              decoration: const InputDecoration(labelText: 'الوصف'),
            ),
            const SizedBox(height: FinanceSpace.md),
            TextField(
              controller: _notes,
              decoration: const InputDecoration(labelText: 'ملاحظات (اختياري)'),
            ),
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

List<Map<String, dynamic>> _list(dynamic value) => value is List
    ? value
          .whereType<Map>()
          .map((Map row) => Map<String, dynamic>.from(row))
          .toList(growable: false)
    : const <Map<String, dynamic>>[];
int _int(dynamic value) => value is int ? value : int.tryParse('$value') ?? 0;
double _amount(dynamic value) => value is num
    ? value.toDouble()
    : double.tryParse('${value ?? 0}'.replaceAll(',', '')) ?? 0;
String _money(dynamic value) => CurrencyFormatter.format(_amount(value));

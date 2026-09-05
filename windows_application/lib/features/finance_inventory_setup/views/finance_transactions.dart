import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/utils/currency_formatter.dart';
import '../models/finance_setup_models.dart';
import '../repositories/finance_setup_repository.dart';
import '../widgets/finance_components.dart';
import '../widgets/finance_design.dart';
import '../widgets/finance_journal_drawer.dart';
import '../widgets/finance_pagination.dart';
import '../widgets/finance_period.dart';
import '../widgets/finance_shell.dart';
import '../widgets/finance_transaction_type.dart';

/// Local, screen-only filters. Kept separate from the global period/branch
/// context so "Clear filters" never resets the shared Finance context.
class FinanceTransactionFilters {
  const FinanceTransactionFilters({
    this.sourceType,
    this.status,
    this.accountId,
    this.paymentMethodId,
    this.search,
  });
  final String? sourceType;
  final String? status;
  final int? accountId;
  final int? paymentMethodId;
  final String? search;

  bool get isEmpty =>
      sourceType == null &&
      status == null &&
      accountId == null &&
      paymentMethodId == null &&
      (search == null || search!.isEmpty);
}

class FinanceTransactionsQuery {
  const FinanceTransactionsQuery({
    required this.dateFrom,
    required this.dateTo,
    this.branchId,
    this.filters = const FinanceTransactionFilters(),
    this.page = 1,
  });
  final DateTime dateFrom;
  final DateTime dateTo;
  final int? branchId;
  final FinanceTransactionFilters filters;
  final int page;

  Map<String, dynamic> get parameters => <String, dynamic>{
    'date_from': FinancePeriod.format(dateFrom),
    'date_to': FinancePeriod.format(dateTo),
    if (branchId != null) 'branch_id': branchId,
    if (filters.sourceType != null) 'source_type': filters.sourceType,
    if (filters.status != null) 'status': filters.status,
    if (filters.accountId != null) 'account_id': filters.accountId,
    if (filters.paymentMethodId != null)
      'payment_method_id': filters.paymentMethodId,
    if (filters.search != null && filters.search!.isNotEmpty)
      'search': filters.search,
    'page': page,
    'perPage': 10,
  };
}

class FinanceTransactionsPayload {
  const FinanceTransactionsPayload({required this.summary, required this.page});
  final Map<String, dynamic> summary;
  final FinancePage<Map<String, dynamic>> page;
}

typedef FinanceTransactionsLoader =
    Future<FinanceTransactionsPayload> Function(
      FinanceTransactionsQuery query,
    );
typedef FinanceTransactionDetailLoader =
    Future<Map<String, dynamic>> Function(int id);

const List<String> _kSourceTypes = <String>[
  'sale',
  'refund',
  'expense',
  'cash_transfer',
  'supplier_invoice',
  'supplier_payment',
  'inventory_waste',
  'stock_count_variance',
  'manual_journal',
  'journal_reversal',
];

/// Canonical Financial Transactions screen (`/finance?tab=transactions`).
/// Laravel supplies every summary total, filtered page, and journal detail;
/// this widget only presents that already-authorized payload — it never
/// computes debit/credit, totals, or accounting state locally.
class FinanceTransactionsView extends StatefulWidget {
  const FinanceTransactionsView({
    super.key,
    required this.loader,
    required this.detailLoader,
    required this.branchesLoader,
    required this.accountsLoader,
    required this.paymentMethodsLoader,
  });

  factory FinanceTransactionsView.fromRepository(
    FinanceSetupRepository repository,
  ) => FinanceTransactionsView(
    loader: (FinanceTransactionsQuery query) async {
      final List<dynamic> values =
          await Future.wait<dynamic>(<Future<dynamic>>[
            repository.getFinanceMap(
              'finance/transactions/summary',
              queryParameters: query.parameters,
            ),
            repository.getFinancePage(
              'finance/transactions',
              queryParameters: query.parameters,
            ),
          ]);
      return FinanceTransactionsPayload(
        summary: values[0] as Map<String, dynamic>,
        page: values[1] as FinancePage<Map<String, dynamic>>,
      );
    },
    detailLoader: (int id) =>
        repository.getFinanceMap('finance/transactions/$id'),
    branchesLoader: () =>
        repository.getFinanceMap('finance/transactions/branches'),
    accountsLoader: repository.getAccounts,
    paymentMethodsLoader: repository.getPaymentMethods,
  );

  final FinanceTransactionsLoader loader;
  final FinanceTransactionDetailLoader detailLoader;
  final Future<Map<String, dynamic>> Function() branchesLoader;
  final Future<List<FinancialAccount>> Function() accountsLoader;
  final Future<List<PaymentMethodSetting>> Function() paymentMethodsLoader;

  @override
  State<FinanceTransactionsView> createState() =>
      _FinanceTransactionsViewState();
}

class _FinanceTransactionsViewState extends State<FinanceTransactionsView> {
  late DateTime _dateFrom;
  late DateTime _dateTo;
  int? _branchId;
  FinanceTransactionFilters _filters = const FinanceTransactionFilters();
  int _page = 1;
  final TextEditingController _searchController = TextEditingController();
  Timer? _debounce;

  int _requestId = 0;
  FinanceTransactionsPayload? _data;
  Object? _error;
  bool _loading = false;

  List<FinanceBranchOption> _branches = const <FinanceBranchOption>[];
  List<FinancialAccount> _accounts = const <FinancialAccount>[];
  List<PaymentMethodSetting> _paymentMethods = const <PaymentMethodSetting>[];

  @override
  void initState() {
    super.initState();
    final DateTime today = DateUtils.dateOnly(DateTime.now());
    _dateFrom = DateTime(today.year, today.month);
    _dateTo = today;
    _load();
    widget.branchesLoader().then((Map<String, dynamic> response) {
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
    widget.accountsLoader().then((List<FinancialAccount> accounts) {
      if (!mounted) return;
      setState(
        () => _accounts = accounts
            .where((FinancialAccount account) => account.isActive)
            .toList(growable: false),
      );
    });
    widget.paymentMethodsLoader().then((List<PaymentMethodSetting> methods) {
      if (!mounted) return;
      setState(
        () => _paymentMethods = methods
            .where((PaymentMethodSetting method) => method.isActive)
            .toList(growable: false),
      );
    });
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  FinanceTransactionsQuery get _query => FinanceTransactionsQuery(
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
      final FinanceTransactionsPayload result = await widget.loader(_query);
      if (!mounted || requestId != _requestId) return;
      setState(() {
        _data = result;
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

  void _applyFilters(FinanceTransactionFilters next) {
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
        FinanceTransactionFilters(
          sourceType: _filters.sourceType,
          status: _filters.status,
          accountId: _filters.accountId,
          paymentMethodId: _filters.paymentMethodId,
          search: value.trim().isEmpty ? null : value.trim(),
        ),
      );
    });
  }

  void _clearFilters() {
    _debounce?.cancel();
    _searchController.clear();
    _applyFilters(const FinanceTransactionFilters());
  }

  void _changePage(int page) {
    setState(() => _page = page);
    _load();
  }

  void _openDrawer(Map<String, dynamic> row) {
    final int id = _int(row['id']);
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
            loader: () => widget.detailLoader(id),
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
  Widget build(BuildContext context) {
    if (_data == null && _error == null) {
      return const FinanceLoadingState(label: 'جارٍ تحميل الحركات المالية…');
    }
    if (_data == null) {
      return FinanceErrorState(
        message: 'تعذّر تحميل الحركات المالية. لم يتم اعتبار الخطأ صفراً.',
        onRetry: _load,
      );
    }
    final FinanceTransactionsPayload data = _data!;
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
              _SummaryGrid(summary: data.summary),
              const SizedBox(height: FinanceSpace.lg),
              _FiltersBar(
                filters: _filters,
                searchController: _searchController,
                accounts: _accounts,
                paymentMethods: _paymentMethods,
                onSourceType: (String? value) => _applyFilters(
                  FinanceTransactionFilters(
                    sourceType: value,
                    status: _filters.status,
                    accountId: _filters.accountId,
                    paymentMethodId: _filters.paymentMethodId,
                    search: _filters.search,
                  ),
                ),
                onStatus: (String? value) => _applyFilters(
                  FinanceTransactionFilters(
                    sourceType: _filters.sourceType,
                    status: value,
                    accountId: _filters.accountId,
                    paymentMethodId: _filters.paymentMethodId,
                    search: _filters.search,
                  ),
                ),
                onAccount: (int? value) => _applyFilters(
                  FinanceTransactionFilters(
                    sourceType: _filters.sourceType,
                    status: _filters.status,
                    accountId: value,
                    paymentMethodId: _filters.paymentMethodId,
                    search: _filters.search,
                  ),
                ),
                onPaymentMethod: (int? value) => _applyFilters(
                  FinanceTransactionFilters(
                    sourceType: _filters.sourceType,
                    status: _filters.status,
                    accountId: _filters.accountId,
                    paymentMethodId: value,
                    search: _filters.search,
                  ),
                ),
                onSearchChanged: _onSearchChanged,
                onClear: _filters.isEmpty ? null : _clearFilters,
              ),
              const SizedBox(height: FinanceSpace.lg),
              if (_error != null) ...<Widget>[
                FinanceAlertBanner(
                  message:
                      'تعذّر تحديث الحركات المالية لهذه الفلاتر. تُعرض آخر بيانات محمّلة.',
                  tone: FinanceTone.warning,
                  action: TextButton(
                    onPressed: _load,
                    child: const Text('إعادة المحاولة'),
                  ),
                ),
                const SizedBox(height: FinanceSpace.md),
              ],
              if (data.page.items.isEmpty)
                SizedBox(
                  height: 220,
                  child: FinanceEmptyState(
                    message: _filters.isEmpty
                        ? 'لا توجد حركات مالية للفترة المحددة'
                        : 'لا توجد حركات مالية مطابقة للفلاتر المحددة',
                    action: _filters.isEmpty
                        ? null
                        : TextButton(
                            onPressed: _clearFilters,
                            child: const Text('إعادة تعيين الفلاتر'),
                          ),
                  ),
                )
              else ...<Widget>[
                _TransactionsTable(rows: data.page.items, onRowTap: _openDrawer),
                FinancePagination(meta: data.page.meta, onPageChanged: _changePage),
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
        label: 'إجمالي الحركات',
        value: '${summary['transactionCount'] ?? 0}',
        icon: Icons.receipt_long_outlined,
      ),
      FinanceKpiData(
        label: 'إجمالي الداخل',
        value: _money(summary['externalCashInflow']),
        icon: Icons.south_west,
        tone: FinanceTone.success,
      ),
      FinanceKpiData(
        label: 'إجمالي الخارج',
        value: _money(summary['externalCashOutflow']),
        icon: Icons.north_east,
        tone: FinanceTone.warning,
      ),
      FinanceKpiData(
        label: 'القيود المسودة',
        value: '${summary['draftJournalCount'] ?? 0}',
        icon: Icons.edit_note_outlined,
        tone: FinanceTone.warning,
      ),
      FinanceKpiData(
        label: 'الحركات المعكوسة',
        value: '${summary['reversedOriginalCount'] ?? 0}',
        icon: Icons.undo_outlined,
        tone: FinanceTone.neutral,
      ),
    ],
  );
}

class _FiltersBar extends StatelessWidget {
  const _FiltersBar({
    required this.filters,
    required this.searchController,
    required this.accounts,
    required this.paymentMethods,
    required this.onSourceType,
    required this.onStatus,
    required this.onAccount,
    required this.onPaymentMethod,
    required this.onSearchChanged,
    required this.onClear,
  });
  final FinanceTransactionFilters filters;
  final TextEditingController searchController;
  final List<FinancialAccount> accounts;
  final List<PaymentMethodSetting> paymentMethods;
  final ValueChanged<String?> onSourceType;
  final ValueChanged<String?> onStatus;
  final ValueChanged<int?> onAccount;
  final ValueChanged<int?> onPaymentMethod;
  final ValueChanged<String> onSearchChanged;
  final VoidCallback? onClear;

  @override
  Widget build(BuildContext context) => FinanceFilterBar(
    onReset: onClear,
    children: <Widget>[
      _FilterDropdown<String>(
        label: 'نوع الحركة',
        value: filters.sourceType,
        items: _kSourceTypes
            .map(
              (String type) => DropdownMenuItem<String>(
                value: type,
                child: Text(FinanceTransactionType.label(type)),
              ),
            )
            .toList(),
        onChanged: onSourceType,
      ),
      _FilterDropdown<String>(
        label: 'الحالة',
        value: filters.status,
        items: const <DropdownMenuItem<String>>[
          DropdownMenuItem<String>(value: 'draft', child: Text('مسودة')),
          DropdownMenuItem<String>(value: 'posted', child: Text('مرحّل')),
        ],
        onChanged: onStatus,
      ),
      _FilterDropdown<int>(
        label: 'الحساب',
        value: filters.accountId,
        items: accounts
            .map(
              (FinancialAccount account) => DropdownMenuItem<int>(
                value: account.id,
                child: Text('${account.code} — ${account.nameAr}'),
              ),
            )
            .toList(),
        onChanged: onAccount,
      ),
      _FilterDropdown<int>(
        label: 'طريقة الدفع',
        value: filters.paymentMethodId,
        items: paymentMethods
            .map(
              (PaymentMethodSetting method) => DropdownMenuItem<int>(
                value: method.id,
                child: Text(method.name),
              ),
            )
            .toList(),
        onChanged: onPaymentMethod,
      ),
      SizedBox(
        width: 240,
        height: 34,
        child: TextField(
          controller: searchController,
          onChanged: onSearchChanged,
          style: FinanceText.body,
          decoration: InputDecoration(
            isDense: true,
            hintText: 'بحث بالمرجع أو الوصف…',
            prefixIcon: const Icon(Icons.search, size: 18),
            filled: true,
            fillColor: FinanceColors.workspace,
            contentPadding: const EdgeInsets.symmetric(vertical: 6),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(FinanceRadius.control),
              borderSide: const BorderSide(color: FinanceColors.border),
            ),
          ),
        ),
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
    // ignore: unused_element_parameter
    super.key,
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

class _TransactionsTable extends StatelessWidget {
  const _TransactionsTable({required this.rows, required this.onRowTap});
  final List<Map<String, dynamic>> rows;
  final ValueChanged<Map<String, dynamic>> onRowTap;

  @override
  Widget build(BuildContext context) => FinanceTable(
    headers: const <String>[
      'التاريخ',
      'النوع',
      'المرجع',
      'الوصف',
      'الفرع',
      'مدين',
      'دائن',
      'الحالة',
    ],
    minWidth: 1320,
    onRowTap: (int index) => onRowTap(rows[index]),
    rows: rows.map((Map<String, dynamic> row) {
      final Map<String, dynamic> source = _map(row['source']);
      final Map<String, dynamic> journal = _map(row['journal']);
      final Map<String, dynamic> reversal = _map(row['reversal']);
      return <Widget>[
        Text('${row['transactionDate'] ?? '—'}', style: FinanceText.small),
        FinanceTransactionTypeBadge(
          normalizedType: source['normalizedType'] as String?,
        ),
        FinanceReference(reference: '${row['reference'] ?? '—'}'),
        Text('${row['description'] ?? '—'}', style: FinanceText.body),
        Text(
          '${_map(row['branch'])['name'] ?? '—'}',
          style: FinanceText.small,
        ),
        FinanceAmount(value: '${journal['totalDebit'] ?? '0.00'}'),
        FinanceAmount(value: '${journal['totalCredit'] ?? '0.00'}'),
        Wrap(
          spacing: 6,
          runSpacing: 4,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: <Widget>[
            FinanceStatusBadge(status: '${journal['status'] ?? 'draft'}'),
            if ('${reversal['state'] ?? 'none'}' != 'none')
              FinanceReversalBadge(state: '${reversal['state']}'),
          ],
        ),
      ];
    }).toList(),
  );
}

Map<String, dynamic> _map(dynamic value) =>
    value is Map ? Map<String, dynamic>.from(value) : const <String, dynamic>{};
List<Map<String, dynamic>> _list(dynamic value) => value is List
    ? value
          .whereType<Map>()
          .map((Map row) => Map<String, dynamic>.from(row))
          .toList(growable: false)
    : const <Map<String, dynamic>>[];
int _int(dynamic value) => value is int ? value : int.tryParse('$value') ?? 0;
double _number(dynamic value) => value is num
    ? value.toDouble()
    : double.tryParse('${value ?? 0}'.replaceAll(',', '')) ?? 0;
String _money(dynamic value) => CurrencyFormatter.format(_number(value));

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../app/app_router.dart';
import '../../../shared/layouts/desktop_page_layout.dart';
import '../../pos/models/branch.dart';
import '../controllers/finance_setup_cubit.dart';
import '../models/finance_report_models.dart';
import '../models/finance_setup_models.dart';
import '../repositories/finance_setup_repository.dart';
import '../widgets/finance_components.dart';
import '../widgets/finance_design.dart';
import '../widgets/finance_journal_drawer.dart';
import '../widgets/finance_shell.dart';
import '../widgets/finance_source_navigation.dart';

/// Canonical Financial Reports Center (`/finance/reports`). Every figure —
/// P&L, Balance Sheet, Cash Flow, Trial Balance, General Ledger, Supplier
/// Aging, Supplier Statement — is `FinancialReportQueryService` output; this
/// screen only selects, filters, and renders it, and turns each row's own
/// journal/source/account/supplier reference into real navigation. It never
/// recomputes a balance, a running total, or an integrity signal.
class FinancialReportsScreen extends StatefulWidget {
  const FinancialReportsScreen({super.key, this.accountId, this.supplierId, this.reportType});
  final int? accountId;
  final int? supplierId;
  final String? reportType;

  @override
  State<FinancialReportsScreen> createState() => _FinancialReportsScreenState();
}

class _ReportDef {
  const _ReportDef(this.id, this.label);
  final String id;
  final String label;
}

const List<_ReportDef> _reportDefs = <_ReportDef>[
  _ReportDef('profit-loss', 'قائمة الدخل'),
  _ReportDef('balance-sheet', 'الميزانية العمومية'),
  _ReportDef('cash-flow', 'التدفقات النقدية'),
  _ReportDef('trial-balance', 'ميزان المراجعة'),
  _ReportDef('general-ledger', 'دفتر الأستاذ العام'),
  _ReportDef('supplier-aging', 'أعمار ذمم الموردين'),
  _ReportDef('supplier-statement', 'كشف حساب المورد'),
];

class _FinancialReportsScreenState extends State<FinancialReportsScreen> {
  late final FinanceSetupRepository _repo;
  late Future<List<dynamic>> _setup;

  String _type = 'profit-loss';
  int? _branchId;
  int? _accountId;
  int? _supplierId;
  late String _from;
  late String _to;
  bool _includeZero = false;

  dynamic _report;
  bool _loading = false;
  Object? _error;
  int _requestId = 0;
  List<FinancialAccount> _accounts = const <FinancialAccount>[];
  List<Supplier> _suppliers = const <Supplier>[];
  List<Branch> _branches = const <Branch>[];

  FinanceSetupRepository get _repository => context.read<FinanceSetupCubit>().repository;

  @override
  void initState() {
    super.initState();
    _repo = _repository;
    _accountId = widget.accountId;
    _supplierId = widget.supplierId;
    _type = widget.reportType ?? _type;
    final DateTime now = DateTime.now();
    _from = DateTime(now.year, now.month).toIso8601String().substring(0, 10);
    _to = now.toIso8601String().substring(0, 10);
    _setup = Future.wait<dynamic>(<Future<dynamic>>[
      _repo.getAccounts(status: 'active'),
      _repo.getBranches(),
      _repo.getSuppliers(),
    ]).then((List<dynamic> results) {
      setState(() {
        _accounts = results[0] as List<FinancialAccount>;
        _branches = results[1] as List<Branch>;
        _suppliers = results[2] as List<Supplier>;
        _accountId ??= _type == 'general-ledger' && _accounts.isNotEmpty ? _accounts.first.id : _accountId;
        _supplierId ??= _type == 'supplier-statement' && _suppliers.isNotEmpty ? _suppliers.first.id : _supplierId;
      });
      _load();
      return results;
    });
  }

  Map<String, dynamic> get _baseFilters => <String, dynamic>{
    if (_from.isNotEmpty) 'dateFrom': _from,
    if (_to.isNotEmpty) 'dateTo': _to,
    if (_branchId != null) 'branchId': _branchId,
  };

  /// Keeps whatever report is already on screen visible (dimmed) while a
  /// filter/report-type/sub-picker change refetches — never blanks it back
  /// to a bare loading state, and never leaves the spinner stuck on success
  /// or failure.
  Future<void> _load() async {
    if (_type == 'general-ledger' && _accountId == null) {
      setState(() {
        _report = null;
        _error = null;
      });
      return;
    }
    if (_type == 'supplier-statement' && _supplierId == null) {
      setState(() {
        _report = null;
        _error = null;
      });
      return;
    }
    final int requestId = ++_requestId;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final dynamic result = await switch (_type) {
        'profit-loss' => _repo.getProfitAndLoss(filters: _baseFilters),
        'balance-sheet' => _repo.getBalanceSheet(filters: <String, dynamic>{..._baseFilters, 'asOfDate': _to}),
        'cash-flow' => _repo.getCashFlow(filters: _baseFilters),
        'trial-balance' => _repo.getTrialBalance(
          filters: <String, dynamic>{..._baseFilters, 'includeZero': _includeZero},
        ),
        'general-ledger' => _repo.getGeneralLedgerReport(
          filters: <String, dynamic>{..._baseFilters, 'accountId': _accountId},
        ),
        'supplier-aging' => _repo.getSupplierAging(
          filters: <String, dynamic>{..._baseFilters, 'asOfDate': _to, if (_supplierId != null) 'supplierId': _supplierId},
        ),
        'supplier-statement' => _repo.getSupplierStatementReport(
          filters: <String, dynamic>{..._baseFilters, 'supplierId': _supplierId},
        ),
        _ => Future<dynamic>.value(),
      };
      if (!mounted || requestId != _requestId) return;
      setState(() {
        _report = result;
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

  void _selectType(String type) {
    setState(() {
      _type = type;
      if (type == 'general-ledger') _accountId ??= _accounts.isNotEmpty ? _accounts.first.id : null;
      if (type == 'supplier-statement') _supplierId ??= _suppliers.isNotEmpty ? _suppliers.first.id : null;
    });
    _load();
  }

  void _drillToGeneralLedger(int accountId) {
    setState(() {
      _type = 'general-ledger';
      _accountId = accountId;
    });
    _load();
  }

  void _drillToSupplierStatement(int supplierId) {
    setState(() {
      _type = 'supplier-statement';
      _supplierId = supplierId;
    });
    _load();
  }

  Future<void> _pickDate({required bool isTo}) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime.tryParse(isTo ? _to : _from) ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime(2035),
    );
    if (picked == null) return;
    setState(() {
      final String value = picked.toIso8601String().substring(0, 10);
      if (isTo) {
        _to = value;
      } else {
        _from = value;
      }
    });
    _load();
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
            loader: () => _repo.getFinanceMap('finance/transactions/$journalId'),
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

  void _navigateSource({required String resourceKind, required int? id}) {
    final String? path = FinanceSourceNavigation.destination(<String, dynamic>{
      'resourceKind': resourceKind,
      'id': id,
      'available': id != null,
    });
    if (path != null) context.go(path);
  }

  @override
  Widget build(BuildContext context) => Directionality(
    textDirection: TextDirection.rtl,
    child: DesktopPageLayout(
      padding: EdgeInsets.zero,
      child: FinanceShell(
        currentSection: 'التقارير المالية',
        title: 'التقارير المالية',
        subtitle: 'تقارير مالية تفصيلية مع تتبع كامل للحسابات والمصادر',
        showContext: false,
        child: FutureBuilder<List<dynamic>>(
          future: _setup,
          builder: (BuildContext context, AsyncSnapshot<List<dynamic>> setup) {
            if (setup.connectionState != ConnectionState.done) {
              return const FinanceLoadingState(label: 'جارٍ تحميل بيانات التقارير…');
            }
            if (setup.hasError) {
              return FinanceErrorState(
                message: 'تعذّر تحميل بيانات الإعداد.',
                onRetry: () => setState(() {
                  _setup = Future.wait<dynamic>(<Future<dynamic>>[
                    _repo.getAccounts(status: 'active'),
                    _repo.getBranches(),
                    _repo.getSuppliers(),
                  ]);
                }),
              );
            }
            return _buildBody();
          },
        ),
      ),
    ),
  );

  Widget _buildBody() => SingleChildScrollView(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Wrap(
          spacing: FinanceSpace.sm,
          runSpacing: FinanceSpace.sm,
          children: _reportDefs
              .map(
                (_ReportDef def) => _SelectorChip(
                  label: def.label,
                  selected: _type == def.id,
                  onTap: () => _selectType(def.id),
                ),
              )
              .toList(),
        ),
        const SizedBox(height: FinanceSpace.md),
        _FilterBar(
          branches: _branches,
          branchId: _branchId,
          from: _from,
          to: _to,
          onBranchChanged: (int? id) {
            setState(() => _branchId = id);
            _load();
          },
          onPickFrom: () => _pickDate(isTo: false),
          onPickTo: () => _pickDate(isTo: true),
        ),
        const SizedBox(height: FinanceSpace.lg),
        if (_type == 'general-ledger')
          _ChipPicker(
            label: 'الحساب:',
            items: _accounts
                .map((FinancialAccount a) => _ChipItem(id: a.id, label: '${a.code} — ${a.nameAr}'))
                .toList(),
            selectedId: _accountId,
            onSelected: (int id) {
              setState(() => _accountId = id);
              _load();
            },
          ),
        if (_type == 'supplier-statement')
          _ChipPicker(
            label: 'المورد:',
            items: _suppliers
                .map((Supplier s) => _ChipItem(id: s.id, label: '${s.supplierNumber} — ${s.name}'))
                .toList(),
            selectedId: _supplierId,
            onSelected: (int id) {
              setState(() => _supplierId = id);
              _load();
            },
          ),
        if (_type == 'general-ledger' || _type == 'supplier-statement') const SizedBox(height: FinanceSpace.lg),
        _body(),
      ],
    ),
  );

  Widget _body() {
    if (_type == 'general-ledger' && _accountId == null) {
      return const FinanceEmptyState(message: 'اختر حساباً لعرض دفتر الأستاذ.');
    }
    if (_type == 'supplier-statement' && _supplierId == null) {
      return const FinanceEmptyState(message: 'اختر مورداً لعرض كشف الحساب.');
    }
    if (_report == null && _error != null) {
      return FinanceErrorState(message: 'تعذّر تحميل التقرير. $_error', onRetry: _load);
    }
    if (_report == null) {
      return const FinanceLoadingState(label: 'جارٍ تحميل التقرير…');
    }
    final dynamic report = _report;
    final Widget content = switch (_type) {
      'profit-loss' => _ProfitAndLossView(report: report as ProfitAndLossReport, onDrillAccount: _drillToGeneralLedger),
      'balance-sheet' => _BalanceSheetView(report: report as BalanceSheetReport, onDrillAccount: _drillToGeneralLedger),
      'cash-flow' => _CashFlowView(report: report as CashFlowReport, onOpenJournal: _openJournalDrawer),
      'trial-balance' => _TrialBalanceView(
        report: report as TrialBalanceReport,
        includeZero: _includeZero,
        onToggleZero: () {
          setState(() => _includeZero = !_includeZero);
          _load();
        },
        onDrillAccount: _drillToGeneralLedger,
      ),
      'general-ledger' => _GeneralLedgerView(report: report as GeneralLedgerReport, onOpenJournal: _openJournalDrawer),
      'supplier-aging' => _SupplierAgingView(report: report as SupplierAgingReport, onOpenStatement: _drillToSupplierStatement),
      'supplier-statement' => _SupplierStatementView(
        report: report as SupplierStatementReport,
        onOpenProfile: () => context.go('${AppRoutes.financeSuppliers}/$_supplierId'),
        onNavigateSource: _navigateSource,
      ),
      _ => const SizedBox.shrink(),
    };
    if (!_loading && _error == null) return content;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        if (_error != null) ...<Widget>[
          FinanceAlertBanner(
            message: 'تعذّر تحديث التقرير لهذه الفلاتر. يُعرض آخر تقرير محمّل.',
            tone: FinanceTone.warning,
            action: TextButton(onPressed: _load, child: const Text('إعادة المحاولة')),
          ),
          const SizedBox(height: FinanceSpace.md),
        ],
        Opacity(opacity: _loading ? 0.6 : 1, child: IgnorePointer(ignoring: _loading, child: content)),
      ],
    );
  }
}

class _SelectorChip extends StatelessWidget {
  const _SelectorChip({required this.label, required this.selected, required this.onTap});
  final String label;
  final bool selected;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => Material(
    color: selected ? FinanceColors.primary : Colors.white,
    borderRadius: BorderRadius.circular(FinanceRadius.control),
    child: InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(FinanceRadius.control),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          border: Border.all(color: selected ? FinanceColors.primary : FinanceColors.border),
          borderRadius: BorderRadius.circular(FinanceRadius.control),
        ),
        child: Text(
          label,
          style: FinanceText.small.copyWith(
            fontWeight: FontWeight.w700,
            color: selected ? Colors.white : FinanceColors.supporting,
          ),
        ),
      ),
    ),
  );
}

class _ChipItem {
  const _ChipItem({required this.id, required this.label});
  final int id;
  final String label;
}

class _ChipPicker extends StatelessWidget {
  const _ChipPicker({required this.label, required this.items, required this.selectedId, required this.onSelected});
  final String label;
  final List<_ChipItem> items;
  final int? selectedId;
  final ValueChanged<int> onSelected;
  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) return const SizedBox.shrink();
    return Wrap(
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: FinanceSpace.sm,
      runSpacing: FinanceSpace.sm,
      children: <Widget>[
        Text(label, style: FinanceText.label),
        ...items.map(
          (_ChipItem item) => _SelectorChip(
            label: item.label,
            selected: item.id == selectedId,
            onTap: () => onSelected(item.id),
          ),
        ),
      ],
    );
  }
}

class _FilterBar extends StatelessWidget {
  const _FilterBar({
    required this.branches,
    required this.branchId,
    required this.from,
    required this.to,
    required this.onBranchChanged,
    required this.onPickFrom,
    required this.onPickTo,
  });
  final List<Branch> branches;
  final int? branchId;
  final String from;
  final String to;
  final ValueChanged<int?> onBranchChanged;
  final VoidCallback onPickFrom;
  final VoidCallback onPickTo;

  @override
  Widget build(BuildContext context) => FinanceFilterBar(
    children: <Widget>[
      OutlinedButton.icon(onPressed: onPickFrom, icon: const Icon(Icons.date_range, size: 16), label: Text('من: $from')),
      OutlinedButton.icon(onPressed: onPickTo, icon: const Icon(Icons.date_range, size: 16), label: Text('إلى: $to')),
      Container(
        height: 34,
        constraints: const BoxConstraints(minWidth: 150),
        padding: const EdgeInsetsDirectional.only(start: FinanceSpace.sm),
        decoration: BoxDecoration(
          color: FinanceColors.workspace,
          border: Border.all(color: FinanceColors.border),
          borderRadius: BorderRadius.circular(FinanceRadius.control),
        ),
        child: DropdownButtonHideUnderline(
          child: DropdownButton<int?>(
            value: branchId,
            hint: const Text('الفرع: الكل', style: FinanceText.small),
            icon: const Icon(Icons.keyboard_arrow_down, size: 18),
            style: FinanceText.body,
            isDense: true,
            onChanged: onBranchChanged,
            items: <DropdownMenuItem<int?>>[
              const DropdownMenuItem<int?>(value: null, child: Text('الفرع: الكل')),
              ...branches.map((Branch b) => DropdownMenuItem<int?>(value: b.id, child: Text('الفرع: ${b.name}'))),
            ],
          ),
        ),
      ),
    ],
  );
}

class _IntegrityBanner extends StatelessWidget {
  const _IntegrityBanner({required this.healthy, required this.message});
  final bool healthy;
  final String message;
  @override
  Widget build(BuildContext context) =>
      FinanceAlertBanner(message: message, tone: healthy ? FinanceTone.success : FinanceTone.danger);
}

class _HierarchyRow {
  const _HierarchyRow({required this.cells, this.bold = false, this.indent = false, this.onTap});
  final List<Widget> cells;
  final bool bold;
  final bool indent;
  final VoidCallback? onTap;
}

class _HierarchyTable extends StatelessWidget {
  const _HierarchyTable({required this.headers, required this.rows});
  final List<String> headers;
  final List<_HierarchyRow> rows;
  @override
  Widget build(BuildContext context) => FinanceTable(
    headers: headers,
    minWidth: 700,
    onRowTap: (int index) => rows[index].onTap?.call(),
    rows: rows
        .map(
          (_HierarchyRow row) => row.cells
              .map(
                (Widget cell) => Padding(
                  padding: row.indent ? const EdgeInsetsDirectional.only(start: FinanceSpace.lg) : EdgeInsets.zero,
                  child: DefaultTextStyle.merge(
                    style: TextStyle(fontWeight: row.bold ? FontWeight.w700 : FontWeight.w400),
                    child: cell,
                  ),
                ),
              )
              .toList(),
        )
        .toList(),
  );
}

/// A non-monetary LTR value (an account code, a percentage) — money uses
/// [FinanceAmount] instead, so its currency suffix and tabular figures stay
/// consistent with every other Finance screen.
Widget _ltrText(String value, {Color? color}) => Directionality(
  textDirection: TextDirection.ltr,
  child: Text(value, style: FinanceText.body.copyWith(color: color)),
);

class _ProfitAndLossView extends StatelessWidget {
  const _ProfitAndLossView({required this.report, required this.onDrillAccount});
  final ProfitAndLossReport report;
  final ValueChanged<int> onDrillAccount;

  @override
  Widget build(BuildContext context) {
    // The backend only compares *period totals* to the prior period
    // (`revenue`/`costOfSales`/`operatingExpenses`/`grossProfit`/
    // `netOperatingProfit`) — never a per-account figure — so the previous
    // period/variance columns are only ever populated on the section-total
    // rows below, never fabricated for an individual account row.
    final List<_HierarchyRow> rows = <_HierarchyRow>[
      _groupHeaderRow('الإيرادات'),
      ...report.revenue.map(_accountRow),
      _totalRow('صافي الإيرادات', report.totalRevenue, comparisonKey: 'revenue'),
      _groupHeaderRow('تكلفة البضاعة المباعة'),
      ...report.costOfSales.map(_accountRow),
      _totalRow(
        'مجمل الربح',
        report.grossProfit,
        comparisonKey: 'grossProfit',
        color: _amount(report.grossProfit) >= 0 ? FinanceColors.success : FinanceColors.danger,
      ),
      _groupHeaderRow('المصروفات التشغيلية'),
      ...report.operatingExpenses.map(_accountRow),
      _totalRow(
        'صافي الربح التشغيلي',
        report.netOperatingProfit,
        comparisonKey: 'netOperatingProfit',
        color: _amount(report.netOperatingProfit) >= 0 ? FinanceColors.success : FinanceColors.danger,
      ),
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        FinanceKpiGrid(
          items: <FinanceKpiData>[
            FinanceKpiData(label: 'صافي الإيرادات', value: report.totalRevenue),
            FinanceKpiData(label: 'مجمل الربح', value: report.grossProfit, tone: _amount(report.grossProfit) >= 0 ? FinanceTone.success : FinanceTone.danger),
            FinanceKpiData(label: 'صافي الربح التشغيلي', value: report.netOperatingProfit, tone: _amount(report.netOperatingProfit) >= 0 ? FinanceTone.success : FinanceTone.danger),
          ],
        ),
        const SizedBox(height: FinanceSpace.md),
        _IntegrityBanner(
          healthy: report.cogsComplete,
          message: report.cogsComplete
              ? 'تكلفة البضاعة المباعة مُرحّلة بالكامل لهذه الفترة — لا توجد فجوات في ترحيل تكلفة المخزون.'
              : 'يوجد ${report.unpostedInventoryEventsCount} حركة مخزون بلا ترحيل محاسبي ضمن هذه الفترة.',
        ),
        const SizedBox(height: FinanceSpace.lg),
        _HierarchyTable(
          headers: const <String>['البند', 'الفترة الحالية', 'الفترة السابقة', 'التغير %'],
          rows: rows,
        ),
      ],
    );
  }

  _HierarchyRow _accountRow(ReportAccountRow r) => _HierarchyRow(
    indent: true,
    onTap: () => onDrillAccount(r.id),
    cells: <Widget>[
      Text(r.name, style: FinanceText.body),
      FinanceAmount(value: r.normalisedBalance ?? '0.00'),
      const SizedBox(),
      const SizedBox(),
    ],
  );

  _HierarchyRow _groupHeaderRow(String label) => _HierarchyRow(
    cells: <Widget>[
      Text(label, style: FinanceText.body.copyWith(fontWeight: FontWeight.w700, color: FinanceColors.ink)),
      const SizedBox(),
      const SizedBox(),
      const SizedBox(),
    ],
  );

  _HierarchyRow _totalRow(String label, String value, {String? comparisonKey, Color? color}) {
    final ReportComparisonValue? cmp = comparisonKey == null ? null : report.comparison?[comparisonKey];
    return _HierarchyRow(
      bold: true,
      cells: <Widget>[
        Text(label),
        FinanceAmount(value: value, color: color),
        cmp == null ? _ltrText('—') : FinanceAmount(value: cmp.previous),
        _ltrText(cmp?.percentageChange != null ? '${cmp!.percentageChange}%' : '—'),
      ],
    );
  }

  double _amount(String value) => double.tryParse(value.replaceAll(',', '')) ?? 0;
}

class _BalanceSheetView extends StatelessWidget {
  const _BalanceSheetView({required this.report, required this.onDrillAccount});
  final BalanceSheetReport report;
  final ValueChanged<int> onDrillAccount;

  @override
  Widget build(BuildContext context) {
    _HierarchyRow group(String title) =>
        _HierarchyRow(cells: <Widget>[Text(title, style: FinanceText.body.copyWith(fontWeight: FontWeight.w700, color: FinanceColors.ink)), const SizedBox()]);
    _HierarchyRow account(ReportAccountRow r) => _HierarchyRow(
      indent: true,
      onTap: () => onDrillAccount(r.id),
      cells: <Widget>[Text(r.name, style: FinanceText.body), FinanceAmount(value: r.normalisedBalance ?? '0.00')],
    );
    _HierarchyRow total(String label, String value) =>
        _HierarchyRow(bold: true, cells: <Widget>[Text(label), FinanceAmount(value: value)]);

    final List<_HierarchyRow> rows = <_HierarchyRow>[
      group('الأصول'),
      ...report.assets.map(account),
      total('إجمالي الأصول', report.totalAssets),
      group('الالتزامات'),
      ...report.liabilities.map(account),
      total('إجمالي الالتزامات', report.totalLiabilities),
      group('حقوق الملكية'),
      ...report.equity.map(account),
      _HierarchyRow(indent: true, cells: <Widget>[const Text('أرباح الفترة الحالية (غير مقفلة)'), FinanceAmount(value: report.currentPeriodEarnings)]),
      total('إجمالي حقوق الملكية', report.totalEquity),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        FinanceKpiGrid(
          items: <FinanceKpiData>[
            FinanceKpiData(label: 'إجمالي الأصول', value: report.totalAssets),
            FinanceKpiData(label: 'إجمالي الالتزامات', value: report.totalLiabilities),
            FinanceKpiData(label: 'إجمالي حقوق الملكية', value: report.totalEquity),
          ],
        ),
        const SizedBox(height: FinanceSpace.md),
        _IntegrityBanner(
          healthy: report.balanced,
          message: report.balanced
              ? 'الأصول = الالتزامات + حقوق الملكية — الفرق ${report.difference}.'
              : 'الميزانية غير متوازنة — الفرق ${report.difference}.',
        ),
        const SizedBox(height: FinanceSpace.lg),
        _HierarchyTable(headers: const <String>['البند', 'الرصيد'], rows: rows),
      ],
    );
  }
}

class _CashFlowView extends StatelessWidget {
  const _CashFlowView({required this.report, required this.onOpenJournal});
  final CashFlowReport report;
  final ValueChanged<int> onOpenJournal;

  @override
  Widget build(BuildContext context) {
    _HierarchyRow group(String title, String amount) => _HierarchyRow(
      bold: true,
      cells: <Widget>[Text(title, style: FinanceText.body.copyWith(color: FinanceColors.ink)), FinanceAmount(value: amount)],
    );
    _HierarchyRow item(CashFlowItem i) => _HierarchyRow(
      indent: true,
      onTap: () => onOpenJournal(i.journalId),
      cells: <Widget>[Text('${i.reference} — ${i.date}', style: FinanceText.body), FinanceAmount(value: i.amount)],
    );
    double sum(List<CashFlowItem> items) =>
        items.fold<double>(0, (double s, CashFlowItem i) => s + (double.tryParse(i.amount.replaceAll(',', '')) ?? 0));
    final List<_HierarchyRow> rows = <_HierarchyRow>[
      _HierarchyRow(bold: true, cells: <Widget>[const Text('النقد والبنوك — افتتاحي'), FinanceAmount(value: report.openingCashBanks)]),
      group('الأنشطة التشغيلية', sum(report.operating).toStringAsFixed(2)),
      ...report.operating.map(item),
      group('الأنشطة الاستثمارية', sum(report.investing).toStringAsFixed(2)),
      ...report.investing.map(item),
      group('الأنشطة التمويلية', sum(report.financing).toStringAsFixed(2)),
      ...report.financing.map(item),
      _HierarchyRow(bold: true, cells: <Widget>[const Text('صافي التدفق النقدي'), FinanceAmount(value: report.netCashFlow, color: FinanceColors.success)]),
      _HierarchyRow(bold: true, cells: <Widget>[Text('النقد والبنوك — ختامي', style: FinanceText.body.copyWith(color: FinanceColors.ink)), FinanceAmount(value: report.closingCashBanks)]),
      if (report.internalTransfer.isNotEmpty)
        group('تحويلات داخلية (لا تُحسب ضمن التدفق الخارجي)', sum(report.internalTransfer).toStringAsFixed(2)),
      if (report.unclassified.isNotEmpty) ...<_HierarchyRow>[
        group('غير مصنّف', sum(report.unclassified).toStringAsFixed(2)),
        ...report.unclassified.map(item),
      ],
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        FinanceKpiGrid(
          items: <FinanceKpiData>[
            FinanceKpiData(label: 'النقد الافتتاحي', value: report.openingCashBanks),
            FinanceKpiData(label: 'صافي التدفق النقدي', value: report.netCashFlow, tone: FinanceTone.success),
            FinanceKpiData(label: 'النقد الختامي', value: report.closingCashBanks),
          ],
        ),
        const SizedBox(height: FinanceSpace.md),
        _IntegrityBanner(
          healthy: report.reconciled,
          message: report.reconciled
              ? 'الافتتاحي + صافي التدفق = الختامي.'
              : 'يوجد فرق بقيمة ${report.difference} — حركات غير مصنّفة بقيمة ${report.unclassifiedAmount}.',
        ),
        const SizedBox(height: FinanceSpace.lg),
        _HierarchyTable(headers: const <String>['البند', 'المبلغ'], rows: rows),
      ],
    );
  }
}

class _TrialBalanceView extends StatelessWidget {
  const _TrialBalanceView({
    required this.report,
    required this.includeZero,
    required this.onToggleZero,
    required this.onDrillAccount,
  });
  final TrialBalanceReport report;
  final bool includeZero;
  final VoidCallback onToggleZero;
  final ValueChanged<int> onDrillAccount;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: <Widget>[
      FinanceKpiGrid(
        items: <FinanceKpiData>[
          FinanceKpiData(label: 'إجمالي مدين', value: report.totalDebit),
          FinanceKpiData(label: 'إجمالي دائن', value: report.totalCredit),
          FinanceKpiData(label: 'الفرق', value: report.difference, tone: report.balanced ? FinanceTone.success : FinanceTone.danger),
        ],
      ),
      const SizedBox(height: FinanceSpace.md),
      _IntegrityBanner(
        healthy: report.balanced,
        message: report.balanced
            ? 'إجمالي المدين يطابق إجمالي الدائن لهذه الفترة.'
            : 'يوجد فرق بين إجمالي المدين والدائن يحتاج مراجعة.',
      ),
      const SizedBox(height: FinanceSpace.md),
      OutlinedButton.icon(
        onPressed: onToggleZero,
        style: OutlinedButton.styleFrom(
          backgroundColor: includeZero ? FinanceColors.accent : Colors.white,
          foregroundColor: includeZero ? Colors.white : FinanceColors.supporting,
        ),
        icon: Icon(includeZero ? Icons.check_box : Icons.check_box_outline_blank, size: 18),
        label: const Text('إظهار الحسابات ذات الرصيد صفر'),
      ),
      const SizedBox(height: FinanceSpace.lg),
      if (report.accounts.isEmpty)
        const FinanceEmptyState(message: 'لا توجد حسابات ضمن الفترة المحددة.')
      else
        FinanceTable(
          minWidth: 1000,
          headers: const <String>['الرمز', 'الحساب', 'النوع', 'مدين', 'دائن'],
          onRowTap: (int index) => onDrillAccount(report.accounts[index].id),
          rows: report.accounts
              .map(
                (ReportAccountRow a) => <Widget>[
                  _ltrText(a.code, color: FinanceColors.supporting),
                  Text(a.name, style: FinanceText.body.copyWith(fontWeight: FontWeight.w600)),
                  Text(a.group, style: FinanceText.body),
                  a.closingDebit == null ? _ltrText('—') : FinanceAmount(value: a.closingDebit!),
                  a.closingCredit == null ? _ltrText('—') : FinanceAmount(value: a.closingCredit!),
                ],
              )
              .toList(),
        ),
    ],
  );
}

class _GeneralLedgerView extends StatelessWidget {
  const _GeneralLedgerView({required this.report, required this.onOpenJournal});
  final GeneralLedgerReport report;
  final ValueChanged<int> onOpenJournal;

  @override
  Widget build(BuildContext context) {
    final double net = (double.tryParse(report.closingBalance.replaceAll(',', '')) ?? 0) -
        (double.tryParse(report.openingBalance.replaceAll(',', '')) ?? 0);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        FinanceKpiGrid(
          items: <FinanceKpiData>[
            FinanceKpiData(label: 'الرصيد الافتتاحي', value: report.openingBalance),
            FinanceKpiData(label: 'الحركة الصافية', value: net.toStringAsFixed(2), tone: net >= 0 ? FinanceTone.success : FinanceTone.danger),
            FinanceKpiData(label: 'الرصيد الختامي', value: report.closingBalance),
          ],
        ),
        const SizedBox(height: FinanceSpace.lg),
        if (report.lines.isEmpty)
          const FinanceEmptyState(message: 'لا توجد حركات على هذا الحساب خلال الفترة المحددة.')
        else
          FinanceTable(
            minWidth: 1200,
            headers: const <String>['التاريخ', 'رقم القيد', 'المصدر', 'الوصف', 'مدين', 'دائن', 'الرصيد الجاري'],
            onRowTap: (int index) => onOpenJournal(report.lines[index].journalId),
            rows: report.lines
                .map(
                  (GeneralLedgerLine line) => <Widget>[
                    Text(line.accountingDate, style: FinanceText.body),
                    FinanceReference(reference: line.journalReference),
                    Text(line.sourceType ?? '—', style: FinanceText.body),
                    Text(line.description, style: FinanceText.body),
                    line.debit == '0.00' ? _ltrText('—') : FinanceAmount(value: line.debit),
                    line.credit == '0.00' ? _ltrText('—') : FinanceAmount(value: line.credit),
                    FinanceAmount(value: line.runningBalance),
                  ],
                )
                .toList(),
          ),
      ],
    );
  }
}

class _SupplierAgingView extends StatelessWidget {
  const _SupplierAgingView({required this.report, required this.onOpenStatement});
  final SupplierAgingReport report;
  final ValueChanged<int> onOpenStatement;

  @override
  Widget build(BuildContext context) {
    final int overdueCount = report.suppliers
        .where((SupplierAgingRow s) => _amt(s.totalOutstanding) - _amt(s.current) > 0)
        .length;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        FinanceKpiGrid(
          items: <FinanceKpiData>[
            FinanceKpiData(label: 'إجمالي المستحقات', value: report.totalOutstanding),
            FinanceKpiData(
              label: 'إجمالي المتأخر',
              value: (_amt(report.totalOutstanding) - _amt(report.totalCurrent)).toStringAsFixed(2),
              tone: (_amt(report.totalOutstanding) - _amt(report.totalCurrent)) > 0 ? FinanceTone.danger : FinanceTone.success,
            ),
            FinanceKpiData(label: 'موردون متأخرون', value: '$overdueCount'),
          ],
        ),
        const SizedBox(height: FinanceSpace.lg),
        if (report.suppliers.isEmpty)
          const FinanceEmptyState(message: 'لا توجد مستحقات موردين قائمة كما في هذا التاريخ.')
        else
          FinanceTable(
            minWidth: 1100,
            headers: const <String>['المورد', 'الحالي', '1-30', '31-60', '61-90', '+90', 'إجمالي المستحق'],
            onRowTap: (int index) => onOpenStatement(report.suppliers[index].supplierId),
            rows: report.suppliers
                .map(
                  (SupplierAgingRow s) => <Widget>[
                    Text(s.supplierName, style: FinanceText.body.copyWith(fontWeight: FontWeight.w600)),
                    FinanceAmount(value: s.current),
                    FinanceAmount(value: s.days1To30, color: _amt(s.days1To30) > 0 ? FinanceColors.accent : null),
                    FinanceAmount(value: s.days31To60, color: _amt(s.days31To60) > 0 ? FinanceColors.accent : null),
                    FinanceAmount(value: s.days61To90, color: _amt(s.days61To90) > 0 ? FinanceColors.danger : null),
                    FinanceAmount(value: s.days90Plus, color: _amt(s.days90Plus) > 0 ? FinanceColors.danger : null),
                    FinanceAmount(value: s.totalOutstanding),
                  ],
                )
                .toList(),
          ),
      ],
    );
  }

  double _amt(String v) => double.tryParse(v.replaceAll(',', '')) ?? 0;
}

class _SupplierStatementView extends StatelessWidget {
  const _SupplierStatementView({required this.report, required this.onOpenProfile, required this.onNavigateSource});
  final SupplierStatementReport report;
  final VoidCallback onOpenProfile;
  final void Function({required String resourceKind, required int? id}) onNavigateSource;

  @override
  Widget build(BuildContext context) {
    final double net =
        (double.tryParse(report.closingBalance.replaceAll(',', '')) ?? 0) - (double.tryParse(report.openingBalance.replaceAll(',', '')) ?? 0);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Align(
          alignment: AlignmentDirectional.centerEnd,
          child: OutlinedButton.icon(
            onPressed: onOpenProfile,
            icon: const Icon(Icons.local_shipping_outlined, size: 18),
            label: const Text('ملف المورد'),
          ),
        ),
        const SizedBox(height: FinanceSpace.sm),
        FinanceKpiGrid(
          items: <FinanceKpiData>[
            FinanceKpiData(label: 'الرصيد الافتتاحي', value: report.openingBalance),
            FinanceKpiData(label: 'صافي الحركة', value: net.toStringAsFixed(2), tone: net > 0 ? FinanceTone.danger : FinanceTone.success),
            FinanceKpiData(label: 'الرصيد الختامي', value: report.closingBalance),
          ],
        ),
        const SizedBox(height: FinanceSpace.lg),
        if (report.lines.isEmpty)
          const FinanceEmptyState(message: 'لا توجد حركات لهذا المورد خلال الفترة المحددة.')
        else
          FinanceTable(
            minWidth: 1000,
            headers: const <String>['التاريخ', 'النوع', 'المرجع', 'زيادة (فاتورة)', 'دفعة', 'الرصيد الجاري'],
            onRowTap: (int index) {
              final SupplierStatementReportLine line = report.lines[index];
              if (line.resourceKind != null) onNavigateSource(resourceKind: line.resourceKind!, id: line.resourceId);
            },
            rows: report.lines
                .map(
                  (SupplierStatementReportLine line) => <Widget>[
                    Text(line.date, style: FinanceText.body),
                    FinanceStatusBadgeCustom(
                      label: line.type == 'supplier_invoice' ? 'فاتورة' : 'دفعة',
                      tone: line.type == 'supplier_invoice' ? FinanceTone.neutral : FinanceTone.success,
                    ),
                    FinanceReference(reference: line.reference),
                    line.debit == '0.00' ? _ltrText('—') : FinanceAmount(value: line.debit),
                    line.credit == '0.00' ? _ltrText('—') : FinanceAmount(value: line.credit, color: FinanceColors.success),
                    FinanceAmount(value: line.runningOutstanding),
                  ],
                )
                .toList(),
          ),
      ],
    );
  }
}

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/services/service_locator.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../shared/layouts/desktop_page_layout.dart';
import '../repositories/finance_setup_repository.dart';
import '../widgets/finance_pagination.dart';
import '../widgets/finance_source_navigation.dart';

/// The approved Finance workspace chrome.  Its content is deliberately driven
/// by Laravel responses; no amounts, readiness, or accounting state is
/// calculated in Flutter.
class FinanceWorkspaceScreen extends StatefulWidget {
  const FinanceWorkspaceScreen({super.key});

  @override
  State<FinanceWorkspaceScreen> createState() => _FinanceWorkspaceScreenState();
}

class _FinanceWorkspaceScreenState extends State<FinanceWorkspaceScreen> {
  late final FinanceSetupRepository _repository;
  late Future<_WorkspacePayload> _future;
  String _tab = 'overview';
  int _page = 1;

  static const List<_FinanceTab> _tabs = <_FinanceTab>[
    _FinanceTab('overview', 'نظرة عامة', Icons.dashboard_outlined),
    _FinanceTab('transactions', 'الحركات المالية', Icons.receipt_long_outlined),
    _FinanceTab('cashbanks', 'النقدية والبنوك', Icons.account_balance_outlined),
    _FinanceTab('expenses', 'المصروفات', Icons.request_quote_outlined),
    _FinanceTab(
      'suppliers',
      'الموردون والمستحقات',
      Icons.local_shipping_outlined,
    ),
    _FinanceTab('reconciliation', 'التسويات', Icons.compare_arrows_outlined),
    _FinanceTab('journals', 'القيود المحاسبية', Icons.menu_book_outlined),
    _FinanceTab('closing', 'الإغلاق اليومي', Icons.event_available_outlined),
    _FinanceTab('reports', 'التقارير المالية', Icons.assessment_outlined),
    _FinanceTab('accounts', 'دليل الحسابات', Icons.account_tree_outlined),
    _FinanceTab('periods', 'الفترات المحاسبية', Icons.date_range_outlined),
    _FinanceTab('settings', 'إعدادات المالية', Icons.settings_outlined),
  ];

  @override
  void initState() {
    super.initState();
    _repository = serviceLocator<FinanceSetupRepository>();
    _future = _load();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final String requested =
        GoRouterState.of(context).uri.queryParameters['tab'] ?? 'overview';
    if (_tabs.any((tab) => tab.id == requested) && requested != _tab) {
      _tab = requested;
      _page = 1;
      _future = _load();
    }
  }

  Future<_WorkspacePayload> _load() async {
    switch (_tab) {
      case 'overview':
        final List<dynamic> values =
            await Future.wait<dynamic>(<Future<dynamic>>[
              _repository.getFinanceMap('finance/dashboard'),
              _repository.getFinanceMap('finance/dashboard/trends'),
              _repository.getFinanceMap('finance/dashboard/branches'),
            ]);
        final Map<String, dynamic> branchResponse = Map<String, dynamic>.from(
          values[2] as Map,
        );
        return _WorkspacePayload(
          summary: Map<String, dynamic>.from(values[0] as Map),
          rows: (branchResponse['branches'] as List? ?? const <dynamic>[])
              .whereType<Map>()
              .map(
                (Map<dynamic, dynamic> row) => Map<String, dynamic>.from(row),
              )
              .toList(growable: false),
          supporting: Map<String, dynamic>.from(values[1] as Map),
        );
      case 'transactions':
        final List<dynamic> values = await Future.wait<dynamic>(
          <Future<dynamic>>[
            _repository.getFinanceMap('finance/transactions/summary'),
            _repository.getFinancePage(
              'finance/transactions',
              queryParameters: <String, dynamic>{'page': _page, 'perPage': 10},
            ),
          ],
        );
        final FinancePage<Map<String, dynamic>> page =
            values[1] as FinancePage<Map<String, dynamic>>;
        return _WorkspacePayload(
          summary: Map<String, dynamic>.from(values[0] as Map),
          rows: page.items,
          pagination: page.meta,
        );
      case 'cashbanks':
        final List<dynamic> values =
            await Future.wait<dynamic>(<Future<dynamic>>[
              _repository.getFinanceList('finance/cash-accounts'),
              _repository.getFinanceList('finance/bank-accounts'),
            ]);
        final List<Map<String, dynamic>> rows = <Map<String, dynamic>>[
          ...List<Map<String, dynamic>>.from(values[0] as List),
          ...List<Map<String, dynamic>>.from(values[1] as List),
        ];
        return _WorkspacePayload(
          summary: <String, dynamic>{
            'cashAccounts': (values[0] as List).length,
            'bankAccounts': (values[1] as List).length,
          },
          rows: rows,
        );
      case 'expenses':
        return _paged('finance/expenses');
      case 'suppliers':
        return _paged('finance/suppliers');
      case 'reconciliation':
        return _paged('finance/reconciliations');
      case 'journals':
        return _paged('finance/journal-entries');
      case 'closing':
        return _paged('finance/daily-closings');
      case 'reports':
        return _WorkspacePayload(
          summary: await _repository.getFinanceMap(
            'finance/reports/profit-loss',
          ),
        );
      case 'accounts':
        return _paged('finance/accounts');
      case 'periods':
        return _WorkspacePayload(
          rows: await _repository.getFinanceList('finance/accounting-periods'),
        );
      case 'settings':
        return _WorkspacePayload(
          summary: await _repository.getFinanceMap('finance/setup-status'),
        );
      default:
        return const _WorkspacePayload();
    }
  }

  Future<_WorkspacePayload> _paged(String path) async {
    final FinancePage<Map<String, dynamic>> page = await _repository
        .getFinancePage(
          path,
          queryParameters: <String, dynamic>{'page': _page, 'perPage': 10},
        );
    return _WorkspacePayload(rows: page.items, pagination: page.meta);
  }

  void _selectPage(int page) {
    if (page == _page) return;
    setState(() {
      _page = page;
      _future = _load();
    });
  }

  Future<void> _refresh() async {
    final Future<_WorkspacePayload> refreshed = _load();
    setState(() => _future = refreshed);
    await refreshed;
  }

  @override
  Widget build(BuildContext context) => Directionality(
    textDirection: TextDirection.rtl,
    child: DesktopPageLayout(
      child: FutureBuilder<_WorkspacePayload>(
        future: _future,
        builder:
            (BuildContext context, AsyncSnapshot<_WorkspacePayload> snapshot) {
              return SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    _FinanceWorkspaceHeader(onRefresh: _refresh),
                    const SizedBox(height: AppSpacing.md),
                    const _GlobalContextBar(),
                    const SizedBox(height: AppSpacing.lg),
                    if (snapshot.connectionState != ConnectionState.done)
                      const _FinanceStateCard.loading()
                    else if (snapshot.hasError)
                      _FinanceStateCard.error(onRetry: _refresh)
                    else
                      _FinancePageBody(
                        tab: _tab,
                        payload: snapshot.data ?? const _WorkspacePayload(),
                        onOpen: _openDetail,
                        onPageChanged: _selectPage,
                      ),
                  ],
                ),
              );
            },
      ),
    ),
  );

  Future<void> _openDetail(Map<String, dynamic> row) async {
    final int? id = row['id'] as int?;
    // Sections with their own operational workspace must open that workspace,
    // rather than presenting a read-only generic map.  This keeps every row
    // actionable and ensures mutations stay in the state-aware screens.
    switch (_tab) {
      case 'cashbanks':
        context.go('/finance/cash-banks');
        return;
      case 'expenses':
        context.go('/finance/expenses');
        return;
      case 'suppliers':
        context.go(
          id == null ? '/finance/suppliers' : '/finance/suppliers/$id',
        );
        return;
      case 'journals':
        context.go('/finance/journal-entries');
        return;
      case 'reconciliation':
        context.go(
          id == null
              ? '/finance/reconciliations'
              : '/finance/reconciliations/$id',
        );
        return;
      case 'closing':
        context.go(
          id == null
              ? '/finance/daily-closings'
              : '/finance/daily-closings/$id',
        );
        return;
      case 'accounts':
        context.go('/finance/accounts');
        return;
      case 'periods':
        context.go(
          id == null
              ? '/finance/accounting-periods'
              : '/finance/accounting-periods/$id',
        );
        return;
      case 'settings':
        context.go('/finance/settings');
        return;
    }
    final String? endpoint = switch (_tab) {
      'transactions' when id != null => 'finance/transactions/$id',
      'journals' when id != null => 'finance/journal-entries/$id',
      'reconciliation' when id != null => 'finance/reconciliations/$id',
      'closing' when id != null => 'finance/daily-closings/$id',
      _ => null,
    };
    if (endpoint == null) return;
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (BuildContext sheetContext) => _FinanceDetailDrawer(
        load: () => _repository.getFinanceMap(endpoint),
        title: _rowTitle(row),
      ),
    );
  }

  String _rowTitle(Map<String, dynamic> row) => _text(
    row['reference'] ??
        row['number'] ??
        row['name'] ??
        row['code'] ??
        'التفاصيل',
  );
}

class _FinancePageBody extends StatelessWidget {
  const _FinancePageBody({
    required this.tab,
    required this.payload,
    required this.onOpen,
    required this.onPageChanged,
  });
  final String tab;
  final _WorkspacePayload payload;
  final ValueChanged<Map<String, dynamic>> onOpen;
  final ValueChanged<int> onPageChanged;

  @override
  Widget build(BuildContext context) {
    final _TabContent content = _TabContent.forTab(tab);
    if (tab == 'overview') {
      return _OverviewContent(payload: payload, onOpen: onOpen);
    }
    if (tab == 'reports') {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Align(
            alignment: Alignment.centerRight,
            child: OutlinedButton.icon(
              onPressed: () => context.go('/finance/reports/general-ledger'),
              icon: const Icon(Icons.open_in_new, size: 17),
              label: const Text('فتح مركز التقارير'),
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          _ReportCenter(summary: payload.summary),
        ],
      );
    }
    if (tab == 'settings') return _SettingsContent(summary: payload.summary);
    final List<_KpiValue> kpis = _kpisFor(tab, payload);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            _PageHeader(title: content.title, subtitle: content.subtitle),
            if (_operationalRoute(tab) != null) ...<Widget>[
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerRight,
                child: OutlinedButton.icon(
                  onPressed: () => context.go(_operationalRoute(tab)!),
                  icon: const Icon(Icons.open_in_new, size: 17),
                  label: const Text('فتح مساحة العمل'),
                ),
              ),
            ],
          ],
        ),
        if (kpis.isNotEmpty) ...<Widget>[
          const SizedBox(height: AppSpacing.md),
          _KpiGrid(items: kpis),
        ],
        const SizedBox(height: AppSpacing.lg),
        if (payload.rows.isEmpty)
          const _FinanceStateCard.empty()
        else
          _FinanceTable(
            title: content.tableTitle,
            rows: payload.rows,
            onOpen: onOpen,
            pagination: payload.pagination,
            onPageChanged: onPageChanged,
          ),
      ],
    );
  }
}

String? _operationalRoute(String tab) => switch (tab) {
  'cashbanks' => '/finance/cash-banks',
  'expenses' => '/finance/expenses',
  'suppliers' => '/finance/suppliers',
  'journals' => '/finance/journal-entries',
  'reconciliation' => '/finance/reconciliations',
  'closing' => '/finance/daily-closings',
  'accounts' => '/finance/accounts',
  'periods' => '/finance/accounting-periods',
  'reports' => '/finance/reports/general-ledger',
  'settings' => '/finance/settings',
  _ => null,
};

class _FinanceWorkspaceHeader extends StatelessWidget {
  const _FinanceWorkspaceHeader({required this.onRefresh});
  final Future<void> Function() onRefresh;
  @override
  Widget build(BuildContext context) => Row(
    children: <Widget>[
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: const <Widget>[
            Text(
              'المالية',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w700,
                color: _FinanceColors.heading,
              ),
            ),
            SizedBox(height: 4),
            Text(
              'مساحة عمل موحّدة لكل شاشات المالية',
              style: TextStyle(fontSize: 13, color: _FinanceColors.muted),
            ),
          ],
        ),
      ),
      IconButton(
        tooltip: 'تحديث',
        onPressed: onRefresh,
        icon: const Icon(Icons.refresh, color: _FinanceColors.primary),
      ),
    ],
  );
}

// Kept as the workspace's tab definition renderer for embedded Finance hosts.
// The application shell now owns the visible shared Finance navigation.
// ignore: unused_element
class _FinanceTabBar extends StatelessWidget {
  const _FinanceTabBar({
    required this.selected,
    required this.tabs,
    required this.onSelect,
  });
  final String selected;
  final List<_FinanceTab> tabs;
  final ValueChanged<String> onSelect;
  @override
  Widget build(BuildContext context) => SizedBox(
    height: 40,
    child: ListView.separated(
      scrollDirection: Axis.horizontal,
      itemCount: tabs.length,
      separatorBuilder: (_, _) => const SizedBox(width: 6),
      itemBuilder: (_, int index) {
        final _FinanceTab tab = tabs[index];
        final bool active = tab.id == selected;
        return InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: () => onSelect(tab.id),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: active ? _FinanceColors.primary : Colors.white,
              border: Border.all(
                color: active ? _FinanceColors.primary : _FinanceColors.border,
              ),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              tab.label,
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w700,
                color: active ? Colors.white : _FinanceColors.primary,
              ),
            ),
          ),
        );
      },
    ),
  );
}

class _GlobalContextBar extends StatelessWidget {
  const _GlobalContextBar();
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
    decoration: _surfaceDecoration(),
    child: Wrap(
      spacing: 8,
      runSpacing: 8,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: <Widget>[
        const Text(
          'السياق العام',
          style: TextStyle(
            fontSize: 11.5,
            fontWeight: FontWeight.w700,
            color: _FinanceColors.muted,
          ),
        ),
        _ContextPill(label: 'هذا الشهر', selected: true),
        const _ContextPill(label: 'هذا الأسبوع'),
        const _ContextPill(label: 'اليوم'),
        const SizedBox(width: 8),
        const _ContextPill(label: 'الفرع: كل الفروع'),
        const Text(
          'يبقى هذا السياق ثابتاً عند التنقّل',
          style: TextStyle(fontSize: 11.5, color: _FinanceColors.lightMuted),
        ),
      ],
    ),
  );
}

class _ContextPill extends StatelessWidget {
  const _ContextPill({required this.label, this.selected = false});
  final String label;
  final bool selected;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
    decoration: BoxDecoration(
      color: selected ? _FinanceColors.tableHeader : _FinanceColors.background,
      border: Border.all(
        color: selected ? const Color(0xffE6C9A0) : _FinanceColors.border,
      ),
      borderRadius: BorderRadius.circular(20),
    ),
    child: Text(
      label,
      style: TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w600,
        color: selected ? _FinanceColors.warning : _FinanceColors.primary,
      ),
    ),
  );
}

class _PageHeader extends StatelessWidget {
  const _PageHeader({required this.title, required this.subtitle});
  final String title;
  final String subtitle;
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: <Widget>[
      Text(
        title,
        style: const TextStyle(
          fontSize: 19,
          fontWeight: FontWeight.w700,
          color: _FinanceColors.heading,
        ),
      ),
      const SizedBox(height: 3),
      Text(
        subtitle,
        style: const TextStyle(fontSize: 12.5, color: _FinanceColors.muted),
      ),
    ],
  );
}

class _KpiGrid extends StatelessWidget {
  const _KpiGrid({required this.items});
  final List<_KpiValue> items;
  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (_, BoxConstraints constraints) {
      final int count = constraints.maxWidth >= 1100
          ? 4
          : constraints.maxWidth >= 720
          ? 3
          : 2;
      return Wrap(
        spacing: 12,
        runSpacing: 12,
        children: items
            .map(
              (_KpiValue item) => SizedBox(
                width: (constraints.maxWidth - (count - 1) * 12) / count,
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: _surfaceDecoration(),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        item.label,
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: _FinanceColors.muted,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        item.value,
                        textDirection: TextDirection.ltr,
                        style: TextStyle(
                          fontSize: 19,
                          fontWeight: FontWeight.w700,
                          color: item.color,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            )
            .toList(),
      );
    },
  );
}

class _FinanceTable extends StatelessWidget {
  const _FinanceTable({
    required this.title,
    required this.rows,
    required this.onOpen,
    this.pagination,
    this.onPageChanged,
  });
  final String title;
  final List<Map<String, dynamic>> rows;
  final ValueChanged<Map<String, dynamic>> onOpen;
  final FinancePageMeta? pagination;
  final ValueChanged<int>? onPageChanged;
  @override
  Widget build(BuildContext context) {
    final List<String> columns = _visibleColumns(rows);
    return Container(
      decoration: _surfaceDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text(
              title,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: _FinanceColors.heading,
              ),
            ),
          ),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: SizedBox(
              width: 920,
              child: Column(
                children: <Widget>[
                  Container(
                    color: _FinanceColors.tableHeader,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                    child: Row(
                      children: columns
                          .map(
                            (String key) => Expanded(
                              child: Text(
                                _labelFor(key),
                                style: const TextStyle(
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.w700,
                                  color: _FinanceColors.primary,
                                ),
                              ),
                            ),
                          )
                          .toList(),
                    ),
                  ),
                  ...rows.map(
                    (Map<String, dynamic> row) => InkWell(
                      onTap: () => onOpen(row),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 14,
                        ),
                        decoration: const BoxDecoration(
                          border: Border(
                            bottom: BorderSide(color: _FinanceColors.border),
                          ),
                        ),
                        child: Row(
                          children: columns
                              .map(
                                (String key) => Expanded(
                                  child: _Cell(value: row[key], field: key),
                                ),
                              )
                              .toList(),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (pagination != null && onPageChanged != null)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: FinancePagination(
                meta: pagination!,
                onPageChanged: onPageChanged!,
              ),
            ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}

class _Cell extends StatelessWidget {
  const _Cell({required this.value, required this.field});
  final dynamic value;
  final String field;
  @override
  Widget build(BuildContext context) {
    if (field == 'status') return _StatusBadge(label: _text(value));
    final bool numeric =
        value is num ||
        field.toLowerCase().contains('amount') ||
        field.toLowerCase().contains('balance') ||
        field.toLowerCase().contains('cash');
    return Text(
      _display(value),
      textDirection: numeric ? TextDirection.ltr : TextDirection.rtl,
      overflow: TextOverflow.ellipsis,
      style: TextStyle(
        fontSize: 12.5,
        color: numeric ? _FinanceColors.heading : _FinanceColors.text,
        fontWeight: numeric ? FontWeight.w600 : FontWeight.w400,
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.label});
  final String label;
  @override
  Widget build(BuildContext context) {
    final String status = label.toLowerCase();
    final Color color =
        status.contains('paid') ||
            status.contains('posted') ||
            status.contains('completed') ||
            status.contains('active') ||
            status.contains('closed') ||
            status.contains('مدفوع') ||
            status.contains('مرحل') ||
            status.contains('مكتمل') ||
            status.contains('نشط') ||
            status.contains('مقفل')
        ? _FinanceColors.success
        : status.contains('reject') ||
              status.contains('overdue') ||
              status.contains('fail') ||
              status.contains('مرفوض') ||
              status.contains('متأخر')
        ? _FinanceColors.danger
        : _FinanceColors.warning;
    return Align(
      alignment: Alignment.centerRight,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
        decoration: BoxDecoration(
          color: color.withValues(alpha: .12),
          borderRadius: BorderRadius.circular(99),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 10.5,
            fontWeight: FontWeight.w700,
            color: color,
          ),
        ),
      ),
    );
  }
}

class _OverviewContent extends StatelessWidget {
  const _OverviewContent({required this.payload, required this.onOpen});
  final _WorkspacePayload payload;
  final ValueChanged<Map<String, dynamic>> onOpen;

  @override
  Widget build(BuildContext context) {
    final Map<String, dynamic> kpis = Map<String, dynamic>.from(
      payload.summary['kpis'] as Map? ?? const <String, dynamic>{},
    );
    const List<_OverviewKpiDefinition> definitions = <_OverviewKpiDefinition>[
      _OverviewKpiDefinition('netSales', 'صافي المبيعات'),
      _OverviewKpiDefinition('grossProfit', 'إجمالي الربح'),
      _OverviewKpiDefinition('operatingExpenses', 'المصروفات التشغيلية'),
      _OverviewKpiDefinition('operatingProfit', 'الربح التشغيلي'),
      _OverviewKpiDefinition('cashBanks', 'النقدية والبنوك'),
      _OverviewKpiDefinition('supplierPayables', 'مستحقات الموردين'),
    ];
    final List<_KpiValue> cards = definitions
        .map((_OverviewKpiDefinition definition) {
          final Map<String, dynamic> value = Map<String, dynamic>.from(
            kpis[definition.key] as Map? ?? const <String, dynamic>{},
          );
          return _KpiValue(
            definition.label,
            _text(value['current'] ?? value['total'] ?? value['outstanding']),
            _kpiColor(definition.key),
          );
        })
        .toList(growable: false);
    final List<Map<String, dynamic>> recent =
        (payload.summary['recentTransactions'] as List? ?? const <dynamic>[])
            .whereType<Map>()
            .map((Map<dynamic, dynamic> row) => Map<String, dynamic>.from(row))
            .toList(growable: false);
    final List<Map<String, dynamic>> alerts =
        (payload.summary['alerts'] as List? ?? const <dynamic>[])
            .whereType<Map>()
            .map((Map<dynamic, dynamic> row) => Map<String, dynamic>.from(row))
            .toList(growable: false);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        const _PageHeader(
          title: 'نظرة عامة',
          subtitle: 'ملخص الأداء المالي والجاهزية التشغيلية ضمن السياق المحدد',
        ),
        const SizedBox(height: AppSpacing.md),
        _KpiGrid(items: cards),
        if (payload.supporting.isNotEmpty) ...<Widget>[
          const SizedBox(height: AppSpacing.lg),
          _OverviewBreakdowns(data: payload.supporting),
        ],
        if (alerts.isNotEmpty) ...<Widget>[
          const SizedBox(height: AppSpacing.lg),
          _FinanceTable(title: 'تنبيهات تشغيلية', rows: alerts, onOpen: onOpen),
        ],
        const SizedBox(height: AppSpacing.lg),
        if (recent.isEmpty)
          const _FinanceStateCard.empty()
        else
          _FinanceTable(
            title: 'أحدث الحركات المالية',
            rows: recent,
            onOpen: onOpen,
          ),
        if (payload.rows.isNotEmpty) ...<Widget>[
          const SizedBox(height: AppSpacing.lg),
          _FinanceTable(
            title: 'أداء الفروع',
            rows: payload.rows,
            onOpen: onOpen,
          ),
        ],
      ],
    );
  }
}

class _OverviewKpiDefinition {
  const _OverviewKpiDefinition(this.key, this.label);
  final String key;
  final String label;
}

class _OverviewBreakdowns extends StatelessWidget {
  const _OverviewBreakdowns({required this.data});
  final Map<String, dynamic> data;

  @override
  Widget build(BuildContext context) {
    const Map<String, String> titles = <String, String>{
      'revenueVsExpenses': 'الإيرادات مقابل المصروفات',
      'salesCogsGrossProfit': 'المبيعات والتكلفة وإجمالي الربح',
      'expenseBreakdown': 'توزيع المصروفات',
      'paymentMethodBreakdown': 'توزيع طرق الدفع',
      'cogsDataQuality': 'اكتمال تكلفة المبيعات وجودة البيانات',
    };
    final List<Widget> sections = <Widget>[];
    for (final MapEntry<String, String> entry in titles.entries) {
      if (!data.containsKey(entry.key)) continue;
      final dynamic value = data[entry.key];
      sections.add(_BackendSection(title: entry.value, value: value));
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: sections,
    );
  }
}

class _BackendSection extends StatelessWidget {
  const _BackendSection({required this.title, required this.value});
  final String title;
  final dynamic value;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: AppSpacing.md),
    child: Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: _surfaceDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            title,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: _FinanceColors.heading,
            ),
          ),
          const SizedBox(height: 10),
          SelectableText(
            _backendText(value),
            style: const TextStyle(fontSize: 12.5, color: _FinanceColors.text),
          ),
        ],
      ),
    ),
  );
}

String _backendText(dynamic value) {
  if (value is List) return value.map(_backendText).join('\n');
  if (value is Map) {
    return value.entries
        .map(
          (MapEntry<dynamic, dynamic> entry) =>
              '${_labelFor('${entry.key}')}: ${_backendText(entry.value)}',
        )
        .join('  •  ');
  }
  return _display(value);
}

class _ReportCenter extends StatelessWidget {
  const _ReportCenter({required this.summary});
  final Map<String, dynamic> summary;
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: <Widget>[
      const _PageHeader(
        title: 'التقارير المالية',
        subtitle: 'تقارير محاسبية مصدرها دفتر الأستاذ في Laravel',
      ),
      const SizedBox(height: AppSpacing.md),
      Wrap(
        spacing: 8,
        runSpacing: 8,
        children: const <Widget>[
          _ContextPill(label: 'الأرباح والخسائر', selected: true),
          _ContextPill(label: 'المركز المالي'),
          _ContextPill(label: 'التدفقات النقدية'),
          _ContextPill(label: 'ميزان المراجعة'),
          _ContextPill(label: 'دفتر الأستاذ'),
          _ContextPill(label: 'أعمار الموردين'),
        ],
      ),
      const SizedBox(height: AppSpacing.lg),
      _StructuredDataCard(data: summary),
    ],
  );
}

class _SettingsContent extends StatelessWidget {
  const _SettingsContent({required this.summary});
  final Map<String, dynamic> summary;
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: <Widget>[
      const _PageHeader(
        title: 'إعدادات المالية',
        subtitle: 'الجاهزية والربط المالي وإعدادات التشغيل',
      ),
      const SizedBox(height: AppSpacing.lg),
      _StructuredDataCard(data: summary),
    ],
  );
}

class _StructuredDataCard extends StatelessWidget {
  const _StructuredDataCard({required this.data});
  final Map<String, dynamic> data;
  @override
  Widget build(BuildContext context) => Container(
    decoration: _surfaceDecoration(),
    padding: const EdgeInsets.all(18),
    child: data.isEmpty
        ? const Text(
            'لا توجد بيانات متاحة.',
            style: TextStyle(color: _FinanceColors.muted),
          )
        : Wrap(
            spacing: 28,
            runSpacing: 18,
            children: data.entries
                .where(
                  (MapEntry<String, dynamic> entry) =>
                      entry.value is! List && entry.value is! Map,
                )
                .map(
                  (MapEntry<String, dynamic> entry) => SizedBox(
                    width: 210,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          _labelFor(entry.key),
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: _FinanceColors.muted,
                          ),
                        ),
                        const SizedBox(height: 5),
                        Text(
                          _display(entry.value),
                          style: const TextStyle(
                            fontSize: 13.5,
                            fontWeight: FontWeight.w600,
                            color: _FinanceColors.heading,
                          ),
                        ),
                      ],
                    ),
                  ),
                )
                .toList(),
          ),
  );
}

class _FinanceStateCard extends StatelessWidget {
  const _FinanceStateCard.loading()
    : message = 'جاري تحميل البيانات المالية…',
      error = false,
      onRetry = null;
  const _FinanceStateCard.empty()
    : message = 'لا توجد بيانات ضمن السياق المحدد.',
      error = false,
      onRetry = null;
  const _FinanceStateCard.error({required this.onRetry})
    : message = 'تعذّر تحميل البيانات. تحقق من الاتصال ثم أعد المحاولة.',
      error = true;
  final String message;
  final bool error;
  final Future<void> Function()? onRetry;
  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(32),
    decoration: _surfaceDecoration(),
    child: Column(
      children: <Widget>[
        Icon(
          error ? Icons.error_outline : Icons.inbox_outlined,
          color: error ? _FinanceColors.danger : _FinanceColors.muted,
        ),
        const SizedBox(height: 10),
        Text(message, style: const TextStyle(color: _FinanceColors.muted)),
        if (onRetry != null) ...<Widget>[
          const SizedBox(height: 12),
          OutlinedButton(
            onPressed: onRetry,
            child: const Text('إعادة المحاولة'),
          ),
        ],
      ],
    ),
  );
}

class _FinanceDetailDrawer extends StatelessWidget {
  const _FinanceDetailDrawer({required this.load, required this.title});
  final Future<Map<String, dynamic>> Function() load;
  final String title;
  @override
  Widget build(BuildContext context) => Align(
    alignment: Alignment.centerLeft,
    child: Material(
      color: Colors.white,
      borderRadius: const BorderRadius.horizontal(right: Radius.circular(12)),
      child: SizedBox(
        width: 440,
        height: MediaQuery.sizeOf(context).height - 96,
        child: FutureBuilder<Map<String, dynamic>>(
          future: load(),
          builder: (_, AsyncSnapshot<Map<String, dynamic>> snapshot) => Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Row(
                  children: <Widget>[
                    Expanded(
                      child: Text(
                        title,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: _FinanceColors.heading,
                        ),
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.close),
                    ),
                  ],
                ),
                const Divider(),
                Expanded(
                  child: snapshot.connectionState != ConnectionState.done
                      ? const Center(child: CircularProgressIndicator())
                      : snapshot.hasError
                      ? const Center(child: Text('تعذّر تحميل التفاصيل.'))
                      : SingleChildScrollView(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: <Widget>[
                              FinanceSourceNavigationActions(
                                data:
                                    snapshot.data ?? const <String, dynamic>{},
                              ),
                              const SizedBox(height: 12),
                              _StructuredDataCard(
                                data:
                                    snapshot.data ?? const <String, dynamic>{},
                              ),
                            ],
                          ),
                        ),
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}

class _WorkspacePayload {
  const _WorkspacePayload({
    this.summary = const <String, dynamic>{},
    this.rows = const <Map<String, dynamic>>[],
    this.supporting = const <String, dynamic>{},
    this.pagination,
  });
  final Map<String, dynamic> summary;
  final List<Map<String, dynamic>> rows;
  final Map<String, dynamic> supporting;
  final FinancePageMeta? pagination;
}

class _FinanceTab {
  const _FinanceTab(this.id, this.label, this.icon);
  final String id;
  final String label;
  final IconData icon;
}

class _KpiValue {
  const _KpiValue(
    this.label,
    this.value, [
    this.color = _FinanceColors.heading,
  ]);
  final String label;
  final String value;
  final Color color;
}

class _TabContent {
  const _TabContent(this.title, this.subtitle, this.tableTitle);
  final String title;
  final String subtitle;
  final String tableTitle;
  static _TabContent forTab(String tab) => switch (tab) {
    'transactions' => const _TabContent(
      'الحركات المالية',
      'سجل موحّد لكل الحركات المالية في النظام',
      'أحدث الحركات',
    ),
    'cashbanks' => const _TabContent(
      'النقدية والبنوك',
      'إدارة الصناديق والحسابات البنكية من دفتر الأستاذ',
      'الحسابات',
    ),
    'expenses' => const _TabContent(
      'المصروفات',
      'متابعة المصروفات وحالات الاعتماد والدفع',
      'المصروفات',
    ),
    'suppliers' => const _TabContent(
      'الموردون والمستحقات',
      'الموردون والأرصدة المستحقة',
      'الموردون',
    ),
    'reconciliation' => const _TabContent(
      'التسويات',
      'مطابقة النظام مع كشف الحساب والنقد الفعلي',
      'التسويات',
    ),
    'journals' => const _TabContent(
      'القيود المحاسبية',
      'دفتر اليومية والقيود المرتبطة بالمصادر',
      'القيود',
    ),
    'closing' => const _TabContent(
      'الإغلاق اليومي',
      'جاهزية وإقفال الأيام التجارية',
      'الإغلاقات',
    ),
    'accounts' => const _TabContent(
      'دليل الحسابات',
      'شجرة الحسابات وحالة التفعيل',
      'الحسابات',
    ),
    'periods' => const _TabContent(
      'الفترات المحاسبية',
      'فتح وإغلاق وقفل الفترات حسب جاهزية النظام',
      'الفترات',
    ),
    _ => const _TabContent('المالية', '', 'البيانات'),
  };
}

class _FinanceColors {
  static const Color background = Color(0xffFAF7F2);
  static const Color primary = Color(0xff3B2417);
  static const Color heading = Color(0xff231005);
  static const Color text = Color(0xff1B1B1C);
  static const Color muted = Color(0xff6B6B6B);
  static const Color lightMuted = Color(0xffB7ADA2);
  static const Color border = Color(0xffE7E2DA);
  static const Color tableHeader = Color(0xffF4E7D3);
  static const Color warning = Color(0xff805437);
  static const Color success = Color(0xff2E7D32);
  static const Color danger = Color(0xffC62828);
}

BoxDecoration _surfaceDecoration() => BoxDecoration(
  color: Colors.white,
  border: Border.all(color: _FinanceColors.border),
  borderRadius: BorderRadius.circular(12),
);
List<String> _visibleColumns(List<Map<String, dynamic>> rows) {
  const List<String> preferred = <String>[
    'reference',
    'number',
    'name',
    'code',
    'branchName',
    'branch',
    'type',
    'businessDate',
    'date',
    'amount',
    'balance',
    'expectedCash',
    'actualCash',
    'difference',
    'status',
  ];
  final Set<String> all = rows
      .expand((Map<String, dynamic> row) => row.keys)
      .toSet();
  final List<String> visible = preferred.where(all.contains).take(7).toList();
  return visible.isEmpty ? all.take(6).toList() : visible;
}

List<_KpiValue> _kpisFor(String tab, _WorkspacePayload payload) {
  final Map<String, dynamic> source = payload.summary;
  if (source.isEmpty) return <_KpiValue>[const _KpiValue('النتائج', '—')];
  final List<_KpiValue> result = <_KpiValue>[];
  for (final MapEntry<String, dynamic> entry in source.entries) {
    if (entry.value is num || entry.value is String || entry.value is bool) {
      result.add(
        _KpiValue(
          _labelFor(entry.key),
          _display(entry.value),
          _kpiColor(entry.key),
        ),
      );
    }
    if (result.length == 6) break;
  }
  return result;
}

Color _kpiColor(String key) {
  final String lower = key.toLowerCase();
  return lower.contains('error') ||
          lower.contains('overdue') ||
          lower.contains('difference')
      ? _FinanceColors.danger
      : lower.contains('profit') ||
            lower.contains('cash') ||
            lower.contains('posted')
      ? _FinanceColors.success
      : _FinanceColors.heading;
}

String _labelFor(String key) {
  const Map<String, String> labels = <String, String>{
    'reference': 'المرجع',
    'number': 'الرقم',
    'name': 'الاسم',
    'code': 'الرمز',
    'branchName': 'الفرع',
    'branch': 'الفرع',
    'type': 'النوع',
    'businessDate': 'التاريخ',
    'date': 'التاريخ',
    'amount': 'المبلغ',
    'balance': 'الرصيد',
    'expectedCash': 'النقد المتوقع',
    'actualCash': 'النقد الفعلي',
    'difference': 'الفرق',
    'status': 'الحالة',
    'netSales': 'صافي المبيعات',
    'grossProfit': 'إجمالي الربح',
    'operatingExpenses': 'المصروفات التشغيلية',
    'operatingProfit': 'الربح التشغيلي',
    'cashAndBanks': 'النقدية والبنوك',
    'supplierPayables': 'مستحقات الموردين',
    'cashAccounts': 'حسابات النقدية',
    'bankAccounts': 'حسابات البنوك',
  };
  return labels[key] ??
      key
          .replaceAllMapped(
            RegExp(r'([a-z])([A-Z])'),
            (Match match) => '${match[1]} ${match[2]}',
          )
          .replaceAll('_', ' ')
          .trim();
}

String _text(dynamic value) {
  const Map<String, String> statuses = <String, String>{
    'draft': 'مسودة',
    'pending_approval': 'بانتظار الموافقة',
    'approved': 'معتمد',
    'rejected': 'مرفوض',
    'paid': 'مدفوع',
    'partially_paid': 'مدفوع جزئياً',
    'posted': 'مرحل',
    'reversed': 'معكوس',
    'active': 'نشط',
    'inactive': 'غير مفعّل',
    'in_progress': 'قيد التنفيذ',
    'completed': 'مكتملة',
    'open': 'مفتوحة',
    'closed': 'مقفلة',
    'locked': 'مقفلة نهائياً',
  };
  final String text = value?.toString() ?? '—';
  return statuses[text.toLowerCase()] ?? text;
}

String _display(dynamic value) {
  if (value == null) return '—';
  if (value is num) return CurrencyFormatter.format(value);
  if (value is Map) {
    return value['name']?.toString() ?? value['reference']?.toString() ?? '—';
  }
  return _text(value);
}

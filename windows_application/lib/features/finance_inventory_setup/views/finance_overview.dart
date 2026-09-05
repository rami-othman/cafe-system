import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/utils/currency_formatter.dart';
import '../repositories/finance_setup_repository.dart';
import '../widgets/finance_components.dart';
import '../widgets/finance_design.dart';
import '../widgets/finance_period.dart';
import '../widgets/finance_shell.dart';
import '../widgets/finance_source_navigation.dart';
import '../widgets/finance_transaction_type.dart';

class FinanceOverviewQuery {
  const FinanceOverviewQuery({
    required this.dateFrom,
    required this.dateTo,
    this.branchId,
    this.comparison = true,
  });
  final DateTime dateFrom;
  final DateTime dateTo;
  final int? branchId;
  final bool comparison;

  Map<String, dynamic> get parameters => <String, dynamic>{
    'date_from': FinancePeriod.format(dateFrom),
    'date_to': FinancePeriod.format(dateTo),
    if (branchId != null) 'branch_id': branchId,
    'comparison': comparison ? 'previous_period' : 'none',
  };
}

class FinanceOverviewPayload {
  const FinanceOverviewPayload({
    required this.dashboard,
    required this.trends,
    required this.branches,
  });
  final Map<String, dynamic> dashboard;
  final Map<String, dynamic> trends;
  final Map<String, dynamic> branches;
}

typedef FinanceOverviewLoader =
    Future<FinanceOverviewPayload> Function(FinanceOverviewQuery query);

/// Canonical dashboard consumer. Laravel supplies every financial figure;
/// this widget only maps that already-authorized payload into presentation.
class FinanceOverview extends StatefulWidget {
  const FinanceOverview({super.key, required this.loader});

  factory FinanceOverview.fromRepository(FinanceSetupRepository repository) =>
      FinanceOverview(
        loader: (FinanceOverviewQuery query) async {
          final List<Map<String, dynamic>> values =
              await Future.wait(<Future<Map<String, dynamic>>>[
                repository.getFinanceMap(
                  'finance/dashboard',
                  queryParameters: query.parameters,
                ),
                repository.getFinanceMap(
                  'finance/dashboard/trends',
                  queryParameters: query.parameters,
                ),
                repository.getFinanceMap(
                  'finance/dashboard/branches',
                  queryParameters: query.parameters,
                ),
              ]);
          return FinanceOverviewPayload(
            dashboard: values[0],
            trends: values[1],
            branches: values[2],
          );
        },
      );

  final FinanceOverviewLoader loader;
  @override
  State<FinanceOverview> createState() => _FinanceOverviewState();
}

class _FinanceOverviewState extends State<FinanceOverview> {
  late FinanceOverviewQuery _query;
  late Future<FinanceOverviewPayload> _future;
  int _requestVersion = 0;

  @override
  void initState() {
    super.initState();
    final DateTime today = DateUtils.dateOnly(DateTime.now());
    _query = FinanceOverviewQuery(
      dateFrom: DateTime(today.year, today.month),
      dateTo: today,
    );
    _future = _load();
  }

  Future<FinanceOverviewPayload> _load() => widget.loader(_query);

  void _reload(FinanceOverviewQuery next) {
    final int version = ++_requestVersion;
    final Future<FinanceOverviewPayload> future = widget.loader(next);
    setState(() {
      _query = next;
      _future = future;
    });
    future.whenComplete(() {
      if (!mounted || version != _requestVersion) return;
    });
  }

  void _setPeriod(String period) async {
    if (period == 'مخصص') {
      final DateTime today = DateUtils.dateOnly(DateTime.now());
      final DateTimeRange? range = await showDateRangePicker(
        context: context,
        firstDate: DateTime(2020),
        lastDate: DateTime(today.year + 1),
        initialDateRange: DateTimeRange(
          start: _query.dateFrom,
          end: _query.dateTo,
        ),
        helpText: 'اختيار فترة مالية',
      );
      if (range == null || !mounted) return;
      _reload(
        FinanceOverviewQuery(
          dateFrom: range.start,
          dateTo: range.end,
          branchId: _query.branchId,
          comparison: _query.comparison,
        ),
      );
      return;
    }
    final DateTimeRange range = FinancePeriod.presetRange(period);
    _reload(
      FinanceOverviewQuery(
        dateFrom: range.start,
        dateTo: range.end,
        branchId: _query.branchId,
        comparison: _query.comparison,
      ),
    );
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<FinanceOverviewPayload>(
    future: _future,
    builder:
        (BuildContext context, AsyncSnapshot<FinanceOverviewPayload> snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const FinanceLoadingState(
              label: 'جارٍ تحميل النظرة المالية…',
            );
          }
          if (snapshot.hasError) {
            return FinanceErrorState(
              message: 'تعذّر تحميل النظرة المالية. لم يتم اعتبار الخطأ صفراً.',
              onRetry: () => _reload(_query),
            );
          }
          final FinanceOverviewPayload payload = snapshot.data!;
          final Map<String, dynamic> overviewContext = _map(
            payload.dashboard['context'],
          );
          final List<FinanceBranchOption> branches =
              _list(overviewContext['branches'])
                  .map(
                    (Map<String, dynamic> branch) => FinanceBranchOption(
                      id: _int(branch['id']),
                      name: '${branch['name'] ?? ''}',
                    ),
                  )
                  .toList();
          return SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                FinanceGlobalContext(
                  selectedPeriod: FinancePeriod.labelFor(
                    _query.dateFrom,
                    _query.dateTo,
                  ),
                  onPeriod: _setPeriod,
                  branches: branches,
                  selectedBranchId: _query.branchId,
                  onBranch: (int? branchId) => _reload(
                    FinanceOverviewQuery(
                      dateFrom: _query.dateFrom,
                      dateTo: _query.dateTo,
                      branchId: branchId,
                      comparison: _query.comparison,
                    ),
                  ),
                  compareEnabled: _query.comparison,
                  onCompareChanged: (bool enabled) => _reload(
                    FinanceOverviewQuery(
                      dateFrom: _query.dateFrom,
                      dateTo: _query.dateTo,
                      branchId: _query.branchId,
                      comparison: enabled,
                    ),
                  ),
                ),
                const SizedBox(height: FinanceSpace.lg),
                _OverviewBody(payload: payload, query: _query),
              ],
            ),
          );
        },
  );
}

class _OverviewBody extends StatelessWidget {
  const _OverviewBody({required this.payload, required this.query});
  final FinanceOverviewPayload payload;
  final FinanceOverviewQuery query;

  @override
  Widget build(BuildContext context) {
    final Map<String, dynamic> dashboard = payload.dashboard;
    final Map<String, dynamic> kpis = _map(dashboard['kpis']);
    final List<Map<String, dynamic>> alerts = _list(dashboard['alerts']);
    final List<Map<String, dynamic>> transactions = _list(
      dashboard['recentTransactions'],
    );
    final Map<String, dynamic> revenueTrend = _map(
      _map(payload.trends)['revenueVsExpenses'],
    );
    final List<Map<String, dynamic>> branchRows = _list(
      _map(payload.branches)['branches'],
    );
    final bool empty = _isEmpty(kpis, revenueTrend, alerts, transactions);
    if (empty) {
      return const SizedBox(
        height: 360,
        child: FinanceEmptyState(
          message: 'لا توجد بيانات مالية للفترة المحددة',
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        FinanceKpiGrid(items: _kpiCards(context, kpis, query.comparison)),
        if (alerts.isNotEmpty) ...<Widget>[
          const SizedBox(height: FinanceSpace.lg),
          _AttentionPanel(alerts: alerts),
        ],
        const SizedBox(height: FinanceSpace.lg),
        LayoutBuilder(
          builder: (BuildContext context, BoxConstraints constraints) {
            final bool sideBySide = constraints.maxWidth >= 1080;
            if (sideBySide) {
              return SizedBox(
                height: 285,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: <Widget>[
                    Expanded(flex: 3, child: _TrendCard(data: revenueTrend)),
                    const SizedBox(width: FinanceSpace.lg),
                    Expanded(
                      flex: 2,
                      child: _BranchPerformance(rows: branchRows),
                    ),
                  ],
                ),
              );
            }
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                SizedBox(height: 285, child: _TrendCard(data: revenueTrend)),
                const SizedBox(height: FinanceSpace.lg),
                SizedBox(
                  height: 285,
                  child: _BranchPerformance(rows: branchRows),
                ),
              ],
            );
          },
        ),
        const SizedBox(height: FinanceSpace.lg),
        _RecentActivityTable(rows: transactions),
      ],
    );
  }

  List<FinanceKpiData> _kpiCards(
    BuildContext context,
    Map<String, dynamic> kpis,
    bool comparison,
  ) {
    FinanceKpiData card(
      String key,
      String label,
      IconData icon, {
      String? route,
      FinanceTone tone = FinanceTone.neutral,
    }) {
      final Map<String, dynamic> item = _map(kpis[key]);
      final String value =
          '${item['current'] ?? item['total'] ?? item['outstanding'] ?? '0.00'}';
      final String? trend = comparison && item['percentageChange'] != null
          ? '${_signed(item['percentageChange'])}% مقارنة بالفترة السابقة'
          : null;
      final String state = '${item['changeState'] ?? ''}';
      final FinanceTone resolvedTone =
          state == 'decrease' && key != 'operatingExpenses'
          ? FinanceTone.danger
          : state == 'increase' && key == 'operatingExpenses'
          ? FinanceTone.warning
          : tone;
      return FinanceKpiData(
        label: label,
        value: _money(value),
        trend: trend,
        tone: resolvedTone,
        icon: icon,
        onTap: route == null ? null : () => context.go(route),
      );
    }

    return <FinanceKpiData>[
      card(
        'netSales',
        'صافي المبيعات',
        Icons.receipt_long_outlined,
        route: '/finance?tab=transactions',
      ),
      card(
        'grossProfit',
        'إجمالي الربح',
        Icons.account_balance_wallet_outlined,
        tone: FinanceTone.success,
      ),
      card(
        'operatingExpenses',
        'المصروفات',
        Icons.request_quote_outlined,
        route: '/finance/expenses',
        tone: FinanceTone.warning,
      ),
      card(
        'operatingProfit',
        'صافي الربح التشغيلي',
        Icons.trending_up,
        tone: FinanceTone.success,
      ),
      card(
        'cashBanks',
        'النقدية والبنوك',
        Icons.account_balance_outlined,
        route: '/finance/cash-banks',
        tone: FinanceTone.success,
      ),
      card(
        'supplierPayables',
        'مستحقات الموردين',
        Icons.local_shipping_outlined,
        route: '/finance/suppliers',
        tone: FinanceTone.warning,
      ),
    ];
  }
}

class _AttentionPanel extends StatelessWidget {
  const _AttentionPanel({required this.alerts});
  final List<Map<String, dynamic>> alerts;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(FinanceSpace.lg),
    decoration: BoxDecoration(
      color: FinanceColors.card,
      border: Border.all(color: FinanceColors.border),
      borderRadius: BorderRadius.circular(FinanceRadius.card),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        const Text('يحتاج انتباهك', style: FinanceText.page),
        const SizedBox(height: FinanceSpace.sm),
        ...alerts
            .take(6)
            .map((Map<String, dynamic> alert) => _AttentionRow(alert: alert)),
      ],
    ),
  );
}

class _AttentionRow extends StatelessWidget {
  const _AttentionRow({required this.alert});
  final Map<String, dynamic> alert;
  @override
  Widget build(BuildContext context) {
    final _AlertPresentation presentation = _alertPresentation(
      '${alert['code'] ?? ''}',
    );
    final FinanceTone tone = '${alert['severity']}' == 'critical'
        ? FinanceTone.danger
        : FinanceTone.warning;
    final Map<String, dynamic> meta = _map(alert['metadata']);
    final String count = meta['count'] == null ? '' : ' (${meta['count']})';
    final String branch = _map(alert['branch'])['name']?.toString() ?? '';
    final String description = <String>[
      presentation.description + count,
      if (branch.isNotEmpty) branch,
      if (alert['amount'] != null) _money('${alert['amount']}'),
    ].join(' · ');
    final colors = financeTone(tone);
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: InkWell(
        onTap: () => context.go(presentation.route),
        borderRadius: BorderRadius.circular(FinanceRadius.control),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: FinanceSpace.sm),
          child: Row(
            children: <Widget>[
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: colors.foreground,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: FinanceSpace.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      presentation.title,
                      style: FinanceText.body.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(description, style: FinanceText.small),
                  ],
                ),
              ),
              Icon(Icons.arrow_back, size: 18, color: FinanceColors.brown),
            ],
          ),
        ),
      ),
    );
  }
}

class _TrendCard extends StatelessWidget {
  const _TrendCard({required this.data});
  final Map<String, dynamic> data;
  @override
  Widget build(BuildContext context) {
    final List<Map<String, dynamic>> series = _list(data['series']);
    final bool hasData = series.any(
      (Map<String, dynamic> point) =>
          _number(point['netSales']) != 0 ||
          _number(point['operatingExpenses']) != 0,
    );
    return _Panel(
      title: 'الإيرادات مقابل المصروفات',
      child: hasData
          ? Column(
              children: <Widget>[
                Expanded(
                  child: CustomPaint(
                    painter: _TrendPainter(series),
                    child: const SizedBox.expand(),
                  ),
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: <Widget>[
                    Text(
                      '${data['granularity'] ?? ''}',
                      style: FinanceText.small,
                    ),
                    Row(
                      children: const <Widget>[
                        _Legend(
                          color: FinanceColors.accent,
                          label: 'الإيرادات',
                        ),
                        SizedBox(width: 12),
                        _Legend(color: FinanceColors.brown, label: 'المصروفات'),
                      ],
                    ),
                  ],
                ),
              ],
            )
          : const FinanceEmptyState(
              message: 'لا توجد حركة إيرادات أو مصروفات للفترة المحددة',
            ),
    );
  }
}

class _Legend extends StatelessWidget {
  const _Legend({required this.color, required this.label});
  final Color color;
  final String label;
  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: <Widget>[
      Container(
        width: 8,
        height: 8,
        decoration: BoxDecoration(color: color, shape: BoxShape.circle),
      ),
      const SizedBox(width: 4),
      Text(label, style: FinanceText.small),
    ],
  );
}

class _TrendPainter extends CustomPainter {
  const _TrendPainter(this.series);
  final List<Map<String, dynamic>> series;
  @override
  void paint(Canvas canvas, Size size) {
    final List<double> revenue = series
        .map((Map<String, dynamic> e) => _number(e['netSales']))
        .toList();
    final List<double> expenses = series
        .map((Map<String, dynamic> e) => _number(e['operatingExpenses']))
        .toList();
    final double maximum = math.max(
      1,
      <double>[...revenue, ...expenses].reduce(math.max),
    );
    void draw(List<double> values, Color color) {
      final Paint paint = Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round;
      final Path path = Path();
      for (int index = 0; index < values.length; index++) {
        final double x = values.length == 1
            ? size.width / 2
            : index * size.width / (values.length - 1);
        final double y =
            size.height - 12 - values[index] / maximum * (size.height - 24);
        if (index == 0) {
          path.moveTo(x, y);
        } else {
          path.lineTo(x, y);
        }
      }
      canvas.drawPath(path, paint);
    }

    draw(revenue, FinanceColors.accent);
    draw(expenses, FinanceColors.brown);
  }

  @override
  bool shouldRepaint(covariant _TrendPainter old) => old.series != series;
}

class _BranchPerformance extends StatelessWidget {
  const _BranchPerformance({required this.rows});
  final List<Map<String, dynamic>> rows;
  @override
  Widget build(BuildContext context) {
    final double maximum = rows.fold<double>(
      0,
      (double maxValue, Map<String, dynamic> row) =>
          math.max(maxValue, _number(row['netSales'])),
    );
    return _Panel(
      title: 'أداء الفروع',
      child: rows.isEmpty
          ? const FinanceEmptyState(
              message: 'لا توجد بيانات فروع للفترة المحددة',
            )
          : ListView.separated(
              itemCount: rows.length,
              separatorBuilder: (_, _) =>
                  const SizedBox(height: FinanceSpace.md),
              itemBuilder: (_, int index) {
                final Map<String, dynamic> row = rows[index];
                final String name =
                    _map(row['branch'])['name']?.toString() ?? '—';
                final double value = _number(row['netSales']);
                final double factor = maximum <= 0 ? 0 : value / maximum;
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Row(
                      children: <Widget>[
                        Expanded(child: Text(name, style: FinanceText.body)),
                        Text(
                          _money('${row['netSales'] ?? '0.00'}'),
                          style: FinanceText.small,
                        ),
                      ],
                    ),
                    const SizedBox(height: 5),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(FinanceRadius.pill),
                      child: LinearProgressIndicator(
                        value: factor,
                        minHeight: 7,
                        color: FinanceColors.accent,
                        backgroundColor: FinanceColors.tableHead,
                      ),
                    ),
                  ],
                );
              },
            ),
    );
  }
}

class _RecentActivityTable extends StatelessWidget {
  const _RecentActivityTable({required this.rows});
  final List<Map<String, dynamic>> rows;
  @override
  Widget build(BuildContext context) => _Panel(
    expand: false,
    title: 'أحدث الحركات المالية',
    child: rows.isEmpty
        ? const SizedBox(
            height: 120,
            child: FinanceEmptyState(
              message: 'لا توجد حركات مالية للفترة المحددة',
            ),
          )
        : FinanceTable(
            headers: const <String>[
              'التاريخ',
              'النوع',
              'الوصف',
              'الفرع',
              'المبلغ',
              'الحالة',
            ],
            minWidth: 1050,
            onRowTap: (int index) {
              final Map<String, dynamic> row = rows[index];
              final Map<String, dynamic> source = _map(row['source']);
              final String destination =
                  FinanceSourceNavigation.destination(source) ??
                  FinanceSourceNavigation.journalDestination(row) ??
                  '/finance/journal-entries';
              context.go(destination);
            },
            rows: rows.map((Map<String, dynamic> row) {
              final Map<String, dynamic> source = _map(row['source']);
              final Map<String, dynamic> journal = _map(row['journal']);
              return <Widget>[
                Text(
                  '${row['transactionDate'] ?? '—'}',
                  style: FinanceText.small,
                ),
                FinanceTransactionTypeBadge(
                  normalizedType: source['normalizedType'] as String?,
                ),
                Text(
                  '${row['description'] ?? row['reference'] ?? '—'}',
                  style: FinanceText.body,
                ),
                Text(
                  '${_map(row['branch'])['name'] ?? '—'}',
                  style: FinanceText.small,
                ),
                FinanceAmount(
                  value:
                      '${row['displayAmount'] ?? journal['totalDebit'] ?? '0.00'}',
                ),
                FinanceStatusBadge(status: '${journal['status'] ?? 'draft'}'),
              ];
            }).toList(),
          ),
  );
}

class _Panel extends StatelessWidget {
  const _Panel({required this.title, required this.child, this.expand = true});
  final String title;
  final Widget child;
  final bool expand;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(FinanceSpace.lg),
    decoration: BoxDecoration(
      color: FinanceColors.card,
      border: Border.all(color: FinanceColors.border),
      borderRadius: BorderRadius.circular(FinanceRadius.card),
    ),
    child: Column(
      mainAxisSize: expand ? MainAxisSize.max : MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(title, style: FinanceText.page),
        const SizedBox(height: FinanceSpace.md),
        if (expand) Expanded(child: child) else child,
      ],
    ),
  );
}

class _AlertPresentation {
  const _AlertPresentation(this.title, this.description, this.route);
  final String title;
  final String description;
  final String route;
}

_AlertPresentation _alertPresentation(String code) => switch (code) {
  'PENDING_EXPENSE_APPROVAL' => const _AlertPresentation(
    'مصروفات بانتظار الاعتماد',
    'تحتاج المصروفات إلى قرار اعتماد',
    '/finance/expenses',
  ),
  'SUPPLIER_INVOICE_OVERDUE' => const _AlertPresentation(
    'فواتير موردين متأخرة',
    'توجد مستحقات تجاوزت تاريخها',
    '/finance/suppliers',
  ),
  'RECONCILIATION_INCOMPLETE' => const _AlertPresentation(
    'تسوية نقدية غير مكتملة',
    'تحتاج المطابقة إلى إكمال',
    '/finance/reconciliations',
  ),
  'DAILY_CLOSING_BLOCKED' => const _AlertPresentation(
    'إغلاق يومي متعثر',
    'توجد متطلبات تمنع الإغلاق',
    '/finance/daily-closings',
  ),
  'DRAFT_JOURNAL_ENTRIES' => const _AlertPresentation(
    'قيود مسودة',
    'توجد قيود تحتاج ترحيلاً أو مراجعة',
    '/finance/journal-entries',
  ),
  'LATE_FINANCIAL_ACTIVITY_AFTER_CLOSE' => const _AlertPresentation(
    'نشاط بعد الإغلاق',
    'تم رصد حركة مالية بعد إغلاق اليوم',
    '/finance/journal-entries',
  ),
  'UNPOSTED_INVENTORY_FINANCIAL_EVENT' => const _AlertPresentation(
    'أثر مخزني غير مرحل',
    'حركة مخزون تحتاج معالجة محاسبية',
    '/finance/journal-entries',
  ),
  _ => const _AlertPresentation(
    'تنبيه مالي',
    'توجد حالة مالية تحتاج متابعة',
    '/finance',
  ),
};

bool _isEmpty(
  Map<String, dynamic> kpis,
  Map<String, dynamic> trend,
  List<Map<String, dynamic>> alerts,
  List<Map<String, dynamic>> transactions,
) =>
    alerts.isEmpty &&
    transactions.isEmpty &&
    _list(trend['series']).every(
      (Map<String, dynamic> point) =>
          _number(point['netSales']) == 0 &&
          _number(point['operatingExpenses']) == 0,
    ) &&
    kpis.values.whereType<Map>().every(
      (Map value) =>
          _number(value['current'] ?? value['total'] ?? value['outstanding']) ==
          0,
    );
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
String _money(String value) => CurrencyFormatter.format(_number(value));
String _signed(dynamic value) {
  final double number = _number(value);
  return '${number > 0 ? '+' : ''}${number.toStringAsFixed(1)}';
}

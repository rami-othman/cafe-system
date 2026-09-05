import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';

import '../../../core/constants/app_sizes.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_radius.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../shared/layouts/desktop_page_layout.dart';
import '../../../shared/widgets/app_card.dart';
import '../controllers/reports_overview_cubit.dart';
import '../controllers/reports_overview_state.dart';
import '../models/reports_overview.dart';

class ReportsOverviewScreen extends StatelessWidget {
  const ReportsOverviewScreen({super.key});

  @override
  Widget build(
    BuildContext context,
  ) => BlocBuilder<ReportsOverviewCubit, ReportsOverviewState>(
    builder: (BuildContext context, ReportsOverviewState state) {
      final ReportsOverviewCubit cubit = context.read<ReportsOverviewCubit>();
      return DesktopPageLayout(
        padding: EdgeInsets.zero,
        child: SingleChildScrollView(
          key: const Key('reports-overview-scroll-view'),
          padding: AppSpacing.allXxl,
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(
                maxWidth: AppSizes.ordersContentMaxWidth,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  _Header(state: state, cubit: cubit),
                  const SizedBox(height: AppSpacing.xxl),
                  if (state.data != null)
                    _OverviewContent(
                      data: state.data!,
                      onBranchTap: cubit.selectBranch,
                    )
                  else if (state.status == ReportsOverviewStatus.loading)
                    const _OverviewSkeleton()
                  else
                    _ErrorState(
                      message:
                          state.errorMessage ??
                          'The overview could not be loaded.',
                      onRetry: cubit.load,
                    ),
                  if (state.data != null &&
                      state.status == ReportsOverviewStatus.loading)
                    const Padding(
                      padding: EdgeInsets.only(top: AppSpacing.md),
                      child: LinearProgressIndicator(color: AppColors.tertiary),
                    ),
                ],
              ),
            ),
          ),
        ),
      );
    },
  );
}

class _Header extends StatelessWidget {
  const _Header({required this.state, required this.cubit});
  final ReportsOverviewState state;
  final ReportsOverviewCubit cubit;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (BuildContext context, BoxConstraints constraints) {
      final bool compact = constraints.maxWidth < 980;
      final Widget actions = Wrap(
        spacing: AppSpacing.sm,
        runSpacing: AppSpacing.sm,
        children: <Widget>[
          OutlinedButton.icon(
            onPressed: () => _pickRange(context),
            icon: const Icon(Icons.date_range_outlined, size: 18),
            label: Text(_rangeLabel),
          ),
          _BranchSelector(
            branches: state.data?.branches ?? const <dynamic>[],
            selectedBranchId: state.branchId,
            onChanged: cubit.selectBranch,
          ),
          FilterChip(
            label: const Text('vs. Previous Period'),
            selected: state.comparePrevious,
            onSelected: cubit.toggleComparison,
            selectedColor: AppColors.discountIconBackground,
            checkmarkColor: AppColors.primary,
            side: const BorderSide(color: AppColors.border),
          ),
          Tooltip(
            message: 'Available in detailed report screens',
            child: OutlinedButton.icon(
              onPressed: null,
              icon: Icon(Icons.file_download_outlined, size: 18),
              label: Text('Export'),
            ),
          ),
        ],
      );
      return compact
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                _TitleBlock(),
                const SizedBox(height: AppSpacing.lg),
                actions,
              ],
            )
          : Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Expanded(child: _TitleBlock()),
                const SizedBox(width: AppSpacing.lg),
                Flexible(child: actions),
              ],
            );
    },
  );

  String get _rangeLabel {
    final range = state.range;
    if (range == null) return 'Date range';
    final formatter = DateFormat('MMM d');
    return '${formatter.format(range.start)} – ${formatter.format(range.end)}';
  }

  Future<void> _pickRange(BuildContext context) async {
    final current = state.range;
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      initialDateRange: current,
    );
    if (picked != null) await cubit.selectRange(picked);
  }
}

class _TitleBlock extends StatelessWidget {
  @override
  Widget build(BuildContext context) => const Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: <Widget>[
      Text('Reports Overview', style: AppTextStyles.headlineLarge),
      SizedBox(height: AppSpacing.xs),
      Text(
        'Track sales, profitability, cash, inventory, and branch performance from one place.',
        style: AppTextStyles.bodyMedium,
      ),
    ],
  );
}

class _BranchSelector extends StatelessWidget {
  const _BranchSelector({
    required this.branches,
    required this.selectedBranchId,
    required this.onChanged,
  });
  final List<dynamic> branches;
  final int? selectedBranchId;
  final ValueChanged<int?> onChanged;
  @override
  Widget build(BuildContext context) => Container(
    height: 40,
    padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
    decoration: BoxDecoration(
      border: Border.all(color: AppColors.border),
      borderRadius: AppRadius.control,
      color: AppColors.surface,
    ),
    child: DropdownButtonHideUnderline(
      child: DropdownButton<int?>(
        value: selectedBranchId,
        hint: const Text('All branches'),
        items: <DropdownMenuItem<int?>>[
          const DropdownMenuItem<int?>(
            value: null,
            child: Text('All branches'),
          ),
          ...branches.map(
            (dynamic branch) => DropdownMenuItem<int?>(
              value: branch.id as int,
              child: Text(branch.name as String),
            ),
          ),
        ],
        onChanged: onChanged,
      ),
    ),
  );
}

class _OverviewContent extends StatelessWidget {
  const _OverviewContent({required this.data, required this.onBranchTap});
  final ReportsOverview data;
  final ValueChanged<int?> onBranchTap;
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: <Widget>[
      _KpiGrid(kpis: data.kpis, currency: data.currency),
      const SizedBox(height: AppSpacing.xxl),
      _SalesTrendCard(points: data.salesTrend, currency: data.currency),
      const SizedBox(height: AppSpacing.xxl),
      LayoutBuilder(
        builder: (BuildContext context, BoxConstraints constraints) {
          final stack = constraints.maxWidth < 950;
          final branch = _BranchComparisonCard(
            items: data.branchComparison,
            currency: data.currency,
            onTap: onBranchTap,
          );
          final products = _TopProductsCard(
            items: data.topProducts,
            currency: data.currency,
          );
          return stack
              ? Column(
                  children: <Widget>[
                    branch,
                    const SizedBox(height: AppSpacing.xxl),
                    products,
                  ],
                )
              : Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Expanded(flex: 6, child: branch),
                    const SizedBox(width: AppSpacing.xxl),
                    Expanded(flex: 4, child: products),
                  ],
                );
        },
      ),
      const SizedBox(height: AppSpacing.xxl),
      _ExceptionsCard(items: data.recentExceptions),
      const SizedBox(height: AppSpacing.xxl),
      const Text('Browse by Category', style: AppTextStyles.titleMedium),
      const SizedBox(height: AppSpacing.md),
      const _BrowseCategories(),
    ],
  );
}

class _KpiGrid extends StatelessWidget {
  const _KpiGrid({required this.kpis, required this.currency});
  final ReportsKpis kpis;
  final String currency;
  @override
  Widget build(BuildContext context) {
    final items =
        <({String label, IconData icon, ReportMetric metric, bool percent})>[
          (
            label: 'Net Sales',
            icon: Icons.payments_outlined,
            metric: kpis.netSales,
            percent: false,
          ),
          (
            label: 'Gross Profit',
            icon: Icons.trending_up_outlined,
            metric: kpis.grossProfit,
            percent: false,
          ),
          (
            label: 'Gross Margin',
            icon: Icons.pie_chart_outline,
            metric: kpis.grossMargin,
            percent: true,
          ),
          (
            label: 'Total Expenses',
            icon: Icons.receipt_long_outlined,
            metric: kpis.totalExpenses,
            percent: false,
          ),
          (
            label: 'Net Profit',
            icon: Icons.account_balance_wallet_outlined,
            metric: kpis.netProfit,
            percent: false,
          ),
        ];
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final columns = constraints.maxWidth > 1320
            ? 5
            : constraints.maxWidth > 900
            ? 3
            : 1;
        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: items.length,
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: columns,
            mainAxisSpacing: AppSpacing.md,
            crossAxisSpacing: AppSpacing.md,
            mainAxisExtent: 150,
          ),
          itemBuilder: (BuildContext context, int index) =>
              _KpiCard(item: items[index], currency: currency),
        );
      },
    );
  }
}

class _KpiCard extends StatelessWidget {
  const _KpiCard({required this.item, required this.currency});
  final ({String label, IconData icon, ReportMetric metric, bool percent}) item;
  final String currency;
  @override
  Widget build(BuildContext context) {
    final metric = item.metric;
    final delta = metric.value != null && metric.previousValue != null
        ? metric.value! - metric.previousValue!
        : null;
    final positive = delta == null || delta >= 0;
    final deltaText = delta == null
        ? null
        : item.percent
        ? '${delta >= 0 ? '+' : ''}${delta.toStringAsFixed(1)} pts vs prev.'
        : '${delta >= 0 ? '+' : ''}${_percentage(delta, metric.previousValue!)} vs prev.';
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Container(
                padding: AppSpacing.allSm,
                decoration: const BoxDecoration(
                  color: AppColors.discountIconBackground,
                  shape: BoxShape.circle,
                ),
                child: Icon(item.icon, color: AppColors.secondary, size: 18),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(item.label, style: AppTextStyles.labelMedium),
              ),
            ],
          ),
          const Spacer(),
          if (metric.available)
            Text(
              item.percent
                  ? '${metric.value!.toStringAsFixed(1)}%'
                  : _money(metric.value!, currency),
              style: AppTextStyles.titleLarge,
            )
          else
            Tooltip(
              message: metric.reason,
              child: const Text(
                'Not available yet',
                style: AppTextStyles.titleMedium,
              ),
            ),
          const SizedBox(height: AppSpacing.xs),
          if (deltaText != null)
            Row(
              children: <Widget>[
                Icon(
                  positive ? Icons.arrow_upward : Icons.arrow_downward,
                  size: 14,
                  color: positive ? AppColors.success : AppColors.danger,
                ),
                const SizedBox(width: 3),
                Text(
                  deltaText,
                  style: AppTextStyles.labelSmall.copyWith(
                    color: positive ? AppColors.success : AppColors.danger,
                  ),
                ),
              ],
            )
          else
            const Text(
              'Comparison unavailable',
              style: AppTextStyles.labelSmall,
            ),
        ],
      ),
    );
  }

  String _percentage(double delta, double previous) =>
      previous == 0 ? '—' : '${(delta / previous * 100).toStringAsFixed(1)}%';
}

class _SalesTrendCard extends StatelessWidget {
  const _SalesTrendCard({required this.points, required this.currency});
  final List<SalesTrendPoint> points;
  final String currency;
  @override
  Widget build(BuildContext context) => AppCard(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        const Text(
          'Sales Trend — Last 14 Days',
          style: AppTextStyles.titleMedium,
        ),
        const SizedBox(height: AppSpacing.lg),
        if (points.every((point) => point.netSales == 0))
          const SizedBox(
            height: 200,
            child: Center(
              child: Text(
                'No sales recorded for this period.',
                style: AppTextStyles.bodyMedium,
              ),
            ),
          )
        else
          SizedBox(
            height: 230,
            child: _TrendChart(points: points, currency: currency),
          ),
      ],
    ),
  );
}

class _TrendChart extends StatelessWidget {
  const _TrendChart({required this.points, required this.currency});
  final List<SalesTrendPoint> points;
  final String currency;
  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (BuildContext context, BoxConstraints constraints) {
      final max = points
          .map((point) => point.netSales)
          .reduce((a, b) => a > b ? a : b);
      const padding = 18.0;
      return Stack(
        children: <Widget>[
          Positioned.fill(
            child: CustomPaint(
              painter: _TrendPainter(points: points, max: max),
            ),
          ),
          ...points.asMap().entries.map((entry) {
            final index = entry.key;
            final point = entry.value;
            final left =
                padding +
                index *
                    ((constraints.maxWidth - padding * 2) /
                        (points.length - 1));
            final top =
                12 + (1 - point.netSales / max) * (constraints.maxHeight - 48);
            return Positioned(
              left: left - 7,
              top: top - 7,
              child: Tooltip(
                message:
                    '${DateFormat('MMM d').format(point.date)}\n${_money(point.netSales, currency)}',
                child: const SizedBox(width: 14, height: 14),
              ),
            );
          }),
          Positioned(
            left: padding,
            right: padding,
            bottom: 0,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: <Widget>[
                Text(
                  DateFormat('MMM d').format(points.first.date),
                  style: AppTextStyles.labelSmall,
                ),
                Text(
                  DateFormat('MMM d').format(points.last.date),
                  style: AppTextStyles.labelSmall,
                ),
              ],
            ),
          ),
        ],
      );
    },
  );
}

class _TrendPainter extends CustomPainter {
  const _TrendPainter({required this.points, required this.max});
  final List<SalesTrendPoint> points;
  final double max;
  @override
  void paint(Canvas canvas, Size size) {
    const padding = 18.0;
    final chartHeight = size.height - 42;
    final grid = Paint()
      ..color = AppColors.border
      ..strokeWidth = 1;
    for (var row = 1; row < 4; row++) {
      canvas.drawLine(
        Offset(padding, chartHeight * row / 4),
        Offset(size.width - padding, chartHeight * row / 4),
        grid,
      );
    }
    final path = Path();
    for (var index = 0; index < points.length; index++) {
      final x =
          padding + index * ((size.width - padding * 2) / (points.length - 1));
      final y = 12 + (1 - points[index].netSales / max) * (chartHeight - 12);
      index == 0 ? path.moveTo(x, y) : path.lineTo(x, y);
    }
    final area = Path.from(path)
      ..lineTo(size.width - padding, chartHeight)
      ..lineTo(padding, chartHeight)
      ..close();
    canvas.drawPath(
      area,
      Paint()..color = AppColors.tertiary.withValues(alpha: .14),
    );
    canvas.drawPath(
      path,
      Paint()
        ..color = AppColors.tertiary
        ..strokeWidth = 3
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );
    for (var index = 0; index < points.length; index++) {
      final x =
          padding + index * ((size.width - padding * 2) / (points.length - 1));
      final y = 12 + (1 - points[index].netSales / max) * (chartHeight - 12);
      canvas.drawCircle(Offset(x, y), 3.5, Paint()..color = AppColors.surface);
      canvas.drawCircle(Offset(x, y), 2.2, Paint()..color = AppColors.tertiary);
    }
  }

  @override
  bool shouldRepaint(covariant _TrendPainter oldDelegate) =>
      oldDelegate.points != points || oldDelegate.max != max;
}

class _BranchComparisonCard extends StatelessWidget {
  const _BranchComparisonCard({
    required this.items,
    required this.currency,
    required this.onTap,
  });
  final List<BranchSales> items;
  final String currency;
  final ValueChanged<int?> onTap;
  @override
  Widget build(BuildContext context) => AppCard(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        const Text('Branch Comparison', style: AppTextStyles.titleMedium),
        const SizedBox(height: AppSpacing.lg),
        if (items.isEmpty)
          const _InlineEmpty(
            message: 'Choose all branches to compare performance.',
          )
        else
          ...items.map(
            (item) => _BranchBar(
              item: item,
              maximum: items.first.netSales,
              currency: currency,
              onTap: () => onTap(item.id),
            ),
          ),
      ],
    ),
  );
}

class _BranchBar extends StatelessWidget {
  const _BranchBar({
    required this.item,
    required this.maximum,
    required this.currency,
    required this.onTap,
  });
  final BranchSales item;
  final double maximum;
  final String currency;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => InkWell(
    onTap: onTap,
    borderRadius: AppRadius.control,
    child: Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Expanded(child: Text(item.name, style: AppTextStyles.labelLarge)),
              Text(
                _money(item.netSales, currency),
                style: AppTextStyles.labelMedium,
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xs),
          ClipRRect(
            borderRadius: AppRadius.pillRadius,
            child: LinearProgressIndicator(
              value: maximum == 0 ? 0 : item.netSales / maximum,
              minHeight: 8,
              color: AppColors.tertiary,
              backgroundColor: AppColors.discountIconBackground,
            ),
          ),
        ],
      ),
    ),
  );
}

class _TopProductsCard extends StatelessWidget {
  const _TopProductsCard({required this.items, required this.currency});
  final List<TopProduct> items;
  final String currency;
  @override
  Widget build(BuildContext context) => AppCard(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        const Text('Top Products', style: AppTextStyles.titleMedium),
        const SizedBox(height: AppSpacing.lg),
        if (items.isEmpty)
          const _InlineEmpty(message: 'No products were sold for this period.')
        else
          ...items.asMap().entries.map(
            (entry) => Tooltip(
              message: 'Product Performance report is coming next.',
              child: ListTile(
                contentPadding: EdgeInsets.zero,
                dense: true,
                leading: CircleAvatar(
                  radius: 15,
                  backgroundColor: AppColors.discountIconBackground,
                  foregroundColor: AppColors.secondary,
                  child: Text(
                    '${entry.key + 1}',
                    style: AppTextStyles.labelSmall,
                  ),
                ),
                title: Text(entry.value.name, style: AppTextStyles.labelLarge),
                trailing: Text(
                  _money(entry.value.netSales, currency),
                  style: AppTextStyles.labelMedium,
                ),
              ),
            ),
          ),
      ],
    ),
  );
}

class _ExceptionsCard extends StatelessWidget {
  const _ExceptionsCard({required this.items});
  final List<ReportException> items;
  @override
  Widget build(BuildContext context) => AppCard(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        const Text('Recent Exceptions', style: AppTextStyles.titleMedium),
        const SizedBox(height: AppSpacing.lg),
        if (items.isEmpty)
          const _InlineEmpty(
            message: 'No operational exceptions found for this period.',
          )
        else
          ...items.map(
            (item) => Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.md),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Icon(
                    item.severity == 'critical'
                        ? Icons.error_outline
                        : Icons.warning_amber_outlined,
                    color: item.severity == 'critical'
                        ? AppColors.danger
                        : AppColors.warning,
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(item.description, style: AppTextStyles.labelLarge),
                        const SizedBox(height: 2),
                        Text(
                          '${item.branch} • ${_relativeTime(item.occurredAt)}',
                          style: AppTextStyles.labelSmall,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    ),
  );
}

class _BrowseCategories extends StatelessWidget {
  const _BrowseCategories();
  @override
  Widget build(BuildContext context) {
    const items = <({String title, IconData icon})>[
      (title: 'Sales & Profitability', icon: Icons.payments_outlined),
      (title: 'Cash & Shifts', icon: Icons.point_of_sale_outlined),
      (title: 'Inventory', icon: Icons.inventory_2_outlined),
      (title: 'Expenses', icon: Icons.receipt_long_outlined),
      (title: 'Purchasing & Suppliers', icon: Icons.local_shipping_outlined),
      (title: 'Financial Reports', icon: Icons.account_balance_outlined),
      (title: 'Custom Report Builder', icon: Icons.tune_outlined),
    ];
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) =>
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: items.length,
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: constraints.maxWidth > 1150
                  ? 4
                  : constraints.maxWidth > 750
                  ? 2
                  : 1,
              childAspectRatio: 2.5,
              crossAxisSpacing: AppSpacing.md,
              mainAxisSpacing: AppSpacing.md,
            ),
            itemBuilder: (BuildContext context, int index) => AppCard(
              child: Row(
                children: <Widget>[
                  Icon(items[index].icon, color: AppColors.secondary),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: Text(
                      items[index].title,
                      style: AppTextStyles.labelLarge,
                    ),
                  ),
                  const _ComingNext(),
                ],
              ),
            ),
          ),
    );
  }
}

class _ComingNext extends StatelessWidget {
  const _ComingNext();
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: 5),
    decoration: BoxDecoration(
      color: AppColors.discountIconBackground,
      borderRadius: AppRadius.pillRadius,
    ),
    child: const Text('Coming next', style: AppTextStyles.labelSmall),
  );
}

class _InlineEmpty extends StatelessWidget {
  const _InlineEmpty({required this.message});
  final String message;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: AppSpacing.xl),
    child: Center(child: Text(message, style: AppTextStyles.bodyMedium)),
  );
}

class _OverviewSkeleton extends StatelessWidget {
  const _OverviewSkeleton();
  @override
  Widget build(BuildContext context) => Column(
    children: <Widget>[
      const _Skeleton(height: 150),
      const SizedBox(height: AppSpacing.xxl),
      const _Skeleton(height: 280),
      const SizedBox(height: AppSpacing.xxl),
      const _Skeleton(height: 240),
    ],
  );
}

class _Skeleton extends StatelessWidget {
  const _Skeleton({required this.height});
  final double height;
  @override
  Widget build(BuildContext context) => Container(
    height: height,
    decoration: BoxDecoration(
      color: AppColors.surface,
      border: Border.all(color: AppColors.border),
      borderRadius: AppRadius.card,
    ),
    child: const Padding(
      padding: AppSpacing.allLg,
      child: Align(
        alignment: Alignment.topLeft,
        child: FractionallySizedBox(
          widthFactor: .38,
          child: LinearProgressIndicator(color: AppColors.border),
        ),
      ),
    ),
  );
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.message, required this.onRetry});
  final String message;
  final VoidCallback onRetry;
  @override
  Widget build(BuildContext context) => AppCard(
    child: Padding(
      padding: const EdgeInsets.symmetric(vertical: 56),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            const Icon(
              Icons.cloud_off_outlined,
              size: 36,
              color: AppColors.textMuted,
            ),
            const SizedBox(height: AppSpacing.md),
            Text(
              message,
              textAlign: TextAlign.center,
              style: AppTextStyles.bodyMedium,
            ),
            const SizedBox(height: AppSpacing.lg),
            OutlinedButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh_outlined),
              label: const Text('Retry'),
            ),
          ],
        ),
      ),
    ),
  );
}

String _money(double value, String currency) =>
    NumberFormat.currency(symbol: '$currency ', decimalDigits: 2).format(value);
String _relativeTime(DateTime? date) {
  if (date == null) return 'Current';
  final difference = DateTime.now().difference(date.toLocal());
  if (difference.inMinutes < 60) {
    return '${difference.inMinutes.clamp(1, 59)}m ago';
  }
  if (difference.inHours < 24) return '${difference.inHours}h ago';
  return DateFormat('MMM d').format(date);
}

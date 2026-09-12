import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart' hide TextDirection;

import '../../../app/localization/localization_extensions.dart';
import '../../../core/constants/app_sizes.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_radius.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../shared/layouts/desktop_page_layout.dart';
import '../../../shared/widgets/app_card.dart';
import '../controllers/sales_profitability_cubit.dart';
import '../controllers/sales_profitability_state.dart';
import '../models/sales_profitability_report.dart';
import '../widgets/reports_overview_components.dart';

class SalesProfitabilityScreen extends StatelessWidget {
  const SalesProfitabilityScreen({super.key, required this.onBack});
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) =>
      BlocBuilder<SalesProfitabilityCubit, SalesProfitabilityState>(
        builder: (context, state) {
          final cubit = context.read<SalesProfitabilityCubit>();
          return DesktopPageLayout(
            padding: EdgeInsets.zero,
            child: SingleChildScrollView(
              key: const Key('sales-profitability-scroll-view'),
              padding: AppSpacing.allXxl,
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(
                    maxWidth: AppSizes.ordersContentMaxWidth,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      _Header(state: state, cubit: cubit, onBack: onBack),
                      if (state.data != null &&
                          state.status == SalesProfitabilityStatus.loading)
                        const Padding(
                          padding: EdgeInsets.only(top: AppSpacing.sm),
                          child: LinearProgressIndicator(minHeight: 2),
                        ),
                      const SizedBox(height: AppSpacing.xl),
                      _GroupingControl(state: state, cubit: cubit),
                      const SizedBox(height: AppSpacing.xxl),
                      if (state.data != null)
                        _ReportContent(data: state.data!, state: state)
                      else if (state.status == SalesProfitabilityStatus.loading)
                        const _Loading()
                      else
                        _Error(onRetry: cubit.load),
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
  const _Header({
    required this.state,
    required this.cubit,
    required this.onBack,
  });
  final SalesProfitabilityState state;
  final SalesProfitabilityCubit cubit;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final controls = Wrap(
        spacing: AppSpacing.sm,
        runSpacing: AppSpacing.sm,
        children: <Widget>[
          OutlinedButton.icon(
            onPressed: () => _pickRange(context),
            icon: const Icon(Icons.calendar_month_outlined, size: 18),
            label: Text(_rangeLabel(context)),
          ),
          _BranchPicker(
            branches:
                state.data?.branches ?? const <SalesProfitabilityBranch>[],
            selected: state.branchId,
            onChanged: cubit.selectBranch,
          ),
          FilterChip(
            label: Text(context.l10n.reportsOverviewComparePrevious),
            selected: state.comparePrevious,
            onSelected: cubit.toggleComparison,
            selectedColor: AppColors.discountIconBackground,
            side: const BorderSide(color: AppColors.border),
          ),
          Tooltip(
            message: context.l10n.salesProfitabilityExportTooltip,
            child: OutlinedButton.icon(
              onPressed: null,
              icon: const Icon(Icons.file_download_outlined, size: 18),
              label: Text(context.l10n.reportsOverviewExport),
            ),
          ),
        ],
      );
      final title = Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          TextButton.icon(
            onPressed: onBack,
            icon: const Icon(Icons.arrow_back_outlined, size: 18),
            label: Text(context.l10n.salesProfitabilityBack),
          ),
          Text(
            context.l10n.salesProfitabilityTitle,
            style: AppTextStyles.headlineLarge,
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            context.l10n.salesProfitabilitySubtitle,
            style: AppTextStyles.bodyMedium,
          ),
        ],
      );
      return constraints.maxWidth < 980
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                title,
                const SizedBox(height: AppSpacing.lg),
                controls,
              ],
            )
          : Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Expanded(child: title),
                const SizedBox(width: AppSpacing.lg),
                Flexible(child: controls),
              ],
            );
    },
  );

  String _rangeLabel(BuildContext context) {
    final range = state.range;
    if (range == null) return context.l10n.reportsOverviewDateRange;
    final f = DateFormat(
      'MMM d',
      Localizations.localeOf(context).toLanguageTag(),
    );
    return '${f.format(range.start)} – ${f.format(range.end)}';
  }

  Future<void> _pickRange(BuildContext context) async {
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      initialDateRange: state.range,
    );
    if (picked != null) await cubit.selectRange(picked);
  }
}

class _BranchPicker extends StatelessWidget {
  const _BranchPicker({
    required this.branches,
    required this.selected,
    required this.onChanged,
  });
  final List<SalesProfitabilityBranch> branches;
  final int? selected;
  final ValueChanged<int?> onChanged;
  @override
  Widget build(BuildContext context) => Container(
    height: 40,
    padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
    decoration: BoxDecoration(
      color: AppColors.surface,
      border: Border.all(color: AppColors.border),
      borderRadius: AppRadius.control,
    ),
    child: DropdownButtonHideUnderline(
      child: DropdownButton<int?>(
        value: branches.any((b) => b.id == selected) ? selected : null,
        hint: Text(context.l10n.reportsOverviewAllBranches),
        items: <DropdownMenuItem<int?>>[
          DropdownMenuItem(
            value: null,
            child: Text(context.l10n.reportsOverviewAllBranches),
          ),
          ...branches.map(
            (b) => DropdownMenuItem(value: b.id, child: Text(b.name)),
          ),
        ],
        onChanged: onChanged,
      ),
    ),
  );
}

class _GroupingControl extends StatelessWidget {
  const _GroupingControl({required this.state, required this.cubit});
  final SalesProfitabilityState state;
  final SalesProfitabilityCubit cubit;
  @override
  Widget build(BuildContext context) {
    final choices = <(SalesProfitabilityGrouping, String)>[
      (SalesProfitabilityGrouping.daily, context.l10n.salesProfitabilityDaily),
      (
        SalesProfitabilityGrouping.weekly,
        context.l10n.salesProfitabilityWeekly,
      ),
      (
        SalesProfitabilityGrouping.monthly,
        context.l10n.salesProfitabilityMonthly,
      ),
    ];
    return Wrap(
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: AppSpacing.sm,
      children: <Widget>[
        Text(
          context.l10n.salesProfitabilityGroupBy,
          style: AppTextStyles.labelMedium,
        ),
        Container(
          decoration: BoxDecoration(
            border: Border.all(color: AppColors.border),
            borderRadius: AppRadius.control,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: choices.map((choice) {
              final selected = state.grouping == choice.$1;
              return TextButton(
                key: Key('sales-group-${choice.$1.name}'),
                onPressed: () => cubit.selectGrouping(choice.$1),
                style: TextButton.styleFrom(
                  backgroundColor: selected
                      ? AppColors.discountIconBackground
                      : AppColors.surface,
                  foregroundColor: selected
                      ? AppColors.primary
                      : AppColors.textSecondary,
                  shape: const RoundedRectangleBorder(),
                ),
                child: Text(choice.$2),
              );
            }).toList(),
          ),
        ),
      ],
    );
  }
}

class _ReportContent extends StatelessWidget {
  const _ReportContent({required this.data, required this.state});
  final SalesProfitabilityReport data;
  final SalesProfitabilityState state;
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: <Widget>[
      _KpiGrid(kpis: data.kpis, currency: data.currency),
      const SizedBox(height: AppSpacing.xxl),
      _TrendCard(
        points: data.trendFor(state.grouping),
        currency: data.currency,
      ),
      const SizedBox(height: AppSpacing.xxl),
      LayoutBuilder(
        builder: (context, constraints) {
          final hourly = _HourlyCard(
            items: data.hourlySales,
            currency: data.currency,
          );
          final categories = _CategoryCard(
            items: data.categorySales,
            currency: data.currency,
          );
          return constraints.maxWidth < 950
              ? Column(
                  children: <Widget>[
                    hourly,
                    const SizedBox(height: AppSpacing.xxl),
                    categories,
                  ],
                )
              : Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Expanded(child: hourly),
                    const SizedBox(width: AppSpacing.xxl),
                    Expanded(child: categories),
                  ],
                );
        },
      ),
      const SizedBox(height: AppSpacing.xxl),
      _BranchCard(
        items: state.branchId == null
            ? data.branchPerformance
            : const <BranchPerformanceRow>[],
        currency: data.currency,
      ),
      const SizedBox(height: AppSpacing.xxl),
      _ProductsCard(data: data, state: state),
    ],
  );
}

class _KpiGrid extends StatelessWidget {
  const _KpiGrid({required this.kpis, required this.currency});
  final SalesProfitabilityKpis kpis;
  final String currency;
  @override
  Widget build(BuildContext context) {
    final rows =
        <
          ({
            String label,
            IconData icon,
            SalesProfitabilityMetric metric,
            bool? higherIsGood,
            bool percent,
          })
        >[
          (
            label: context.l10n.salesProfitabilityGrossSales,
            icon: Icons.payments_outlined,
            metric: kpis.grossSales,
            higherIsGood: true,
            percent: false,
          ),
          (
            label: context.l10n.salesProfitabilityNetSales,
            icon: Icons.trending_up_outlined,
            metric: kpis.netSales,
            higherIsGood: true,
            percent: false,
          ),
          (
            label: context.l10n.salesProfitabilityDiscounts,
            icon: Icons.sell_outlined,
            metric: kpis.discounts,
            higherIsGood: null,
            percent: false,
          ),
          (
            label: context.l10n.salesProfitabilityRefunds,
            icon: Icons.keyboard_return_outlined,
            metric: kpis.refunds,
            higherIsGood: false,
            percent: false,
          ),
          (
            label: context.l10n.salesProfitabilityCogs,
            icon: Icons.inventory_2_outlined,
            metric: kpis.cogs,
            higherIsGood: null,
            percent: false,
          ),
          (
            label: context.l10n.salesProfitabilityGrossProfit,
            icon: Icons.account_balance_wallet_outlined,
            metric: kpis.grossProfit,
            higherIsGood: true,
            percent: false,
          ),
          (
            label: context.l10n.salesProfitabilityGrossMargin,
            icon: Icons.pie_chart_outline,
            metric: kpis.grossMargin,
            higherIsGood: true,
            percent: true,
          ),
          (
            label: context.l10n.salesProfitabilityAverageOrder,
            icon: Icons.receipt_long_outlined,
            metric: kpis.averageOrderValue,
            higherIsGood: true,
            percent: false,
          ),
        ];
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth > 1320
            ? 4
            : constraints.maxWidth > 900
            ? 3
            : 1;
        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: rows.length,
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: columns,
            mainAxisExtent: 168,
            mainAxisSpacing: AppSpacing.md,
            crossAxisSpacing: AppSpacing.md,
          ),
          itemBuilder: (_, index) =>
              _KpiCard(item: rows[index], currency: currency),
        );
      },
    );
  }
}

class _KpiCard extends StatelessWidget {
  const _KpiCard({required this.item, required this.currency});
  final ({
    String label,
    IconData icon,
    SalesProfitabilityMetric metric,
    bool? higherIsGood,
    bool percent,
  })
  item;
  final String currency;
  @override
  Widget build(BuildContext context) {
    final delta = item.metric.value != null && item.metric.previousValue != null
        ? item.metric.value! - item.metric.previousValue!
        : null;
    final increase = delta == null || delta >= 0;
    final Color tone = item.higherIsGood == null
        ? AppColors.textMuted
        : increase == item.higherIsGood
        ? AppColors.success
        : AppColors.danger;
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
                child: Icon(item.icon, size: 17, color: AppColors.secondary),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(item.label, style: AppTextStyles.labelMedium),
              ),
            ],
          ),
          const Spacer(),
          Text(
            item.metric.available
                ? item.percent
                      ? '${item.metric.value!.toStringAsFixed(1)}%'
                      : CurrencyFormatter.formatForContext(
                          context,
                          item.metric.value!,
                          currencyCode: currency,
                        )
                : context.l10n.salesProfitabilityUnavailable,
            style: AppTextStyles.titleLarge,
          ),
          const SizedBox(height: AppSpacing.xs),
          if (delta == null)
            Text(
              context.l10n.reportsOverviewComparisonUnavailable,
              style: AppTextStyles.labelSmall,
            )
          else
            Row(
              children: <Widget>[
                Icon(
                  increase ? Icons.arrow_upward : Icons.arrow_downward,
                  size: 14,
                  color: tone,
                ),
                const SizedBox(width: 3),
                Text(
                  '${delta >= 0 ? '+' : ''}${item.percent ? delta.toStringAsFixed(1) : _change(delta, item.metric.previousValue!)}',
                  style: AppTextStyles.labelSmall.copyWith(color: tone),
                ),
              ],
            ),
        ],
      ),
    );
  }

  String _change(double delta, double previous) =>
      previous == 0 ? '—' : '${(delta / previous * 100).toStringAsFixed(1)}%';
}

class _TrendCard extends StatelessWidget {
  const _TrendCard({required this.points, required this.currency});
  final List<SalesProfitTrendPoint> points;
  final String currency;
  @override
  Widget build(BuildContext context) => ReportsOverviewSectionCard(
    title: context.l10n.salesProfitabilityTrend,
    trailing: Wrap(
      spacing: AppSpacing.md,
      children: <Widget>[
        _Legend(
          color: AppColors.tertiary,
          label: context.l10n.salesProfitabilityNetSales,
        ),
        _Legend(
          color: AppColors.secondary,
          label: context.l10n.salesProfitabilityGrossProfit,
        ),
      ],
    ),
    child: points.length < 2
        ? _InlineEmpty(message: context.l10n.salesProfitabilityNoTrend)
        : SizedBox(
            height: 230,
            child: _TrendChart(points: points, currency: currency),
          ),
  );
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
        width: 10,
        height: 10,
        decoration: BoxDecoration(color: color, shape: BoxShape.circle),
      ),
      const SizedBox(width: AppSpacing.xs),
      Text(label, style: AppTextStyles.labelSmall),
    ],
  );
}

class _TrendChart extends StatelessWidget {
  const _TrendChart({required this.points, required this.currency});
  final List<SalesProfitTrendPoint> points;
  final String currency;
  @override
  Widget build(BuildContext context) {
    final locale = Localizations.localeOf(context).toLanguageTag();
    return LayoutBuilder(
      builder: (context, constraints) => Directionality(
        textDirection: TextDirection.ltr,
        child: Stack(
          children: <Widget>[
            Positioned.fill(
              child: RepaintBoundary(
                child: CustomPaint(painter: _TrendPainter(points)),
              ),
            ),
            ...points.asMap().entries.map((entry) {
              final x =
                  18 +
                  entry.key *
                      ((constraints.maxWidth - 36) / (points.length - 1));
              final max = _max(points);
              final y =
                  12 +
                  (1 -
                          math.max(
                                entry.value.netSales,
                                entry.value.grossProfit,
                              ) /
                              max) *
                      (constraints.maxHeight - 50);
              return Positioned(
                left: x - 8,
                top: y - 8,
                child: Tooltip(
                  message:
                      '${DateFormat('MMM d', locale).format(entry.value.date)}\n${CurrencyFormatter.formatForContext(context, entry.value.netSales, currencyCode: currency)}',
                  child: const SizedBox(width: 16, height: 16),
                ),
              );
            }),
            Positioned(
              left: 18,
              right: 18,
              bottom: 0,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: <Widget>[
                  Text(
                    DateFormat('MMM d', locale).format(points.first.date),
                    key: const Key('sales-trend-start'),
                    style: AppTextStyles.labelSmall,
                  ),
                  Text(
                    DateFormat('MMM d', locale).format(points.last.date),
                    key: const Key('sales-trend-end'),
                    style: AppTextStyles.labelSmall,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

double _max(List<SalesProfitTrendPoint> points) => points
    .fold(
      1.0,
      (value, point) =>
          math.max(value, math.max(point.netSales, point.grossProfit)),
    )
    .toDouble();

class _TrendPainter extends CustomPainter {
  const _TrendPainter(this.points);
  final List<SalesProfitTrendPoint> points;
  @override
  void paint(Canvas canvas, Size size) {
    const pad = 18.0;
    final h = size.height - 42;
    final grid = Paint()..color = AppColors.border;
    for (var i = 1; i < 4; i++) {
      canvas.drawLine(
        Offset(pad, h * i / 4),
        Offset(size.width - pad, h * i / 4),
        grid,
      );
    }
    _line(canvas, size, (p) => p.netSales, AppColors.tertiary);
    _line(canvas, size, (p) => p.grossProfit, AppColors.secondary);
  }

  void _line(
    Canvas canvas,
    Size size,
    double Function(SalesProfitTrendPoint) value,
    Color color,
  ) {
    const pad = 18.0;
    final h = size.height - 42;
    final max = _max(points);
    final path = Path();
    for (var i = 0; i < points.length; i++) {
      final x = pad + i * ((size.width - pad * 2) / (points.length - 1));
      final y = 12 + (1 - value(points[i]) / max) * (h - 12);
      i == 0 ? path.moveTo(x, y) : path.lineTo(x, y);
      canvas.drawCircle(Offset(x, y), 2.5, Paint()..color = color);
    }
    canvas.drawPath(
      path,
      Paint()
        ..color = color
        ..strokeWidth = 3
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round,
    );
  }

  @override
  bool shouldRepaint(covariant _TrendPainter old) => old.points != points;
}

class _HourlyCard extends StatelessWidget {
  const _HourlyCard({required this.items, required this.currency});
  final List<HourlySalesBucket> items;
  final String currency;
  @override
  Widget build(BuildContext context) {
    final peak = items.isEmpty
        ? null
        : items.reduce((a, b) => a.sales > b.sales ? a : b);
    return ReportsOverviewSectionCard(
      title: context.l10n.salesProfitabilitySalesByHour,
      trailing: peak == null
          ? null
          : Text(
              context.l10n.salesProfitabilityPeak(peak.label),
              style: AppTextStyles.labelSmall,
            ),
      child: items.isEmpty
          ? _InlineEmpty(message: context.l10n.salesProfitabilityNoHourly)
          : SizedBox(
              height: 200,
              child: Directionality(
                textDirection: TextDirection.ltr,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: items.map((item) {
                    final factor = item.sales / math.max(1, peak!.sales);
                    final isPeak = item == peak;
                    return Expanded(
                      child: Tooltip(
                        message: CurrencyFormatter.formatForContext(
                          context,
                          item.sales,
                          currencyCode: currency,
                        ),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 3),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: <Widget>[
                              Expanded(
                                child: Align(
                                  alignment: Alignment.bottomCenter,
                                  child: FractionallySizedBox(
                                    heightFactor: factor,
                                    widthFactor: .76,
                                    child: DecoratedBox(
                                      decoration: BoxDecoration(
                                        color: isPeak
                                            ? AppColors.tertiary
                                            : AppColors.discountIconBackground,
                                        borderRadius:
                                            const BorderRadius.vertical(
                                              top: Radius.circular(
                                                AppRadius.sm,
                                              ),
                                            ),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(height: AppSpacing.sm),
                              Text(
                                item.label,
                                overflow: TextOverflow.ellipsis,
                                style: AppTextStyles.labelSmall.copyWith(
                                  color: isPeak
                                      ? AppColors.secondary
                                      : AppColors.textMuted,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),
            ),
    );
  }
}

class _CategoryCard extends StatelessWidget {
  const _CategoryCard({required this.items, required this.currency});
  final List<CategorySalesRow> items;
  final String currency;
  @override
  Widget build(BuildContext context) => ReportsOverviewSectionCard(
    title: context.l10n.salesProfitabilitySalesByCategory,
    child: items.isEmpty
        ? _InlineEmpty(message: context.l10n.salesProfitabilityNoCategories)
        : Column(
            children: <Widget>[
              for (final item in items)
                Padding(
                  padding: const EdgeInsets.only(bottom: AppSpacing.md),
                  child: Column(
                    children: <Widget>[
                      Row(
                        children: <Widget>[
                          Expanded(
                            child: Text(
                              item.name,
                              style: AppTextStyles.labelLarge,
                            ),
                          ),
                          Text(
                            '${item.percent.toStringAsFixed(1)}%',
                            style: AppTextStyles.labelSmall,
                          ),
                          const SizedBox(width: AppSpacing.md),
                          Text(
                            CurrencyFormatter.formatForContext(
                              context,
                              item.netSales,
                              currencyCode: currency,
                            ),
                            style: AppTextStyles.labelMedium,
                          ),
                        ],
                      ),
                      const SizedBox(height: AppSpacing.xs),
                      ClipRRect(
                        borderRadius: AppRadius.pillRadius,
                        child: LinearProgressIndicator(
                          value: (item.percent / 100).clamp(0, 1),
                          minHeight: 8,
                          color: AppColors.tertiary,
                          backgroundColor: AppColors.discountIconBackground,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
  );
}

class _BranchCard extends StatelessWidget {
  const _BranchCard({required this.items, required this.currency});
  final List<BranchPerformanceRow> items;
  final String currency;
  @override
  Widget build(BuildContext context) => ReportsOverviewSectionCard(
    title: context.l10n.salesProfitabilityBranchPerformance,
    child: items.isEmpty
        ? _InlineEmpty(message: context.l10n.salesProfitabilityNoBranches)
        : LayoutBuilder(
            builder: (context, constraints) {
              final double width = math
                  .max(900, constraints.maxWidth)
                  .toDouble();
              final maxNet = items.fold(1.0, (v, e) => math.max(v, e.netSales));
              final maxProfit = items.fold(
                1.0,
                (v, e) => math.max(v, e.grossProfit),
              );
              return SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: SizedBox(
                  width: width,
                  child: Column(
                    children: <Widget>[
                      _branchHeader(context),
                      ...items.map(
                        (item) => Padding(
                          padding: const EdgeInsets.symmetric(
                            vertical: AppSpacing.sm,
                            horizontal: AppSpacing.sm,
                          ),
                          child: Row(
                            children: <Widget>[
                              Expanded(
                                flex: 14,
                                child: Text(
                                  item.name,
                                  style: AppTextStyles.labelLarge,
                                ),
                              ),
                              Expanded(
                                flex: 10,
                                child: _ValueBar(
                                  value: item.netSales,
                                  max: maxNet,
                                  color: AppColors.tertiary,
                                  text: CurrencyFormatter.formatForContext(
                                    context,
                                    item.netSales,
                                    currencyCode: currency,
                                  ),
                                ),
                              ),
                              Expanded(
                                flex: 7,
                                child: Text(
                                  '${item.orders}',
                                  style: AppTextStyles.labelMedium,
                                ),
                              ),
                              Expanded(
                                flex: 10,
                                child: _ValueBar(
                                  value: item.grossProfit,
                                  max: maxProfit,
                                  color: AppColors.secondary,
                                  text: CurrencyFormatter.formatForContext(
                                    context,
                                    item.grossProfit,
                                    currencyCode: currency,
                                  ),
                                ),
                              ),
                              Expanded(
                                flex: 7,
                                child: Text(
                                  '${item.margin.toStringAsFixed(1)}%',
                                  style: AppTextStyles.labelMedium,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
  );
  Widget _branchHeader(BuildContext context) => Container(
    padding: AppSpacing.allSm,
    decoration: const BoxDecoration(
      color: AppColors.background,
      borderRadius: AppRadius.control,
    ),
    child: Row(
      children: <Widget>[
        Expanded(
          flex: 14,
          child: Text(
            context.l10n.salesProfitabilityBack,
            style: AppTextStyles.labelSmall,
          ),
        ),
        Expanded(
          flex: 10,
          child: Text(
            context.l10n.salesProfitabilityNetSales,
            style: AppTextStyles.labelSmall,
          ),
        ),
        Expanded(
          flex: 7,
          child: Text(
            context.l10n.salesProfitabilityOrders,
            style: AppTextStyles.labelSmall,
          ),
        ),
        Expanded(
          flex: 10,
          child: Text(
            context.l10n.salesProfitabilityGrossProfit,
            style: AppTextStyles.labelSmall,
          ),
        ),
        Expanded(
          flex: 7,
          child: Text(
            context.l10n.salesProfitabilityMargin,
            style: AppTextStyles.labelSmall,
          ),
        ),
      ],
    ),
  );
}

class _ValueBar extends StatelessWidget {
  const _ValueBar({
    required this.value,
    required this.max,
    required this.color,
    required this.text,
  });
  final double value;
  final double max;
  final Color color;
  final String text;
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: <Widget>[
      Text(text, style: AppTextStyles.labelMedium),
      const SizedBox(height: AppSpacing.xs),
      ClipRRect(
        borderRadius: AppRadius.pillRadius,
        child: LinearProgressIndicator(
          value: (value / max).clamp(0, 1),
          minHeight: 5,
          color: color,
          backgroundColor: AppColors.discountIconBackground,
        ),
      ),
    ],
  );
}

class _ProductsCard extends StatelessWidget {
  const _ProductsCard({required this.data, required this.state});
  final SalesProfitabilityReport data;
  final SalesProfitabilityState state;
  @override
  Widget build(BuildContext context) {
    final cubit = context.read<SalesProfitabilityCubit>();
    // Sorting is computed once by the cubit when data or sort state changes;
    // building visible rows must stay cheap while the table scrolls.
    final rows = state.sortedProducts;
    final choices = <(ProductPerformanceView, String)>[
      (
        ProductPerformanceView.topSelling,
        context.l10n.salesProfitabilityTopSelling,
      ),
      (
        ProductPerformanceView.mostProfitable,
        context.l10n.salesProfitabilityMostProfitable,
      ),
      (
        ProductPerformanceView.underperforming,
        context.l10n.salesProfitabilityUnderperforming,
      ),
    ];
    return ReportsOverviewSectionCard(
      title: context.l10n.salesProfitabilityProductPerformance,
      trailing: Wrap(
        children: choices
            .map(
              (choice) => TextButton(
                key: Key('product-view-${choice.$1.name}'),
                onPressed: () => cubit.selectProductView(choice.$1),
                style: TextButton.styleFrom(
                  backgroundColor: state.productView == choice.$1
                      ? AppColors.discountIconBackground
                      : null,
                ),
                child: Text(choice.$2),
              ),
            )
            .toList(),
      ),
      child: rows.isEmpty
          ? _InlineEmpty(message: context.l10n.salesProfitabilityNoProducts)
          : LayoutBuilder(
              builder: (context, constraints) => SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: SizedBox(
                  width: math.max(1100, constraints.maxWidth),
                  child: Column(children: <Widget>[
                    _productHeader(context, cubit),
                    SizedBox(
                      height: math.min(420.0, rows.length * 53.0),
                      child: ListView.builder(
                        primary: false,
                        itemExtent: 53,
                        itemCount: rows.length,
                        itemBuilder: (_, index) => _productRow(context, rows[index]),
                      ),
                    ),
                  ]),
                ),
              ),
            ),
    );
  }

  Widget _productHeader(BuildContext context, SalesProfitabilityCubit cubit) {
    final columns = <(String, ProductPerformanceSortField)>[
      (
        context.l10n.salesProfitabilityProduct,
        ProductPerformanceSortField.name,
      ),
      (
        context.l10n.salesProfitabilityCategory,
        ProductPerformanceSortField.category,
      ),
      (
        context.l10n.salesProfitabilityQuantity,
        ProductPerformanceSortField.quantity,
      ),
      (
        context.l10n.salesProfitabilityGrossSales,
        ProductPerformanceSortField.grossSales,
      ),
      (
        context.l10n.salesProfitabilityDiscounts,
        ProductPerformanceSortField.discounts,
      ),
      (
        context.l10n.salesProfitabilityNetSales,
        ProductPerformanceSortField.netSales,
      ),
      (context.l10n.salesProfitabilityCogs, ProductPerformanceSortField.cogs),
      (
        context.l10n.salesProfitabilityGrossProfit,
        ProductPerformanceSortField.grossProfit,
      ),
      (
        context.l10n.salesProfitabilityGrossMargin,
        ProductPerformanceSortField.margin,
      ),
    ];
    return Container(
      color: AppColors.background,
      padding: AppSpacing.allSm,
      child: Row(
        children: columns
            .map(
              (c) => Expanded(
                child: TextButton.icon(
                  onPressed: () => cubit.toggleSort(c.$2),
                  icon: Icon(
                    state.sortField == c.$2
                        ? state.sortDirection == ProductSortDirection.descending
                              ? Icons.arrow_downward
                              : Icons.arrow_upward
                        : Icons.unfold_more,
                    size: 13,
                  ),
                  label: Text(c.$1, overflow: TextOverflow.ellipsis),
                  style: TextButton.styleFrom(
                    padding: EdgeInsets.zero,
                    textStyle: AppTextStyles.labelSmall,
                  ),
                ),
              ),
            )
            .toList(),
      ),
    );
  }

  Widget _productRow(BuildContext context, ProductPerformanceRow row) =>
      Padding(
        padding: const EdgeInsets.symmetric(
          vertical: AppSpacing.md,
          horizontal: AppSpacing.sm,
        ),
        child: Row(
          children: <Widget>[
            Expanded(child: Text(row.name, style: AppTextStyles.labelLarge)),
            Expanded(child: Text(row.category, style: AppTextStyles.bodySmall)),
            Expanded(
              child: Text('${row.quantity}', style: AppTextStyles.labelMedium),
            ),
            Expanded(child: _money(context, row.grossSales)),
            Expanded(
              child: _money(context, row.discounts, color: AppColors.warning),
            ),
            Expanded(child: _money(context, row.netSales)),
            Expanded(child: _money(context, row.cogs)),
            Expanded(child: _money(context, row.grossProfit)),
            Expanded(
              child: Text(
                '${row.margin.toStringAsFixed(1)}%',
                style: AppTextStyles.labelMedium,
              ),
            ),
          ],
        ),
      );
  Widget _money(BuildContext context, double amount, {Color? color}) => Text(
    CurrencyFormatter.formatForContext(
      context,
      amount,
      currencyCode: data.currency,
    ),
    style: AppTextStyles.labelMedium.copyWith(color: color),
  );
}

class _InlineEmpty extends StatelessWidget {
  const _InlineEmpty({required this.message});
  final String message;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: AppSpacing.xl),
    child: Center(
      child: Text(
        message,
        textAlign: TextAlign.center,
        style: AppTextStyles.bodyMedium,
      ),
    ),
  );
}

class _Loading extends StatelessWidget {
  const _Loading();
  @override
  Widget build(BuildContext context) => Column(
    children: <Widget>[
      const ReportsOverviewSkeletonCard(height: 140),
      const SizedBox(height: AppSpacing.xxl),
      const ReportsOverviewSkeletonCard(height: 260),
      const SizedBox(height: AppSpacing.xxl),
      const ReportsOverviewSkeletonCard(height: 240),
      const SizedBox(height: AppSpacing.xxl),
      const ReportsOverviewSkeletonCard(height: 280),
    ],
  );
}

class _Error extends StatelessWidget {
  const _Error({required this.onRetry});
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
              context.l10n.salesProfitabilityError,
              style: AppTextStyles.bodyMedium,
            ),
            const SizedBox(height: AppSpacing.lg),
            OutlinedButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh_outlined),
              label: Text(context.l10n.commonRetry),
            ),
          ],
        ),
      ),
    ),
  );
}

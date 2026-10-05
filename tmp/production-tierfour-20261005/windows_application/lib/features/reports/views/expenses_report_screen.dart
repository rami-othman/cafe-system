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
import '../controllers/expenses_report_cubit.dart';
import '../controllers/expenses_report_state.dart';
import '../models/expenses_report.dart';
import '../widgets/reports_overview_components.dart';

class ExpensesReportScreen extends StatelessWidget {
  const ExpensesReportScreen({super.key, required this.onBack});
  final VoidCallback onBack;
  @override
  Widget build(BuildContext context) =>
      BlocBuilder<ExpensesReportCubit, ExpensesReportState>(
        builder: (context, state) {
          final cubit = context.read<ExpensesReportCubit>();
          return DesktopPageLayout(
            padding: EdgeInsets.zero,
            child: SingleChildScrollView(
              key: const Key('expenses-report-scroll'),
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
                          state.status == ExpensesReportLoadStatus.loading)
                        const Padding(
                          padding: EdgeInsets.only(top: AppSpacing.sm),
                          child: LinearProgressIndicator(minHeight: 2),
                        ),
                      const SizedBox(height: AppSpacing.xxl),
                      if (state.data != null)
                        _Content(data: state.data!, state: state, cubit: cubit)
                      else if (state.status == ExpensesReportLoadStatus.loading)
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
  final ExpensesReportState state;
  final ExpensesReportCubit cubit;
  final VoidCallback onBack;
  @override
  Widget build(BuildContext context) {
    final data = state.data;
    final title = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        TextButton.icon(
          onPressed: onBack,
          icon: const Icon(Icons.arrow_back_outlined, size: 18),
          label: Text(context.l10n.salesProfitabilityBack),
        ),
        Text(
          context.l10n.expensesReportTitle,
          style: AppTextStyles.headlineLarge,
        ),
        const SizedBox(height: AppSpacing.xs),
        Text(
          context.l10n.expensesReportSubtitle,
          style: AppTextStyles.bodyMedium,
        ),
      ],
    );
    final controls = Wrap(
      spacing: AppSpacing.sm,
      runSpacing: AppSpacing.sm,
      children: <Widget>[
        OutlinedButton.icon(
          key: const Key('expenses-date-filter'),
          onPressed: () => _pick(context),
          icon: const Icon(Icons.calendar_month_outlined, size: 18),
          label: Text(context.l10n.reportsOverviewDateRange),
        ),
        _IdPicker(
          key: const Key('expenses-branch-filter'),
          hint: context.l10n.reportsOverviewAllBranches,
          options: data?.branches ?? const [],
          value: state.branchId,
          onChanged: cubit.selectBranch,
        ),
        _IdPicker(
          key: const Key('expenses-category-filter'),
          hint: context.l10n.expensesReportAllCategories,
          options: data?.categories ?? const [],
          value: state.categoryId,
          onChanged: cubit.selectCategory,
        ),
        _StatusPicker(
          key: const Key('expenses-status-filter'),
          hint: context.l10n.expensesReportAllStatuses,
          options: data?.statuses ?? const [],
          value: state.expenseStatus,
          onChanged: cubit.selectStatus,
        ),
        FilterChip(
          key: const Key('expenses-comparison-toggle'),
          label: Text(context.l10n.reportsOverviewComparePrevious),
          selected: state.comparePrevious,
          onSelected: cubit.toggleComparison,
        ),
        Tooltip(
          message: context.l10n.expensesReportExportTooltip,
          child: OutlinedButton.icon(
            onPressed: null,
            icon: const Icon(Icons.file_download_outlined, size: 18),
            label: Text(context.l10n.reportsOverviewExport),
          ),
        ),
      ],
    );
    return LayoutBuilder(
      builder: (_, constraints) => constraints.maxWidth < 980
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
            ),
    );
  }

  Future<void> _pick(BuildContext context) async {
    final result = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      initialDateRange: state.range,
    );
    if (result != null) await cubit.selectRange(result);
  }
}

class _IdPicker extends StatelessWidget {
  const _IdPicker({
    super.key,
    required this.hint,
    required this.options,
    required this.value,
    required this.onChanged,
  });
  final String hint;
  final List<ExpenseReportFilterOption> options;
  final int? value;
  final ValueChanged<int?> onChanged;
  @override
  Widget build(BuildContext context) => _Control(
    child: DropdownButton<int?>(
      value: options.any((x) => x.id == value) ? value : null,
      hint: Text(hint),
      underline: const SizedBox(),
      items: <DropdownMenuItem<int?>>[
        DropdownMenuItem(value: null, child: Text(hint)),
        ...options.map(
          (x) => DropdownMenuItem(value: x.id, child: Text(x.name)),
        ),
      ],
      onChanged: onChanged,
    ),
  );
}

class _StatusPicker extends StatelessWidget {
  const _StatusPicker({
    super.key,
    required this.hint,
    required this.options,
    required this.value,
    required this.onChanged,
  });
  final String hint;
  final List<ExpenseReportStatus> options;
  final ExpenseReportStatus? value;
  final ValueChanged<ExpenseReportStatus?> onChanged;
  @override
  Widget build(BuildContext context) => _Control(
    child: DropdownButton<ExpenseReportStatus?>(
      value: options.contains(value) ? value : null,
      hint: Text(hint),
      underline: const SizedBox(),
      items: <DropdownMenuItem<ExpenseReportStatus?>>[
        DropdownMenuItem(value: null, child: Text(hint)),
        ...options.map(
          (x) =>
              DropdownMenuItem(value: x, child: Text(_statusLabel(context, x))),
        ),
      ],
      onChanged: onChanged,
    ),
  );
}

class _Control extends StatelessWidget {
  const _Control({required this.child});
  final Widget child;
  @override
  Widget build(BuildContext context) => Container(
    height: 40,
    padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
    decoration: BoxDecoration(
      color: AppColors.surface,
      border: Border.all(color: AppColors.border),
      borderRadius: AppRadius.control,
    ),
    child: DropdownButtonHideUnderline(child: child),
  );
}

class _Content extends StatelessWidget {
  const _Content({
    required this.data,
    required this.state,
    required this.cubit,
  });
  final ExpensesReport data;
  final ExpensesReportState state;
  final ExpensesReportCubit cubit;
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: <Widget>[
      _Kpis(data: data),
      const SizedBox(height: AppSpacing.xxl),
      LayoutBuilder(
        builder: (_, b) => b.maxWidth < 950
            ? Column(
                children: <Widget>[
                  _Trend(data: data),
                  const SizedBox(height: AppSpacing.xxl),
                  _Categories(data: data),
                ],
              )
            : Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Expanded(child: _Trend(data: data)),
                  const SizedBox(width: AppSpacing.xxl),
                  Expanded(child: _Categories(data: data)),
                ],
              ),
      ),
      const SizedBox(height: AppSpacing.xxl),
      LayoutBuilder(
        builder: (_, b) => b.maxWidth < 950
            ? Column(
                children: <Widget>[
                  _Largest(data: data),
                  const SizedBox(height: AppSpacing.xxl),
                  _BranchComparison(data: data),
                ],
              )
            : Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Expanded(child: _Largest(data: data)),
                  const SizedBox(width: AppSpacing.xxl),
                  Expanded(child: _BranchComparison(data: data)),
                ],
              ),
      ),
      const SizedBox(height: AppSpacing.xxl),
      _PeriodComparison(data: data),
      const SizedBox(height: AppSpacing.xxl),
      _ExpenseTable(data: data, state: state, cubit: cubit),
    ],
  );
}

class _Kpis extends StatelessWidget {
  const _Kpis({required this.data});
  final ExpensesReport data;
  @override
  Widget build(BuildContext context) {
    final entries = <(String, IconData, ExpenseMetric, bool, bool)>[
      (
        context.l10n.expensesReportTotal,
        Icons.receipt_long_outlined,
        data.kpis.total,
        true,
        false,
      ),
      (
        context.l10n.expensesReportPosted,
        Icons.task_alt_outlined,
        data.kpis.posted,
        false,
        false,
      ),
      (
        context.l10n.expensesReportPending,
        Icons.hourglass_empty_outlined,
        data.kpis.pending,
        true,
        false,
      ),
      (
        context.l10n.expensesReportAverageDaily,
        Icons.calendar_today_outlined,
        data.kpis.averageDaily,
        false,
        false,
      ),
      (
        context.l10n.expensesReportRatio,
        Icons.percent_outlined,
        data.kpis.expenseToSalesRatio,
        true,
        true,
      ),
      (
        context.l10n.expensesReportLargestCategory,
        Icons.category_outlined,
        data.kpis.largestCategory,
        false,
        false,
      ),
    ];
    return LayoutBuilder(
      builder: (_, b) {
        final cols = b.maxWidth > 1320
            ? 3
            : b.maxWidth > 800
            ? 2
            : 1;
        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: entries.length,
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: cols,
            mainAxisExtent: 158,
            crossAxisSpacing: AppSpacing.md,
            mainAxisSpacing: AppSpacing.md,
          ),
          itemBuilder: (_, i) {
            final e = entries[i];
            final delta = e.$3.value == null || e.$3.previousValue == null
                ? null
                : e.$3.value! - e.$3.previousValue!;
            final adverse = e.$4 && delta != null && delta > 0;
            return AppCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Row(
                    children: <Widget>[
                      Icon(e.$2, size: 18, color: AppColors.secondary),
                      const SizedBox(width: AppSpacing.sm),
                      Expanded(
                        child: Text(e.$1, style: AppTextStyles.labelMedium),
                      ),
                      Tooltip(
                        message: e.$1,
                        child: const Icon(
                          Icons.info_outline,
                          size: 16,
                          color: AppColors.textMuted,
                        ),
                      ),
                    ],
                  ),
                  const Spacer(),
                  Text(
                    _metric(context, e.$3, data.currency, percent: e.$5),
                    style: AppTextStyles.titleLarge,
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    delta == null
                        ? context.l10n.expensesReportComparisonUnavailable
                        : '${delta >= 0 ? '+' : ''}${e.$5 ? delta.toStringAsFixed(1) : delta.toStringAsFixed(0)}${e.$5 ? '%' : ''}',
                    style: AppTextStyles.labelSmall.copyWith(
                      color: adverse ? AppColors.danger : AppColors.textMuted,
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}

class _Trend extends StatelessWidget {
  const _Trend({required this.data});
  final ExpensesReport data;
  @override
  Widget build(BuildContext context) {
    final points = List<ExpenseTrendPoint>.from(data.trend)
      ..sort((a, b) => a.date.compareTo(b.date));
    return _Section(
      title: context.l10n.expensesReportTrend,
      child: points.isEmpty
          ? _Empty(context.l10n.expensesReportNoExpenses)
          : SizedBox(
              height: 230,
              child: _TrendChart(points: points, currency: data.currency),
            ),
    );
  }
}

class _TrendChart extends StatelessWidget {
  const _TrendChart({required this.points, required this.currency});
  final List<ExpenseTrendPoint> points;
  final String currency;
  @override
  Widget build(BuildContext context) {
    final locale = Localizations.localeOf(context).toLanguageTag();
    return Directionality(
      textDirection: TextDirection.ltr,
      child: LayoutBuilder(
        builder: (_, b) {
          final max = points
              .fold(
                1.0,
                (v, e) => math.max(v, math.max(e.value, e.previousValue ?? 0)),
              )
              .toDouble();
          return Stack(
            children: <Widget>[
              Positioned.fill(
                child: RepaintBoundary(
                  child: CustomPaint(
                    painter: _ExpensesTrendPainter(points: points, max: max),
                  ),
                ),
              ),
              ...points.asMap().entries.map((e) {
                final x =
                    18.0 +
                    e.key *
                        ((b.maxWidth - 36) / math.max(1, points.length - 1));
                final y = 12.0 + (1 - e.value.value / max) * 165;
                return Positioned(
                  left: x - 9,
                  top: y - 9,
                  child: Tooltip(
                    message:
                        '${DateFormat('MMM d', locale).format(e.value.date)}\n${CurrencyFormatter.formatForContext(context, e.value.value, currencyCode: currency)}',
                    child: const SizedBox(width: 18, height: 18),
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
                      style: AppTextStyles.labelSmall,
                    ),
                    Text(
                      DateFormat('MMM d', locale).format(points.last.date),
                      style: AppTextStyles.labelSmall,
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _ExpensesTrendPainter extends CustomPainter {
  const _ExpensesTrendPainter({required this.points, required this.max});
  final List<ExpenseTrendPoint> points;
  final double max;
  @override
  void paint(Canvas canvas, Size size) {
    const p = 18.0;
    final h = size.height - 42;
    final grid = Paint()..color = AppColors.border;
    for (var i = 1; i < 4; i++) {
      canvas.drawLine(
        Offset(p, h * i / 4),
        Offset(size.width - p, h * i / 4),
        grid,
      );
    }
    Path line = Path();
    for (var i = 0; i < points.length; i++) {
      final x = p + i * ((size.width - p * 2) / math.max(1, points.length - 1));
      final y = 12 + (1 - points[i].value / max) * (h - 12);
      if (i == 0) {
        line.moveTo(x, y);
      } else {
        line.lineTo(x, y);
      }
    }
    final area = Path.from(line)
      ..lineTo(size.width - p, h)
      ..lineTo(p, h)
      ..close();
    canvas.drawPath(
      area,
      Paint()..color = AppColors.tertiary.withValues(alpha: .14),
    );
    canvas.drawPath(
      line,
      Paint()
        ..color = AppColors.tertiary
        ..strokeWidth = 3
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round,
    );
  }

  @override
  bool shouldRepaint(covariant _ExpensesTrendPainter old) =>
      old.points != points || old.max != max;
}

class _Categories extends StatelessWidget {
  const _Categories({required this.data});
  final ExpensesReport data;
  @override
  Widget build(BuildContext context) {
    final total = data.categoryBreakdown.fold(0.0, (v, e) => v + e.amount);
    return _Section(
      title: context.l10n.expensesReportByCategory,
      child: data.categoryBreakdown.isEmpty
          ? _Empty(context.l10n.expensesReportNoCategories)
          : Column(
              children: data.categoryBreakdown.map((e) {
                final share = e.share ?? (total == 0 ? 0 : e.amount / total);
                return Padding(
                  padding: const EdgeInsets.only(bottom: AppSpacing.md),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Row(
                        children: <Widget>[
                          Expanded(
                            child: Text(
                              e.name,
                              style: AppTextStyles.labelLarge,
                            ),
                          ),
                          Text(
                            CurrencyFormatter.formatForContext(
                              context,
                              e.amount,
                              currencyCode: data.currency,
                            ),
                            style: AppTextStyles.labelMedium,
                          ),
                        ],
                      ),
                      const SizedBox(height: AppSpacing.xs),
                      LinearProgressIndicator(
                        value: share.clamp(0, 1).toDouble(),
                        minHeight: 8,
                        color: AppColors.tertiary,
                        backgroundColor: AppColors.discountIconBackground,
                      ),
                      const SizedBox(height: AppSpacing.xs),
                      Text(
                        '${(share * 100).toStringAsFixed(1)}% ${context.l10n.expensesReportPercentOfTotal}',
                        style: AppTextStyles.labelSmall,
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
    );
  }
}

class _Largest extends StatelessWidget {
  const _Largest({required this.data});
  final ExpensesReport data;
  @override
  Widget build(BuildContext context) => _Section(
    title: context.l10n.expensesReportLargest,
    child: data.largestExpenses.isEmpty
        ? _Empty(context.l10n.expensesReportNoLargest)
        : Column(
            children: data.largestExpenses
                .take(5)
                .toList()
                .asMap()
                .entries
                .map(
                  (x) => ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: CircleAvatar(
                      radius: 15,
                      backgroundColor: AppColors.discountIconBackground,
                      foregroundColor: AppColors.secondary,
                      child: Text(
                        '${x.key + 1}',
                        style: AppTextStyles.labelSmall,
                      ),
                    ),
                    title: Text(
                      x.value.description,
                      style: AppTextStyles.labelLarge,
                    ),
                    subtitle: Text(
                      '${x.value.category} • ${x.value.branch ?? context.l10n.expensesReportCompanyWide}',
                      style: AppTextStyles.labelSmall,
                    ),
                    trailing: Text(
                      CurrencyFormatter.formatForContext(
                        context,
                        x.value.amount,
                        currencyCode: data.currency,
                      ),
                      style: AppTextStyles.labelMedium,
                    ),
                  ),
                )
                .toList(),
          ),
  );
}

class _BranchComparison extends StatelessWidget {
  const _BranchComparison({required this.data});
  final ExpensesReport data;
  @override
  Widget build(BuildContext context) {
    final max = data.branchComparison
        .fold(1.0, (v, e) => math.max(v, e.totalExpenses))
        .toDouble();
    return _Section(
      title: context.l10n.expensesReportBranchComparison,
      child: data.branchComparison.isEmpty
          ? _Empty(context.l10n.expensesReportNoBranches)
          : Column(
              children: data.branchComparison
                  .map(
                    (e) => Padding(
                      padding: const EdgeInsets.only(bottom: AppSpacing.md),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Row(
                            children: <Widget>[
                              Expanded(
                                child: Text(
                                  e.branch,
                                  style: AppTextStyles.labelLarge,
                                ),
                              ),
                              Text(
                                CurrencyFormatter.formatForContext(
                                  context,
                                  e.totalExpenses,
                                  currencyCode: data.currency,
                                ),
                                style: AppTextStyles.labelMedium,
                              ),
                            ],
                          ),
                          const SizedBox(height: AppSpacing.xs),
                          LinearProgressIndicator(
                            value: (e.totalExpenses / max)
                                .clamp(0, 1)
                                .toDouble(),
                            minHeight: 8,
                            color: AppColors.warning,
                            backgroundColor: AppColors.discountIconBackground,
                          ),
                          const SizedBox(height: AppSpacing.xs),
                          Text(
                            e.expenseToSalesRatio == null
                                ? context
                                      .l10n
                                      .expensesReportComparisonUnavailable
                                : '${context.l10n.expensesReportExpenseSales}: ${e.expenseToSalesRatio!.toStringAsFixed(1)}%',
                            style: AppTextStyles.labelSmall,
                          ),
                        ],
                      ),
                    ),
                  )
                  .toList(),
            ),
    );
  }
}

class _PeriodComparison extends StatelessWidget {
  const _PeriodComparison({required this.data});
  final ExpensesReport data;
  @override
  Widget build(BuildContext context) {
    final p = data.periodComparison;
    return _Section(
      title: context.l10n.expensesReportPeriodComparison,
      child: p == null
          ? _Empty(context.l10n.expensesReportComparisonUnavailable)
          : LayoutBuilder(
              builder: (_, b) => Wrap(
                spacing: AppSpacing.xl,
                runSpacing: AppSpacing.lg,
                children: <Widget>[
                  _ComparisonValue(
                    label: p.currentLabel.isEmpty
                        ? context.l10n.expensesReportCurrentPeriod
                        : p.currentLabel,
                    value: p.currentAmount,
                    currency: data.currency,
                  ),
                  _ComparisonValue(
                    label: p.previousLabel.isEmpty
                        ? context.l10n.expensesReportPreviousPeriod
                        : p.previousLabel,
                    value: p.previousAmount,
                    currency: data.currency,
                  ),
                  _ComparisonValue(
                    label: context.l10n.expensesReportDifference,
                    value: p.difference,
                    currency: data.currency,
                    negative: p.difference > 0,
                  ),
                ],
              ),
            ),
    );
  }
}

class _ComparisonValue extends StatelessWidget {
  const _ComparisonValue({
    required this.label,
    required this.value,
    required this.currency,
    this.negative = false,
  });
  final String label, currency;
  final double value;
  final bool negative;
  @override
  Widget build(BuildContext context) => SizedBox(
    width: 180,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(label, style: AppTextStyles.labelSmall),
        const SizedBox(height: AppSpacing.xs),
        Text(
          CurrencyFormatter.formatForContext(
            context,
            value,
            currencyCode: currency,
          ),
          style: AppTextStyles.titleMedium.copyWith(
            color: negative ? AppColors.danger : null,
          ),
        ),
      ],
    ),
  );
}

class _ExpenseTable extends StatelessWidget {
  const _ExpenseTable({
    required this.data,
    required this.state,
    required this.cubit,
  });
  final ExpensesReport data;
  final ExpensesReportState state;
  final ExpensesReportCubit cubit;
  @override
  Widget build(BuildContext context) {
    final rows = state.sortedRows;
    final specs = <(String, ExpensesReportSort)>[
      (context.l10n.expensesReportDate, ExpensesReportSort.date),
      (context.l10n.expensesReportExpense, ExpensesReportSort.description),
      (context.l10n.expensesReportCategory, ExpensesReportSort.category),
      (context.l10n.expensesReportBranch, ExpensesReportSort.branch),
      (context.l10n.expensesReportPayee, ExpensesReportSort.payee),
      (
        context.l10n.expensesReportPaymentMethod,
        ExpensesReportSort.paymentMethod,
      ),
      (context.l10n.expensesReportAmount, ExpensesReportSort.amount),
      (context.l10n.expensesReportStatus, ExpensesReportSort.status),
    ];
    return _Section(
      title: context.l10n.expensesReportTable,
      child: rows.isEmpty
          ? _Empty(context.l10n.expensesReportNoExpenses)
          : LayoutBuilder(
              builder: (_, constraints) => SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: SizedBox(
                  width: math.max(950, constraints.maxWidth).toDouble(),
                  child: Column(
                    children: <Widget>[
                      Container(
                        padding: AppSpacing.allSm,
                        color: AppColors.background,
                        child: Row(
                          children: specs
                              .map(
                                (spec) => Expanded(
                                  child: TextButton.icon(
                                    onPressed: () => cubit.toggleSort(spec.$2),
                                    icon: Icon(
                                      state.sort == spec.$2
                                          ? (state.sortAscending
                                                ? Icons.arrow_drop_up
                                                : Icons.arrow_drop_down)
                                          : Icons.unfold_more,
                                      size: 16,
                                    ),
                                    label: Text(
                                      spec.$1,
                                      style: AppTextStyles.labelSmall,
                                    ),
                                  ),
                                ),
                              )
                              .toList(),
                        ),
                      ),
                      SizedBox(
                        height: math.min(420.0, rows.length * 54.0),
                        child: ListView.builder(
                          primary: false,
                          itemExtent: 54,
                          itemCount: rows.length,
                          itemBuilder: (_, index) {
                            final row = rows[index];
                            return Container(
                          padding: const EdgeInsets.symmetric(
                            vertical: AppSpacing.sm,
                            horizontal: AppSpacing.sm,
                          ),
                          decoration: const BoxDecoration(
                            border: Border(
                              bottom: BorderSide(color: AppColors.border),
                            ),
                          ),
                          child: Row(
                            children: <Widget>[
                              Expanded(
                                child: Text(
                                  DateFormat.yMMMd(
                                    Localizations.localeOf(
                                      context,
                                    ).toLanguageTag(),
                                  ).format(row.date),
                                ),
                              ),
                              Expanded(
                                child: Text(
                                  row.description,
                                  style: AppTextStyles.labelLarge,
                                ),
                              ),
                              Expanded(child: Text(row.category)),
                              Expanded(
                                child: Text(
                                  row.branch ??
                                      context.l10n.expensesReportCompanyWide,
                                ),
                              ),
                              Expanded(child: Text(row.payee ?? '—')),
                              Expanded(child: Text(row.paymentMethod ?? '—')),
                              Expanded(
                                child: Text(
                                  CurrencyFormatter.formatForContext(
                                    context,
                                    row.amount,
                                    currencyCode: data.currency,
                                  ),
                                  style: AppTextStyles.labelMedium,
                                ),
                              ),
                              Expanded(
                                child: _Badge(
                                  label: _statusLabel(context, row.status),
                                  color: _statusColor(row.status),
                                ),
                              ),
                            ],
                          ),
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
    );
  }
}


class _Section extends StatelessWidget {
  const _Section({required this.title, required this.child});
  final String title;
  final Widget child;
  @override
  Widget build(BuildContext context) =>
      ReportsOverviewSectionCard(title: title, child: child);
}

class _Badge extends StatelessWidget {
  const _Badge({required this.label, required this.color});
  final String label;
  final Color color;
  @override
  Widget build(BuildContext context) => Align(
    alignment: AlignmentDirectional.centerStart,
    child: DecoratedBox(
      decoration: BoxDecoration(
        color: color.withValues(alpha: .12),
        borderRadius: AppRadius.pillRadius,
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.sm,
          vertical: AppSpacing.xs,
        ),
        child: Text(
          label,
          style: AppTextStyles.labelSmall.copyWith(color: color),
        ),
      ),
    ),
  );
}

class _Empty extends StatelessWidget {
  const _Empty(this.message);
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
  Widget build(BuildContext context) => const Column(
    children: <Widget>[
      ReportsOverviewSkeletonCard(height: 150),
      SizedBox(height: AppSpacing.xxl),
      ReportsOverviewSkeletonCard(height: 230),
      SizedBox(height: AppSpacing.xxl),
      ReportsOverviewSkeletonCard(height: 260),
      SizedBox(height: AppSpacing.xxl),
      ReportsOverviewSkeletonCard(height: 280),
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
            Text(context.l10n.expensesReportError),
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

String _metric(
  BuildContext c,
  ExpenseMetric m,
  String currency, {
  bool percent = false,
}) => !m.available
    ? c.l10n.expensesReportUnavailable
    : m.textValue ??
          (percent
              ? '${m.value!.toStringAsFixed(1)}%'
              : CurrencyFormatter.formatForContext(
                  c,
                  m.value!,
                  currencyCode: currency,
                ));
String _statusLabel(BuildContext c, ExpenseReportStatus s) => switch (s) {
  ExpenseReportStatus.draft => c.l10n.expensesReportDraft,
  ExpenseReportStatus.pendingApproval => c.l10n.expensesReportPendingApproval,
  ExpenseReportStatus.approved => c.l10n.expensesReportApproved,
  ExpenseReportStatus.paid => c.l10n.expensesReportPaid,
  ExpenseReportStatus.rejected => c.l10n.expensesReportRejected,
  ExpenseReportStatus.reversed => c.l10n.expensesReportReversed,
};
Color _statusColor(ExpenseReportStatus s) => switch (s) {
  ExpenseReportStatus.draft => AppColors.textMuted,
  ExpenseReportStatus.pendingApproval => AppColors.warning,
  ExpenseReportStatus.approved => AppColors.info,
  ExpenseReportStatus.paid => AppColors.success,
  ExpenseReportStatus.rejected => AppColors.danger,
  ExpenseReportStatus.reversed => AppColors.textMuted,
};

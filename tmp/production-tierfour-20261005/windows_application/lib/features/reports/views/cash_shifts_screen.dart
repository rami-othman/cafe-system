import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../app/localization/localization_extensions.dart';
import '../../../core/constants/app_sizes.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_radius.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../shared/layouts/desktop_page_layout.dart';
import '../../../shared/widgets/app_card.dart';
import '../controllers/cash_shifts_cubit.dart';
import '../controllers/cash_shifts_state.dart';
import '../models/cash_shifts_report.dart';
import '../widgets/reports_overview_components.dart';

class CashShiftsScreen extends StatelessWidget {
  const CashShiftsScreen({super.key, required this.onBack});
  final VoidCallback onBack;
  @override
  Widget build(BuildContext context) =>
      BlocBuilder<CashShiftsCubit, CashShiftsState>(
        builder: (context, state) {
          final c = context.read<CashShiftsCubit>();
          return DesktopPageLayout(
            padding: EdgeInsets.zero,
            child: SingleChildScrollView(
              key: const Key('cash-shifts-scroll'),
              padding: AppSpacing.allXxl,
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(
                    maxWidth: AppSizes.ordersContentMaxWidth,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      _Header(state: state, cubit: c, onBack: onBack),
                      if (state.data != null &&
                          state.status == CashShiftsStatus.loading)
                        const Padding(
                          padding: EdgeInsets.only(top: AppSpacing.sm),
                          child: LinearProgressIndicator(minHeight: 2),
                        ),
                      const SizedBox(height: AppSpacing.xxl),
                      if (state.data != null)
                        _Content(data: state.data!, state: state)
                      else if (state.status == CashShiftsStatus.loading)
                        const _Loading()
                      else
                        _Error(onRetry: c.load),
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
  final CashShiftsState state;
  final CashShiftsCubit cubit;
  final VoidCallback onBack;
  @override
  Widget build(BuildContext context) {
    final data = state.data;
    final controls = Wrap(
      spacing: AppSpacing.sm,
      runSpacing: AppSpacing.sm,
      children: <Widget>[
        OutlinedButton.icon(
          onPressed: () => _range(context),
          icon: const Icon(Icons.calendar_month_outlined, size: 18),
          label: Text(context.l10n.reportsOverviewDateRange),
        ),
        _Picker(
          hint: context.l10n.reportsOverviewAllBranches,
          items: data?.branches ?? const <ReportFilterOption>[],
          value: state.branchId,
          onChanged: cubit.selectBranch,
        ),
        _Picker(
          hint: context.l10n.cashShiftsAllEmployees,
          items: data?.cashiers ?? const <ReportFilterOption>[],
          value: state.cashierId,
          onChanged: cubit.selectCashier,
        ),
        FilterChip(
          label: Text(context.l10n.reportsOverviewComparePrevious),
          selected: state.comparePrevious,
          onSelected: cubit.toggleComparison,
        ),
        Tooltip(
          message: context.l10n.cashShiftsExportTooltip,
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
          icon: const Icon(Icons.arrow_back_outlined),
          label: Text(context.l10n.salesProfitabilityBack),
        ),
        Text(context.l10n.cashShiftsTitle, style: AppTextStyles.headlineLarge),
        const SizedBox(height: AppSpacing.xs),
        Text(context.l10n.cashShiftsSubtitle, style: AppTextStyles.bodyMedium),
      ],
    );
    return LayoutBuilder(
      builder: (context, box) => box.maxWidth < 980
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

  Future<void> _range(BuildContext context) async {
    final v = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      initialDateRange: state.range,
    );
    if (v != null) await cubit.selectRange(v);
  }
}

class _Picker extends StatelessWidget {
  const _Picker({
    required this.hint,
    required this.items,
    required this.value,
    required this.onChanged,
  });
  final String hint;
  final List<ReportFilterOption> items;
  final int? value;
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
        value: items.any((e) => e.id == value) ? value : null,
        hint: Text(hint),
        items: <DropdownMenuItem<int?>>[
          DropdownMenuItem(value: null, child: Text(hint)),
          ...items.map(
            (e) => DropdownMenuItem(value: e.id, child: Text(e.name)),
          ),
        ],
        onChanged: onChanged,
      ),
    ),
  );
}

class _Content extends StatelessWidget {
  const _Content({required this.data, required this.state});
  final CashShiftsReport data;
  final CashShiftsState state;
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: <Widget>[
      _Kpis(kpis: data.kpis, currency: data.currency),
      const SizedBox(height: AppSpacing.xxl),
      _Reconciliation(value: data.reconciliation, currency: data.currency),
      const SizedBox(height: AppSpacing.xxl),
      LayoutBuilder(
        builder: (context, b) => b.maxWidth < 950
            ? Column(
                children: <Widget>[
                  _Trend(items: data.trend, currency: data.currency),
                  const SizedBox(height: AppSpacing.xxl),
                  _Payments(items: data.payments, currency: data.currency),
                ],
              )
            : Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Expanded(
                    child: _Trend(items: data.trend, currency: data.currency),
                  ),
                  const SizedBox(width: AppSpacing.xxl),
                  Expanded(
                    child: _Payments(
                      items: data.payments,
                      currency: data.currency,
                    ),
                  ),
                ],
              ),
      ),
      const SizedBox(height: AppSpacing.xxl),
      _Shifts(items: data.shifts, currency: data.currency),
      const SizedBox(height: AppSpacing.xxl),
      LayoutBuilder(
        builder: (context, b) => b.maxWidth < 950
            ? Column(
                children: <Widget>[
                  _Top(items: data.topShifts, currency: data.currency),
                  const SizedBox(height: AppSpacing.xxl),
                  _Exceptions(items: data.exceptions),
                ],
              )
            : Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Expanded(
                    child: _Top(items: data.topShifts, currency: data.currency),
                  ),
                  const SizedBox(width: AppSpacing.xxl),
                  Expanded(child: _Exceptions(items: data.exceptions)),
                ],
              ),
      ),
    ],
  );
}

class _Kpis extends StatelessWidget {
  const _Kpis({required this.kpis, required this.currency});
  final CashShiftKpis kpis;
  final String currency;
  @override
  Widget build(BuildContext context) {
    final rows = <(String, IconData, CashShiftMetric)>[
      (
        context.l10n.cashShiftsTotalSales,
        Icons.payments_outlined,
        kpis.totalSales,
      ),
      (
        context.l10n.cashShiftsExpectedCash,
        Icons.account_balance_wallet_outlined,
        kpis.expectedCash,
      ),
      (
        context.l10n.cashShiftsActualCash,
        Icons.point_of_sale_outlined,
        kpis.actualCash,
      ),
      (
        context.l10n.cashShiftsDifference,
        Icons.warning_amber_outlined,
        kpis.cashDifference,
      ),
      (context.l10n.cashShiftsClosed, Icons.lock_outline, kpis.closedShifts),
      (context.l10n.cashShiftsOpen, Icons.lock_open_outlined, kpis.openShifts),
      (
        context.l10n.cashShiftsAverage,
        Icons.trending_up_outlined,
        kpis.averageShiftSales,
      ),
    ];
    return LayoutBuilder(
      builder: (context, b) {
        final cols = b.maxWidth > 1320
            ? 4
            : b.maxWidth > 900
            ? 3
            : 1;
        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: rows.length,
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: cols,
            mainAxisExtent: 150,
            crossAxisSpacing: AppSpacing.md,
            mainAxisSpacing: AppSpacing.md,
          ),
          itemBuilder: (_, i) {
            final r = rows[i];
            return AppCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Row(
                    children: <Widget>[
                      Icon(r.$2, color: AppColors.secondary, size: 18),
                      const SizedBox(width: AppSpacing.sm),
                      Expanded(
                        child: Text(r.$1, style: AppTextStyles.labelMedium),
                      ),
                    ],
                  ),
                  const Spacer(),
                  Text(
                    r.$3.available
                        ? CurrencyFormatter.formatForContext(
                            context,
                            r.$3.value!,
                            currencyCode: currency,
                          )
                        : context.l10n.salesProfitabilityUnavailable,
                    style: AppTextStyles.titleLarge,
                  ),
                  Text(
                    r.$3.previousValue == null
                        ? context.l10n.reportsOverviewComparisonUnavailable
                        : '${r.$3.value! - r.$3.previousValue! >= 0 ? '+' : ''}${(r.$3.value! - r.$3.previousValue!).toStringAsFixed(1)}',
                    style: AppTextStyles.labelSmall,
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

class _Reconciliation extends StatelessWidget {
  const _Reconciliation({required this.value, required this.currency});
  final CashReconciliationSummary? value;
  final String currency;
  @override
  Widget build(BuildContext context) {
    final summary = value;
    if (summary == null) {
      return ReportsOverviewSectionCard(
        title: context.l10n.cashShiftsReconciliation,
        child: _Empty(context.l10n.salesProfitabilityUnavailable),
      );
    }
    final status = switch (summary.status) {
      CashReconciliationStatus.matched => (
        context.l10n.cashShiftsMatched,
        AppColors.success,
      ),
      CashReconciliationStatus.minorDifference => (
        context.l10n.cashShiftsMinor,
        AppColors.warning,
      ),
      CashReconciliationStatus.needsReview => (
        context.l10n.cashShiftsReview,
        AppColors.danger,
      ),
    };
    final diff = summary.difference == 0
        ? context.l10n.cashShiftsMatched
        : summary.difference < 0
        ? context.l10n.cashShiftsShortage
        : context.l10n.cashShiftsOverage;
    return ReportsOverviewSectionCard(
      title: context.l10n.cashShiftsReconciliation,
      trailing: Chip(
        label: Text(status.$1),
        backgroundColor: status.$2.withValues(alpha: .12),
        labelStyle: AppTextStyles.labelSmall.copyWith(color: status.$2),
      ),
      child: Wrap(
        spacing: AppSpacing.xxl,
        runSpacing: AppSpacing.lg,
        children: <Widget>[
          _amount(context.l10n.cashShiftsExpectedCash, summary.expected),
          _amount(context.l10n.cashShiftsActualCash, summary.actual),
          _amount(
            '$diff · ${context.l10n.cashShiftsDifference}',
            summary.difference,
            color: status.$2,
          ),
        ],
      ),
    );
  }

  Widget _amount(String label, double value, {Color? color}) => Builder(
    builder: (context) => Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(label, style: AppTextStyles.labelSmall),
        Text(
          CurrencyFormatter.formatForContext(
            context,
            value,
            currencyCode: currency,
          ),
          style: AppTextStyles.titleLarge.copyWith(color: color),
        ),
      ],
    ),
  );
}

class _Trend extends StatelessWidget {
  const _Trend({required this.items, required this.currency});
  final List<ShiftTrendPoint> items;
  final String currency;
  @override
  Widget build(BuildContext context) => ReportsOverviewSectionCard(
    title: context.l10n.cashShiftsTrend,
    child: items.length < 2
        ? _Empty(context.l10n.cashShiftsNoTrend)
        : SizedBox(
            height: 200,
            child: Directionality(
              textDirection: TextDirection.ltr,
              child: RepaintBoundary(child: CustomPaint(painter: _Line(items))),
            ),
          ),
  );
}

class _Line extends CustomPainter {
  const _Line(this.items);
  final List<ShiftTrendPoint> items;
  @override
  void paint(Canvas c, Size s) {
    final max = items.fold(1.0, (v, e) => math.max(v, e.sales));
    final p = Path();
    for (var i = 0; i < items.length; i++) {
      final x = 18 + i * (s.width - 36) / (items.length - 1);
      final y = 12 + (1 - items[i].sales / max) * (s.height - 28);
      i == 0 ? p.moveTo(x, y) : p.lineTo(x, y);
    }
    c.drawPath(
      p,
      Paint()
        ..color = AppColors.tertiary
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3,
    );
  }

  @override
  bool shouldRepaint(covariant _Line old) => old.items != items;
}

class _Payments extends StatelessWidget {
  const _Payments({required this.items, required this.currency});
  final List<PaymentMethodBreakdownRow> items;
  final String currency;
  @override
  Widget build(BuildContext context) => ReportsOverviewSectionCard(
    title: context.l10n.cashShiftsPayments,
    child: items.isEmpty
        ? _Empty(context.l10n.cashShiftsNoPayments)
        : Column(
            children: <Widget>[
              for (final e in items)
                Padding(
                  padding: const EdgeInsets.only(bottom: AppSpacing.md),
                  child: Column(
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
                            '${e.percent.toStringAsFixed(1)}%',
                            style: AppTextStyles.labelSmall,
                          ),
                          const SizedBox(width: AppSpacing.md),
                          Text(
                            CurrencyFormatter.formatForContext(
                              context,
                              e.amount,
                              currencyCode: currency,
                            ),
                            style: AppTextStyles.labelMedium,
                          ),
                        ],
                      ),
                      const SizedBox(height: AppSpacing.xs),
                      LinearProgressIndicator(
                        value: (e.percent / 100).clamp(0, 1),
                        minHeight: 7,
                        color: AppColors.tertiary,
                        backgroundColor: AppColors.discountIconBackground,
                      ),
                    ],
                  ),
                ),
            ],
          ),
  );
}

class _Shifts extends StatelessWidget {
  const _Shifts({required this.items, required this.currency});
  final List<ShiftPerformanceRow> items;
  final String currency;
  @override
  Widget build(BuildContext context) => ReportsOverviewSectionCard(
    title: context.l10n.cashShiftsPerformance,
    child: items.isEmpty
        ? _Empty(context.l10n.cashShiftsNoShifts)
        : SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: SizedBox(
              width: 1100,
              child: Column(
                children: <Widget>[
                  for (final e in items)
                    Padding(
                      padding: const EdgeInsets.all(AppSpacing.sm),
                      child: Row(
                        children: <Widget>[
                          Expanded(
                            child: Text(
                              e.name,
                              style: AppTextStyles.labelLarge,
                            ),
                          ),
                          Expanded(
                            child: Text(
                              e.employee,
                              style: AppTextStyles.bodySmall,
                            ),
                          ),
                          Expanded(child: Text('${e.orders}')),
                          Expanded(
                            child: Text(
                              CurrencyFormatter.formatForContext(
                                context,
                                e.sales,
                                currencyCode: currency,
                              ),
                            ),
                          ),
                          Expanded(
                            child: Text(
                              e.difference == null
                                  ? '—'
                                  : CurrencyFormatter.formatForContext(
                                      context,
                                      e.difference!,
                                      currencyCode: currency,
                                    ),
                            ),
                          ),
                          Expanded(
                            child: Chip(
                              label: Text(
                                e.status == ShiftStatus.closed
                                    ? context.l10n.cashShiftsClosed
                                    : context.l10n.cashShiftsOpen,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ),
  );
}

class _Top extends StatelessWidget {
  const _Top({required this.items, required this.currency});
  final List<TopShiftRow> items;
  final String currency;
  @override
  Widget build(BuildContext context) => ReportsOverviewSectionCard(
    title: context.l10n.cashShiftsTop,
    child: items.isEmpty
        ? _Empty(context.l10n.cashShiftsNoShifts)
        : Column(
            children: <Widget>[
              for (final e in items)
                ListTile(
                  leading: CircleAvatar(
                    backgroundColor: AppColors.discountIconBackground,
                    child: Text('${items.indexOf(e) + 1}'),
                  ),
                  title: Text(e.name, style: AppTextStyles.labelLarge),
                  subtitle: Text('${e.orders}'),
                  trailing: Text(
                    CurrencyFormatter.formatForContext(
                      context,
                      e.sales,
                      currencyCode: currency,
                    ),
                    style: AppTextStyles.labelMedium,
                  ),
                ),
            ],
          ),
  );
}

class _Exceptions extends StatelessWidget {
  const _Exceptions({required this.items});
  final List<CashShiftException> items;
  @override
  Widget build(BuildContext context) => ReportsOverviewSectionCard(
    title: context.l10n.cashShiftsExceptions,
    child: items.isEmpty
        ? _Empty(context.l10n.cashShiftsNoExceptions)
        : Column(
            children: <Widget>[
              for (final e in items)
                Padding(
                  padding: const EdgeInsets.only(bottom: AppSpacing.md),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Icon(
                        e.severity == CashShiftExceptionSeverity.critical
                            ? Icons.error_outline
                            : e.severity == CashShiftExceptionSeverity.warning
                            ? Icons.warning_amber_outlined
                            : Icons.info_outline,
                        color: e.severity == CashShiftExceptionSeverity.critical
                            ? AppColors.danger
                            : e.severity == CashShiftExceptionSeverity.warning
                            ? AppColors.warning
                            : AppColors.info,
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            Text(
                              e.description,
                              style: AppTextStyles.labelLarge,
                            ),
                            Text(e.context, style: AppTextStyles.labelSmall),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
  );
}

class _Empty extends StatelessWidget {
  const _Empty(this.text);
  final String text;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: AppSpacing.xl),
    child: Center(
      child: Text(
        text,
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
      ReportsOverviewSkeletonCard(height: 240),
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
            Text(context.l10n.cashShiftsError),
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

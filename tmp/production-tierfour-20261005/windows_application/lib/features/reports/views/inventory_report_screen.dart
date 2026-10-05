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
import '../controllers/inventory_report_cubit.dart';
import '../controllers/inventory_report_state.dart';
import '../models/inventory_report.dart';
import '../widgets/reports_overview_components.dart';

class InventoryReportScreen extends StatelessWidget {
  const InventoryReportScreen({super.key, required this.onBack});
  final VoidCallback onBack;
  @override
  Widget build(BuildContext context) =>
      BlocBuilder<InventoryReportCubit, InventoryReportState>(
        builder: (context, state) {
          final c = context.read<InventoryReportCubit>();
          return DesktopPageLayout(
            padding: EdgeInsets.zero,
            child: SingleChildScrollView(
              key: const Key('inventory-report-scroll'),
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
                          state.status == InventoryReportStatus.loading)
                        const Padding(
                          padding: EdgeInsets.only(top: AppSpacing.sm),
                          child: LinearProgressIndicator(minHeight: 2),
                        ),
                      const SizedBox(height: AppSpacing.xxl),
                      if (state.data != null)
                        _Content(data: state.data!)
                      else if (state.status == InventoryReportStatus.loading)
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
  final InventoryReportState state;
  final InventoryReportCubit cubit;
  final VoidCallback onBack;
  @override
  Widget build(BuildContext context) {
    final d = state.data;
    final controls = Wrap(
      spacing: AppSpacing.sm,
      runSpacing: AppSpacing.sm,
      children: <Widget>[
        OutlinedButton.icon(
          onPressed: () => _pick(context),
          icon: const Icon(Icons.calendar_month_outlined, size: 18),
          label: Text(context.l10n.reportsOverviewDateRange),
        ),
        _Picker(
          hint: context.l10n.reportsOverviewAllBranches,
          options: d?.branches ?? const <InventoryFilterOption>[],
          value: state.branchId,
          onChanged: cubit.selectBranch,
        ),
        _Picker(
          hint: context.l10n.inventoryReportAllLocations,
          options: d?.locations ?? const <InventoryFilterOption>[],
          value: state.locationId,
          onChanged: cubit.selectLocation,
        ),
        _Picker(
          hint: context.l10n.inventoryReportAllCategories,
          options: d?.categories ?? const <InventoryFilterOption>[],
          value: state.categoryId,
          onChanged: cubit.selectCategory,
        ),
        FilterChip(
          label: Text(context.l10n.reportsOverviewComparePrevious),
          selected: state.comparePrevious,
          onSelected: cubit.toggleComparison,
        ),
        Tooltip(
          message: context.l10n.inventoryReportExportTooltip,
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
          context.l10n.inventoryReportTitle,
          style: AppTextStyles.headlineLarge,
        ),
        const SizedBox(height: AppSpacing.xs),
        Text(
          context.l10n.inventoryReportSubtitle,
          style: AppTextStyles.bodyMedium,
        ),
      ],
    );
    return LayoutBuilder(
      builder: (_, b) => b.maxWidth < 980
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
    final range = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      initialDateRange: state.range,
    );
    if (range != null) await cubit.selectRange(range);
  }
}

class _Picker extends StatelessWidget {
  const _Picker({
    required this.hint,
    required this.options,
    required this.value,
    required this.onChanged,
  });
  final String hint;
  final List<InventoryFilterOption> options;
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
        value: options.any((x) => x.id == value) ? value : null,
        hint: Text(hint),
        items: <DropdownMenuItem<int?>>[
          DropdownMenuItem(value: null, child: Text(hint)),
          ...options.map(
            (x) => DropdownMenuItem(value: x.id, child: Text(x.name)),
          ),
        ],
        onChanged: onChanged,
      ),
    ),
  );
}

class _Content extends StatelessWidget {
  const _Content({required this.data});
  final InventoryReport data;
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
                  _LocationValues(data: data),
                  const SizedBox(height: AppSpacing.xxl),
                  _Movement(data: data),
                ],
              )
            : Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Expanded(child: _LocationValues(data: data)),
                  const SizedBox(width: AppSpacing.xxl),
                  Expanded(child: _Movement(data: data)),
                ],
              ),
      ),
      const SizedBox(height: AppSpacing.xxl),
      _Health(data: data),
      const SizedBox(height: AppSpacing.xxl),
      _StockTable(data: data),
      const SizedBox(height: AppSpacing.xxl),
      LayoutBuilder(
        builder: (_, b) => b.maxWidth < 950
            ? Column(
                children: <Widget>[
                  _Consumption(data: data),
                  const SizedBox(height: AppSpacing.xxl),
                  _Variance(data: data),
                ],
              )
            : Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Expanded(child: _Consumption(data: data)),
                  const SizedBox(width: AppSpacing.xxl),
                  Expanded(child: _Variance(data: data)),
                ],
              ),
      ),
      const SizedBox(height: AppSpacing.xxl),
      _Waste(data: data),
      const SizedBox(height: AppSpacing.xxl),
      _LocationComparison(data: data),
      const SizedBox(height: AppSpacing.xxl),
      _Exceptions(items: data.exceptions),
    ],
  );
}

class _Kpis extends StatelessWidget {
  const _Kpis({required this.data});
  final InventoryReport data;
  @override
  Widget build(BuildContext context) {
    final rows = <(String, IconData, InventoryMetric, bool)>[
      (
        context.l10n.inventoryReportCurrentValue,
        Icons.inventory_2_outlined,
        data.kpis.currentValue,
        false,
      ),
      (
        context.l10n.inventoryReportLowStock,
        Icons.trending_down_outlined,
        data.kpis.lowStock,
        true,
      ),
      (
        context.l10n.inventoryReportOutOfStock,
        Icons.remove_shopping_cart_outlined,
        data.kpis.outOfStock,
        true,
      ),
      (
        context.l10n.inventoryReportWasteValue,
        Icons.delete_outline,
        data.kpis.wasteValue,
        true,
      ),
      (
        context.l10n.inventoryReportCountVariance,
        Icons.balance_outlined,
        data.kpis.countVariance,
        true,
      ),
      (
        context.l10n.inventoryReportConsumption,
        Icons.outbox_outlined,
        data.kpis.consumption,
        false,
      ),
      (
        context.l10n.inventoryReportReceived,
        Icons.move_to_inbox_outlined,
        data.kpis.received,
        false,
      ),
      (
        context.l10n.inventoryReportTransfers,
        Icons.sync_alt_outlined,
        data.kpis.transfers,
        false,
      ),
    ];
    return LayoutBuilder(
      builder: (_, b) {
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
            mainAxisExtent: 170,
            crossAxisSpacing: AppSpacing.md,
            mainAxisSpacing: AppSpacing.md,
          ),
          itemBuilder: (_, i) {
            final row = rows[i];
            final metric = row.$3;
            final delta = metric.value == null || metric.previousValue == null
                ? null
                : metric.value! - metric.previousValue!;
            final bad = row.$4 && delta != null && delta > 0;
            return AppCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Row(
                    children: <Widget>[
                      Icon(row.$2, size: 18, color: AppColors.secondary),
                      const SizedBox(width: AppSpacing.sm),
                      Expanded(
                        child: Text(row.$1, style: AppTextStyles.labelMedium),
                      ),
                    ],
                  ),
                  const Spacer(),
                  Text(
                    metric.available
                        ? (row.$1 == context.l10n.inventoryReportLowStock ||
                                  row.$1 ==
                                      context.l10n.inventoryReportOutOfStock ||
                                  row.$1 ==
                                      context.l10n.inventoryReportTransfers
                              ? metric.value!.toStringAsFixed(0)
                              : CurrencyFormatter.formatForContext(
                                  context,
                                  metric.value!,
                                  currencyCode: data.currency,
                                ))
                        : context.l10n.salesProfitabilityUnavailable,
                    style: AppTextStyles.titleLarge,
                  ),
                  Text(
                    delta == null
                        ? context.l10n.reportsOverviewComparisonUnavailable
                        : '${delta >= 0 ? '+' : ''}${delta.toStringAsFixed(1)}',
                    style: AppTextStyles.labelSmall.copyWith(
                      color: bad ? AppColors.danger : AppColors.textMuted,
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

class _LocationValues extends StatelessWidget {
  const _LocationValues({required this.data});
  final InventoryReport data;
  @override
  Widget build(BuildContext context) {
    final max = data.valueByLocation.fold(1.0, (v, e) => math.max(v, e.value));
    return _Section(
      title: context.l10n.inventoryReportValueByLocation,
      child: data.valueByLocation.isEmpty
          ? _Empty(context.l10n.inventoryReportNoLocations)
          : Column(
              children: data.valueByLocation
                  .map(
                    (e) => Padding(
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
                                CurrencyFormatter.formatForContext(
                                  context,
                                  e.value,
                                  currencyCode: data.currency,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: AppSpacing.xs),
                          LinearProgressIndicator(
                            value: (e.value / max).clamp(0, 1),
                            color: AppColors.tertiary,
                            backgroundColor: AppColors.discountIconBackground,
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

class _Movement extends StatelessWidget {
  const _Movement({required this.data});
  final InventoryReport data;
  @override
  Widget build(BuildContext context) {
    final rows = List<InventoryMovementPoint>.from(data.movements)
      ..sort((a, b) => a.date.compareTo(b.date));
    final max = rows.fold(
      1.0,
      (value, item) => math.max(value, item.value.abs()),
    );
    return _Section(
      title: context.l10n.inventoryReportMovement,
      child: rows.isEmpty
          ? _Empty(context.l10n.inventoryReportNoMovements)
          : Directionality(
              textDirection: TextDirection.ltr,
              child: SizedBox(
                height: 190,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: rows.map((item) {
                    return Expanded(
                      child: Tooltip(
                        message:
                            '${item.label}: ${CurrencyFormatter.formatForContext(context, item.value, currencyCode: data.currency)}',
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 4),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: <Widget>[
                              Expanded(
                                child: Align(
                                  alignment: Alignment.bottomCenter,
                                  child: FractionallySizedBox(
                                    heightFactor: (item.value.abs() / max)
                                        .clamp(0, 1),
                                    widthFactor: .72,
                                    child: DecoratedBox(
                                      decoration: BoxDecoration(
                                        color: item.value < 0
                                            ? AppColors.warning
                                            : AppColors.tertiary,
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
                                style: AppTextStyles.labelSmall,
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

class _Health extends StatelessWidget {
  const _Health({required this.data});
  final InventoryReport data;
  @override
  Widget build(BuildContext context) => _Section(
    title: context.l10n.inventoryReportHealth,
    child: data.stockHealth.isEmpty
        ? _Empty(context.l10n.salesProfitabilityUnavailable)
        : LayoutBuilder(
            builder: (_, b) => Wrap(
              spacing: AppSpacing.md,
              runSpacing: AppSpacing.md,
              children: data.stockHealth.map((e) {
                final color = _healthColor(e.health);
                return SizedBox(
                  width: math.min(190, b.maxWidth),
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: .12),
                      borderRadius: AppRadius.control,
                    ),
                    child: Padding(
                      padding: AppSpacing.allMd,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Text(
                            '${e.count}',
                            style: AppTextStyles.headlineMedium.copyWith(
                              color: color,
                            ),
                          ),
                          Text(
                            _healthLabel(context, e.health),
                            style: AppTextStyles.labelMedium.copyWith(
                              color: color,
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
  );
}

class _StockTable extends StatelessWidget {
  const _StockTable({required this.data});
  final InventoryReport data;
  @override
  Widget build(BuildContext context) => _Section(
    title: context.l10n.inventoryReportLowOut,
    child: data.stockRows.isEmpty
        ? _Empty(context.l10n.inventoryReportNoLowStock)
        : _Table(
            width: 860,
            headers: <String>[
              context.l10n.inventoryReportItem,
              context.l10n.inventoryReportCategory,
              context.l10n.inventoryReportLocation,
              context.l10n.inventoryReportAvailable,
              context.l10n.inventoryReportMinimum,
              context.l10n.inventoryReportUnit,
              context.l10n.inventoryReportStatus,
            ],
            rows: data.stockRows
                .map(
                  (e) => <Widget>[
                    Text(e.name),
                    Text(e.category),
                    Text(e.location),
                    Text(e.quantity.toStringAsFixed(2)),
                    Text(e.minimum.toStringAsFixed(2)),
                    Text(e.unit),
                    _Badge(
                      label: _healthLabel(context, e.health),
                      color: _healthColor(e.health),
                    ),
                  ],
                )
                .toList(),
          ),
  );
}

class _Consumption extends StatelessWidget {
  const _Consumption({required this.data});
  final InventoryReport data;
  @override
  Widget build(BuildContext context) => _Section(
    title: context.l10n.inventoryReportConsumptionAnalysis,
    child: data.consumption.isEmpty
        ? _Empty(context.l10n.salesProfitabilityUnavailable)
        : Column(
            children: data.consumption.asMap().entries.map((entry) {
              final e = entry.value;
              return Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.md),
                child: Row(
                  children: <Widget>[
                    CircleAvatar(
                      radius: 15,
                      backgroundColor: AppColors.discountIconBackground,
                      child: Text(
                        '${entry.key + 1}',
                        style: AppTextStyles.labelSmall,
                      ),
                    ),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Text(e.name, style: AppTextStyles.labelLarge),
                          Text(e.category, style: AppTextStyles.labelSmall),
                        ],
                      ),
                    ),
                    Text(
                      '${e.quantity.toStringAsFixed(2)} ${e.unit}',
                      style: AppTextStyles.labelMedium,
                    ),
                    if (e.value != null) ...<Widget>[
                      const SizedBox(width: AppSpacing.md),
                      Text(
                        CurrencyFormatter.formatForContext(
                          context,
                          e.value!,
                          currencyCode: data.currency,
                        ),
                        style: AppTextStyles.labelMedium,
                      ),
                    ],
                  ],
                ),
              );
            }).toList(),
          ),
  );
}

class _Variance extends StatelessWidget {
  const _Variance({required this.data});
  final InventoryReport data;
  @override
  Widget build(BuildContext context) => _Section(
    title: context.l10n.inventoryReportVariance,
    child: data.variances.isEmpty
        ? _Empty(context.l10n.inventoryReportNoVariance)
        : _Table(
            width: 720,
            headers: <String>[
              context.l10n.inventoryReportLocation,
              context.l10n.inventoryReportExpected,
              context.l10n.inventoryReportCounted,
              context.l10n.inventoryReportDifference,
              context.l10n.inventoryReportVarianceValue,
              context.l10n.inventoryReportStatus,
            ],
            rows: data.variances
                .map(
                  (e) => <Widget>[
                    Text(e.location),
                    Text(e.expected.toStringAsFixed(2)),
                    Text(e.counted.toStringAsFixed(2)),
                    Text(
                      '${e.difference >= 0 ? '+' : ''}${e.difference.toStringAsFixed(2)}',
                    ),
                    Text(
                      CurrencyFormatter.formatForContext(
                        context,
                        e.value,
                        currencyCode: data.currency,
                      ),
                    ),
                    _Badge(
                      label: _varianceLabel(context, e.status),
                      color: e.status == InventoryVarianceStatus.matched
                          ? AppColors.success
                          : e.status == InventoryVarianceStatus.shortage
                          ? AppColors.danger
                          : AppColors.warning,
                    ),
                  ],
                )
                .toList(),
          ),
  );
}

class _Waste extends StatelessWidget {
  const _Waste({required this.data});
  final InventoryReport data;
  @override
  Widget build(BuildContext context) => _Section(
    title: context.l10n.inventoryReportWasteAnalysis,
    child: data.waste.isEmpty
        ? _Empty(context.l10n.inventoryReportNoWaste)
        : _Table(
            width: 760,
            headers: <String>[
              context.l10n.inventoryReportItem,
              context.l10n.inventoryReportQuantity,
              context.l10n.inventoryReportValue,
              context.l10n.inventoryReportReason,
              context.l10n.inventoryReportLocation,
            ],
            rows: data.waste
                .map(
                  (e) => <Widget>[
                    Text(e.name),
                    Text('${e.quantity.toStringAsFixed(2)} ${e.unit}'),
                    Text(
                      CurrencyFormatter.formatForContext(
                        context,
                        e.value,
                        currencyCode: data.currency,
                      ),
                      style: AppTextStyles.labelMedium.copyWith(
                        color: AppColors.danger,
                      ),
                    ),
                    Text(e.reason),
                    Text(e.location),
                  ],
                )
                .toList(),
          ),
  );
}

class _LocationComparison extends StatelessWidget {
  const _LocationComparison({required this.data});
  final InventoryReport data;
  @override
  Widget build(BuildContext context) => _Section(
    title: context.l10n.inventoryReportLocationComparison,
    child: data.locationComparison.isEmpty
        ? _Empty(context.l10n.inventoryReportNoLocations)
        : _Table(
            width: 800,
            headers: <String>[
              context.l10n.inventoryReportLocation,
              context.l10n.inventoryReportValue,
              context.l10n.inventoryReportItems,
              context.l10n.inventoryReportLowStock,
              context.l10n.inventoryReportOutOfStock,
              context.l10n.inventoryReportWasteValue,
              context.l10n.inventoryReportVarianceValue,
            ],
            rows: data.locationComparison
                .map(
                  (e) => <Widget>[
                    Text(e.name),
                    Text(
                      e.value == null
                          ? '—'
                          : CurrencyFormatter.formatForContext(
                              context,
                              e.value!,
                              currencyCode: data.currency,
                            ),
                    ),
                    Text(e.items?.toString() ?? '—'),
                    Text(e.lowStock?.toString() ?? '—'),
                    Text(e.outOfStock?.toString() ?? '—'),
                    Text(
                      e.waste == null
                          ? '—'
                          : CurrencyFormatter.formatForContext(
                              context,
                              e.waste!,
                              currencyCode: data.currency,
                            ),
                    ),
                    Text(
                      e.variance == null
                          ? '—'
                          : CurrencyFormatter.formatForContext(
                              context,
                              e.variance!,
                              currencyCode: data.currency,
                            ),
                    ),
                  ],
                )
                .toList(),
          ),
  );
}

class _Exceptions extends StatelessWidget {
  const _Exceptions({required this.items});
  final List<InventoryReportException> items;
  @override
  Widget build(BuildContext context) => _Section(
    title: context.l10n.inventoryReportExceptions,
    child: items.isEmpty
        ? _Empty(context.l10n.inventoryReportNoExceptions)
        : Column(
            children: items.map((e) {
              final color = e.severity == InventoryExceptionSeverity.critical
                  ? AppColors.danger
                  : e.severity == InventoryExceptionSeverity.warning
                  ? AppColors.warning
                  : AppColors.info;
              return Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.md),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Icon(
                      e.severity == InventoryExceptionSeverity.info
                          ? Icons.info_outline
                          : Icons.warning_amber_outlined,
                      color: color,
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Text(e.description, style: AppTextStyles.labelLarge),
                          Text(e.context, style: AppTextStyles.labelSmall),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
  );
}

class _Section extends StatelessWidget {
  const _Section({required this.title, required this.child});
  final String title;
  final Widget child;
  @override
  Widget build(BuildContext context) =>
      ReportsOverviewSectionCard(title: title, child: child);
}

class _Table extends StatelessWidget {
  const _Table({
    required this.width,
    required this.headers,
    required this.rows,
  });
  final double width;
  final List<String> headers;
  final List<List<Widget>> rows;
  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (_, b) => SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: SizedBox(
        width: math.max(width, b.maxWidth),
        child: Column(
          children: <Widget>[
            Container(
              padding: AppSpacing.allSm,
              color: AppColors.background,
              child: Row(
                children: headers
                    .map(
                      (e) => Expanded(
                        child: Text(e, style: AppTextStyles.labelSmall),
                      ),
                    )
                    .toList(),
              ),
            ),
            ...rows.map(
              (r) => Container(
                decoration: const BoxDecoration(
                  border: Border(bottom: BorderSide(color: AppColors.border)),
                ),
                padding: const EdgeInsets.symmetric(
                  vertical: AppSpacing.sm,
                  horizontal: AppSpacing.sm,
                ),
                child: Row(children: r.map((e) => Expanded(child: e)).toList()),
              ),
            ),
          ],
        ),
      ),
    ),
  );
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
      ReportsOverviewSkeletonCard(height: 145),
      SizedBox(height: AppSpacing.xxl),
      ReportsOverviewSkeletonCard(height: 220),
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
            Text(context.l10n.inventoryReportError),
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

Color _healthColor(InventoryHealth h) => switch (h) {
  InventoryHealth.available => AppColors.success,
  InventoryHealth.low => AppColors.warning,
  InventoryHealth.out => AppColors.danger,
  InventoryHealth.overstock => AppColors.info,
};
String _healthLabel(BuildContext c, InventoryHealth h) => switch (h) {
  InventoryHealth.available => c.l10n.inventoryReportAvailableStatus,
  InventoryHealth.low => c.l10n.inventoryReportLowStatus,
  InventoryHealth.out => c.l10n.inventoryReportOutStatus,
  InventoryHealth.overstock => c.l10n.inventoryReportOverstockStatus,
};
String _varianceLabel(BuildContext c, InventoryVarianceStatus s) => switch (s) {
  InventoryVarianceStatus.matched => c.l10n.inventoryReportMatched,
  InventoryVarianceStatus.shortage => c.l10n.inventoryReportShortage,
  InventoryVarianceStatus.overage => c.l10n.inventoryReportOverage,
};

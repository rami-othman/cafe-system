import 'dart:math' as math;

import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_radius.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/utils/currency_formatter.dart';
import '../models/daily_report_data.dart';
import 'report_analytics_cards.dart';

class TopSellingProductsTable extends StatelessWidget {
  const TopSellingProductsTable({super.key, required this.items});
  final List<TopSellingProductItem> items;
  @override
  Widget build(BuildContext context) => ReportSectionCard(
    title: 'Top Selling Products',
    child: _HorizontalTable(
      minWidth: 640,
      child: Table(
        key: const Key('top-products-table'),
        columnWidths: const <int, TableColumnWidth>{
          0: FlexColumnWidth(2.4),
          1: FlexColumnWidth(1.4),
          2: FlexColumnWidth(),
          3: FlexColumnWidth(1.2),
          4: FlexColumnWidth(),
        },
        children: <TableRow>[
          _header(<String>[
            'PRODUCT NAME',
            'CATEGORY',
            'QTY SOLD',
            'REVENUE',
            'TREND',
          ]),
          for (final TopSellingProductItem item in items)
            TableRow(
              children: <Widget>[
                _cell(item.name),
                _cell(item.category),
                _cell('${item.quantitySold}'),
                _cell(item.revenueDisplay, color: AppColors.secondary),
                _trend(item.trend),
              ],
            ),
        ],
      ),
    ),
  );
}

class RefundSummaryCard extends StatelessWidget {
  const RefundSummaryCard({super.key, required this.items});
  final List<RefundReportItem> items;
  @override
  Widget build(BuildContext context) => ReportSectionCard(
    title: 'Refund Summary',
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          '-${CurrencyFormatter.format(42.50)}',
          style: AppTextStyles.headlineMedium.copyWith(
            color: AppColors.dangerStrong,
          ),
        ),
        Text('(3 Refunds)', style: AppTextStyles.bodySmall),
        const SizedBox(height: AppSpacing.lg),
        Text('RECENT REFUNDS', style: AppTextStyles.labelSmall),
        const SizedBox(height: AppSpacing.sm),
        for (final RefundReportItem item in items)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
            child: Column(
              children: <Widget>[
                Row(
                  children: <Widget>[
                    Expanded(
                      child: Text(
                        '${item.orderNumber} - ${item.reason}',
                        style: AppTextStyles.labelMedium.copyWith(
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ),
                    Text(
                      item.value,
                      style: AppTextStyles.labelMedium.copyWith(
                        color: AppColors.dangerStrong,
                      ),
                    ),
                  ],
                ),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    item.details,
                    style: AppTextStyles.bodySmall.copyWith(
                      color: AppColors.textMuted,
                    ),
                  ),
                ),
                const Padding(
                  padding: EdgeInsets.only(top: AppSpacing.sm),
                  child: Divider(height: 1, color: AppColors.border),
                ),
              ],
            ),
          ),
      ],
    ),
  );
}

class DiscountsUsageTable extends StatelessWidget {
  const DiscountsUsageTable({super.key, required this.items});
  final List<DiscountUsageReportItem> items;
  @override
  Widget build(BuildContext context) => ReportSectionCard(
    title: 'Discounts Usage',
    trailing: const _DiscountSummary(),
    child: _HorizontalTable(
      minWidth: 760,
      child: Table(
        key: const Key('discounts-usage-table'),
        columnWidths: const <int, TableColumnWidth>{
          0: FlexColumnWidth(2.2),
          1: FlexColumnWidth(1.5),
          2: FlexColumnWidth(),
          3: FlexColumnWidth(1.2),
          4: FlexColumnWidth(1.3),
        },
        children: <TableRow>[
          _header(<String>[
            'DISCOUNT NAME',
            'TYPE',
            'USAGE',
            'TOTAL VALUE',
            'REVENUE AFTER',
          ]),
          for (final DiscountUsageReportItem item in items)
            TableRow(
              children: <Widget>[
                _cell(item.name),
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: _TypeBadge(label: item.type),
                  ),
                ),
                _cell('${item.usageCount}'),
                _cell(item.totalValueDisplay, color: AppColors.warning),
                _cell(item.revenueAfterDisplay),
              ],
            ),
        ],
      ),
    ),
  );
}

class RecentTransactionsTable extends StatelessWidget {
  const RecentTransactionsTable({
    super.key,
    required this.items,
    required this.onViewAll,
  });
  final List<RecentTransactionReportItem> items;
  final VoidCallback onViewAll;
  @override
  Widget build(BuildContext context) => ReportSectionCard(
    title: 'Recent Transactions',
    trailing: TextButton(onPressed: onViewAll, child: const Text('View All')),
    child: _HorizontalTable(
      minWidth: 1000,
      child: Table(
        key: const Key('recent-transactions-table'),
        defaultVerticalAlignment: TableCellVerticalAlignment.middle,
        columnWidths: const <int, TableColumnWidth>{
          0: IntrinsicColumnWidth(),
          1: IntrinsicColumnWidth(),
          2: FlexColumnWidth(1.2),
          3: IntrinsicColumnWidth(),
          4: IntrinsicColumnWidth(),
          5: IntrinsicColumnWidth(),
          6: IntrinsicColumnWidth(),
          7: IntrinsicColumnWidth(),
          8: IntrinsicColumnWidth(),
          9: IntrinsicColumnWidth(),
        },
        children: <TableRow>[
          _header(<String>[
            'ORDER #',
            'TIME',
            'CUSTOMER',
            'TYPE',
            'PAYMENT',
            'SUBTOTAL',
            'DISCOUNT',
            'TAX',
            'TOTAL',
            'STATUS',
          ]),
          for (final RecentTransactionReportItem item in items)
            TableRow(
              children: <Widget>[
                _cell(item.orderNumber),
                _cell(item.time),
                _cell(item.customer),
                _cell(item.orderType),
                _cell(item.payment),
                _cell(item.subtotal),
                _cell(item.discount, color: AppColors.warning),
                _cell(item.tax),
                _cell(
                  item.total,
                  color: item.status == TransactionReportStatus.refunded
                      ? AppColors.dangerStrong
                      : null,
                  decoration: item.status == TransactionReportStatus.refunded
                      ? TextDecoration.lineThrough
                      : null,
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
                  child: _StatusBadge(status: item.status),
                ),
              ],
            ),
        ],
      ),
    ),
  );
}

class _HorizontalTable extends StatelessWidget {
  const _HorizontalTable({required this.minWidth, required this.child});
  final double minWidth;
  final Widget child;
  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (BuildContext context, BoxConstraints constraints) {
      final double tableWidth = math.max(constraints.maxWidth, minWidth);

      return SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: SizedBox(width: tableWidth, child: child),
      );
    },
  );
}

TableRow _header(List<String> labels) => TableRow(
  decoration: const BoxDecoration(color: AppColors.background),
  children: labels
      .map(
        (String label) => Padding(
          padding: const EdgeInsets.all(AppSpacing.sm),
          child: Text(label, style: AppTextStyles.labelSmall),
        ),
      )
      .toList(),
);
Widget _cell(String value, {Color? color, TextDecoration? decoration}) =>
    Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: AppSpacing.md,
      ),
      child: Text(
        value,
        style: AppTextStyles.bodySmall.copyWith(
          color: color ?? AppColors.textPrimary,
          decoration: decoration,
        ),
      ),
    );
Widget _trend(ProductTrend trend) => Padding(
  padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
  child: Icon(
    trend == ProductTrend.up
        ? Icons.trending_up
        : trend == ProductTrend.down
        ? Icons.trending_down
        : Icons.trending_flat,
    color: trend == ProductTrend.up ? AppColors.success : AppColors.textMuted,
    size: 18,
  ),
);

class _DiscountSummary extends StatelessWidget {
  const _DiscountSummary();
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(
      horizontal: AppSpacing.md,
      vertical: AppSpacing.sm,
    ),
    decoration: const BoxDecoration(
      color: AppColors.background,
      borderRadius: AppRadius.control,
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: <Widget>[
            Text('Total Discount Value', style: AppTextStyles.labelSmall),
            Text(
              '-${CurrencyFormatter.format(125)}',
              style: AppTextStyles.labelMedium.copyWith(
                color: AppColors.warning,
              ),
            ),
          ],
        ),
        const SizedBox(width: AppSpacing.md),
        Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: <Widget>[
            Text('Times Applied', style: AppTextStyles.labelSmall),
            const Text('34'),
          ],
        ),
      ],
    ),
  );
}

class _TypeBadge extends StatelessWidget {
  const _TypeBadge({required this.label});
  final String label;
  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: const BoxDecoration(
      color: AppColors.surfaceAlt,
      borderRadius: AppRadius.pillRadius,
    ),
    child: Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: AppSpacing.xs,
      ),
      child: Text(label, style: AppTextStyles.labelSmall),
    ),
  );
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.status});
  final TransactionReportStatus status;
  @override
  Widget build(BuildContext context) {
    final bool paid = status == TransactionReportStatus.paid;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: paid
            ? AppColors.discountGreenBadge
            : AppColors.refundWarningBackground,
        borderRadius: AppRadius.pillRadius,
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.sm,
          vertical: AppSpacing.xs,
        ),
        child: Text(
          paid ? 'Paid' : 'Refunded',
          style: AppTextStyles.labelSmall.copyWith(
            color: paid ? AppColors.success : AppColors.dangerStrong,
          ),
        ),
      ),
    );
  }
}

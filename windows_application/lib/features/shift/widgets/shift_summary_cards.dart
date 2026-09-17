import 'package:flutter/material.dart';

import '../../../core/theme/app_spacing.dart';
import '../models/shift_models.dart';
import 'shift_design.dart';
import 'shift_format.dart';
import 'shift_primitives.dart';
import 'shift_strings.dart';

/// The shift KPI grid: gross/net sales, order counts, per-channel sales,
/// discounts, refunds and cancellations. Eleven tiles, laid out responsively.
class ShiftKpiGrid extends StatelessWidget {
  const ShiftKpiGrid({super.key, required this.sales, required this.payments});

  final ShiftSalesSummary sales;
  final PaymentBreakdown payments;

  @override
  Widget build(BuildContext context) {
    final List<ShiftMetricCard> tiles = <ShiftMetricCard>[
      ShiftMetricCard(
        label: ShiftStrings.grossSales,
        value: ShiftFormat.money(sales.grossSales),
        icon: Icons.point_of_sale_outlined,
      ),
      ShiftMetricCard(
        label: ShiftStrings.netSales,
        value: ShiftFormat.money(sales.netSales),
        icon: Icons.savings_outlined,
        context_: ShiftStrings.afterDiscountsAndRefunds,
        tone: ShiftTone.success,
      ),
      ShiftMetricCard(
        label: ShiftStrings.orderCount,
        value: ShiftFormat.count(sales.orderCount),
        icon: Icons.receipt_long_outlined,
      ),
      ShiftMetricCard(
        label: ShiftStrings.averageOrder,
        value: ShiftFormat.money(sales.averageOrderValue),
        icon: Icons.calculate_outlined,
        context_: ShiftStrings.perOrderAverage,
      ),
      ShiftMetricCard(
        label: ShiftStrings.cashSales,
        value: ShiftFormat.money(payments.amountFor(PaymentChannel.cash)),
        icon: Icons.payments_outlined,
        context_:
            '${ShiftFormat.count(payments.transactionsFor(PaymentChannel.cash))} '
            '${ShiftStrings.ordersPaidInCash}',
      ),
      ShiftMetricCard(
        label: ShiftStrings.cardSales,
        value: ShiftFormat.money(payments.amountFor(PaymentChannel.card)),
        icon: Icons.credit_card_outlined,
        context_:
            '${ShiftFormat.count(payments.transactionsFor(PaymentChannel.card))} '
            '${ShiftStrings.ordersPaidByCard}',
      ),
      ShiftMetricCard(
        label: ShiftStrings.transferSales,
        value: ShiftFormat.money(
          payments.amountFor(PaymentChannel.transfer) +
              payments.amountFor(PaymentChannel.other) +
              payments.amountFor(PaymentChannel.customerCredit),
        ),
        icon: Icons.swap_horiz_outlined,
      ),
      ShiftMetricCard(
        label: ShiftStrings.totalDiscounts,
        value: ShiftFormat.money(sales.discounts),
        icon: Icons.local_offer_outlined,
        context_:
            '${ShiftFormat.count(sales.discountPolicyCount)} ${ShiftStrings.discountPoliciesApplied}',
        tone: ShiftTone.surplus,
      ),
      ShiftMetricCard(
        label: ShiftStrings.totalRefunds,
        value: ShiftFormat.money(sales.refunds),
        icon: Icons.replay_outlined,
        context_: '${ShiftFormat.percent(sales.refundRatio)} ${ShiftStrings.ofGrossSales}',
        tone: ShiftTone.warning,
      ),
      ShiftMetricCard(
        label: ShiftStrings.refundCount,
        value: ShiftFormat.count(sales.refundCount),
        icon: Icons.undo_outlined,
        context_: ShiftStrings.refundedOperations,
      ),
      ShiftMetricCard(
        label: ShiftStrings.cancelledOrders,
        value: ShiftFormat.count(sales.cancelledOrderCount),
        icon: Icons.cancel_outlined,
        context_: ShiftStrings.cancelledBeforePayment,
        tone: ShiftTone.blocker,
      ),
    ];

    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final int columns = constraints.maxWidth >= ShiftLayout.wideBreakpoint
            ? 4
            : constraints.maxWidth >= ShiftLayout.desktopBreakpoint
            ? 3
            : constraints.maxWidth >= ShiftLayout.tabletBreakpoint
            ? 2
            : 1;
        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: tiles.length,
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: columns,
            mainAxisSpacing: AppSpacing.md,
            crossAxisSpacing: AppSpacing.md,
            childAspectRatio: columns == 1 ? 2.6 : 1.7,
          ),
          itemBuilder: (BuildContext context, int index) => tiles[index],
        );
      },
    );
  }
}

/// Cash/card/transfer/credit/other rows with amount, transaction count and
/// share of total, plus a totals row.
class PaymentBreakdownCard extends StatelessWidget {
  const PaymentBreakdownCard({super.key, required this.breakdown});

  final PaymentBreakdown breakdown;

  @override
  Widget build(BuildContext context) {
    final List<PaymentBreakdownLine> lines = breakdown.usedLines.isEmpty
        ? breakdown.lines
        : breakdown.usedLines;
    return ShiftCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const ShiftSectionHeader(
            title: ShiftStrings.paymentBreakdown,
            icon: Icons.pie_chart_outline,
          ),
          const SizedBox(height: AppSpacing.md),
          for (final PaymentBreakdownLine line in lines)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Row(
                children: <Widget>[
                  Icon(_iconFor(line.channel), size: 16, color: ShiftColors.inkMuted),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    flex: 2,
                    child: Text(_labelFor(line.channel), style: ShiftText.bodyStrong),
                  ),
                  Expanded(
                    child: ShiftValue(
                      '${ShiftFormat.count(line.transactionCount)} ${ShiftStrings.operationsUnit}',
                      style: ShiftText.label,
                    ),
                  ),
                  Expanded(
                    child: ShiftValue(
                      ShiftFormat.percent(breakdown.ratioFor(line.channel)),
                      style: ShiftText.label,
                    ),
                  ),
                  Expanded(
                    child: ShiftValue(
                      ShiftFormat.money(line.amount),
                      style: ShiftText.bodyStrong,
                      align: TextAlign.end,
                    ),
                  ),
                ],
              ),
            ),
          const ShiftDividerLine(),
          Row(
            children: <Widget>[
              Expanded(
                child: Text(ShiftStrings.total, style: ShiftText.cardTitle),
              ),
              ShiftValue(
                ShiftFormat.money(breakdown.total),
                style: ShiftText.metricValueSmall,
              ),
            ],
          ),
        ],
      ),
    );
  }

  static IconData _iconFor(PaymentChannel channel) => switch (channel) {
    PaymentChannel.cash => Icons.payments_outlined,
    PaymentChannel.card => Icons.credit_card_outlined,
    PaymentChannel.transfer => Icons.swap_horiz_outlined,
    PaymentChannel.customerCredit => Icons.account_balance_wallet_outlined,
    PaymentChannel.other => Icons.more_horiz,
  };

  static String _labelFor(PaymentChannel channel) => switch (channel) {
    PaymentChannel.cash => ShiftStrings.paymentCash,
    PaymentChannel.card => ShiftStrings.paymentCard,
    PaymentChannel.transfer => ShiftStrings.paymentTransfer,
    PaymentChannel.customerCredit => ShiftStrings.paymentCustomerCredit,
    PaymentChannel.other => ShiftStrings.paymentOther,
  };
}

/// Order status counts, plus an inline warning row for open/preparing orders.
class OrdersStatusCard extends StatelessWidget {
  const OrdersStatusCard({super.key, required this.orders, this.onViewOrder});

  final OrdersStatusSummary orders;
  final ValueChanged<OpenOrderRef>? onViewOrder;

  @override
  Widget build(BuildContext context) {
    final List<(String, int, ShiftTone)> rows = <(String, int, ShiftTone)>[
      (ShiftStrings.ordersCompleted, orders.completed, ShiftTone.success),
      (ShiftStrings.ordersPaid, orders.paid, ShiftTone.accent),
      (ShiftStrings.ordersPreparing, orders.preparing, ShiftTone.warning),
      (ShiftStrings.ordersOpen, orders.open, ShiftTone.blocker),
      (ShiftStrings.ordersCancelled, orders.cancelled, ShiftTone.neutral),
      (
        ShiftStrings.ordersPartiallyRefunded,
        orders.partiallyRefunded,
        ShiftTone.surplus,
      ),
      (ShiftStrings.ordersFullyRefunded, orders.fullyRefunded, ShiftTone.surplus),
    ];

    return ShiftCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const ShiftSectionHeader(
            title: ShiftStrings.ordersStatus,
            icon: Icons.assignment_turned_in_outlined,
          ),
          const SizedBox(height: AppSpacing.md),
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.sm,
            children: <Widget>[
              for (final (String label, int count, ShiftTone tone) in rows)
                _OrderStatusChip(label: label, count: count, tone: tone),
            ],
          ),
          if (orders.hasUnfinished) ...<Widget>[
            const SizedBox(height: AppSpacing.md),
            ShiftNotice(
              tone: ShiftTone.blocker,
              message: ShiftStrings.unfinishedOrdersWarning(orders.unfinished),
              detail: orders.openOrders.isEmpty
                  ? ShiftStrings.blockedByOpenOrders
                  : null,
            ),
            if (orders.openOrders.isNotEmpty) ...<Widget>[
              const SizedBox(height: AppSpacing.sm),
              for (final OpenOrderRef order in orders.openOrders)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 3),
                  child: Row(
                    children: <Widget>[
                      Expanded(
                        child: Text(
                          '${order.orderNumber} — ${order.stateLabel}',
                          style: ShiftText.body,
                        ),
                      ),
                      ShiftValue(
                        ShiftFormat.money(order.amount),
                        style: ShiftText.bodyStrong,
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      if (onViewOrder != null)
                        ShiftButton(
                          label: ShiftStrings.viewOrder,
                          variant: ShiftButtonVariant.quiet,
                          onPressed: () => onViewOrder!(order),
                        ),
                    ],
                  ),
                ),
            ],
          ] else ...<Widget>[
            const SizedBox(height: AppSpacing.md),
            const ShiftNotice(
              tone: ShiftTone.success,
              message: ShiftStrings.allOrdersSettled,
            ),
          ],
        ],
      ),
    );
  }
}

class _OrderStatusChip extends StatelessWidget {
  const _OrderStatusChip({required this.label, required this.count, required this.tone});

  final String label;
  final int count;
  final ShiftTone tone;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: 8),
    decoration: BoxDecoration(
      color: tone.fill,
      borderRadius: BorderRadius.circular(10),
      border: Border.all(color: tone.ink.withValues(alpha: 0.18)),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        ShiftValue(
          ShiftFormat.count(count),
          style: ShiftText.metricValueSmall,
          color: tone.ink,
        ),
        const SizedBox(width: 6),
        Text(label, style: ShiftText.body.copyWith(color: tone.ink)),
      ],
    ),
  );
}

/// The cash drawer projection: opening float through withdrawals/deposits to
/// the currently expected amount. Deliberately never shows a counted actual —
/// that only exists after step 2 of the closing wizard.
class CashDrawerStatusCard extends StatelessWidget {
  const CashDrawerStatusCard({super.key, required this.drawer});

  final CashDrawerSnapshot drawer;

  @override
  Widget build(BuildContext context) => ShiftCard(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        const ShiftSectionHeader(
          title: ShiftStrings.cashDrawer,
          icon: Icons.point_of_sale_outlined,
        ),
        const SizedBox(height: AppSpacing.md),
        ShiftKeyValueRow(
          label: ShiftStrings.openingFloat,
          value: ShiftFormat.money(drawer.openingFloat),
        ),
        ShiftKeyValueRow(
          label: '+ ${ShiftStrings.cashSales}',
          value: ShiftFormat.money(drawer.cashSales),
          valueColor: ShiftColors.matchInk,
        ),
        if (drawer.cashRefunds > 0)
          ShiftKeyValueRow(
            label: '- ${ShiftStrings.cashRefunds}',
            value: ShiftFormat.money(drawer.cashRefunds),
            valueColor: ShiftColors.blockerInk,
          ),
        if (drawer.withdrawals > 0)
          ShiftKeyValueRow(
            label: '- ${ShiftStrings.cashWithdrawals}',
            value: ShiftFormat.money(drawer.withdrawals),
            valueColor: ShiftColors.blockerInk,
          ),
        if (drawer.deposits > 0)
          ShiftKeyValueRow(
            label: '+ ${ShiftStrings.cashDeposits}',
            value: ShiftFormat.money(drawer.deposits),
            valueColor: ShiftColors.matchInk,
          ),
        if (drawer.expenses > 0)
          ShiftKeyValueRow(
            label: '- ${ShiftStrings.cashExpenses}',
            value: ShiftFormat.money(drawer.expenses),
            valueColor: ShiftColors.blockerInk,
          ),
        const ShiftDividerLine(),
        ShiftKeyValueRow(
          label: ShiftStrings.expectedNow,
          value: ShiftFormat.money(drawer.expected),
          emphasize: true,
        ),
        const SizedBox(height: AppSpacing.sm),
        Text(ShiftStrings.cashNotCountedYet, style: ShiftText.label),
      ],
    ),
  );
}

/// Bar-count status preview, shown on the overview before the closing wizard
/// is entered.
class BarCountStatusCard extends StatelessWidget {
  const BarCountStatusCard({super.key, required this.template, required this.now});

  final BarCountTemplate template;
  final DateTime now;

  @override
  Widget build(BuildContext context) {
    final String statusLabel = !template.isStarted
        ? ShiftStrings.barCountNotStarted
        : template.isComplete
        ? ShiftStrings.barCountComplete
        : ShiftStrings.barCountInProgress;
    final ShiftTone statusTone = !template.isStarted
        ? ShiftTone.neutral
        : template.isComplete
        ? ShiftTone.success
        : ShiftTone.warning;

    return ShiftCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          ShiftSectionHeader(
            title: ShiftStrings.barCountStatus,
            icon: Icons.inventory_2_outlined,
            trailing: ShiftBadge(label: statusLabel, tone: statusTone, dense: true),
          ),
          const SizedBox(height: AppSpacing.md),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Expanded(
                child: ShiftFactTile(
                  label: ShiftStrings.itemsToCount,
                  value: ShiftFormat.count(template.totalItems),
                ),
              ),
              Expanded(
                child: ShiftFactTile(
                  label: ShiftStrings.itemsCounted,
                  value: ShiftFormat.count(template.countedItems),
                ),
              ),
              Expanded(
                child: ShiftFactTile(
                  label: ShiftStrings.currentDifferences,
                  value: ShiftFormat.count(template.differenceItems),
                  valueColor: template.differenceItems > 0
                      ? ShiftColors.shortageInk
                      : ShiftColors.ink,
                ),
              ),
              Expanded(
                child: ShiftFactTile(
                  label: ShiftStrings.lastCount,
                  value: template.lastCountedAt == null
                      ? '—'
                      : ShiftFormat.relativeDayTime(template.lastCountedAt!, now),
                  numeric: false,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          ShiftProgressBar(value: template.progress, tone: statusTone),
        ],
      ),
    );
  }
}

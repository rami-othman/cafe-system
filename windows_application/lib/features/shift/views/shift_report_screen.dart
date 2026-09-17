import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../app/shift_route_locations.dart';
import '../../../core/theme/app_radius.dart';
import '../../../core/theme/app_spacing.dart';
import '../controllers/shift_report_cubit.dart';
import '../models/shift_models.dart';
import '../widgets/shift_design.dart';
import '../widgets/shift_format.dart';
import '../widgets/shift_identity_header.dart';
import '../widgets/shift_primitives.dart';
import '../widgets/shift_state_views.dart';
import '../widgets/shift_strings.dart';

/// The complete closing report: identity, sales, orders, payments, cash,
/// cash movements, bar count and differences, refunds, discounts, notes and
/// audit trail — plus a print-preview overlay for A4 or thermal-receipt
/// layouts. No backend printing is performed; this is a UI mock.
class ShiftReportScreen extends StatefulWidget {
  const ShiftReportScreen({super.key, required this.shiftNumber});

  final String shiftNumber;

  @override
  State<ShiftReportScreen> createState() => _ShiftReportScreenState();
}

class _ShiftReportScreenState extends State<ShiftReportScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => context.read<ShiftReportCubit>().load(widget.shiftNumber),
    );
  }

  @override
  Widget build(BuildContext context) => BlocBuilder<ShiftReportCubit, ShiftReportState>(
    builder: (BuildContext context, ShiftReportState state) {
      switch (state.status) {
        case ShiftReportStatus.loading:
          return const SingleChildScrollView(
            padding: EdgeInsets.all(AppSpacing.xl),
            child: ShiftTableSkeleton(label: ShiftStrings.loadingShift),
          );
        case ShiftReportStatus.error:
        case ShiftReportStatus.missing:
          return ShiftErrorView(
            title: ShiftStrings.errorLoadingShift,
            detail: state.errorMessage,
            onRetry: () => context.read<ShiftReportCubit>().load(widget.shiftNumber),
          );
        case ShiftReportStatus.ready:
          break;
      }

      final ShiftClosingResult result = state.result!;
      return Stack(
        children: <Widget>[
          _ReportBody(result: result),
          if (state.showPrintPreview)
            _PrintPreviewOverlay(result: result, layout: state.printLayout),
        ],
      );
    },
  );
}

class _ReportBody extends StatelessWidget {
  const _ReportBody({required this.result});

  final ShiftClosingResult result;

  @override
  Widget build(BuildContext context) {
    final ShiftSnapshot snapshot = result.snapshot;
    final ShiftReportCubit cubit = context.read<ShiftReportCubit>();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppSpacing.xl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              IconButton(
                onPressed: () => context.canPop()
                    ? context.pop()
                    : context.go(ShiftRouteLocations.history),
                icon: const Icon(Icons.arrow_back),
                color: ShiftColors.inkSoft,
              ),
              Expanded(
                child: Text(ShiftStrings.reportTitle, style: ShiftText.pageTitle),
              ),
              ShiftButton(
                label: ShiftStrings.print,
                variant: ShiftButtonVariant.secondary,
                icon: Icons.print_outlined,
                onPressed: () => cubit.showPrintPreview(ShiftPrintLayout.a4),
              ),
              const SizedBox(width: AppSpacing.sm),
              ShiftButton(
                buttonKey: const Key('shift-report-export-pdf'),
                label: ShiftStrings.exportPdf,
                icon: Icons.picture_as_pdf_outlined,
                onPressed: () => cubit.showPrintPreview(ShiftPrintLayout.a4),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          ShiftCard(
            child: Row(
              children: <Widget>[
                Expanded(
                  child: ShiftFactTile(
                    label: ShiftStrings.reportNumber,
                    value: result.reportNumber,
                  ),
                ),
                Expanded(
                  child: ShiftFactTile(
                    label: ShiftStrings.reportDate,
                    value: ShiftFormat.dateTime(DateTime.now()),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          ShiftIdentityHeader(identity: snapshot.identity),
          const SizedBox(height: AppSpacing.lg),
          _Section(
            title: ShiftStrings.reportSectionSales,
            icon: Icons.trending_up,
            child: _SalesTable(sales: snapshot.sales),
          ),
          const SizedBox(height: AppSpacing.lg),
          _Section(
            title: ShiftStrings.reportSectionOrders,
            icon: Icons.assignment_turned_in_outlined,
            child: _OrdersTable(orders: snapshot.orders),
          ),
          const SizedBox(height: AppSpacing.lg),
          _Section(
            title: ShiftStrings.reportSectionPayments,
            icon: Icons.pie_chart_outline,
            child: _PaymentsTable(breakdown: snapshot.payments),
          ),
          const SizedBox(height: AppSpacing.lg),
          _Section(
            title: ShiftStrings.reportSectionCash,
            icon: Icons.point_of_sale_outlined,
            child: _CashSection(result: result),
          ),
          const SizedBox(height: AppSpacing.lg),
          _Section(
            title: ShiftStrings.reportSectionCashMovements,
            icon: Icons.receipt_long_outlined,
            child: _CashMovementsTable(movements: snapshot.drawer.movements),
          ),
          const SizedBox(height: AppSpacing.lg),
          _Section(
            title: ShiftStrings.reportSectionBarCount,
            icon: Icons.inventory_2_outlined,
            child: _BarCountTable(bar: snapshot.barCount),
          ),
          const SizedBox(height: AppSpacing.lg),
          _Section(
            title: ShiftStrings.reportSectionBarDifferences,
            icon: Icons.difference_outlined,
            child: _BarDifferencesTable(bar: snapshot.barCount),
          ),
          const SizedBox(height: AppSpacing.lg),
          _Section(
            title: ShiftStrings.reportSectionRefunds,
            icon: Icons.undo_outlined,
            child: _RefundsTable(refunds: snapshot.refunds),
          ),
          const SizedBox(height: AppSpacing.lg),
          _Section(
            title: ShiftStrings.reportSectionDiscounts,
            icon: Icons.local_offer_outlined,
            child: _DiscountsTable(discounts: snapshot.discounts),
          ),
          const SizedBox(height: AppSpacing.lg),
          _Section(
            title: ShiftStrings.reportSectionNotes,
            icon: Icons.notes_outlined,
            child: Text(
              result.closingNotes.isEmpty ? ShiftStrings.noNotes : result.closingNotes,
              style: ShiftText.body,
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          _Section(
            title: ShiftStrings.reportSectionClosing,
            icon: Icons.fact_check_outlined,
            child: Column(
              children: <Widget>[
                ShiftKeyValueRow(
                  label: ShiftStrings.openedBy,
                  value: snapshot.identity.openedBy,
                  numeric: false,
                ),
                ShiftKeyValueRow(
                  label: ShiftStrings.closedBy,
                  value: result.closedBy,
                  numeric: false,
                ),
                ShiftKeyValueRow(
                  label: ShiftStrings.closedAt,
                  value: ShiftFormat.dateTime(result.closedAt),
                ),
                ShiftKeyValueRow(
                  label: ShiftStrings.cashDifferenceReason,
                  value: result.cash.reason == null
                      ? ShiftStrings.noReasonRecorded
                      : _reasonLabel(result.cash.reason!),
                  numeric: false,
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.xxxl),
        ],
      ),
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({required this.title, required this.child, this.icon});

  final String title;
  final Widget child;
  final IconData? icon;

  @override
  Widget build(BuildContext context) => ShiftCard(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Row(
          children: <Widget>[
            if (icon != null) ...<Widget>[
              Icon(icon, size: 16, color: ShiftColors.inkMuted),
              const SizedBox(width: 6),
            ],
            Text(title, style: ShiftText.sectionTitle),
          ],
        ),
        const SizedBox(height: AppSpacing.md),
        child,
      ],
    ),
  );
}

class _SalesTable extends StatelessWidget {
  const _SalesTable({required this.sales});

  final ShiftSalesSummary sales;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (BuildContext context, BoxConstraints constraints) {
      final int columns = constraints.maxWidth >= ShiftLayout.desktopBreakpoint ? 4 : 2;
      final List<(String, String)> rows = <(String, String)>[
        (ShiftStrings.grossSales, ShiftFormat.money(sales.grossSales)),
        (ShiftStrings.totalDiscounts, ShiftFormat.money(sales.discounts)),
        (ShiftStrings.totalRefunds, ShiftFormat.money(sales.refunds)),
        (ShiftStrings.netSales, ShiftFormat.money(sales.netSales)),
        (ShiftStrings.orderCount, ShiftFormat.count(sales.orderCount)),
        (ShiftStrings.averageOrder, ShiftFormat.money(sales.averageOrderValue)),
        (ShiftStrings.cancelledOrders, ShiftFormat.count(sales.cancelledOrderCount)),
        (ShiftStrings.refundCount, ShiftFormat.count(sales.refundCount)),
      ];
      return GridView.count(
        crossAxisCount: columns,
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        mainAxisSpacing: AppSpacing.md,
        crossAxisSpacing: AppSpacing.md,
        childAspectRatio: 2.6,
        children: <Widget>[
          for (final (String label, String value) in rows)
            ShiftFactTile(label: label, value: value),
        ],
      );
    },
  );
}

class _OrdersTable extends StatelessWidget {
  const _OrdersTable({required this.orders});

  final OrdersStatusSummary orders;

  @override
  Widget build(BuildContext context) => Wrap(
    spacing: AppSpacing.sm,
    runSpacing: AppSpacing.sm,
    children: <Widget>[
      ShiftBadge(
        label: '${ShiftStrings.ordersCompleted}: ${ShiftFormat.count(orders.completed)}',
        tone: ShiftTone.success,
      ),
      ShiftBadge(
        label: '${ShiftStrings.ordersCancelled}: ${ShiftFormat.count(orders.cancelled)}',
        tone: ShiftTone.neutral,
      ),
      ShiftBadge(
        label:
            '${ShiftStrings.ordersPartiallyRefunded}: ${ShiftFormat.count(orders.partiallyRefunded)}',
        tone: ShiftTone.surplus,
      ),
      ShiftBadge(
        label: '${ShiftStrings.ordersFullyRefunded}: ${ShiftFormat.count(orders.fullyRefunded)}',
        tone: ShiftTone.surplus,
      ),
    ],
  );
}

class _PaymentsTable extends StatelessWidget {
  const _PaymentsTable({required this.breakdown});

  final PaymentBreakdown breakdown;

  @override
  Widget build(BuildContext context) => Column(
    children: <Widget>[
      for (final PaymentBreakdownLine line in breakdown.lines)
        ShiftKeyValueRow(
          label: switch (line.channel) {
            PaymentChannel.cash => ShiftStrings.paymentCash,
            PaymentChannel.card => ShiftStrings.paymentCard,
            PaymentChannel.transfer => ShiftStrings.paymentTransfer,
            PaymentChannel.customerCredit => ShiftStrings.paymentCustomerCredit,
            PaymentChannel.other => ShiftStrings.paymentOther,
          },
          value: ShiftFormat.money(line.amount),
          secondary: '${ShiftFormat.count(line.transactionCount)} ${ShiftStrings.operationsUnit}',
        ),
      const ShiftDividerLine(),
      ShiftKeyValueRow(
        label: ShiftStrings.total,
        value: ShiftFormat.money(breakdown.total),
        emphasize: true,
      ),
    ],
  );
}

class _CashSection extends StatelessWidget {
  const _CashSection({required this.result});

  final ShiftClosingResult result;

  @override
  Widget build(BuildContext context) {
    final CashCountResult cash = result.cash;
    return Column(
      children: <Widget>[
        ShiftKeyValueRow(
          label: ShiftStrings.openingFloat,
          value: ShiftFormat.money(result.snapshot.drawer.openingFloat),
        ),
        ShiftKeyValueRow(label: ShiftStrings.expectedCash, value: ShiftFormat.money(cash.expected)),
        ShiftKeyValueRow(label: ShiftStrings.actualCash, value: ShiftFormat.money(cash.actual)),
        ShiftKeyValueRow(
          label: ShiftStrings.cashDifference,
          value: ShiftFormat.signedMoney(cash.difference),
          valueColor: cash.isBalanced
              ? ShiftColors.matchInk
              : cash.isShortage
              ? ShiftColors.shortageInk
              : ShiftColors.surplusInk,
          emphasize: true,
        ),
      ],
    );
  }
}

class _CashMovementsTable extends StatelessWidget {
  const _CashMovementsTable({required this.movements});

  final List<CashMovement> movements;

  static const List<ShiftTableCell> _headers = <ShiftTableCell>[
    ShiftTableCell(ShiftStrings.movementType, flex: 1.4),
    ShiftTableCell(ShiftStrings.movementTime, flex: .8, alignment: Alignment.center),
    ShiftTableCell(ShiftStrings.movementDescription, flex: 1.6),
    ShiftTableCell(ShiftStrings.movementValue, flex: 1, alignment: Alignment.center),
  ];

  @override
  Widget build(BuildContext context) => ShiftTableFrame(
    minWidth: 700,
    child: Column(
      children: <Widget>[
        ShiftTableHeader(cells: _headers),
        for (final CashMovement m in movements)
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.lg,
              vertical: AppSpacing.sm,
            ),
            decoration: const BoxDecoration(
              border: Border(bottom: BorderSide(color: ShiftColors.border)),
            ),
            child: Row(
              children: <Widget>[
                Expanded(
                  flex: 14,
                  child: Text(_movementLabel(m.kind), style: ShiftText.tableCell),
                ),
                Expanded(
                  flex: 8,
                  child: Center(
                    child: ShiftValue(ShiftFormat.time(m.occurredAt), style: ShiftText.tableCell),
                  ),
                ),
                Expanded(
                  flex: 16,
                  child: Text(m.description, style: ShiftText.tableCell),
                ),
                Expanded(
                  flex: 10,
                  child: Center(
                    child: ShiftValue(
                      ShiftFormat.signedMoney(m.amount),
                      style: ShiftText.bodyStrong,
                      color: m.amount >= 0 ? ShiftColors.matchInk : ShiftColors.blockerInk,
                    ),
                  ),
                ),
              ],
            ),
          ),
      ],
    ),
  );

  static String _movementLabel(CashMovementKind kind) => switch (kind) {
    CashMovementKind.openingFloat => ShiftStrings.movementOpeningFloat,
    CashMovementKind.cashSale => ShiftStrings.movementCashSale,
    CashMovementKind.cashRefund => ShiftStrings.movementCashRefund,
    CashMovementKind.withdrawal => ShiftStrings.movementWithdrawal,
    CashMovementKind.deposit => ShiftStrings.movementDeposit,
    CashMovementKind.expense => ShiftStrings.movementExpense,
  };
}

class _BarCountTable extends StatelessWidget {
  const _BarCountTable({required this.bar});

  final BarCountTemplate bar;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (BuildContext context, BoxConstraints constraints) {
      final int columns = constraints.maxWidth >= ShiftLayout.desktopBreakpoint ? 5 : 2;
      final List<(String, String, Color?)> rows = <(String, String, Color?)>[
        (ShiftStrings.itemsToCount, ShiftFormat.count(bar.totalItems), null),
        (ShiftStrings.statusMatch, ShiftFormat.count(bar.matchedItems), ShiftColors.matchInk),
        (
          ShiftStrings.statusShortage,
          ShiftFormat.count(bar.shortageItems),
          bar.shortageItems > 0 ? ShiftColors.shortageInk : null,
        ),
        (
          ShiftStrings.statusSurplus,
          ShiftFormat.count(bar.surplusItems),
          bar.surplusItems > 0 ? ShiftColors.surplusInk : null,
        ),
        (
          ShiftStrings.currentDifferences,
          ShiftFormat.count(bar.differenceItems),
          bar.differenceItems > 0 ? ShiftColors.blockerInk : null,
        ),
      ];
      return GridView.count(
        crossAxisCount: columns,
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        mainAxisSpacing: AppSpacing.md,
        crossAxisSpacing: AppSpacing.md,
        childAspectRatio: 2.4,
        children: <Widget>[
          for (final (String label, String value, Color? color) in rows)
            ShiftFactTile(label: label, value: value, valueColor: color),
        ],
      );
    },
  );
}

class _BarDifferencesTable extends StatelessWidget {
  const _BarDifferencesTable({required this.bar});

  final BarCountTemplate bar;

  static const List<ShiftTableCell> _headers = <ShiftTableCell>[
    ShiftTableCell(ShiftStrings.item, flex: 2.4),
    ShiftTableCell(ShiftStrings.unit, flex: .8, alignment: Alignment.center),
    ShiftTableCell(ShiftStrings.theoreticalQty, flex: 1, alignment: Alignment.center),
    ShiftTableCell(ShiftStrings.actualQty, flex: 1, alignment: Alignment.center),
    ShiftTableCell(ShiftStrings.difference, flex: 1, alignment: Alignment.center),
    ShiftTableCell(ShiftStrings.differenceStatus, flex: 1.2, alignment: Alignment.center),
    ShiftTableCell(ShiftStrings.differenceNote, flex: 1.8),
  ];

  @override
  Widget build(BuildContext context) {
    final List<BarCountLine> lines = bar.differenceLines;
    if (lines.isEmpty) {
      return const ShiftNotice(
        tone: ShiftTone.success,
        message: ShiftStrings.noBarDifferences,
      );
    }
    return ShiftTableFrame(
      minWidth: 900,
      child: Column(
        children: <Widget>[
          ShiftTableHeader(cells: _headers),
          for (final BarCountLine line in lines)
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.lg,
                vertical: AppSpacing.sm,
              ),
              decoration: const BoxDecoration(
                border: Border(bottom: BorderSide(color: ShiftColors.border)),
              ),
              child: Row(
                children: <Widget>[
                  Expanded(flex: 24, child: Text(line.name, style: ShiftText.tableCell)),
                  Expanded(
                    flex: 8,
                    child: Center(child: Text(line.unit, style: ShiftText.tableCell)),
                  ),
                  Expanded(
                    flex: 10,
                    child: Center(
                      child: ShiftValue(
                        ShiftFormat.quantity(line.theoretical, line.decimals),
                        style: ShiftText.tableCell,
                      ),
                    ),
                  ),
                  Expanded(
                    flex: 10,
                    child: Center(
                      child: ShiftValue(
                        ShiftFormat.quantity(line.counted!, line.decimals),
                        style: ShiftText.tableCell,
                      ),
                    ),
                  ),
                  Expanded(
                    flex: 10,
                    child: Center(
                      child: ShiftValue(
                        ShiftFormat.signedQuantity(line.difference!, line.decimals),
                        style: ShiftText.bodyStrong,
                        color: line.status == BarCountStatus.shortage
                            ? ShiftColors.shortageInk
                            : ShiftColors.surplusInk,
                      ),
                    ),
                  ),
                  Expanded(
                    flex: 12,
                    child: Center(
                      child: ShiftBadge(
                        label: line.status == BarCountStatus.shortage
                            ? ShiftStrings.statusShortage
                            : ShiftStrings.statusSurplus,
                        tone: line.status == BarCountStatus.shortage
                            ? ShiftTone.warning
                            : ShiftTone.surplus,
                        dense: true,
                      ),
                    ),
                  ),
                  Expanded(
                    flex: 18,
                    child: Text(
                      line.note.isEmpty ? '—' : line.note,
                      style: ShiftText.tableCell,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _RefundsTable extends StatelessWidget {
  const _RefundsTable({required this.refunds});

  final List<ShiftRefundEntry> refunds;

  @override
  Widget build(BuildContext context) {
    if (refunds.isEmpty) {
      return Text(ShiftStrings.noRefunds, style: ShiftText.body);
    }
    return Column(
      children: <Widget>[
        for (final ShiftRefundEntry r in refunds)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Row(
              children: <Widget>[
                Expanded(
                  flex: 2,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      ShiftValue(r.orderNumber, style: ShiftText.bodyStrong),
                      Text(r.reason, style: ShiftText.label),
                    ],
                  ),
                ),
                Expanded(
                  child: ShiftValue(ShiftFormat.time(r.occurredAt), style: ShiftText.tableCell),
                ),
                ShiftValue(
                  ShiftFormat.money(r.amount),
                  style: ShiftText.bodyStrong,
                  color: ShiftColors.blockerInk,
                ),
              ],
            ),
          ),
      ],
    );
  }
}

class _DiscountsTable extends StatelessWidget {
  const _DiscountsTable({required this.discounts});

  final List<ShiftDiscountEntry> discounts;

  @override
  Widget build(BuildContext context) {
    if (discounts.isEmpty) {
      return Text(ShiftStrings.noDiscounts, style: ShiftText.body);
    }
    return Column(
      children: <Widget>[
        for (final ShiftDiscountEntry d in discounts)
          ShiftKeyValueRow(
            label: d.policyName,
            value: ShiftFormat.money(d.amount),
            secondary: '${ShiftFormat.count(d.appliedCount)} ${ShiftStrings.operationsUnit}',
          ),
      ],
    );
  }
}

String _reasonLabel(CashDifferenceReason reason) => switch (reason) {
  CashDifferenceReason.changeError => ShiftStrings.reasonChangeError,
  CashDifferenceReason.unrecordedTransaction => ShiftStrings.reasonUnrecordedTransaction,
  CashDifferenceReason.unrecordedWithdrawal => ShiftStrings.reasonUnrecordedWithdrawal,
  CashDifferenceReason.unrecordedExpense => ShiftStrings.reasonUnrecordedExpense,
  CashDifferenceReason.unknownSurplus => ShiftStrings.reasonUnknownSurplus,
  CashDifferenceReason.unknownShortage => ShiftStrings.reasonUnknownShortage,
  CashDifferenceReason.other => ShiftStrings.reasonOther,
};

/// Print-preview overlay: A4 report or thermal-receipt summary. Mock only —
/// no real print pipeline is invoked.
class _PrintPreviewOverlay extends StatelessWidget {
  const _PrintPreviewOverlay({required this.result, required this.layout});

  final ShiftClosingResult result;
  final ShiftPrintLayout layout;

  @override
  Widget build(BuildContext context) {
    final ShiftReportCubit cubit = context.read<ShiftReportCubit>();
    return Positioned.fill(
      child: ColoredBox(
        color: Colors.black.withValues(alpha: 0.45),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 640),
            child: Container(
              width: layout == ShiftPrintLayout.a4 ? ShiftLayout.reportPageWidth : 320,
              margin: const EdgeInsets.all(AppSpacing.xl),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: AppRadius.card,
              ),
              child: Column(
                children: <Widget>[
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.lg,
                      vertical: AppSpacing.sm,
                    ),
                    decoration: const BoxDecoration(
                      border: Border(bottom: BorderSide(color: ShiftColors.border)),
                    ),
                    child: Row(
                      children: <Widget>[
                        Expanded(
                          child: Text(ShiftStrings.printPreview, style: ShiftText.cardTitle),
                        ),
                        ShiftSegmentedControl<ShiftPrintLayout>(
                          selected: layout,
                          segments: const <ShiftSegment<ShiftPrintLayout>>[
                            ShiftSegment(
                              value: ShiftPrintLayout.a4,
                              label: ShiftStrings.printLayoutA4,
                            ),
                            ShiftSegment(
                              value: ShiftPrintLayout.receipt,
                              label: ShiftStrings.printLayoutReceipt,
                            ),
                          ],
                          onChanged: cubit.setPrintLayout,
                        ),
                        IconButton(
                          onPressed: cubit.hidePrintPreview,
                          icon: const Icon(Icons.close),
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.all(AppSpacing.lg),
                      child: layout == ShiftPrintLayout.a4
                          ? _A4Preview(result: result)
                          : _ReceiptPreview(result: result),
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
}

class _A4Preview extends StatelessWidget {
  const _A4Preview({required this.result});

  final ShiftClosingResult result;

  @override
  Widget build(BuildContext context) {
    final ShiftSnapshot s = result.snapshot;
    return DefaultTextStyle(
      style: ShiftText.body.copyWith(color: Colors.black),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const Text('Cafe 6:18', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18)),
          Text(ShiftStrings.reportTitle),
          const SizedBox(height: AppSpacing.md),
          Text('${ShiftStrings.shiftNumber}: ${s.identity.shiftNumber}'),
          Text('${ShiftStrings.branch}: ${s.identity.branchName}'),
          Text('${ShiftStrings.cashier}: ${s.identity.cashierName}'),
          const SizedBox(height: AppSpacing.md),
          Text('${ShiftStrings.netSales}: ${ShiftFormat.money(s.sales.netSales)}'),
          Text('${ShiftStrings.cashDifference}: ${ShiftFormat.signedMoney(result.cash.difference)}'),
          Text(
            '${ShiftStrings.barDifferenceCount}: ${ShiftFormat.count(s.barCount.differenceItems)}',
          ),
        ],
      ),
    );
  }
}

class _ReceiptPreview extends StatelessWidget {
  const _ReceiptPreview({required this.result});

  final ShiftClosingResult result;

  @override
  Widget build(BuildContext context) {
    final ShiftSnapshot s = result.snapshot;
    return DefaultTextStyle(
      style: ShiftText.tableCell.copyWith(color: Colors.black, fontFamily: 'monospace'),
      textAlign: TextAlign.center,
      child: Column(
        children: <Widget>[
          const Text('CAFE 6:18', style: TextStyle(fontWeight: FontWeight.w800)),
          Text(s.identity.shiftNumber),
          const Divider(),
          Text('${ShiftStrings.netSales}: ${ShiftFormat.money(s.sales.netSales)}'),
          Text('${ShiftStrings.actualCash}: ${ShiftFormat.money(result.cash.actual)}'),
          Text('${ShiftStrings.cashDifference}: ${ShiftFormat.signedMoney(result.cash.difference)}'),
          const Divider(),
          Text(ShiftFormat.dateTime(result.closedAt)),
        ],
      ),
    );
  }
}

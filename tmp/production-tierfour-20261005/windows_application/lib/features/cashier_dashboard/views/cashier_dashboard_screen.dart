import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../app/localization/localization_extensions.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../shared/access/cashier_access.dart';
import '../controllers/cashier_dashboard_cubit.dart';
import '../controllers/cashier_dashboard_state.dart';
import '../models/cashier_dashboard.dart';
import '../widgets/cashier_dashboard_widgets.dart';
import '../widgets/cashier_identity_header.dart';

/// The Cashier's operational control centre.
///
/// Everything here answers a question a cashier has at the till: how much cash
/// should be in the drawer, what has been sold and how it was paid, what is
/// still open, and what stock the POS is working from. There is deliberately no
/// profit, margin, cost, valuation or ledger figure on this screen — and none
/// is sent to it.
class CashierDashboardScreen extends StatefulWidget {
  const CashierDashboardScreen({super.key});

  @override
  State<CashierDashboardScreen> createState() => _CashierDashboardScreenState();
}

class _CashierDashboardScreenState extends State<CashierDashboardScreen> {
  @override
  void initState() {
    super.initState();
    // One call per mount. The cubit itself drops duplicate in-flight loads, so
    // a rebuild can never turn into a second request.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) context.read<CashierDashboardCubit>().load();
    });
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<CashierDashboardCubit, CashierDashboardState>(
      builder: (BuildContext context, CashierDashboardState state) {
        return RefreshIndicator(
          onRefresh: () => context.read<CashierDashboardCubit>().refresh(),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.xl,
              AppSpacing.lg,
              AppSpacing.xl,
              AppSpacing.xxl,
            ),
            children: <Widget>[
              Text(
                context.l10n.cashierDashboardTitle,
                style: AppTextStyles.headlineMedium,
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                context.l10n.cashierDashboardSubtitle,
                style: AppTextStyles.bodySmall.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              if (state.status == CashierDashboardStatus.error &&
                  state.data == null)
                CashierErrorPanel(
                  message: context.l10n.cashierLoadError,
                  retryLabel: context.l10n.cashierRetry,
                  onRetry: () =>
                      context.read<CashierDashboardCubit>().refresh(),
                )
              else if (state.showsSkeleton)
                const _DashboardSkeleton()
              else
                _DashboardBody(
                  data: state.data ?? CashierDashboard.empty,
                  staleError: state.status == CashierDashboardStatus.error,
                ),
            ],
          ),
        );
      },
    );
  }
}

class _DashboardSkeleton extends StatelessWidget {
  const _DashboardSkeleton();

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: <Widget>[
      const CashierSkeletonCard(height: 96),
      const SizedBox(height: AppSpacing.xl),
      CashierCardGrid(
        children: List<Widget>.generate(4, (_) => const CashierSkeletonCard()),
      ),
      const SizedBox(height: AppSpacing.xl),
      CashierCardGrid(
        children: List<Widget>.generate(4, (_) => const CashierSkeletonCard()),
      ),
    ],
  );
}

class _DashboardBody extends StatelessWidget {
  const _DashboardBody({required this.data, required this.staleError});

  final CashierDashboard data;

  /// A refresh failed but earlier figures are still on screen. The banner says
  /// so rather than replacing a working till view with an error page.
  final bool staleError;

  @override
  Widget build(BuildContext context) {
    final String scopeLabel = data.hasOpenShift
        ? context.l10n.cashierScopeCurrentShift
        : context.l10n.cashierScopeBranch;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        if (staleError) ...<Widget>[
          CashierErrorPanel(
            message: context.l10n.cashierLoadError,
            retryLabel: context.l10n.cashierRetry,
            onRetry: () => context.read<CashierDashboardCubit>().refresh(),
          ),
          const SizedBox(height: AppSpacing.lg),
        ],
        CashierIdentityHeader(scope: data.scope, shift: data.shift),
        const SizedBox(height: AppSpacing.xl),
        _QuickAccessSection(data: data),
        const SizedBox(height: AppSpacing.xl),
        _CashAndShiftSection(data: data, scopeLabel: scopeLabel),
        const SizedBox(height: AppSpacing.xl),
        _SalesAndOrdersSection(data: data, scopeLabel: scopeLabel),
        const SizedBox(height: AppSpacing.xl),
        if (data.finance.capabilities.isNotEmpty) ...<Widget>[
          _FinanceSection(data: data, scopeLabel: scopeLabel),
          const SizedBox(height: AppSpacing.xl),
        ],
        _InventorySection(data: data),
        const SizedBox(height: AppSpacing.xl),
        _AlertsSection(alerts: data.alerts),
      ],
    );
  }
}

class _CashAndShiftSection extends StatelessWidget {
  const _CashAndShiftSection({required this.data, required this.scopeLabel});

  final CashierDashboard data;
  final String scopeLabel;

  @override
  Widget build(BuildContext context) {
    final CashierCashDrawer drawer = data.cashDrawer;
    final String currency = data.scope.currency;
    final CashierVoucherTotals? receipts = data.finance.receiptVouchers;
    final CashierVoucherTotals? payments = data.finance.paymentVouchers;

    return CashierSection(
      title: context.l10n.cashierSectionCashAndShift,
      scopeLabel: scopeLabel,
      child: CashierCardGrid(
        children: <Widget>[
          CashierMetricCard(
            label: context.l10n.cashierExpectedDrawer,
            value: _money(drawer.expectedCash, currency, drawer.available),
            icon: Icons.point_of_sale_outlined,
            emphasis: true,
            tone: AppColors.primary,
            footnote: context.l10n.cashierExpectedDrawerHint,
          ),
          CashierMetricCard(
            label: context.l10n.cashierOpeningFloat,
            value: _money(drawer.openingCash, currency, drawer.available),
            icon: Icons.savings_outlined,
          ),
          CashierMetricCard(
            label: context.l10n.cashierCashSales,
            value: _money(drawer.cashSales, currency, drawer.available),
            icon: Icons.payments_outlined,
            subtext: drawer.available
                ? context.l10n.cashierOperationsCount(drawer.cashSaleCount)
                : null,
          ),
          CashierMetricCard(
            label: context.l10n.cashierCashRefunds,
            value: _money(drawer.cashRefunds, currency, drawer.available),
            icon: Icons.undo_outlined,
            tone: AppColors.danger,
            subtext: drawer.available
                ? context.l10n.cashierOperationsCount(drawer.cashRefundCount)
                : null,
          ),
          if (receipts case final CashierVoucherTotals totals)
            CashierMetricCard(
              label: context.l10n.cashierReceiptVouchers,
              value: _money(totals.cashTotal, currency, true),
              icon: Icons.request_quote_outlined,
              tone: AppColors.success,
              subtext: context.l10n.cashierOperationsCount(totals.count),
            ),
          if (payments case final CashierVoucherTotals totals)
            CashierMetricCard(
              label: context.l10n.cashierPaymentVouchers,
              value: _money(totals.cashTotal, currency, true),
              icon: Icons.receipt_long_outlined,
              tone: AppColors.warning,
              subtext: context.l10n.cashierOperationsCount(totals.count),
            ),
        ],
      ),
    );
  }
}

class _SalesAndOrdersSection extends StatelessWidget {
  const _SalesAndOrdersSection({required this.data, required this.scopeLabel});

  final CashierDashboard data;
  final String scopeLabel;

  @override
  Widget build(BuildContext context) {
    final CashierSales sales = data.sales;
    final CashierOrders orders = data.orders;
    final String currency = data.scope.currency;

    return CashierSection(
      title: context.l10n.cashierSectionSalesAndOrders,
      scopeLabel: scopeLabel,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          CashierCardGrid(
            children: <Widget>[
              CashierMetricCard(
                label: context.l10n.cashierShiftSales,
                value: _money(sales.netSales, currency, sales.available),
                icon: Icons.trending_up_outlined,
                tone: AppColors.primary,
              ),
              CashierMetricCard(
                label: context.l10n.cashierOrderCount,
                value: sales.available ? '${sales.orderCount}' : '—',
                icon: Icons.receipt_outlined,
              ),
              CashierMetricCard(
                label: context.l10n.cashierAverageOrder,
                value: _money(
                  sales.averageOrderValue,
                  currency,
                  sales.available,
                ),
                icon: Icons.calculate_outlined,
              ),
              CashierMetricCard(
                label: context.l10n.cashierCashSales,
                value: _money(
                  sales.amountFor('cash'),
                  currency,
                  sales.available,
                ),
                icon: Icons.payments_outlined,
              ),
              CashierMetricCard(
                label: context.l10n.cashierCardSales,
                value: _money(
                  sales.amountFor('card'),
                  currency,
                  sales.available,
                ),
                icon: Icons.credit_card_outlined,
              ),
              if (sales.otherMethodCount > 0)
                CashierMetricCard(
                  label: context.l10n.cashierOtherMethods,
                  value: '${sales.otherMethodCount}',
                  icon: Icons.account_balance_wallet_outlined,
                ),
              CashierMetricCard(
                label: context.l10n.cashierDiscounts,
                value: _money(sales.discounts, currency, sales.available),
                icon: Icons.local_offer_outlined,
                tone: AppColors.tertiary,
              ),
              CashierMetricCard(
                label: context.l10n.cashierRefunds,
                value: _money(sales.refunds, currency, sales.available),
                icon: Icons.undo_outlined,
                tone: AppColors.danger,
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          CashierCardGrid(
            minTileWidth: 180,
            children: <Widget>[
              CashierMetricCard(
                label: context.l10n.cashierOrdersActive,
                value: '${orders.active}',
                icon: Icons.play_circle_outline,
                tone: AppColors.info,
              ),
              CashierMetricCard(
                label: context.l10n.cashierOrdersHeld,
                value: '${orders.held}',
                icon: Icons.pause_circle_outline,
                tone: AppColors.warning,
              ),
              CashierMetricCard(
                label: context.l10n.cashierOrdersCompleted,
                value: '${orders.completed}',
                icon: Icons.check_circle_outline,
                tone: AppColors.success,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _FinanceSection extends StatelessWidget {
  const _FinanceSection({required this.data, required this.scopeLabel});

  final CashierDashboard data;
  final String scopeLabel;

  @override
  Widget build(BuildContext context) {
    final CashierFinance finance = data.finance;

    return CashierSection(
      title: context.l10n.cashierSectionFinance,
      scopeLabel: scopeLabel,
      // Only the four permitted workspaces are ever rendered; no accounts,
      // journals, reports, reconciliation, daily-closing or settings tile
      // exists on this surface for any actor.
      child: CashierCardGrid(
        minTileWidth: 200,
        children: <Widget>[
          if (finance.allows('receipts') || finance.allows('vouchers'))
            CashierActionTile(
              label: context.l10n.cashierQuickReceiptVoucher,
              icon: Icons.request_quote_outlined,
              tone: AppColors.success,
              badge: finance.receiptVouchers == null
                  ? null
                  : '${finance.receiptVouchers!.count}',
              onTap: () => context.go(CashierRoutes.financeVouchers),
            ),
          if (finance.allows('payments') || finance.allows('vouchers'))
            CashierActionTile(
              label: context.l10n.cashierQuickPaymentVoucher,
              icon: Icons.receipt_long_outlined,
              tone: AppColors.warning,
              badge: finance.paymentVouchers == null
                  ? null
                  : '${finance.paymentVouchers!.count}',
              onTap: () => context.go(CashierRoutes.financeVouchers),
            ),
          if (finance.allows('purchases'))
            CashierActionTile(
              label: context.l10n.cashierQuickPurchases,
              icon: Icons.local_shipping_outlined,
              badge: finance.purchaseDocumentCount == null
                  ? null
                  : '${finance.purchaseDocumentCount}',
              onTap: () => context.go(CashierRoutes.financePurchases),
            ),
          if (finance.allows('sales'))
            CashierActionTile(
              label: context.l10n.cashierQuickSales,
              icon: Icons.sell_outlined,
              badge: finance.salesInvoiceCount == null
                  ? null
                  : '${finance.salesInvoiceCount}',
              onTap: () => context.go(CashierRoutes.financeSales),
            ),
        ],
      ),
    );
  }
}

class _InventorySection extends StatelessWidget {
  const _InventorySection({required this.data});

  final CashierDashboard data;

  @override
  Widget build(BuildContext context) {
    final CashierInventorySummary inventory = data.inventory;
    final String countLabel = !inventory.shiftCount.required
        ? context.l10n.cashierShiftCountNotRequired
        : inventory.shiftCount.completed
        ? context.l10n.cashierShiftCountComplete
        : context.l10n.cashierShiftCountPending;

    return CashierSection(
      title: context.l10n.cashierSectionInventory,
      scopeLabel: context.l10n.cashierScopeBranch,
      child: CashierCardGrid(
        minTileWidth: 200,
        children: <Widget>[
          CashierMetricCard(
            label: context.l10n.cashierPosWarehouse,
            value: inventory.configured ? inventory.warehouseName : '—',
            icon: Icons.warehouse_outlined,
            tone: inventory.configured ? AppColors.secondary : AppColors.danger,
          ),
          CashierMetricCard(
            label: context.l10n.cashierItemCount,
            value: '${inventory.totalItems}',
            icon: Icons.inventory_2_outlined,
          ),
          CashierMetricCard(
            label: context.l10n.cashierLowStock,
            value: '${inventory.lowStockCount}',
            icon: Icons.trending_down_outlined,
            tone: AppColors.warning,
          ),
          CashierMetricCard(
            label: context.l10n.cashierZeroStock,
            value: '${inventory.zeroStockCount}',
            icon: Icons.exposure_zero_outlined,
            tone: AppColors.textSecondary,
          ),
          // Negative stock is an allowed operational outcome here, so it is
          // surfaced as a warning and never as a blocked sale.
          CashierMetricCard(
            label: context.l10n.cashierNegativeStock,
            value: '${inventory.negativeStockCount}',
            icon: Icons.warning_amber_outlined,
            tone: AppColors.danger,
          ),
          CashierMetricCard(
            label: context.l10n.cashierShiftCountStatus,
            value: countLabel,
            icon: Icons.fact_check_outlined,
            subtext:
                inventory.shiftCount.required && !inventory.shiftCount.completed
                ? context.l10n.cashierPendingTemplates(
                    inventory.shiftCount.pendingTemplates,
                  )
                : null,
          ),
        ],
      ),
    );
  }
}

class _QuickAccessSection extends StatelessWidget {
  const _QuickAccessSection({required this.data});

  final CashierDashboard data;

  @override
  Widget build(BuildContext context) {
    return CashierSection(
      title: context.l10n.cashierSectionQuickAccess,
      child: CashierCardGrid(
        minTileWidth: 200,
        children: <Widget>[
          CashierActionTile(
            label: context.l10n.cashierQuickPos,
            icon: Icons.point_of_sale_outlined,
            tone: AppColors.primary,
            onTap: () => context.go(CashierRoutes.pos),
          ),
          CashierActionTile(
            label: context.l10n.cashierQuickOrders,
            icon: Icons.receipt_long_outlined,
            badge: data.orders.blockingCount > 0
                ? '${data.orders.blockingCount}'
                : null,
            onTap: () => context.go(CashierRoutes.orders),
          ),
          CashierActionTile(
            label: context.l10n.cashierQuickDiscounts,
            icon: Icons.local_offer_outlined,
            tone: AppColors.tertiary,
            onTap: () => context.go(CashierRoutes.discounts),
          ),
          CashierActionTile(
            label: context.l10n.cashierQuickInventory,
            icon: Icons.inventory_2_outlined,
            onTap: () => context.go(CashierRoutes.cashierInventory),
          ),
          CashierActionTile(
            label: context.l10n.cashierQuickLowStock,
            icon: Icons.trending_down_outlined,
            tone: AppColors.warning,
            badge: '${data.inventory.lowStockCount}',
            onTap: () =>
                context.go('${CashierRoutes.cashierInventory}?state=low'),
          ),
          CashierActionTile(
            label: context.l10n.cashierQuickNegativeStock,
            icon: Icons.warning_amber_outlined,
            tone: AppColors.danger,
            badge: '${data.inventory.negativeStockCount}',
            onTap: () =>
                context.go('${CashierRoutes.cashierInventory}?state=negative'),
          ),
          CashierActionTile(
            label: context.l10n.cashierCloseShift,
            icon: Icons.lock_clock_outlined,
            onTap: () => context.go(CashierRoutes.shift),
          ),
        ],
      ),
    );
  }
}

class _AlertsSection extends StatelessWidget {
  const _AlertsSection({required this.alerts});

  final List<CashierAlert> alerts;

  @override
  Widget build(BuildContext context) {
    return CashierSection(
      title: context.l10n.cashierSectionAlerts,
      child: alerts.isEmpty
          ? Text(
              context.l10n.cashierAlertsNone,
              style: AppTextStyles.bodySmall.copyWith(
                color: AppColors.textMuted,
              ),
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                for (final CashierAlert alert in alerts)
                  CashierAlertRow(
                    severity: alert.severity,
                    message: _alertMessage(context, alert),
                  ),
              ],
            ),
    );
  }

  static String _alertMessage(
    BuildContext context,
    CashierAlert alert,
  ) => switch (alert.code) {
    'NO_OPERATIONAL_BRANCH' => context.l10n.cashierAlertNoBranch,
    'NO_OPEN_SHIFT' => context.l10n.cashierAlertNoShift,
    'POS_WAREHOUSE_NOT_CONFIGURED' => context.l10n.cashierAlertWarehouseMissing,
    'POS_WAREHOUSE_AMBIGUOUS' => context.l10n.cashierAlertWarehouseAmbiguous,
    'ORDERS_BLOCKING_SHIFT_CLOSE' => context.l10n.cashierAlertBlockingOrders(
      alert.count ?? 0,
    ),
    'NEGATIVE_STOCK_ITEMS' => context.l10n.cashierAlertNegativeStock(
      alert.count ?? 0,
    ),
    'LOW_STOCK_ITEMS' => context.l10n.cashierAlertLowStock(alert.count ?? 0),
    'SHIFT_COUNT_INCOMPLETE' => context.l10n.cashierAlertShiftCount,
    _ => alert.code,
  };
}

/// Amounts render as `CURRENCY value`; an em dash marks a figure that has no
/// meaning without an open shift, rather than a misleading zero.
String _money(String value, String currency, bool available) =>
    available ? '$currency $value' : '—';

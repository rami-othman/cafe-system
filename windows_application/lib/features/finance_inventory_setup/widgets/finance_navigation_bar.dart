import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../app/localization/localization_extensions.dart';
import '../../../l10n/app_localizations.dart';
import '../../../shared/access/cashier_access.dart';
import 'finance_design.dart';

/// The only Finance tab bar. It is installed by the application shell, so
/// Finance screens do not create competing local navigation.
///
/// Tab order and active-tab matching are driven by [_FinanceDestination.id]
/// (a stable route identifier), never by the localized [label] text, so
/// switching languages at runtime cannot desynchronize the selected tab.
class FinanceNavigationBar extends StatelessWidget {
  const FinanceNavigationBar({super.key, required this.selected, this.access});

  final String selected;
  final CashierAccess? access;

  static const List<_FinanceDestination> _destinations = <_FinanceDestination>[
    _FinanceDestination(
      'overview',
      '/finance',
      Icons.dashboard_outlined,
      permission: 'finance.view',
    ),
    _FinanceDestination(
      'transactions',
      '/finance/transactions',
      Icons.swap_horiz_outlined,
      permission: 'finance.transactions.view',
    ),
    _FinanceDestination(
      'vouchers',
      '/finance/vouchers',
      Icons.receipt_long_outlined,
      permission: 'finance.vouchers.view',
    ),
    _FinanceDestination(
      'cashbanks',
      '/finance/cash-banks',
      Icons.account_balance_outlined,
      permission: 'finance.cash_accounts.view',
    ),
    _FinanceDestination(
      'expenses',
      '/finance/expenses',
      Icons.payments_outlined,
      permission: 'finance.expenses.view',
    ),
    _FinanceDestination(
      'purchases',
      '/finance/purchases',
      Icons.shopping_cart_outlined,
      permission: 'finance.purchases.view',
    ),
    _FinanceDestination(
      'sales',
      '/finance/sales',
      Icons.point_of_sale_outlined,
      permission: 'finance.sales.view',
    ),
    _FinanceDestination(
      'suppliers',
      '/finance/suppliers',
      Icons.local_shipping_outlined,
      permission: 'finance.suppliers.view',
    ),
    _FinanceDestination(
      'reconciliation',
      '/finance/reconciliation',
      Icons.fact_check_outlined,
      permission: 'finance.reconciliation.view',
    ),
    _FinanceDestination(
      'journals',
      '/finance/journal-entries',
      Icons.menu_book_outlined,
      permission: 'finance.journals.view',
    ),
    _FinanceDestination(
      'closing',
      '/finance/daily-closing',
      Icons.lock_clock_outlined,
      permission: 'finance.daily_closing.view',
    ),
    _FinanceDestination(
      'reports',
      '/finance/reports',
      Icons.bar_chart_outlined,
      permission: 'finance.reports.view',
    ),
    _FinanceDestination(
      'accounts',
      '/finance/accounts',
      Icons.account_tree_outlined,
      permission: 'finance.accounts.view',
    ),
    _FinanceDestination(
      'periods',
      '/finance/accounting-periods',
      Icons.calendar_month_outlined,
      permission: 'finance.periods.view',
    ),
    _FinanceDestination(
      'settings',
      '/finance/settings',
      Icons.settings_outlined,
      permission: 'finance.settings.view',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
    color: FinanceColors.workspace,
    child: DecoratedBox(
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: FinanceColors.border)),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(
          horizontal: FinanceSpace.lg,
          vertical: FinanceSpace.sm,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: _visibleDestinations
              .map(
                (_FinanceDestination destination) => _FinanceNavigationItem(
                  destination: destination,
                  selected: destination.id == selected,
                ),
              )
              .toList(growable: false),
        ),
      ),
    ),
  );
  }

  /// A Cashier's tab bar is the explicit Cashier route allowlist
  /// (`CashierAccess.financeRoutePermissions`), not "every tab whose backend
  /// permission happens to be granted" — some of those permissions exist only
  /// to power reference-data lookups (supplier/account/payment-method
  /// dropdowns) inside the Purchases/Sales forms, and must not surface their
  /// own administrative workspace tab.
  Iterable<_FinanceDestination> get _visibleDestinations {
    final CashierAccess? currentAccess = access;
    if (currentAccess?.isCashier != true) return _destinations;
    return _destinations.where(
      (_FinanceDestination destination) =>
          CashierAccess.financeRoutePermissions.containsKey(
            destination.path,
          ) &&
          currentAccess!.allowsFinancePermission(destination.permission!),
    );
  }
}

class _FinanceDestination {
  const _FinanceDestination(this.id, this.path, this.icon, {this.permission});
  final String id;
  final String path;
  final IconData icon;
  final String? permission;
}

String financeSectionLabel(AppLocalizations l10n, String id) => switch (id) {
  'receipt-vouchers' => 'سند قبض',
  'payment-vouchers' => 'سند دفع',
  'overview' => l10n.financeSectionOverview,
  'transactions' => l10n.financeSectionTransactions,
  'vouchers' => 'السندات والقيود',
  'cashbanks' => l10n.financeSectionCashBanks,
  'expenses' => l10n.financeSectionExpenses,
  'purchases' => 'المشتريات',
  'sales' => 'المبيعات',
  'suppliers' => l10n.financeSectionSuppliers,
  'reconciliation' => l10n.financeSectionReconciliation,
  'journals' => l10n.financeSectionJournals,
  'closing' => l10n.financeSectionClosing,
  'reports' => l10n.financeSectionReports,
  'accounts' => l10n.financeSectionAccounts,
  'periods' => l10n.financeSectionPeriods,
  'settings' => l10n.financeSectionSettings,
  _ => l10n.financeSectionOverview,
};

class _FinanceNavigationItem extends StatelessWidget {
  const _FinanceNavigationItem({
    required this.destination,
    required this.selected,
  });
  final _FinanceDestination destination;
  final bool selected;

  @override
  Widget build(BuildContext context) => Material(
    color: selected ? FinanceColors.tableHead : Colors.transparent,
    borderRadius: BorderRadius.circular(FinanceRadius.control),
    child: InkWell(
      onTap: selected ? null : () => context.go(destination.path),
      borderRadius: BorderRadius.circular(FinanceRadius.control),
      hoverColor: FinanceColors.tableHead,
      focusColor: FinanceColors.tableHead,
      child: Container(
        key: ValueKey<String>('finance-tab-${destination.id}'),
        constraints: const BoxConstraints(minHeight: 44),
        padding: const EdgeInsets.symmetric(
          horizontal: FinanceSpace.lg,
          vertical: FinanceSpace.sm,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(
              destination.icon,
              size: 20,
              color: selected
                  ? FinanceColors.primary
                  : FinanceColors.textSecondary,
            ),
            const SizedBox(width: FinanceSpace.xs),
            Text(
              financeSectionLabel(context.l10n, destination.id),
              maxLines: 1,
              softWrap: false,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontFamily: FinanceText.fontFamily,
                color: selected ? FinanceColors.primary : FinanceColors.ink,
                fontSize: 13,
                fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

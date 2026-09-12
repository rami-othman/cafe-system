import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../app/localization/localization_extensions.dart';
import '../../../l10n/app_localizations.dart';
import 'finance_design.dart';

/// The only Finance tab bar. It is installed by the application shell, so
/// Finance screens do not create competing local navigation.
///
/// Tab order and active-tab matching are driven by [_FinanceDestination.id]
/// (a stable route identifier), never by the localized [label] text, so
/// switching languages at runtime cannot desynchronize the selected tab.
class FinanceNavigationBar extends StatelessWidget {
  const FinanceNavigationBar({super.key, required this.selected});

  final String selected;

  static const List<_FinanceDestination> _destinations = <_FinanceDestination>[
    _FinanceDestination('overview', '/finance', Icons.dashboard_outlined),
    _FinanceDestination(
      'transactions',
      '/finance/transactions',
      Icons.swap_horiz_outlined,
    ),
    _FinanceDestination('vouchers', '/finance/vouchers', Icons.receipt_long_outlined),
    _FinanceDestination(
      'cashbanks',
      '/finance/cash-banks',
      Icons.account_balance_outlined,
    ),
    _FinanceDestination(
      'expenses',
      '/finance/expenses',
      Icons.payments_outlined,
    ),
    _FinanceDestination(
      'purchases',
      '/finance/purchases',
      Icons.shopping_cart_outlined,
    ),
    _FinanceDestination(
      'suppliers',
      '/finance/suppliers',
      Icons.local_shipping_outlined,
    ),
    _FinanceDestination(
      'reconciliation',
      '/finance/reconciliation',
      Icons.fact_check_outlined,
    ),
    _FinanceDestination(
      'journals',
      '/finance/journal-entries',
      Icons.menu_book_outlined,
    ),
    _FinanceDestination(
      'closing',
      '/finance/daily-closing',
      Icons.lock_clock_outlined,
    ),
    _FinanceDestination('reports', '/finance/reports', Icons.bar_chart_outlined),
    _FinanceDestination(
      'accounts',
      '/finance/accounts',
      Icons.account_tree_outlined,
    ),
    _FinanceDestination(
      'periods',
      '/finance/accounting-periods',
      Icons.calendar_month_outlined,
    ),
    _FinanceDestination(
      'settings',
      '/finance/settings',
      Icons.settings_outlined,
    ),
  ];

  @override
  Widget build(BuildContext context) => Container(
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
          children: _destinations
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

class _FinanceDestination {
  const _FinanceDestination(this.id, this.path, this.icon);
  final String id;
  final String path;
  final IconData icon;
}

String financeSectionLabel(AppLocalizations l10n, String id) => switch (id) {
  'overview' => l10n.financeSectionOverview,
  'transactions' => l10n.financeSectionTransactions,
  'vouchers' => 'السندات والقيود',
  'cashbanks' => l10n.financeSectionCashBanks,
  'expenses' => l10n.financeSectionExpenses,
  'purchases' => 'المشتريات',
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

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
    _FinanceDestination('overview', '/finance'),
    _FinanceDestination('transactions', '/finance/transactions'),
    _FinanceDestination('cashbanks', '/finance/cash-banks'),
    _FinanceDestination('expenses', '/finance/expenses'),
    _FinanceDestination('suppliers', '/finance/suppliers'),
    _FinanceDestination('reconciliation', '/finance/reconciliation'),
    _FinanceDestination('journals', '/finance/journal-entries'),
    _FinanceDestination('closing', '/finance/daily-closing'),
    _FinanceDestination('reports', '/finance/reports'),
    _FinanceDestination('accounts', '/finance/accounts'),
    _FinanceDestination('periods', '/finance/accounting-periods'),
    _FinanceDestination('settings', '/finance/settings'),
  ];

  @override
  Widget build(BuildContext context) => Container(
    height: 54,
    decoration: const BoxDecoration(
      color: FinanceColors.workspace,
      border: Border(bottom: BorderSide(color: FinanceColors.border)),
    ),
    child: SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(
        horizontal: FinanceSpace.sm,
        vertical: 8,
      ),
      child: Row(
        children: _destinations
            .map(
              (_FinanceDestination destination) => Padding(
                padding: const EdgeInsetsDirectional.only(
                  start: FinanceSpace.sm,
                ),
                child: _FinanceNavigationItem(
                  destination: destination,
                  selected: destination.id == selected,
                ),
              ),
            )
            .toList(growable: false),
      ),
    ),
  );
}

class _FinanceDestination {
  const _FinanceDestination(this.id, this.path);
  final String id;
  final String path;
}

String financeSectionLabel(AppLocalizations l10n, String id) => switch (id) {
  'overview' => l10n.financeSectionOverview,
  'transactions' => l10n.financeSectionTransactions,
  'cashbanks' => l10n.financeSectionCashBanks,
  'expenses' => l10n.financeSectionExpenses,
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
    color: selected ? FinanceColors.primary : FinanceColors.card,
    borderRadius: BorderRadius.circular(FinanceRadius.control),
    child: InkWell(
      onTap: () => context.go(destination.path),
      borderRadius: BorderRadius.circular(FinanceRadius.control),
      child: Container(
        key: ValueKey<String>('finance-tab-${destination.id}'),
        height: 36,
        alignment: Alignment.center,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        decoration: BoxDecoration(
          border: Border.all(
            color: selected ? FinanceColors.primary : FinanceColors.border,
          ),
          borderRadius: BorderRadius.circular(FinanceRadius.control),
        ),
        child: Text(
          financeSectionLabel(context.l10n, destination.id),
          style: TextStyle(
            color: selected ? Colors.white : FinanceColors.primary,
            fontSize: 13,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    ),
  );
}

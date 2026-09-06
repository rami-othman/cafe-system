import 'package:flutter/material.dart';

import '../../../app/localization/localization_extensions.dart';
import 'finance_design.dart';
import 'finance_period.dart';

/// Per-page Finance header (title/subtitle/actions + optional global
/// context bar). Module-level chrome (notifications/profile breadcrumb and
/// [FinanceNavigationBar]) is owned once by `FinanceModuleShell`, mounted by
/// the router — this widget must never duplicate that chrome, only page
/// content, so each Finance screen calls it exactly once.
class FinanceShell extends StatelessWidget {
  const FinanceShell({
    super.key,
    required this.child,
    this.showContext = false,
    this.title = 'المالية',
    this.subtitle = 'مساحة عمل موحّدة لكل شاشات المالية',
    this.actions = const <Widget>[],
  });
  final String title;
  final String subtitle;
  final Widget child;
  final bool showContext;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: <Widget>[
      Row(
        children: <Widget>[
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(title, style: FinanceText.title),
                const SizedBox(height: 4),
                Text(subtitle, style: FinanceText.subtitle),
              ],
            ),
          ),
          ...actions,
        ],
      ),
      if (showContext) ...<Widget>[
        const SizedBox(height: FinanceSpace.lg),
        const FinanceGlobalContext(),
      ],
      const SizedBox(height: FinanceSpace.lg),
      Expanded(child: child),
    ],
  );
}

class FinanceBranchOption {
  const FinanceBranchOption({required this.id, required this.name});
  final int id;
  final String name;
}

/// The context bar only enables a control when a route supplies a real
/// callback. Its branch options come from the Finance dashboard response,
/// which already filters them by the signed-in actor's branch authority.
class FinanceGlobalContext extends StatelessWidget {
  const FinanceGlobalContext({
    super.key,
    this.selectedPeriod = FinancePeriod.thisMonth,
    this.onPeriod,
    this.branches = const <FinanceBranchOption>[],
    this.selectedBranchId,
    this.onBranch,
    this.compareEnabled = false,
    this.onCompareChanged,
    this.showCompare = true,
  });
  final String selectedPeriod;
  final ValueChanged<String>? onPeriod;
  final List<FinanceBranchOption> branches;
  final int? selectedBranchId;
  final ValueChanged<int?>? onBranch;
  final bool compareEnabled;
  final ValueChanged<bool>? onCompareChanged;
  /// Some lists (e.g. Financial Transactions) have no logical comparison
  /// role; hide the toggle there instead of showing a control that does
  /// nothing when disabled.
  final bool showCompare;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(
      horizontal: FinanceSpace.lg,
      vertical: FinanceSpace.md,
    ),
    decoration: BoxDecoration(
      color: FinanceColors.card,
      border: Border.all(color: FinanceColors.border),
      borderRadius: BorderRadius.circular(FinanceRadius.card),
    ),
    child: Wrap(
      spacing: FinanceSpace.sm,
      runSpacing: FinanceSpace.sm,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: <Widget>[
        Text(context.l10n.financeGlobalContextTitle, style: FinanceText.label),
        ...<String>[
          FinancePeriod.today,
          FinancePeriod.thisWeek,
          FinancePeriod.thisMonth,
          FinancePeriod.custom,
        ].map(
          (String value) => _ContextButton(
            label: FinancePeriod.label(context.l10n, value),
            selected: selectedPeriod == value,
            onTap: onPeriod == null ? null : () => onPeriod!(value),
          ),
        ),
        const SizedBox(
          width: 1,
          height: 22,
          child: ColoredBox(color: FinanceColors.border),
        ),
        if (branches.isNotEmpty)
          Container(
            height: 34,
            padding: const EdgeInsetsDirectional.only(start: FinanceSpace.sm),
            decoration: BoxDecoration(
              color: FinanceColors.workspace,
              border: Border.all(color: FinanceColors.border),
              borderRadius: BorderRadius.circular(FinanceRadius.control),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<int>(
                value: selectedBranchId ?? -1,
                icon: const Icon(Icons.keyboard_arrow_down, size: 18),
                style: FinanceText.body,
                onChanged: onBranch == null
                    ? null
                    : (int? id) =>
                          onBranch!(id == null || id == -1 ? null : id),
                items: <DropdownMenuItem<int>>[
                  DropdownMenuItem<int>(
                    value: -1,
                    child: Text(context.l10n.financeGlobalContextBranchAll),
                  ),
                  ...branches.map(
                    (FinanceBranchOption branch) => DropdownMenuItem<int>(
                      value: branch.id,
                      child: Text(
                        context.l10n.financeGlobalContextBranchNamed(
                          branch.name,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        if (showCompare) ...<Widget>[
          Switch.adaptive(
            value: compareEnabled,
            onChanged: onCompareChanged,
            activeThumbColor: FinanceColors.primary,
          ),
          Text(
            context.l10n.reportsOverviewComparePrevious,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: FinanceColors.textSecondary,
            ),
          ),
        ],
      ],
    ),
  );
}

class _ContextButton extends StatelessWidget {
  const _ContextButton({
    required this.label,
    required this.selected,
    this.onTap,
  });
  final String label;
  final bool selected;
  final VoidCallback? onTap;
  @override
  Widget build(BuildContext context) => Material(
    color: selected ? FinanceColors.tableHead : FinanceColors.workspace,
    borderRadius: BorderRadius.circular(FinanceRadius.control),
    child: InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(FinanceRadius.control),
      child: Container(
        height: 34,
        padding: const EdgeInsets.symmetric(horizontal: 10),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          border: Border.all(
            color: selected ? FinanceColors.accent : FinanceColors.border,
          ),
          borderRadius: BorderRadius.circular(FinanceRadius.control),
        ),
        child: Text(
          label,
          style: FinanceText.body.copyWith(
            color: onTap == null ? FinanceColors.supporting : FinanceColors.ink,
          ),
        ),
      ),
    ),
  );
}

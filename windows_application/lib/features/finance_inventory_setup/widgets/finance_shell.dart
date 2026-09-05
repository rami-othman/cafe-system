import 'package:flutter/material.dart';

import 'finance_design.dart';

/// Finance-only page frame. Navigation remains owned by [FinanceNavigationBar]
/// in the application shell, so there is no duplicate local navigation.
class FinanceShell extends StatelessWidget {
  const FinanceShell({
    super.key,
    required this.currentSection,
    required this.child,
    this.showContext = false,
    this.title = 'المالية',
    this.subtitle = 'مساحة عمل موحّدة لكل شاشات المالية',
    this.actions = const <Widget>[],
  });
  final String currentSection;
  final String title;
  final String subtitle;
  final Widget child;
  final bool showContext;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) => Directionality(
    textDirection: TextDirection.rtl,
    child: ColoredBox(
      color: FinanceColors.workspace,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          FinanceSpace.pageX,
          FinanceSpace.xl,
          FinanceSpace.pageX,
          28,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                Expanded(
                  child: Text(
                    'المالية / $currentSection',
                    style: FinanceText.small,
                  ),
                ),
                const Icon(
                  Icons.notifications_none,
                  color: FinanceColors.primary,
                ),
                const SizedBox(width: FinanceSpace.md),
                const Icon(Icons.person_outline, color: FinanceColors.primary),
              ],
            ),
            const SizedBox(height: FinanceSpace.xl),
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
        ),
      ),
    ),
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
    this.selectedPeriod = 'هذا الشهر',
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
        const Text('السياق العام', style: FinanceText.label),
        ...<String>['اليوم', 'هذا الأسبوع', 'هذا الشهر', 'مخصص'].map(
          (String value) => _ContextButton(
            label: value,
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
                  const DropdownMenuItem<int>(
                    value: -1,
                    child: Text('الفرع: كل الفروع'),
                  ),
                  ...branches.map(
                    (FinanceBranchOption branch) => DropdownMenuItem<int>(
                      value: branch.id,
                      child: Text('الفرع: ${branch.name}'),
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
          const Text(
            'مقارنة بالفترة السابقة',
            style: TextStyle(
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

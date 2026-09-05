import 'package:flutter/material.dart';

import '../../../app/localization/localization_extensions.dart';
import '../../../core/navigation/unsaved_navigation_guard.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_radius.dart';
import '../../../core/theme/app_spacing.dart';

enum CafeConfigurationDestination {
  overview('/cafe-configuration/overview', Icons.space_dashboard_outlined),
  profile('/cafe-configuration/profile', Icons.storefront_outlined),
  branches('/cafe-configuration/branches', Icons.account_tree_outlined),
  team('/cafe-configuration/team', Icons.group_outlined),
  tax('/cafe-configuration/tax', Icons.percent_outlined);

  const CafeConfigurationDestination(this.path, this.icon);
  final String path;
  final IconData icon;
  static CafeConfigurationDestination forPath(String path) =>
      path.contains('/branches')
      ? branches
      : path.contains('/team')
      ? team
      : path.contains('/tax')
      ? tax
      : path.contains('/profile')
      ? profile
      : overview;
}

class CafeConfigurationNavigation extends StatelessWidget {
  const CafeConfigurationNavigation({super.key, required this.selected});
  final CafeConfigurationDestination selected;
  @override
  Widget build(BuildContext context) {
    final _CafeConfigurationCopy copy = _CafeConfigurationCopy(context);
    return Semantics(
      container: true,
      label: copy.moduleTitle,
      child: Container(
        color: AppColors.contentBackground,
        child: DecoratedBox(
          decoration: const BoxDecoration(
            border: Border(bottom: BorderSide(color: AppColors.border)),
          ),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsetsDirectional.symmetric(
              horizontal: AppSpacing.xl,
              vertical: AppSpacing.sm,
            ),
            child: Row(
              children: <Widget>[
                for (final CafeConfigurationDestination destination
                    in CafeConfigurationDestination.values)
                  _DestinationTab(
                    key: Key('cafe-configuration-${destination.name}'),
                    destination: destination,
                    selected: destination == selected,
                    label: copy.destination(destination),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _DestinationTab extends StatelessWidget {
  const _DestinationTab({
    super.key,
    required this.destination,
    required this.selected,
    required this.label,
  });
  final CafeConfigurationDestination destination;
  final bool selected;
  final String label;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsetsDirectional.only(end: AppSpacing.sm),
    child: Semantics(
      button: true,
      selected: selected,
      label: label,
      child: Material(
        color: selected ? AppColors.primarySoft : AppColors.transparent,
        borderRadius: AppRadius.control,
        child: InkWell(
          borderRadius: AppRadius.control,
          focusColor: AppColors.primarySoft,
          hoverColor: AppColors.primarySoft,
          onTap: selected ? null : () => context.guardedGo(destination.path),
          child: Container(
            constraints: const BoxConstraints(minHeight: 44),
            padding: const EdgeInsetsDirectional.symmetric(
              horizontal: AppSpacing.lg,
              vertical: AppSpacing.sm,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Icon(
                  destination.icon,
                  size: 20,
                  color: selected ? AppColors.primary : AppColors.textSecondary,
                ),
                const SizedBox(width: AppSpacing.sm),
                Text(
                  label,
                  maxLines: 1,
                  softWrap: false,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.labelLarge?.copyWith(
                    color: selected ? AppColors.primary : AppColors.textPrimary,
                    fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
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

class _CafeConfigurationCopy {
  const _CafeConfigurationCopy(this.context);
  final BuildContext context;
  String get moduleTitle =>
      context.maybeL10n?.cafeConfigurationTitle ?? 'Cafe Configuration';
  String destination(CafeConfigurationDestination d) => switch (d) {
    CafeConfigurationDestination.overview =>
      context.maybeL10n?.cafeConfigurationOverview ?? 'Overview',
    CafeConfigurationDestination.profile =>
      context.maybeL10n?.cafeConfigurationProfile ?? 'Cafe Profile',
    CafeConfigurationDestination.branches =>
      context.maybeL10n?.cafeConfigurationBranches ?? 'Branches',
    CafeConfigurationDestination.team =>
      context.maybeL10n?.cafeConfigurationTeamAccess ?? 'Team & Access',
    CafeConfigurationDestination.tax =>
      context.maybeL10n?.cafeConfigurationTax ?? 'Tax',
  };
}

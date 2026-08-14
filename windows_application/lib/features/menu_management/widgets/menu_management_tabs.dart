import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../app/localization/localization_extensions.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_radius.dart';
import '../../../core/theme/app_spacing.dart';

class MenuManagementTabs extends StatelessWidget {
  const MenuManagementTabs({super.key, required this.selected});
  final String selected;
  @override
  Widget build(BuildContext context) {
    final l10n = context.maybeL10n;
    return Semantics(
      label: l10n?.menuManagementWorkflow ?? 'Menu management workflow',
      child: Container(
        width: double.infinity,
        padding: AppSpacing.allSm,
        decoration: BoxDecoration(
          color: AppColors.surfaceAlt,
          border: Border.all(color: AppColors.border),
          borderRadius: AppRadius.card,
        ),
        child: Wrap(
          spacing: AppSpacing.sm,
          runSpacing: AppSpacing.sm,
          children: <Widget>[
            _WorkflowGroup(
              label: l10n?.menuManagementBuild ?? 'Build',
              items: <_MenuDestination>[
                _MenuDestination(
                  id: 'products',
                  label: l10n?.menuManagementProducts ?? 'Products',
                  route: '/menu-management/products',
                ),
                _MenuDestination(
                  id: 'modifiers',
                  label: l10n?.menuManagementModifiers ?? 'Modifiers',
                  route: '/menu-management/modifiers',
                ),
                _MenuDestination(
                  id: 'menus',
                  label: l10n?.menuManagementMenus ?? 'Menus',
                  route: '/menu-management/menus',
                ),
              ],
              selected: selected,
            ),
            _WorkflowGroup(
              label: l10n?.menuManagementConfigure ?? 'Configure',
              items: <_MenuDestination>[
                _MenuDestination(
                  id: 'assignments',
                  label:
                      l10n?.menuManagementAssignments ??
                      'Assignments & schedules',
                  route: '/menu-management/assignments',
                ),
                _MenuDestination(
                  id: 'catalog-setup',
                  label: l10n?.menuManagementCatalogSetup ?? 'Catalog setup',
                  route: '/menu-management/catalog-setup',
                ),
              ],
              selected: selected,
            ),
            _WorkflowGroup(
              label: l10n?.menuManagementRelease ?? 'Review & release',
              items: <_MenuDestination>[
                _MenuDestination(
                  id: 'review',
                  label: l10n?.menuManagementReview ?? 'Review & preview',
                  route: '/menu-management/review',
                ),
              ],
              selected: selected,
            ),
          ],
        ),
      ),
    );
  }
}

class _WorkflowGroup extends StatelessWidget {
  const _WorkflowGroup({
    required this.label,
    required this.items,
    required this.selected,
  });

  final String label;
  final List<_MenuDestination> items;
  final String selected;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsetsDirectional.fromSTEB(8, 6, 8, 6),
    decoration: BoxDecoration(
      color: AppColors.surface,
      border: Border.all(color: AppColors.border),
      borderRadius: AppRadius.control,
    ),
    child: Wrap(
      spacing: 6,
      runSpacing: 4,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: <Widget>[
        Padding(
          padding: const EdgeInsetsDirectional.only(start: 2, end: 2),
          child: Text(
            label,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: AppColors.textMuted,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        ...items.map(
          (item) => ChoiceChip(
            label: Text(item.label, overflow: TextOverflow.ellipsis),
            selected: selected == item.id,
            selectedColor: AppColors.primary.withValues(alpha: .14),
            showCheckmark: false,
            onSelected: (_) => context.go(item.route),
          ),
        ),
      ],
    ),
  );
}

class _MenuDestination {
  const _MenuDestination({
    required this.id,
    required this.label,
    required this.route,
  });

  final String id;
  final String label;
  final String route;
}

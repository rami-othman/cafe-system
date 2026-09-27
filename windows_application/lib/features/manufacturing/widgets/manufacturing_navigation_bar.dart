import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../app/app_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_radius.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_text_styles.dart';

/// The Manufacturing workspace's tab bar, mirroring
/// [InventoryNavigationBar]'s route-driven pattern. All tabs route to real
/// screens.
class ManufacturingNavigationBar extends StatelessWidget {
  const ManufacturingNavigationBar({super.key, required this.selected});

  final String selected;

  static const List<_ManufacturingDestination> _destinations =
      <_ManufacturingDestination>[
        _ManufacturingDestination(
          'overview',
          AppRoutes.manufacturing,
          'نظرة عامة',
          Icons.dashboard_outlined,
          enabled: true,
        ),
        _ManufacturingDestination(
          'materials',
          AppRoutes.manufacturingMaterials,
          'المواد',
          Icons.inventory_2_outlined,
          enabled: true,
        ),
        _ManufacturingDestination(
          'recipes',
          AppRoutes.manufacturingRecipes,
          'الوصفات',
          Icons.receipt_long_outlined,
          enabled: true,
        ),
        _ManufacturingDestination(
          'production',
          AppRoutes.manufacturingProduction,
          'الإنتاج',
          Icons.precision_manufacturing_outlined,
          enabled: true,
        ),
        _ManufacturingDestination(
          'stockCounts',
          AppRoutes.manufacturingStockCounts,
          'الجرد',
          Icons.fact_check_outlined,
          enabled: true,
        ),
        _ManufacturingDestination(
          'reports',
          AppRoutes.manufacturingReports,
          'التقارير',
          Icons.bar_chart_outlined,
          enabled: true,
        ),
      ];

  @override
  Widget build(BuildContext context) => Container(
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
          mainAxisSize: MainAxisSize.min,
          children: _destinations
              .map(
                (_ManufacturingDestination destination) =>
                    _ManufacturingNavigationItem(
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

class _ManufacturingDestination {
  const _ManufacturingDestination(
    this.id,
    this.path,
    this.label,
    this.icon, {
    this.enabled = false,
  });

  final String id;
  final String? path;
  final String label;
  final IconData icon;
  final bool enabled;
}

class _ManufacturingNavigationItem extends StatelessWidget {
  const _ManufacturingNavigationItem({
    required this.destination,
    required this.selected,
  });

  final _ManufacturingDestination destination;
  final bool selected;

  @override
  Widget build(BuildContext context) => Material(
    color: selected ? AppColors.primarySoft : AppColors.transparent,
    borderRadius: AppRadius.control,
    child: InkWell(
      onTap: destination.enabled && !selected
          ? () => context.go(destination.path!)
          : null,
      borderRadius: AppRadius.control,
      hoverColor: destination.enabled ? AppColors.primarySoft : null,
      focusColor: destination.enabled ? AppColors.primarySoft : null,
      child: Container(
        key: ValueKey<String>('manufacturing-tab-${destination.id}'),
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
              color: !destination.enabled
                  ? AppColors.textSecondary.withValues(alpha: 0.5)
                  : selected
                  ? AppColors.primary
                  : AppColors.textSecondary,
            ),
            const SizedBox(width: AppSpacing.sm),
            Text(
              destination.label,
              maxLines: 1,
              softWrap: false,
              overflow: TextOverflow.ellipsis,
              style: AppTextStyles.labelLarge.copyWith(
                color: !destination.enabled
                    ? AppColors.textSecondary.withValues(alpha: 0.5)
                    : selected
                    ? AppColors.primary
                    : AppColors.textPrimary,
                fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
              ),
            ),
            if (!destination.enabled) ...<Widget>[
              const SizedBox(width: AppSpacing.xs),
              Icon(
                Icons.lock_clock_outlined,
                size: 14,
                color: AppColors.textSecondary.withValues(alpha: 0.5),
              ),
            ],
          ],
        ),
      ),
    ),
  );
}

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../app/app_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_radius.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_text_styles.dart';

/// The single, route-driven navigation bar for the inventory workspace.
/// It is mounted by [InventoryModuleShell], rather than by individual pages,
/// so navigation stays visible while the page body scrolls.
class InventoryNavigationBar extends StatelessWidget {
  const InventoryNavigationBar({super.key, required this.selected});

  final String selected;

  static const List<_InventoryDestination>
  _destinations = <_InventoryDestination>[
    _InventoryDestination(
      'overview',
      AppRoutes.inventory,
      'نظرة عامة',
      Icons.dashboard_outlined,
    ),
    _InventoryDestination(
      'items',
      AppRoutes.inventoryItems,
      'المواد',
      Icons.inventory_2_outlined,
    ),
    _InventoryDestination(
      'balances',
      AppRoutes.inventoryBalances,
      'الأرصدة',
      Icons.warehouse_outlined,
    ),
    _InventoryDestination(
      'movements',
      AppRoutes.inventoryMovements,
      'الحركات',
      Icons.swap_horiz_outlined,
    ),
    _InventoryDestination(
      'counts',
      AppRoutes.inventoryCounts,
      'الجرد',
      Icons.fact_check_outlined,
    ),
    _InventoryDestination(
      'transfers',
      AppRoutes.inventoryTransfers,
      'التحويلات',
      Icons.swap_calls_outlined,
    ),
    _InventoryDestination(
      'barChecks',
      AppRoutes.barCheckTemplates,
      'فحص البار',
      Icons.local_bar_outlined,
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
                (_InventoryDestination destination) =>
                    _InventoryNavigationItem(
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

class _InventoryDestination {
  const _InventoryDestination(this.id, this.path, this.label, this.icon);

  final String id;
  final String path;
  final String label;
  final IconData icon;
}

class _InventoryNavigationItem extends StatelessWidget {
  const _InventoryNavigationItem({
    required this.destination,
    required this.selected,
  });

  final _InventoryDestination destination;
  final bool selected;

  @override
  Widget build(BuildContext context) => Material(
    color: selected ? AppColors.primarySoft : AppColors.transparent,
    borderRadius: AppRadius.control,
    child: InkWell(
      onTap: selected ? null : () => context.go(destination.path),
      borderRadius: AppRadius.control,
      hoverColor: AppColors.primarySoft,
      focusColor: AppColors.primarySoft,
      child: Container(
        key: ValueKey<String>('inventory-tab-${destination.id}'),
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
              destination.label,
              maxLines: 1,
              softWrap: false,
              overflow: TextOverflow.ellipsis,
              style: AppTextStyles.labelLarge.copyWith(
                color: selected ? AppColors.primary : AppColors.textPrimary,
                fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

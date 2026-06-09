import 'package:flutter/material.dart';

import '../../core/constants/app_constants.dart';
import '../../core/constants/app_sizes.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_radius.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_text_styles.dart';
import 'app_sidebar_item.dart';

class AppSidebar extends StatelessWidget {
  const AppSidebar({
    super.key,
    required this.activeLabel,
    this.isCollapsed = false,
  });

  final String activeLabel;
  final bool isCollapsed;

  static const List<_SidebarDestination> _destinations = <_SidebarDestination>[
    _SidebarDestination('Dashboard', Icons.dashboard_outlined),
    _SidebarDestination('POS', Icons.point_of_sale_outlined),
    _SidebarDestination('Orders', Icons.receipt_long_outlined),
    _SidebarDestination('Customers', Icons.groups_outlined),
    _SidebarDestination('Discounts', Icons.local_offer_outlined),
    _SidebarDestination('Menu', Icons.restaurant_menu_outlined),
    _SidebarDestination('Inventory', Icons.inventory_2_outlined),
    _SidebarDestination('Reports', Icons.bar_chart_outlined),
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      width: isCollapsed ? AppSizes.sidebarRailWidth : AppSizes.sidebarWidth,
      decoration: const BoxDecoration(
        color: AppColors.sidebarBackground,
        border: Border(right: BorderSide(color: AppColors.shellBorder)),
      ),
      padding: EdgeInsets.fromLTRB(
        isCollapsed ? AppSpacing.sm : AppSpacing.lg,
        AppSpacing.xxl,
        isCollapsed ? AppSpacing.sm : AppSpacing.md,
        AppSpacing.xxl,
      ),
      child: Column(
        crossAxisAlignment: isCollapsed
            ? CrossAxisAlignment.center
            : CrossAxisAlignment.start,
        children: <Widget>[
          _LogoBlock(isCollapsed: isCollapsed),
          const SizedBox(height: AppSpacing.xxxl),
          for (final _SidebarDestination destination in _destinations)
            AppSidebarItem(
              icon: destination.icon,
              label: destination.label,
              isActive: destination.label == activeLabel,
              isCollapsed: isCollapsed,
            ),
          const Spacer(),
          AppSidebarItem(
            icon: Icons.settings_outlined,
            label: 'Settings',
            isCollapsed: isCollapsed,
          ),
        ],
      ),
    );
  }
}

class _LogoBlock extends StatelessWidget {
  const _LogoBlock({required this.isCollapsed});

  final bool isCollapsed;

  @override
  Widget build(BuildContext context) {
    final Widget mark = Container(
      width: AppSizes.logoMarkSize,
      height: AppSizes.logoMarkSize,
      alignment: Alignment.center,
      decoration: const BoxDecoration(
        color: AppColors.tertiary,
        borderRadius: AppRadius.control,
      ),
      child: Text(
        'C',
        style: AppTextStyles.titleMedium.copyWith(color: AppColors.textInverse),
      ),
    );

    if (isCollapsed) {
      return Center(child: mark);
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: <Widget>[
        mark,
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                AppConstants.appName,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: AppTextStyles.bodyLarge.copyWith(
                  fontWeight: FontWeight.w800,
                  height: 1.15,
                ),
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                'OPERATIONAL HUB',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppTextStyles.labelSmall.copyWith(
                  color: AppColors.textSecondary,
                  fontSize: 10,
                  letterSpacing: 0,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _SidebarDestination {
  const _SidebarDestination(this.label, this.icon);

  final String label;
  final IconData icon;
}

import 'package:flutter/material.dart';

import '../../core/constants/app_sizes.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_radius.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_text_styles.dart';

class AppSidebarItem extends StatelessWidget {
  const AppSidebarItem({
    super.key,
    required this.icon,
    required this.label,
    this.isActive = false,
    this.isCollapsed = false,
    this.onTap,
  });

  final IconData icon;
  final String label;
  final bool isActive;
  final bool isCollapsed;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final Color foreground = isActive
        ? AppColors.navActiveText
        : AppColors.textSecondary;

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Tooltip(
        message: isCollapsed ? label : '',
        child: Material(
          color: isActive
              ? AppColors.navActiveBackground
              : AppColors.transparent,
          borderRadius: AppRadius.control,
          child: InkWell(
            onTap: onTap,
            borderRadius: AppRadius.control,
            child: SizedBox(
              width: isCollapsed ? AppSizes.sidebarItemHeight : null,
              height: AppSizes.sidebarItemHeight,
              child: Padding(
                padding: EdgeInsets.symmetric(
                  horizontal: isCollapsed ? 0 : AppSpacing.md,
                ),
                child: Row(
                  mainAxisAlignment: isCollapsed
                      ? MainAxisAlignment.center
                      : MainAxisAlignment.start,
                  children: <Widget>[
                    Icon(
                      icon,
                      size: AppSizes.sidebarIconSize,
                      color: foreground,
                    ),
                    if (!isCollapsed) ...<Widget>[
                      const SizedBox(width: AppSpacing.sm),
                      Expanded(
                        child: Text(
                          label,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppTextStyles.bodySmall.copyWith(
                            color: foreground,
                            fontWeight: isActive
                                ? FontWeight.w800
                                : FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

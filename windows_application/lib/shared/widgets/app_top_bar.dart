import 'package:flutter/material.dart';

import '../../core/constants/app_sizes.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_radius.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_text_styles.dart';
import 'shift_status_badge.dart';

class AppTopBar extends StatelessWidget {
  const AppTopBar({super.key, this.showCartButton = false});

  final bool showCartButton;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final bool isVeryCompact =
            constraints.maxWidth < AppSizes.topBarVeryCompactWidth;
        final bool isCompact =
            constraints.maxWidth < AppSizes.topBarCompactWidth;
        final EdgeInsets padding = isVeryCompact
            ? AppSpacing.horizontalSm
            : AppSpacing.horizontalXl;
        final bool showShiftBadge = !isVeryCompact;
        final bool showOptionalIcons = !isCompact;

        return Container(
          height: AppSizes.topBarHeight,
          decoration: const BoxDecoration(
            color: AppColors.shellBackground,
            border: Border(bottom: BorderSide(color: AppColors.shellBorder)),
          ),
          padding: padding,
          child: Row(
            children: <Widget>[
              Expanded(
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  children: const <Widget>[
                    _BranchTab(label: 'DOWNTOWN', isActive: true),
                    _BranchTab(label: 'Mall'),
                    _BranchTab(label: 'Airport'),
                  ],
                ),
              ),
              if (showShiftBadge) ...const <Widget>[
                SizedBox(width: AppSpacing.lg),
                ShiftStatusBadge(),
              ],
              if (showCartButton) ...<Widget>[
                const SizedBox(width: AppSpacing.sm),
                _TopBarIconButton(
                  icon: Icons.shopping_cart_outlined,
                  tooltip: 'Cart',
                  onPressed: () {},
                ),
              ],
              if (showOptionalIcons) ...<Widget>[
                const SizedBox(width: AppSpacing.sm),
                _TopBarIconButton(
                  icon: Icons.notifications_none_outlined,
                  tooltip: 'Notifications',
                  onPressed: () {},
                ),
                const SizedBox(width: AppSpacing.sm),
                _TopBarIconButton(
                  icon: Icons.account_circle_outlined,
                  tooltip: 'Profile',
                  onPressed: () {},
                ),
              ],
            ],
          ),
        );
      },
    );
  }
}

class _BranchTab extends StatelessWidget {
  const _BranchTab({required this.label, this.isActive = false});

  final String label;
  final bool isActive;

  @override
  Widget build(BuildContext context) {
    final Color foreground = isActive
        ? AppColors.textPrimary
        : AppColors.textSecondary;

    return SizedBox(
      height: AppSizes.topBarHeight,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.end,
          children: <Widget>[
            Expanded(
              child: Center(
                child: Text(
                  label,
                  style: AppTextStyles.bodyLarge.copyWith(
                    color: foreground,
                    fontWeight: isActive ? FontWeight.w800 : FontWeight.w500,
                  ),
                ),
              ),
            ),
            Container(
              width: AppSizes.branchTabUnderlineWidth,
              height: 2,
              color: isActive ? AppColors.textPrimary : AppColors.transparent,
            ),
          ],
        ),
      ),
    );
  }
}

class _TopBarIconButton extends StatelessWidget {
  const _TopBarIconButton({
    required this.icon,
    required this.tooltip,
    required this.onPressed,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: AppColors.transparent,
        borderRadius: AppRadius.pillRadius,
        child: InkWell(
          onTap: onPressed,
          borderRadius: AppRadius.pillRadius,
          child: SizedBox.square(
            dimension: AppSizes.iconButtonSize,
            child: Icon(
              icon,
              color: AppColors.primary,
              size: AppSizes.topBarIconSize,
            ),
          ),
        ),
      ),
    );
  }
}

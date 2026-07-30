import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../core/constants/app_sizes.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_radius.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_text_styles.dart';
import '../../features/orders/controllers/orders_cubit.dart';
import '../../features/orders/controllers/orders_state.dart';
import '../../features/pos/models/branch.dart';
import 'shift_status_badge.dart';

class AppTopBar extends StatefulWidget {
  const AppTopBar({super.key, this.showCartButton = false, this.onRefresh});

  final bool showCartButton;
  final Future<void> Function(BuildContext context)? onRefresh;

  @override
  State<AppTopBar> createState() => _AppTopBarState();
}

class _AppTopBarState extends State<AppTopBar> {
  bool _isRefreshing = false;

  Future<void> _refresh() async {
    if (_isRefreshing || widget.onRefresh == null) {
      return;
    }

    setState(() => _isRefreshing = true);
    try {
      await widget.onRefresh!(context);
    } finally {
      if (mounted) {
        setState(() => _isRefreshing = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final OrdersState ordersState = context.watch<OrdersCubit>().state;
        final OrdersCubit ordersCubit = context.read<OrdersCubit>();
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
                  children: <Widget>[
                    for (final Branch branch in ordersState.branches)
                      _BranchTab(
                        label: branch.name,
                        isActive: branch.id == ordersState.selectedBranchId,
                        onTap: () => ordersCubit.selectBranch(branch.id),
                      ),
                  ],
                ),
              ),
              if (showShiftBadge) ...const <Widget>[
                SizedBox(width: AppSpacing.lg),
                ShiftStatusBadge(),
              ],
              if (widget.showCartButton) ...<Widget>[
                const SizedBox(width: AppSpacing.sm),
                _TopBarIconButton(
                  icon: Icons.shopping_cart_outlined,
                  tooltip: 'Cart',
                  onPressed: () {},
                ),
              ],
              if (widget.onRefresh != null) ...<Widget>[
                const SizedBox(width: AppSpacing.sm),
                _TopBarIconButton(
                  icon: Icons.refresh_outlined,
                  tooltip: 'Refresh screen data',
                  isLoading: _isRefreshing,
                  onPressed: _isRefreshing ? null : _refresh,
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
  const _BranchTab({
    required this.label,
    required this.onTap,
    this.isActive = false,
  });

  final String label;
  final bool isActive;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final Color foreground = isActive
        ? AppColors.textPrimary
        : AppColors.textSecondary;

    return InkWell(
      onTap: onTap,
      child: SizedBox(
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
      ),
    );
  }
}

class _TopBarIconButton extends StatelessWidget {
  const _TopBarIconButton({
    required this.icon,
    required this.tooltip,
    required this.onPressed,
    this.isLoading = false,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback? onPressed;
  final bool isLoading;

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
            child: isLoading
                ? const Padding(
                    padding: EdgeInsets.all(AppSpacing.sm),
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: AppColors.primary,
                    ),
                  )
                : Icon(
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

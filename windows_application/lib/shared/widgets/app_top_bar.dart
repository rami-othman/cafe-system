import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../app/localization/app_locale_cubit.dart';
import '../../app/localization/localization_extensions.dart';
import '../../core/constants/app_sizes.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_radius.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_text_styles.dart';
import '../../features/pos/controllers/pos_cubit.dart';
import '../../features/pos/controllers/pos_state.dart';
import '../../features/pos/models/branch.dart';
import 'shift_status_badge.dart';

class AppTopBar extends StatefulWidget {
  const AppTopBar({
    super.key,
    this.showCartButton = false,
    this.onRefresh,
    this.showOperationalBranchTabs = true,
    this.contextTitle,
  });

  final bool showCartButton;
  final Future<void> Function(BuildContext context)? onRefresh;
  final bool showOperationalBranchTabs;
  final String? contextTitle;

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
        PosCubit? posCubit;
        if (widget.showOperationalBranchTabs) {
          try {
            posCubit = context.watch<PosCubit>();
          } catch (_) {
            // Standalone top-bar tests and menu-only shells do not provide POS.
          }
        }
        final PosState? posState = posCubit?.state;
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
                child: widget.showOperationalBranchTabs && posState != null
                    ? ListView(
                        scrollDirection: Axis.horizontal,
                        children: <Widget>[
                          for (final Branch branch in posState.branches)
                            _BranchTab(
                              label: branch.name,
                              isActive: branch.id == posState.branchId,
                              onTap: () => _selectBranch(posCubit, branch.id),
                            ),
                        ],
                      )
                    : Semantics(
                        header: true,
                        child: Align(
                          alignment: AlignmentDirectional.centerStart,
                          child: Text(
                            widget.contextTitle ??
                                context.l10n.navigationMenuManagement,
                            style: AppTextStyles.titleMedium,
                          ),
                        ),
                      ),
              ),
              if (showShiftBadge) ...<Widget>[
                const SizedBox(width: AppSpacing.lg),
                ShiftStatusBadge(
                  isOpen:
                      posState != null &&
                      !posState.isLoading &&
                      posState.shiftId != null,
                ),
              ],
              if (widget.showCartButton) ...<Widget>[
                const SizedBox(width: AppSpacing.sm),
                _TopBarIconButton(
                  icon: Icons.shopping_cart_outlined,
                  tooltip: context.l10n.tooltipCart,
                  onPressed: () {},
                ),
              ],
              if (widget.onRefresh != null) ...<Widget>[
                const SizedBox(width: AppSpacing.sm),
                _TopBarIconButton(
                  icon: Icons.refresh_outlined,
                  tooltip: context.l10n.tooltipRefreshScreenData,
                  isLoading: _isRefreshing,
                  onPressed: _isRefreshing ? null : _refresh,
                ),
              ],
              const SizedBox(width: AppSpacing.sm),
              const _LanguageSelector(),
              if (showOptionalIcons) ...<Widget>[
                const SizedBox(width: AppSpacing.sm),
                _TopBarIconButton(
                  icon: Icons.notifications_none_outlined,
                  tooltip: context.l10n.tooltipNotifications,
                  onPressed: () {},
                ),
                const SizedBox(width: AppSpacing.sm),
                _TopBarIconButton(
                  icon: Icons.account_circle_outlined,
                  tooltip: context.l10n.tooltipProfile,
                  onPressed: () {},
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  Future<void> _selectBranch(PosCubit? cubit, int branchId) async {
    if (cubit == null) return;
    final bool switched = await cubit.selectBranch(branchId);
    if (!mounted || switched) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(context.l10n.posBranchSwitchBlockedWithCart)),
    );
  }
}

class _LanguageSelector extends StatelessWidget {
  const _LanguageSelector();

  @override
  Widget build(BuildContext context) {
    final AppLocaleCubit localeCubit = context.read<AppLocaleCubit>();
    final bool isArabic =
        context.watch<AppLocaleCubit>().state.locale.languageCode == 'ar';
    return PopupMenuButton<Locale>(
      key: const Key('app-language-selector'),
      tooltip: context.l10n.languageSelection,
      initialValue: isArabic ? AppLocaleCubit.arabic : AppLocaleCubit.english,
      onSelected: localeCubit.selectLocale,
      itemBuilder: (BuildContext context) => <PopupMenuEntry<Locale>>[
        PopupMenuItem<Locale>(
          value: AppLocaleCubit.english,
          child: Text(context.l10n.languageEnglish),
        ),
        PopupMenuItem<Locale>(
          value: AppLocaleCubit.arabic,
          child: Text(context.l10n.languageArabic),
        ),
      ],
      child: Semantics(
        button: true,
        label: context.l10n.language,
        child: SizedBox(
          height: AppSizes.iconButtonSize,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              const Icon(Icons.language, color: AppColors.primary),
              const SizedBox(width: AppSpacing.xs),
              Text(
                isArabic
                    ? context.l10n.languageArabic
                    : context.l10n.languageEnglish,
                style: AppTextStyles.labelMedium,
              ),
            ],
          ),
        ),
      ),
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

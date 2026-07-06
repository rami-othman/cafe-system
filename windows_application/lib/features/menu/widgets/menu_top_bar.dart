import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/constants/app_sizes.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_radius.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../shared/widgets/app_text_field.dart';
import '../controllers/menu_cubit.dart';

class MenuTopBar extends StatelessWidget {
  const MenuTopBar({super.key});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final bool showContext = constraints.maxWidth >= 1150;
        final bool showTitle = constraints.maxWidth >= 610;

        return Container(
          height: AppSizes.topBarHeight,
          padding: EdgeInsets.symmetric(
            horizontal: constraints.maxWidth < 700
                ? AppSpacing.md
                : AppSpacing.xl,
          ),
          decoration: const BoxDecoration(
            color: AppColors.contentBackground,
            border: Border(bottom: BorderSide(color: AppColors.shellBorder)),
            boxShadow: <BoxShadow>[
              BoxShadow(
                color: Color(0x0D000000),
                offset: Offset(0, 1),
                blurRadius: 1,
              ),
            ],
          ),
          child: Row(
            children: <Widget>[
              if (showTitle) ...<Widget>[
                Text(AppConstants.appName, style: AppTextStyles.headlineMedium),
                const SizedBox(width: AppSpacing.xl),
              ],
              SizedBox(
                width: AppSizes.menuSearchWidth,
                height: AppSizes.menuSearchHeight,
                child: Theme(
                  data: Theme.of(context).copyWith(
                    inputDecorationTheme: Theme.of(context).inputDecorationTheme
                        .copyWith(
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: AppSpacing.md,
                            vertical: AppSpacing.sm,
                          ),
                          border: const OutlineInputBorder(
                            borderRadius: AppRadius.pillRadius,
                          ),
                          enabledBorder: const OutlineInputBorder(
                            borderRadius: AppRadius.pillRadius,
                            borderSide: BorderSide(color: AppColors.border),
                          ),
                          focusedBorder: const OutlineInputBorder(
                            borderRadius: AppRadius.pillRadius,
                            borderSide: BorderSide(color: AppColors.secondary),
                          ),
                        ),
                  ),
                  child: AppTextField(
                    hintText: 'Search menu...',
                    prefixIcon: Icons.search,
                    onChanged: context.read<MenuCubit>().updateSearchQuery,
                  ),
                ),
              ),
              const Spacer(),
              if (showContext) ...const <Widget>[
                _ContextLabel(text: 'Branch: Central Branch'),
                SizedBox(width: AppSpacing.lg),
                _ContextLabel(text: 'Shift: Morning Shift'),
                SizedBox(width: AppSpacing.xl),
                SizedBox(
                  height: 24,
                  child: VerticalDivider(color: AppColors.border),
                ),
                SizedBox(width: AppSpacing.lg),
              ],
              IconButton(
                onPressed: () {},
                tooltip: 'Notifications',
                icon: const Icon(Icons.notifications_none_outlined),
                color: AppColors.textSecondary,
              ),
              const SizedBox(width: AppSpacing.xs),
              const _AvatarPlaceholder(),
            ],
          ),
        );
      },
    );
  }
}

class _ContextLabel extends StatelessWidget {
  const _ContextLabel({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      maxLines: 1,
      style: AppTextStyles.bodySmall.copyWith(
        color: AppColors.textSecondary,
        fontSize: 14,
      ),
    );
  }
}

class _AvatarPlaceholder extends StatelessWidget {
  const _AvatarPlaceholder();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 32,
      height: 32,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: AppColors.primarySoft,
        shape: BoxShape.circle,
        border: Border.all(color: AppColors.border),
      ),
      child: Text(
        'CJ',
        style: AppTextStyles.labelSmall.copyWith(
          color: AppColors.primary,
          fontSize: 10,
        ),
      ),
    );
  }
}

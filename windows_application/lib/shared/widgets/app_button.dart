import 'package:flutter/material.dart';

import '../../core/constants/app_sizes.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_radius.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_text_styles.dart';

enum AppButtonVariant { primary, secondary, accent, outlined, inverted, danger }

class AppButton extends StatelessWidget {
  const AppButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.variant = AppButtonVariant.primary,
    this.isExpanded = false,
    this.minimumHeight = AppSizes.buttonHeight,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final AppButtonVariant variant;
  final bool isExpanded;
  final double minimumHeight;

  @override
  Widget build(BuildContext context) {
    final TextStyle textStyle = AppTextStyles.buttonMedium.copyWith(
      fontFamily: Directionality.of(context) == TextDirection.rtl
          ? 'IBMPlexSansArabic'
          : null,
    );
    final Widget button = switch (variant) {
      AppButtonVariant.outlined => _buildOutlinedButton(textStyle),
      _ => _buildFilledButton(_filledColor, _filledForeground, textStyle),
    };

    if (isExpanded) {
      return SizedBox(width: double.infinity, child: button);
    }

    return button;
  }

  Widget _buildFilledButton(
    Color backgroundColor,
    Color foregroundColor,
    TextStyle textStyle,
  ) {
    final ButtonStyle style = FilledButton.styleFrom(
      minimumSize: Size(0, minimumHeight),
      backgroundColor: backgroundColor,
      foregroundColor: foregroundColor,
      disabledBackgroundColor: AppColors.border,
      disabledForegroundColor: AppColors.textMuted,
      textStyle: textStyle,
      padding: AppSpacing.horizontalXl,
      shape: const RoundedRectangleBorder(borderRadius: AppRadius.control),
    );

    if (icon == null) {
      return FilledButton(
        onPressed: onPressed,
        style: style,
        child: Text(label),
      );
    }

    return FilledButton.icon(
      onPressed: onPressed,
      style: style,
      icon: Icon(icon),
      label: Text(label),
    );
  }

  Widget _buildOutlinedButton(TextStyle textStyle) {
    final ButtonStyle style = OutlinedButton.styleFrom(
      minimumSize: Size(0, minimumHeight),
      foregroundColor: AppColors.primary,
      disabledForegroundColor: AppColors.textMuted,
      textStyle: textStyle,
      padding: AppSpacing.horizontalXl,
      side: const BorderSide(color: AppColors.border),
      shape: const RoundedRectangleBorder(borderRadius: AppRadius.control),
    );

    if (icon == null) {
      return OutlinedButton(
        onPressed: onPressed,
        style: style,
        child: Text(label),
      );
    }

    return OutlinedButton.icon(
      onPressed: onPressed,
      style: style,
      icon: Icon(icon),
      label: Text(label),
    );
  }

  Color get _filledColor {
    return switch (variant) {
      AppButtonVariant.secondary => AppColors.secondary,
      AppButtonVariant.accent => AppColors.tertiary,
      AppButtonVariant.inverted => AppColors.neutral,
      AppButtonVariant.danger => AppColors.danger,
      AppButtonVariant.primary ||
      AppButtonVariant.outlined => AppColors.primary,
    };
  }

  Color get _filledForeground {
    return switch (variant) {
      AppButtonVariant.primary ||
      AppButtonVariant.secondary ||
      AppButtonVariant.accent ||
      AppButtonVariant.inverted ||
      AppButtonVariant.danger => AppColors.textInverse,
      AppButtonVariant.outlined => AppColors.primary,
    };
  }
}

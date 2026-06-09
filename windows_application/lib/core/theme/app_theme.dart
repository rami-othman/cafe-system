import 'package:flutter/material.dart';

import '../constants/app_sizes.dart';
import 'app_colors.dart';
import 'app_radius.dart';
import 'app_spacing.dart';
import 'app_text_styles.dart';

abstract final class AppTheme {
  static ThemeData get lightTheme {
    const ColorScheme colorScheme = ColorScheme(
      brightness: Brightness.light,
      primary: AppColors.primary,
      onPrimary: AppColors.textInverse,
      secondary: AppColors.secondary,
      onSecondary: AppColors.textInverse,
      tertiary: AppColors.tertiary,
      onTertiary: AppColors.textInverse,
      error: AppColors.danger,
      onError: AppColors.textInverse,
      surface: AppColors.surface,
      onSurface: AppColors.textPrimary,
    );

    return ThemeData(
      useMaterial3: true,
      fontFamily: AppTextStyles.fontFamily,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: AppColors.background,
      appBarTheme: const AppBarTheme(
        backgroundColor: AppColors.surface,
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: AppTextStyles.titleLarge,
      ),
      textTheme: AppTextStyles.textTheme,
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          minimumSize: const Size(0, AppSizes.buttonHeight),
          backgroundColor: AppColors.primary,
          foregroundColor: AppColors.textInverse,
          disabledBackgroundColor: AppColors.border,
          disabledForegroundColor: AppColors.textMuted,
          textStyle: AppTextStyles.buttonMedium,
          padding: AppSpacing.horizontalXl,
          shape: const RoundedRectangleBorder(borderRadius: AppRadius.control),
          elevation: 0,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(0, AppSizes.buttonHeight),
          foregroundColor: AppColors.primary,
          disabledForegroundColor: AppColors.textMuted,
          textStyle: AppTextStyles.buttonMedium,
          padding: AppSpacing.horizontalXl,
          side: const BorderSide(color: AppColors.border),
          shape: const RoundedRectangleBorder(borderRadius: AppRadius.control),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: AppColors.secondary,
          disabledForegroundColor: AppColors.textMuted,
          textStyle: AppTextStyles.buttonMedium,
          padding: AppSpacing.horizontalLg,
          shape: const RoundedRectangleBorder(borderRadius: AppRadius.control),
        ),
      ),
      inputDecorationTheme: const InputDecorationTheme(
        filled: true,
        fillColor: AppColors.surface,
        contentPadding: EdgeInsets.symmetric(
          horizontal: AppSpacing.lg,
          vertical: AppSpacing.md,
        ),
        hintStyle: TextStyle(color: AppColors.textMuted),
        labelStyle: AppTextStyles.labelMedium,
        floatingLabelStyle: TextStyle(
          color: AppColors.secondary,
          fontFamily: AppTextStyles.fontFamily,
          fontWeight: FontWeight.w700,
        ),
        border: OutlineInputBorder(borderRadius: AppRadius.control),
        enabledBorder: OutlineInputBorder(
          borderRadius: AppRadius.control,
          borderSide: BorderSide(color: AppColors.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: AppRadius.control,
          borderSide: BorderSide(color: AppColors.secondary, width: 1.4),
        ),
        disabledBorder: OutlineInputBorder(
          borderRadius: AppRadius.control,
          borderSide: BorderSide(color: AppColors.divider),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: AppRadius.control,
          borderSide: BorderSide(color: AppColors.danger),
        ),
      ),
      cardTheme: const CardThemeData(
        color: AppColors.surface,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(borderRadius: AppRadius.card),
      ),
      dialogTheme: const DialogThemeData(
        backgroundColor: AppColors.surface,
        titleTextStyle: AppTextStyles.titleLarge,
        contentTextStyle: AppTextStyles.bodyMedium,
        shape: RoundedRectangleBorder(borderRadius: AppRadius.panel),
      ),
      dividerTheme: const DividerThemeData(
        color: AppColors.divider,
        space: 1,
        thickness: 1,
      ),
      iconTheme: const IconThemeData(color: AppColors.textSecondary, size: 22),
    );
  }

  static ThemeData get light => lightTheme;
}

import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_radius.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_text_styles.dart';

/// Presentation constants owned by Customer Management.
///
/// These values intentionally consume the existing application vocabulary while
/// keeping the reference-specific composition local to this feature.
abstract final class CustomerManagementVisualTokens {
  static const double collectionBreakpoint = 760;
  static const double readableContentWidth = 720;
  static const double moduleContentMaxWidth = 1440;
  static const double minimumInteractiveSize = 48;

  static const Color pageBackground = AppColors.contentBackground;
  static const Color surface = AppColors.surface;
  static const Color warmHeader = AppColors.menuTableHeader;
  static const Color accent = AppColors.primary;
  static const Color mutedText = AppColors.textMuted;
  static const Color border = AppColors.border;
  static const Color focus = AppColors.secondary;

  static const BorderSide surfaceBorder = BorderSide(color: border);
  static const BorderRadius surfaceRadius = AppRadius.card;
  static const EdgeInsetsGeometry pagePadding = EdgeInsetsDirectional.fromSTEB(
    AppSpacing.xl,
    AppSpacing.lg,
    AppSpacing.xl,
    AppSpacing.xxl,
  );
  static const EdgeInsetsGeometry surfacePadding = EdgeInsetsDirectional.all(
    AppSpacing.lg,
  );
  static const TextStyle pageTitle = AppTextStyles.headlineMedium;
  static const TextStyle pageDescription = AppTextStyles.bodySmall;

  static bool usesCollectionCards(double availableWidth) =>
      availableWidth < collectionBreakpoint;
}

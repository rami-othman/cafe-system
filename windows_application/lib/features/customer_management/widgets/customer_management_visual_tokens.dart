import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_radius.dart';
import '../../../core/theme/app_spacing.dart';

/// Presentation constants owned by Customer Management.
///
/// These values intentionally consume the existing application vocabulary while
/// keeping the reference-specific composition local to this feature.
abstract final class CustomerManagementVisualTokens {
  static const double collectionBreakpoint = 760;
  static const double readableContentWidth = 720;
  static const double moduleContentMaxWidth = 1440;
  static const double minimumInteractiveSize = 48;

  static const Color pageBackground = AppColors.background;
  static const Color surface = AppColors.surface;
  static const Color warmHeader = AppColors.menuTableHeader;
  static const Color accent = AppColors.primary;
  static const Color mutedText = AppColors.textMuted;
  static const Color border = AppColors.border;
  static const Color focus = AppColors.secondary;
  static const Color groupCreateFocus = AppColors.tertiary;
  static const Color error = AppColors.danger;
  static const Color rowText = AppColors.textSecondary;
  static const Color activeBadgeBackground = AppColors.customerVipBadge;
  static const Color activeBadgeForeground = AppColors.customerVipText;
  static const Color inactiveBadgeBackground = AppColors.surfaceAlt;
  static const Color inactiveBadgeForeground = AppColors.textSecondary;
  static const Color archivedBadgeBackground = Color(0xFFEDE7DE);
  static const Color archivedBadgeForeground = AppColors.textMuted;
  static const Color skeleton = Color(0xFFEDE7DE);
  static const List<String> fontFamilyFallback = <String>['IBMPlexSansArabic'];

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
  static const TextStyle pageTitle = TextStyle(
    fontSize: 22,
    height: 1.25,
    fontWeight: FontWeight.w700,
    color: AppColors.textPrimary,
    fontFamilyFallback: fontFamilyFallback,
  );
  static const TextStyle pageDescription = TextStyle(
    fontSize: 12,
    height: 1.4,
    fontWeight: FontWeight.w500,
    color: AppColors.textSecondary,
    fontFamilyFallback: fontFamilyFallback,
  );
  static const TextStyle tableHeading = TextStyle(
    fontSize: 12,
    height: 1.25,
    fontWeight: FontWeight.w700,
    color: AppColors.primary,
    fontFamilyFallback: fontFamilyFallback,
  );
  static const TextStyle tableCell = TextStyle(
    fontSize: 13,
    height: 1.3,
    fontWeight: FontWeight.w500,
    color: rowText,
    fontFamilyFallback: fontFamilyFallback,
  );

  static bool usesCollectionCards(double availableWidth) =>
      availableWidth < collectionBreakpoint;
}

import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';

/// Shift-module design tokens. Every color here either reuses an
/// application token or names a variance tone the shift domain needs
/// (shortage / surplus / match / uncounted) so no screen invents its own.
abstract final class ShiftColors {
  static const Color workspace = AppColors.contentBackground;
  static const Color surface = AppColors.surface;
  static const Color border = AppColors.border;
  static const Color softBorder = Color(0xFFF0E6D2);
  static const Color headerFill = Color(0xFFF4E7D3);
  static const Color subtleFill = Color(0xFFFAF7F2);
  static const Color accent = AppColors.tertiary;
  static const Color ink = AppColors.textPrimary;
  static const Color inkSoft = AppColors.textSecondary;
  static const Color inkMuted = AppColors.textMuted;

  /// Counted quantity equals the theoretical quantity, or cash reconciles.
  static const Color matchFill = Color(0xFFE3F5E8);
  static const Color matchInk = Color(0xFF2E7D32);

  /// Physical count is below the theoretical quantity (عجز / نقص).
  static const Color shortageFill = Color(0xFFFFF3D6);
  static const Color shortageInk = Color(0xFF9B6A0C);

  /// Physical count is above the theoretical quantity (زيادة).
  static const Color surplusFill = Color(0xFFE3EDF7);
  static const Color surplusInk = Color(0xFF2B5F8C);

  static const Color blockerFill = Color(0xFFFFE1DE);
  static const Color blockerInk = AppColors.danger;

  static const Color neutralFill = AppColors.surfaceAlt;
  static const Color neutralInk = AppColors.textMuted;

  static const Color skeleton = Color(0xFFEDE7DE);
  static const Color trackLine = Color(0xFFD8CFC2);
}

/// Arabic-first typography for the module. The whole POS surface renders RTL,
/// so the shift screens pin the Arabic family rather than switching per call
/// site the way older management pages do.
abstract final class ShiftText {
  static const String family = 'IBMPlexSansArabic';

  static TextStyle _a(TextStyle base) => base.copyWith(fontFamily: family);

  static TextStyle get pageTitle => _a(AppTextStyles.headlineMedium);
  static TextStyle get sectionTitle => _a(AppTextStyles.titleMedium);
  static TextStyle get cardTitle =>
      _a(AppTextStyles.bodyMedium).copyWith(fontWeight: FontWeight.w700);
  static TextStyle get metricValue =>
      _a(AppTextStyles.titleLarge).copyWith(fontWeight: FontWeight.w700);
  static TextStyle get metricValueSmall =>
      _a(AppTextStyles.bodyLarge).copyWith(fontWeight: FontWeight.w700);
  static TextStyle get body => _a(AppTextStyles.bodySmall);
  static TextStyle get bodyStrong =>
      _a(AppTextStyles.bodySmall).copyWith(fontWeight: FontWeight.w700);
  static TextStyle get label =>
      _a(AppTextStyles.labelSmall).copyWith(color: ShiftColors.inkMuted);
  static TextStyle get labelStrong =>
      _a(AppTextStyles.labelSmall).copyWith(color: ShiftColors.inkSoft);
  static TextStyle get badge => _a(
    AppTextStyles.labelSmall,
  ).copyWith(fontSize: 11, fontWeight: FontWeight.w700);
  static TextStyle get tableHeader => _a(
    AppTextStyles.labelSmall,
  ).copyWith(color: AppColors.primary, fontWeight: FontWeight.w700);
  static TextStyle get tableCell => _a(AppTextStyles.bodySmall);
  static TextStyle get button =>
      _a(AppTextStyles.buttonMedium).copyWith(fontWeight: FontWeight.w700);
}

/// Layout constants shared by every shift screen. Named breakpoints keep the
/// responsive rules (desktop table -> tablet two-column -> mobile cards)
/// identical across the module instead of drifting per screen.
abstract final class ShiftLayout {
  static const double tabletBreakpoint = 700;
  static const double desktopBreakpoint = 1100;
  static const double wideBreakpoint = 1420;

  /// Minimum interactive size; keeps counting inputs usable on a tablet.
  static const double touchTarget = 44;
  static const double countFieldWidth = 96;
  static const double actionBarHeight = 72;
  static const double reportPageWidth = 794; // A4 at 96dpi
}

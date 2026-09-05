import 'package:flutter/material.dart';

/// Exact Finance-only desktop tokens extracted from the approved reference.
abstract final class FinanceColors {
  static const canvas = Color(0xffEDE7DE),
      workspace = Color(0xffFAF7F2),
      card = Colors.white;
  static const ink = Color(0xff231005),
      primary = Color(0xff3B2417),
      brown = Color(0xff6B4226),
      brownLight = Color(0xff805437),
      accent = Color(0xffC47A3A),
      accentLight = Color(0xffFEC29E);
  static const muted = Color(0xff8B8B8B),
      supporting = Color(0xff6B6B6B),
      textSecondary = Color(0xff50443F),
      disabled = Color(0xffB7ADA2),
      border = Color(0xffE7E2DA),
      tableHead = Color(0xffF4E7D3);
  static const success = Color(0xff2E7D32),
      successBg = Color(0xffE3F5E8),
      danger = Color(0xffC62828),
      dangerLight = Color(0xffFFE1DE),
      dangerBg = Color(0xffFFF5F4),
      warning = Color(0xff805437),
      warningBg = Color(0xffFCF7EF),
      warningBorder = Color(0xffE6C9A0);
}

abstract final class FinanceSpace {
  static const double xs = 6, sm = 8, md = 12, lg = 16, xl = 22, pageX = 32;
}

abstract final class FinanceRadius {
  static const card = 12.0, control = 8.0, pill = 999.0;
}

abstract final class FinanceText {
  static const title = TextStyle(
    fontSize: 22,
    fontWeight: FontWeight.w700,
    color: FinanceColors.ink,
  );
  static const page = TextStyle(
    fontSize: 19,
    fontWeight: FontWeight.w700,
    color: FinanceColors.ink,
  );
  static const subtitle = TextStyle(
    fontSize: 12.5,
    color: FinanceColors.supporting,
  );
  static const body = TextStyle(fontSize: 13, color: FinanceColors.ink);
  static const small = TextStyle(fontSize: 11.5, color: FinanceColors.muted);
  static const label = TextStyle(
    fontSize: 11,
    fontWeight: FontWeight.w700,
    color: FinanceColors.muted,
  );
}

enum FinanceTone { neutral, success, warning, danger, dark }

({Color foreground, Color background, Color border}) financeTone(
  FinanceTone tone,
) => switch (tone) {
  FinanceTone.success => (
    foreground: FinanceColors.success,
    background: FinanceColors.successBg,
    border: const Color(0xffBFE5C8),
  ),
  FinanceTone.warning => (
    foreground: FinanceColors.warning,
    background: FinanceColors.warningBg,
    border: FinanceColors.warningBorder,
  ),
  FinanceTone.danger => (
    foreground: FinanceColors.danger,
    background: FinanceColors.dangerBg,
    border: FinanceColors.dangerLight,
  ),
  FinanceTone.dark => (
    foreground: Colors.white,
    background: FinanceColors.primary,
    border: FinanceColors.primary,
  ),
  FinanceTone.neutral => (
    foreground: FinanceColors.brown,
    background: FinanceColors.workspace,
    border: FinanceColors.border,
  ),
};

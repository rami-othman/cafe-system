import '../widgets/shift_strings.dart';

/// Demo scenarios the shift module can render.
///
/// This is a UI-approval affordance: it lets a reviewer walk every state the
/// backend will eventually have to produce (balanced close, cash variance,
/// stock variance, negative theoretical stock, a blocking open order, an
/// incomplete count, no shift at all, plus loading/error) without a server.
/// The switcher is only mounted in debug builds.
enum ShiftScenario {
  balanced,
  cashShortage,
  cashSurplus,
  stockVariance,
  negativeStock,
  openOrderBlocker,
  incompleteCount,
  noOpenShift,
  loading,
  error;

  String get label => switch (this) {
    ShiftScenario.balanced => ShiftStrings.scenarioBalanced,
    ShiftScenario.cashShortage => ShiftStrings.scenarioCashShortage,
    ShiftScenario.cashSurplus => ShiftStrings.scenarioCashSurplus,
    ShiftScenario.stockVariance => ShiftStrings.scenarioStockVariance,
    ShiftScenario.negativeStock => ShiftStrings.scenarioNegativeStock,
    ShiftScenario.openOrderBlocker => ShiftStrings.scenarioOpenOrder,
    ShiftScenario.incompleteCount => ShiftStrings.scenarioIncompleteCount,
    ShiftScenario.noOpenShift => ShiftStrings.scenarioNoShift,
    ShiftScenario.loading => ShiftStrings.scenarioLoading,
    ShiftScenario.error => ShiftStrings.scenarioError,
  };

  /// Scenarios that seed the wizard with counts already entered, so a
  /// reviewer can jump straight to the variance screens.
  bool get prefillsCounts =>
      this == ShiftScenario.cashShortage ||
      this == ShiftScenario.cashSurplus ||
      this == ShiftScenario.stockVariance ||
      this == ShiftScenario.negativeStock;
}

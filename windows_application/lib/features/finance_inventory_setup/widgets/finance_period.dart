import 'package:flutter/material.dart';

import '../../../l10n/app_localizations.dart';

/// Shared Finance period-preset resolution (today / this week / this month /
/// custom) so every Finance screen that binds [FinanceGlobalContext] to a
/// real date range agrees on the same presets and label.
///
/// The preset identifiers ('today', 'this_week', 'this_month', 'custom') are
/// stable, English, locale-invariant keys — they flow through
/// [FinanceGlobalContext.selectedPeriod]/`onPeriod` and are compared/switched
/// on by callers to compute a date range. Never display them directly; use
/// [label] to resolve the localized text for a preset key.
class FinancePeriod {
  const FinancePeriod._();

  static const String today = 'today';
  static const String thisWeek = 'this_week';
  static const String thisMonth = 'this_month';
  static const String custom = 'custom';

  static String format(DateTime value) =>
      '${value.year.toString().padLeft(4, '0')}-${value.month.toString().padLeft(2, '0')}-${value.day.toString().padLeft(2, '0')}';

  static DateTimeRange presetRange(String preset) {
    final DateTime todayDate = DateUtils.dateOnly(DateTime.now());
    return switch (preset) {
      today => DateTimeRange(start: todayDate, end: todayDate),
      thisWeek => DateTimeRange(
        start: todayDate.subtract(Duration(days: todayDate.weekday - 1)),
        end: todayDate,
      ),
      _ => DateTimeRange(
        start: DateTime(todayDate.year, todayDate.month),
        end: todayDate,
      ),
    };
  }

  static String labelFor(DateTime from, DateTime to) {
    final DateTime todayDate = DateUtils.dateOnly(DateTime.now());
    if (DateUtils.isSameDay(from, todayDate) &&
        DateUtils.isSameDay(to, todayDate)) {
      return today;
    }
    if (DateUtils.isSameDay(
          from,
          todayDate.subtract(Duration(days: todayDate.weekday - 1)),
        ) &&
        DateUtils.isSameDay(to, todayDate)) {
      return thisWeek;
    }
    if (from.year == todayDate.year &&
        from.month == todayDate.month &&
        from.day == 1 &&
        DateUtils.isSameDay(to, todayDate)) {
      return thisMonth;
    }
    return custom;
  }

  /// Localized display text for a preset key returned by [labelFor] or one
  /// of the [today]/[thisWeek]/[thisMonth]/[custom] constants.
  static String label(AppLocalizations l10n, String preset) => switch (preset) {
    today => l10n.financePeriodToday,
    thisWeek => l10n.financePeriodThisWeek,
    thisMonth => l10n.financePeriodThisMonth,
    _ => l10n.financePeriodCustom,
  };
}

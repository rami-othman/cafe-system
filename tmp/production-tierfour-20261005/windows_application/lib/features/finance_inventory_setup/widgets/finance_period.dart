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
  static const String yearToDate = 'year_to_date';
  static const String fourMonths = 'four_months';
  static const String sixMonths = 'six_months';
  static const String oneYear = 'one_year';
  static const String fiscalYear = 'fiscal_year';
  static const String custom = 'custom';

  static DateTime? fiscalStartFromPeriods(
    Iterable<Map<String, dynamic>> periods, {
    DateTime? now,
  }) {
    final todayDate = DateUtils.dateOnly(now ?? DateTime.now());
    DateTime? result;
    for (final period in periods) {
      final start = DateTime.tryParse('${period['startDate'] ?? ''}');
      final end = DateTime.tryParse('${period['endDate'] ?? ''}');
      if (start == null || end == null || end.difference(start).inDays < 300 ||
          start.isAfter(todayDate) || end.isBefore(todayDate)) {
        continue;
      }
      if (result == null || start.isAfter(result)) {
        result = start;
      }
    }
    return result;
  }

  static Map<String, dynamic>? expiredOpenYearFromPeriods(
    Iterable<Map<String, dynamic>> periods, {
    DateTime? now,
  }) {
    final todayDate = DateUtils.dateOnly(now ?? DateTime.now());
    Map<String, dynamic>? oldest;
    DateTime? oldestEnd;
    for (final period in periods) {
      final start = DateTime.tryParse('${period['startDate'] ?? ''}');
      final end = DateTime.tryParse('${period['endDate'] ?? ''}');
      if (period['status'] == 'open' && start != null && end != null &&
          end.difference(start).inDays >= 300 && end.isBefore(todayDate)) {
        if (oldestEnd == null || end.isBefore(oldestEnd)) {
          oldest = period;
          oldestEnd = end;
        }
      }
    }
    return oldest;
  }

  static String format(DateTime value) =>
      '${value.year.toString().padLeft(4, '0')}-${value.month.toString().padLeft(2, '0')}-${value.day.toString().padLeft(2, '0')}';

  static DateTimeRange presetRange(
    String preset, {
    DateTime? now,
    DateTime? fiscalYearStart,
  }) {
    final DateTime todayDate = DateUtils.dateOnly(now ?? DateTime.now());
    return switch (preset) {
      today => DateTimeRange(start: todayDate, end: todayDate),
      thisWeek => DateTimeRange(
        start: todayDate.subtract(Duration(days: todayDate.weekday - 1)),
        end: todayDate,
      ),
      yearToDate => DateTimeRange(
        start: DateTime(todayDate.year),
        end: todayDate,
      ),
      fourMonths => DateTimeRange(
        start: DateTime(todayDate.year, todayDate.month - 3),
        end: todayDate,
      ),
      sixMonths => DateTimeRange(
        start: DateTime(todayDate.year, todayDate.month - 5),
        end: todayDate,
      ),
      oneYear => DateTimeRange(
        start: DateTime(todayDate.year, todayDate.month - 11),
        end: todayDate,
      ),
      fiscalYear when fiscalYearStart != null => DateTimeRange(
        start: DateUtils.dateOnly(fiscalYearStart),
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
    yearToDate => l10n.localeName == 'ar' ? 'من بداية السنة' : 'Year to date',
    fourMonths => l10n.localeName == 'ar' ? 'ثلث سنة (4 أشهر)' : '4 months',
    sixMonths => l10n.localeName == 'ar' ? '6 أشهر' : '6 months',
    oneYear => l10n.localeName == 'ar' ? 'سنة' : '1 year',
    fiscalYear => l10n.localeName == 'ar' ? 'من بداية السنة المحاسبية' : 'Fiscal year to date',
    _ => l10n.financePeriodCustom,
  };
}

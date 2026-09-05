import 'package:flutter/material.dart';

/// Shared Finance period-preset resolution (اليوم / هذا الأسبوع / هذا الشهر /
/// مخصص) so every Finance screen that binds [FinanceGlobalContext] to a real
/// date range agrees on the same presets and label.
class FinancePeriod {
  const FinancePeriod._();

  static String format(DateTime value) =>
      '${value.year.toString().padLeft(4, '0')}-${value.month.toString().padLeft(2, '0')}-${value.day.toString().padLeft(2, '0')}';

  static DateTimeRange presetRange(String preset) {
    final DateTime today = DateUtils.dateOnly(DateTime.now());
    return switch (preset) {
      'اليوم' => DateTimeRange(start: today, end: today),
      'هذا الأسبوع' => DateTimeRange(
        start: today.subtract(Duration(days: today.weekday - 1)),
        end: today,
      ),
      _ => DateTimeRange(start: DateTime(today.year, today.month), end: today),
    };
  }

  static String labelFor(DateTime from, DateTime to) {
    final DateTime today = DateUtils.dateOnly(DateTime.now());
    if (DateUtils.isSameDay(from, today) && DateUtils.isSameDay(to, today)) {
      return 'اليوم';
    }
    if (DateUtils.isSameDay(
          from,
          today.subtract(Duration(days: today.weekday - 1)),
        ) &&
        DateUtils.isSameDay(to, today)) {
      return 'هذا الأسبوع';
    }
    if (from.year == today.year &&
        from.month == today.month &&
        from.day == 1 &&
        DateUtils.isSameDay(to, today)) {
      return 'هذا الشهر';
    }
    return 'مخصص';
  }
}

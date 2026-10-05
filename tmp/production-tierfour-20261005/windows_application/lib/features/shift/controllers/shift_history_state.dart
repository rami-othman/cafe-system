import 'package:equatable/equatable.dart';

import '../models/shift_models.dart';

enum ShiftHistoryStatusView { loading, ready, empty, error }

enum ShiftHistoryPeriod { today, yesterday, thisWeek, thisMonth, custom }

enum ShiftDifferenceFilter { all, matched, shortage, surplus }

class ShiftHistoryState extends Equatable {
  const ShiftHistoryState({
    this.status = ShiftHistoryStatusView.loading,
    this.all = const <ShiftHistoryEntry>[],
    this.query = '',
    this.period = ShiftHistoryPeriod.thisMonth,
    this.customStart,
    this.customEnd,
    this.cashier,
    this.branch,
    this.shiftStatus,
    this.differenceFilter = ShiftDifferenceFilter.all,
    this.page = 1,
    this.pageSize = 8,
    this.errorMessage,
  });

  final ShiftHistoryStatusView status;

  /// Everything the source returned; filters are applied on top of it.
  final List<ShiftHistoryEntry> all;

  final String query;
  final ShiftHistoryPeriod period;
  final DateTime? customStart;
  final DateTime? customEnd;
  final String? cashier;
  final String? branch;
  final ShiftHistoryStatus? shiftStatus;
  final ShiftDifferenceFilter differenceFilter;
  final int page;
  final int pageSize;
  final String? errorMessage;

  bool get isLoading => status == ShiftHistoryStatusView.loading;

  bool get hasActiveFilters =>
      query.trim().isNotEmpty ||
      period != ShiftHistoryPeriod.thisMonth ||
      cashier != null ||
      branch != null ||
      shiftStatus != null ||
      differenceFilter != ShiftDifferenceFilter.all;

  List<String> get cashierOptions {
    final Set<String> names = all.map((ShiftHistoryEntry e) => e.cashierName).toSet();
    return names.toList()..sort();
  }

  List<String> get branchOptions {
    final Set<String> names = all.map((ShiftHistoryEntry e) => e.branchName).toSet();
    return names.toList()..sort();
  }

  /// Every entry matching the active filters, newest first.
  List<ShiftHistoryEntry> filtered(DateTime now) {
    final String search = query.trim().toLowerCase();
    final (DateTime start, DateTime end) = _range(now);

    final List<ShiftHistoryEntry> matches = all.where((ShiftHistoryEntry e) {
      if (search.isNotEmpty &&
          !e.shiftNumber.toLowerCase().contains(search) &&
          !e.cashierName.toLowerCase().contains(search)) {
        return false;
      }
      if (e.date.isBefore(start) || e.date.isAfter(end)) return false;
      if (cashier != null && e.cashierName != cashier) return false;
      if (branch != null && e.branchName != branch) return false;
      if (shiftStatus != null && e.status != shiftStatus) return false;
      return switch (differenceFilter) {
        ShiftDifferenceFilter.all => true,
        ShiftDifferenceFilter.matched => e.isBalanced,
        ShiftDifferenceFilter.shortage => e.isShortage,
        ShiftDifferenceFilter.surplus => e.isSurplus,
      };
    }).toList();

    matches.sort(
      (ShiftHistoryEntry a, ShiftHistoryEntry b) =>
          b.closedAt.compareTo(a.closedAt),
    );
    return matches;
  }

  ShiftHistorySummary summary(DateTime now) =>
      ShiftHistorySummary.from(filtered(now));

  int pageCount(DateTime now) {
    final int total = filtered(now).length;
    if (total == 0) return 1;
    return (total / pageSize).ceil();
  }

  /// The current page of [filtered], clamped so a filter change can never
  /// leave the table on a page that no longer exists.
  List<ShiftHistoryEntry> pageEntries(DateTime now) {
    final List<ShiftHistoryEntry> matches = filtered(now);
    final int pages = pageCount(now);
    final int safePage = page.clamp(1, pages);
    final int start = (safePage - 1) * pageSize;
    if (start >= matches.length) return const <ShiftHistoryEntry>[];
    final int end = (start + pageSize).clamp(0, matches.length);
    return matches.sublist(start, end);
  }

  (DateTime, DateTime) _range(DateTime now) {
    final DateTime today = DateTime(now.year, now.month, now.day);
    return switch (period) {
      ShiftHistoryPeriod.today => (today, today),
      ShiftHistoryPeriod.yesterday => (
        today.subtract(const Duration(days: 1)),
        today.subtract(const Duration(days: 1)),
      ),
      ShiftHistoryPeriod.thisWeek => (
        today.subtract(Duration(days: today.weekday % 7)),
        today,
      ),
      ShiftHistoryPeriod.thisMonth => (DateTime(now.year, now.month), today),
      ShiftHistoryPeriod.custom => (
        customStart ?? DateTime(now.year, now.month),
        customEnd ?? today,
      ),
    };
  }

  ShiftHistoryState copyWith({
    ShiftHistoryStatusView? status,
    List<ShiftHistoryEntry>? all,
    String? query,
    ShiftHistoryPeriod? period,
    DateTime? customStart,
    DateTime? customEnd,
    String? cashier,
    bool clearCashier = false,
    String? branch,
    bool clearBranch = false,
    ShiftHistoryStatus? shiftStatus,
    bool clearShiftStatus = false,
    ShiftDifferenceFilter? differenceFilter,
    int? page,
    String? errorMessage,
    bool clearErrorMessage = false,
  }) => ShiftHistoryState(
    status: status ?? this.status,
    all: all ?? this.all,
    query: query ?? this.query,
    period: period ?? this.period,
    customStart: customStart ?? this.customStart,
    customEnd: customEnd ?? this.customEnd,
    cashier: clearCashier ? null : cashier ?? this.cashier,
    branch: clearBranch ? null : branch ?? this.branch,
    shiftStatus: clearShiftStatus ? null : shiftStatus ?? this.shiftStatus,
    differenceFilter: differenceFilter ?? this.differenceFilter,
    page: page ?? this.page,
    pageSize: pageSize,
    errorMessage: clearErrorMessage ? null : errorMessage ?? this.errorMessage,
  );

  @override
  List<Object?> get props => <Object?>[
    status,
    all,
    query,
    period,
    customStart,
    customEnd,
    cashier,
    branch,
    shiftStatus,
    differenceFilter,
    page,
    pageSize,
    errorMessage,
  ];
}

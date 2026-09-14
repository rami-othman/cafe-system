import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../models/expenses_report.dart';
import '../repositories/expenses_report_repository.dart';
import 'expenses_report_state.dart';
import 'report_memory_cache.dart';
import 'report_debug_timing.dart';

class ExpensesReportCubit extends Cubit<ExpensesReportState> {
  ExpensesReportCubit({required this.repository})
    : super(const ExpensesReportState());
  final ExpensesReportRepository repository;
  static final ReportMemoryCache<ExpensesReport> _cache =
      ReportMemoryCache<ExpensesReport>();
  String? _inFlightQuery;
  String? _completedQuery;
  int _requestVersion = 0;
  Future<void> load() async {
    final now = DateTime.now();
    final range =
        state.range ??
        DateTimeRange(
          start: DateTime(now.year, now.month, now.day - 29),
          end: now,
        );
    final query = reportQueryKey('expenses:${identityHashCode(repository)}', from: range.start, to: range.end,
        filters: <Object?>[state.branchId, state.categoryId, state.expenseStatus,
          state.comparePrevious]);
    if (_inFlightQuery == query || _completedQuery == query) return;
    final cached = _cache.read(query);
    if (cached != null) {
      emit(state.copyWith(status: ExpensesReportLoadStatus.loaded, range: range,
          data: cached, sortedRows: _sort(cached.rows)));
    } else {
      emit(state.copyWith(status: ExpensesReportLoadStatus.loading, range: range));
    }
    _inFlightQuery = query;
    final request = ++_requestVersion;
    final timing = ReportDebugTiming('expenses');
    try {
      final data = await repository.getReport(
        from: range.start,
        to: range.end,
        branchId: state.branchId,
        categoryId: state.categoryId,
        status: state.expenseStatus,
        comparePrevious: state.comparePrevious,
      );
      if (request != _requestVersion || isClosed) return;
      _cache.put(query, data);
      _completedQuery = query;
      _inFlightQuery = null;
      timing.complete();
      emit(state.copyWith(status: ExpensesReportLoadStatus.loaded, data: data,
          sortedRows: _sort(data.rows)));
    } catch (_) {
      if (request != _requestVersion || isClosed) return;
      _inFlightQuery = null;
      emit(state.copyWith(status: ExpensesReportLoadStatus.error));
    }
  }

  Future<void> selectRange(DateTimeRange value) {
    if (state.range == value) return Future<void>.value();
    emit(state.copyWith(range: value));
    return load();
  }

  Future<void> selectBranch(int? value) {
    if (state.branchId == value) return Future<void>.value();
    emit(state.copyWith(branchId: value, clearBranch: value == null));
    return load();
  }

  Future<void> selectCategory(int? value) {
    if (state.categoryId == value) return Future<void>.value();
    emit(state.copyWith(categoryId: value, clearCategory: value == null));
    return load();
  }

  Future<void> selectStatus(ExpenseReportStatus? value) {
    if (state.expenseStatus == value) return Future<void>.value();
    emit(state.copyWith(expenseStatus: value, clearStatus: value == null));
    return load();
  }

  Future<void> toggleComparison(bool value) {
    if (state.comparePrevious == value) return Future<void>.value();
    emit(state.copyWith(comparePrevious: value));
    return load();
  }

  void toggleSort(ExpensesReportSort value) {
    final ascending = state.sort == value ? !state.sortAscending : true;
    emit(state.copyWith(sort: value, sortAscending: ascending,
        sortedRows: _sort(state.data?.rows, sort: value, ascending: ascending)));
  }

  List<ExpenseReportRow> _sort(List<ExpenseReportRow>? rows,
      {ExpensesReportSort? sort, bool? ascending}) {
    final result = List<ExpenseReportRow>.of(rows ?? const <ExpenseReportRow>[]);
    final activeSort = sort ?? state.sort;
    final isAscending = ascending ?? state.sortAscending;
    result.sort((a, b) => _compare(a, b, activeSort, isAscending));
    return result;
  }

  int _compare(ExpenseReportRow a, ExpenseReportRow b, ExpensesReportSort sort,
      bool ascending) {
    final Object av = switch (sort) {
      ExpensesReportSort.date => a.date.millisecondsSinceEpoch,
      ExpensesReportSort.description => a.description,
      ExpensesReportSort.category => a.category,
      ExpensesReportSort.branch => a.branch ?? '',
      ExpensesReportSort.payee => a.payee ?? '',
      ExpensesReportSort.paymentMethod => a.paymentMethod ?? '',
      ExpensesReportSort.amount => a.amount,
      ExpensesReportSort.status => a.status.index,
    };
    final Object bv = switch (sort) {
      ExpensesReportSort.date => b.date.millisecondsSinceEpoch,
      ExpensesReportSort.description => b.description,
      ExpensesReportSort.category => b.category,
      ExpensesReportSort.branch => b.branch ?? '',
      ExpensesReportSort.payee => b.payee ?? '',
      ExpensesReportSort.paymentMethod => b.paymentMethod ?? '',
      ExpensesReportSort.amount => b.amount,
      ExpensesReportSort.status => b.status.index,
    };
    final result = av is String ? av.compareTo(bv as String) : (av as num).compareTo(bv as num);
    return ascending ? result : -result;
  }
}

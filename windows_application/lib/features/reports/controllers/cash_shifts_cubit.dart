import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../repositories/cash_shifts_repository.dart';
import '../models/cash_shifts_report.dart';
import 'report_memory_cache.dart';
import 'report_debug_timing.dart';
import 'cash_shifts_state.dart';

class CashShiftsCubit extends Cubit<CashShiftsState> {
  CashShiftsCubit({required this.repository}) : super(const CashShiftsState());
  final CashShiftsRepository repository;
  static final ReportMemoryCache<CashShiftsReport> _cache =
      ReportMemoryCache<CashShiftsReport>();
  String? _inFlightQuery;
  String? _completedQuery;
  int _requestVersion = 0;
  Future<void> load() async {
    final now = DateTime.now();
    final range =
        state.range ??
        DateTimeRange(
          start: DateTime(now.year, now.month, now.day - 13),
          end: now,
        );
    final query = reportQueryKey('cash-shifts:${identityHashCode(repository)}', from: range.start, to: range.end,
        filters: <Object?>[state.branchId, state.cashierId, state.comparePrevious]);
    if (_inFlightQuery == query || _completedQuery == query) return;
    final cached = _cache.read(query);
    if (cached != null) {
      emit(state.copyWith(status: CashShiftsStatus.loaded, range: range, data: cached));
    } else {
      emit(state.copyWith(status: CashShiftsStatus.loading, range: range));
    }
    _inFlightQuery = query;
    final request = ++_requestVersion;
    final timing = ReportDebugTiming('cash-shifts');
    try {
      final data = await repository.getReport(
        from: range.start,
        to: range.end,
        branchId: state.branchId,
        cashierId: state.cashierId,
        comparePrevious: state.comparePrevious,
      );
      if (request != _requestVersion || isClosed) return;
      _cache.put(query, data);
      _completedQuery = query;
      _inFlightQuery = null;
      timing.complete();
      emit(state.copyWith(status: CashShiftsStatus.loaded, data: data));
    } catch (_) {
      if (request != _requestVersion || isClosed) return;
      _inFlightQuery = null;
      emit(state.copyWith(status: CashShiftsStatus.error));
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

  Future<void> selectCashier(int? value) {
    if (state.cashierId == value) return Future<void>.value();
    emit(state.copyWith(cashierId: value, clearCashier: value == null));
    return load();
  }

  Future<void> toggleComparison(bool value) {
    if (state.comparePrevious == value) return Future<void>.value();
    emit(state.copyWith(comparePrevious: value));
    return load();
  }
}

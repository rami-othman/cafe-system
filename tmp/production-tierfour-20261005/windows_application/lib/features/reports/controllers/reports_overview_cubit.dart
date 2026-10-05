import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../repositories/reports_repository.dart';
import 'report_memory_cache.dart';
import 'report_debug_timing.dart';
import '../models/reports_overview.dart';
import 'reports_overview_state.dart';

class ReportsOverviewCubit extends Cubit<ReportsOverviewState> {
  ReportsOverviewCubit({required this.repository})
    : super(const ReportsOverviewState());

  final ReportsRepository repository;
  static final ReportMemoryCache<ReportsOverview> _cache =
      ReportMemoryCache<ReportsOverview>();
  String? _inFlightQuery;
  String? _completedQuery;
  int _requestVersion = 0;

  Future<void> load({bool force = false}) async {
    final DateTime now = DateTime.now();
    final DateTimeRange range =
        state.range ??
        DateTimeRange(
          start: DateTime(now.year, now.month, now.day - 13),
          end: now,
        );
    final query = reportQueryKey('overview:${identityHashCode(repository)}', from: range.start, to: range.end,
        filters: <Object?>[state.branchId, state.comparePrevious]);
    if (_inFlightQuery == query || (!force && _completedQuery == query)) return;
    final cached = _cache.read(query);
    if (cached != null) {
      emit(state.copyWith(status: ReportsOverviewStatus.loaded, range: range, data: cached));
    } else {
      emit(state.copyWith(status: ReportsOverviewStatus.loading, range: range));
    }
    _inFlightQuery = query;
    final request = ++_requestVersion;
    final timing = ReportDebugTiming('overview');
    try {
      final data = await repository.getOverview(
        from: range.start,
        to: range.end,
        branchId: state.branchId,
        comparePrevious: state.comparePrevious,
      );
      if (request != _requestVersion || isClosed) return;
      _cache.put(query, data);
      _completedQuery = query;
      _inFlightQuery = null;
      timing.complete();
      emit(state.copyWith(status: ReportsOverviewStatus.loaded, data: data));
    } catch (error) {
      if (request != _requestVersion || isClosed) return;
      _inFlightQuery = null;
      emit(state.copyWith(status: ReportsOverviewStatus.error));
    }
  }

  Future<void> selectRange(DateTimeRange range) {
    if (state.range == range) return Future<void>.value();
    emit(state.copyWith(range: range));
    return load();
  }

  Future<void> selectBranch(int? branchId) {
    if (state.branchId == branchId) return Future<void>.value();
    emit(state.copyWith(branchId: branchId, clearBranch: branchId == null));
    return load();
  }

  Future<void> toggleComparison(bool value) {
    if (state.comparePrevious == value) return Future<void>.value();
    emit(state.copyWith(comparePrevious: value));
    return load();
  }
}

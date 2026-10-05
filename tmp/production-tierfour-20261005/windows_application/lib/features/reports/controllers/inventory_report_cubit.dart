import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../repositories/inventory_report_repository.dart';
import '../models/inventory_report.dart';
import 'report_memory_cache.dart';
import 'report_debug_timing.dart';
import 'inventory_report_state.dart';

class InventoryReportCubit extends Cubit<InventoryReportState> {
  InventoryReportCubit({required this.repository})
    : super(const InventoryReportState());
  final InventoryReportRepository repository;
  static final ReportMemoryCache<InventoryReport> _cache =
      ReportMemoryCache<InventoryReport>();
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
    final query = reportQueryKey('inventory:${identityHashCode(repository)}', from: range.start, to: range.end,
        filters: <Object?>[state.branchId, state.locationId, state.categoryId,
          state.comparePrevious]);
    if (_inFlightQuery == query || _completedQuery == query) return;
    final cached = _cache.read(query);
    if (cached != null) {
      emit(state.copyWith(status: InventoryReportStatus.loaded, range: range, data: cached));
    } else {
      emit(state.copyWith(status: InventoryReportStatus.loading, range: range));
    }
    _inFlightQuery = query;
    final request = ++_requestVersion;
    final timing = ReportDebugTiming('inventory');
    try {
      final data = await repository.getReport(
        from: range.start,
        to: range.end,
        branchId: state.branchId,
        locationId: state.locationId,
        categoryId: state.categoryId,
        comparePrevious: state.comparePrevious,
      );
      if (request != _requestVersion || isClosed) return;
      _cache.put(query, data);
      _completedQuery = query;
      _inFlightQuery = null;
      timing.complete();
      emit(state.copyWith(status: InventoryReportStatus.loaded, data: data));
    } catch (_) {
      if (request != _requestVersion || isClosed) return;
      _inFlightQuery = null;
      emit(state.copyWith(status: InventoryReportStatus.error));
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

  Future<void> selectLocation(int? value) {
    if (state.locationId == value) return Future<void>.value();
    emit(state.copyWith(locationId: value, clearLocation: value == null));
    return load();
  }

  Future<void> selectCategory(int? value) {
    if (state.categoryId == value) return Future<void>.value();
    emit(state.copyWith(categoryId: value, clearCategory: value == null));
    return load();
  }

  Future<void> toggleComparison(bool value) {
    if (state.comparePrevious == value) return Future<void>.value();
    emit(state.copyWith(comparePrevious: value));
    return load();
  }
}

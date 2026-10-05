import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../models/sales_profitability_report.dart';
import '../repositories/sales_profitability_repository.dart';
import 'sales_profitability_state.dart';
import 'report_memory_cache.dart';
import 'report_debug_timing.dart';

class SalesProfitabilityCubit extends Cubit<SalesProfitabilityState> {
  SalesProfitabilityCubit({required this.repository})
    : super(const SalesProfitabilityState());
  final SalesProfitabilityRepository repository;
  static final ReportMemoryCache<SalesProfitabilityReport> _cache =
      ReportMemoryCache<SalesProfitabilityReport>();
  String? _inFlightQuery;
  String? _completedQuery;
  int _requestVersion = 0;

  Future<void> load() async {
    final DateTime now = DateTime.now();
    final DateTimeRange range =
        state.range ??
        DateTimeRange(
          start: DateTime(now.year, now.month, now.day - 13),
          end: now,
        );
    final query = reportQueryKey('sales:${identityHashCode(repository)}', from: range.start, to: range.end,
        filters: <Object?>[state.branchId, state.comparePrevious]);
    if (_inFlightQuery == query || _completedQuery == query) return;
    final cached = _cache.read(query);
    if (cached != null) {
      emit(state.copyWith(status: SalesProfitabilityStatus.loaded, range: range,
          data: cached, sortedProducts: _sort(dataProducts: cached.products)));
    } else {
      emit(state.copyWith(status: SalesProfitabilityStatus.loading, range: range));
    }
    _inFlightQuery = query;
    final request = ++_requestVersion;
    final timing = ReportDebugTiming('sales');
    try {
      final data = await repository.getReport(
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
      emit(state.copyWith(status: SalesProfitabilityStatus.loaded, data: data,
          sortedProducts: _sort(dataProducts: data.products)));
    } catch (_) {
      if (request != _requestVersion || isClosed) return;
      _inFlightQuery = null;
      emit(state.copyWith(status: SalesProfitabilityStatus.error));
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

  void selectGrouping(SalesProfitabilityGrouping grouping) {
    if (state.grouping != grouping) emit(state.copyWith(grouping: grouping));
  }

  void selectProductView(ProductPerformanceView view) => emit(
    state.copyWith(
      productView: view,
      sortField: view == ProductPerformanceView.topSelling
          ? ProductPerformanceSortField.netSales
          : ProductPerformanceSortField.grossProfit,
      sortDirection: view == ProductPerformanceView.underperforming
          ? ProductSortDirection.ascending
          : ProductSortDirection.descending,
      sortedProducts: _sort(dataProducts: state.data?.products, field: view == ProductPerformanceView.topSelling ? ProductPerformanceSortField.netSales : ProductPerformanceSortField.grossProfit, direction: view == ProductPerformanceView.underperforming ? ProductSortDirection.ascending : ProductSortDirection.descending),
    ),
  );

  void toggleSort(ProductPerformanceSortField field) => emit(
    state.copyWith(
      sortField: field,
      sortDirection:
          state.sortField == field &&
              state.sortDirection == ProductSortDirection.descending
          ? ProductSortDirection.ascending
          : ProductSortDirection.descending,
      sortedProducts: _sort(dataProducts: state.data?.products, field: field,
          direction: state.sortField == field && state.sortDirection == ProductSortDirection.descending ? ProductSortDirection.ascending : ProductSortDirection.descending),
    ),
  );

  List<ProductPerformanceRow> _sort({List<ProductPerformanceRow>? dataProducts,
      ProductPerformanceSortField? field, ProductSortDirection? direction}) {
    final products = dataProducts ?? const <ProductPerformanceRow>[];
    final result = List<ProductPerformanceRow>.of(products);
    final sortField = field ?? state.sortField;
    final sortDirection = direction ?? state.sortDirection;
    final value = switch (sortField) {
      ProductPerformanceSortField.name =>
        (ProductPerformanceRow row) => row.name,
      ProductPerformanceSortField.category =>
        (ProductPerformanceRow row) => row.category,
      ProductPerformanceSortField.quantity =>
        (ProductPerformanceRow row) => row.quantity,
      ProductPerformanceSortField.grossSales =>
        (ProductPerformanceRow row) => row.grossSales,
      ProductPerformanceSortField.discounts =>
        (ProductPerformanceRow row) => row.discounts,
      ProductPerformanceSortField.netSales =>
        (ProductPerformanceRow row) => row.netSales,
      ProductPerformanceSortField.cogs =>
        (ProductPerformanceRow row) => row.cogs,
      ProductPerformanceSortField.grossProfit =>
        (ProductPerformanceRow row) => row.grossProfit,
      ProductPerformanceSortField.margin =>
        (ProductPerformanceRow row) => row.margin,
    };
    result.sort((a, b) {
      final dynamic left = value(a);
      final dynamic right = value(b);
      final order = left is String
          ? left.compareTo(right as String)
          : (left as double).compareTo(right as double);
      return sortDirection == ProductSortDirection.descending
          ? -order
          : order;
    });
    return result;
  }
}

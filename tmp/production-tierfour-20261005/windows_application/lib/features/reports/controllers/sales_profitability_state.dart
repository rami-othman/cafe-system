import 'package:equatable/equatable.dart';
import 'package:flutter/material.dart';

import '../models/sales_profitability_report.dart';

enum SalesProfitabilityStatus { loading, loaded, error }

enum ProductSortDirection { ascending, descending }

class SalesProfitabilityState extends Equatable {
  const SalesProfitabilityState({
    this.status = SalesProfitabilityStatus.loading,
    this.range,
    this.branchId,
    this.comparePrevious = true,
    this.grouping = SalesProfitabilityGrouping.daily,
    this.productView = ProductPerformanceView.topSelling,
    this.sortField = ProductPerformanceSortField.netSales,
    this.sortDirection = ProductSortDirection.descending,
    this.data,
    this.sortedProducts = const <ProductPerformanceRow>[],
  });
  final SalesProfitabilityStatus status;
  final DateTimeRange? range;
  final int? branchId;
  final bool comparePrevious;
  final SalesProfitabilityGrouping grouping;
  final ProductPerformanceView productView;
  final ProductPerformanceSortField sortField;
  final ProductSortDirection sortDirection;
  final SalesProfitabilityReport? data;
  final List<ProductPerformanceRow> sortedProducts;

  SalesProfitabilityState copyWith({
    SalesProfitabilityStatus? status,
    DateTimeRange? range,
    int? branchId,
    bool clearBranch = false,
    bool? comparePrevious,
    SalesProfitabilityGrouping? grouping,
    ProductPerformanceView? productView,
    ProductPerformanceSortField? sortField,
    ProductSortDirection? sortDirection,
    SalesProfitabilityReport? data,
    List<ProductPerformanceRow>? sortedProducts,
  }) => SalesProfitabilityState(
    status: status ?? this.status,
    range: range ?? this.range,
    branchId: clearBranch ? null : branchId ?? this.branchId,
    comparePrevious: comparePrevious ?? this.comparePrevious,
    grouping: grouping ?? this.grouping,
    productView: productView ?? this.productView,
    sortField: sortField ?? this.sortField,
    sortDirection: sortDirection ?? this.sortDirection,
    data: data ?? this.data,
    sortedProducts: sortedProducts ?? this.sortedProducts,
  );

  @override
  List<Object?> get props => <Object?>[
    status,
    range,
    branchId,
    comparePrevious,
    grouping,
    productView,
    sortField,
    sortDirection,
    data,
    sortedProducts,
  ];
}

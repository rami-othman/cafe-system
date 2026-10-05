import 'package:equatable/equatable.dart';
import 'package:flutter/material.dart';
import '../models/inventory_report.dart';

enum InventoryReportStatus { loading, loaded, error }

class InventoryReportState extends Equatable {
  const InventoryReportState({
    this.status = InventoryReportStatus.loading,
    this.range,
    this.branchId,
    this.locationId,
    this.categoryId,
    this.comparePrevious = true,
    this.data,
  });
  final InventoryReportStatus status;
  final DateTimeRange? range;
  final int? branchId, locationId, categoryId;
  final bool comparePrevious;
  final InventoryReport? data;
  InventoryReportState copyWith({
    InventoryReportStatus? status,
    DateTimeRange? range,
    int? branchId,
    int? locationId,
    int? categoryId,
    bool clearBranch = false,
    bool clearLocation = false,
    bool clearCategory = false,
    bool? comparePrevious,
    InventoryReport? data,
  }) => InventoryReportState(
    status: status ?? this.status,
    range: range ?? this.range,
    branchId: clearBranch ? null : branchId ?? this.branchId,
    locationId: clearLocation ? null : locationId ?? this.locationId,
    categoryId: clearCategory ? null : categoryId ?? this.categoryId,
    comparePrevious: comparePrevious ?? this.comparePrevious,
    data: data ?? this.data,
  );
  @override
  List<Object?> get props => <Object?>[
    status,
    range,
    branchId,
    locationId,
    categoryId,
    comparePrevious,
    data,
  ];
}

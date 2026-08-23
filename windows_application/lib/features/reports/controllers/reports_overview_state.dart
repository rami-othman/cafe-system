import 'package:equatable/equatable.dart';
import 'package:flutter/material.dart';

import '../models/reports_overview.dart';

enum ReportsOverviewStatus { loading, loaded, error }

class ReportsOverviewState extends Equatable {
  const ReportsOverviewState({
    this.status = ReportsOverviewStatus.loading,
    this.range,
    this.branchId,
    this.comparePrevious = true,
    this.data,
    this.errorMessage,
  });
  final ReportsOverviewStatus status;
  final DateTimeRange? range;
  final int? branchId;
  final bool comparePrevious;
  final ReportsOverview? data;
  final String? errorMessage;
  ReportsOverviewState copyWith({
    ReportsOverviewStatus? status,
    DateTimeRange? range,
    int? branchId,
    bool clearBranch = false,
    bool? comparePrevious,
    ReportsOverview? data,
    String? errorMessage,
    bool clearError = false,
  }) => ReportsOverviewState(
    status: status ?? this.status,
    range: range ?? this.range,
    branchId: clearBranch ? null : branchId ?? this.branchId,
    comparePrevious: comparePrevious ?? this.comparePrevious,
    data: data ?? this.data,
    errorMessage: clearError ? null : errorMessage ?? this.errorMessage,
  );
  @override
  List<Object?> get props => <Object?>[
    status,
    range,
    branchId,
    comparePrevious,
    data,
    errorMessage,
  ];
}

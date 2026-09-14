import 'package:equatable/equatable.dart';
import 'package:flutter/material.dart';
import '../models/cash_shifts_report.dart';

enum CashShiftsStatus { loading, loaded, error }

class CashShiftsState extends Equatable {
  const CashShiftsState({
    this.status = CashShiftsStatus.loading,
    this.range,
    this.branchId,
    this.cashierId,
    this.comparePrevious = true,
    this.data,
  });
  final CashShiftsStatus status;
  final DateTimeRange? range;
  final int? branchId, cashierId;
  final bool comparePrevious;
  final CashShiftsReport? data;
  CashShiftsState copyWith({
    CashShiftsStatus? status,
    DateTimeRange? range,
    int? branchId,
    int? cashierId,
    bool clearBranch = false,
    bool clearCashier = false,
    bool? comparePrevious,
    CashShiftsReport? data,
  }) => CashShiftsState(
    status: status ?? this.status,
    range: range ?? this.range,
    branchId: clearBranch ? null : branchId ?? this.branchId,
    cashierId: clearCashier ? null : cashierId ?? this.cashierId,
    comparePrevious: comparePrevious ?? this.comparePrevious,
    data: data ?? this.data,
  );
  @override
  List<Object?> get props => <Object?>[
    status,
    range,
    branchId,
    cashierId,
    comparePrevious,
    data,
  ];
}

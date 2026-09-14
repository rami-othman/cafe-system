import 'package:equatable/equatable.dart';
import 'package:flutter/material.dart';
import '../models/expenses_report.dart';

enum ExpensesReportLoadStatus { loading, loaded, error }

enum ExpensesReportSort {
  date,
  description,
  category,
  branch,
  payee,
  paymentMethod,
  amount,
  status,
}

class ExpensesReportState extends Equatable {
  const ExpensesReportState({
    this.status = ExpensesReportLoadStatus.loading,
    this.range,
    this.branchId,
    this.categoryId,
    this.expenseStatus,
    this.comparePrevious = true,
    this.sort = ExpensesReportSort.date,
    this.sortAscending = false,
    this.data,
    this.sortedRows = const <ExpenseReportRow>[],
  });
  final ExpensesReportLoadStatus status;
  final DateTimeRange? range;
  final int? branchId, categoryId;
  final ExpenseReportStatus? expenseStatus;
  final bool comparePrevious, sortAscending;
  final ExpensesReportSort sort;
  final ExpensesReport? data;
  final List<ExpenseReportRow> sortedRows;
  ExpensesReportState copyWith({
    ExpensesReportLoadStatus? status,
    DateTimeRange? range,
    int? branchId,
    int? categoryId,
    ExpenseReportStatus? expenseStatus,
    bool clearBranch = false,
    bool clearCategory = false,
    bool clearStatus = false,
    bool? comparePrevious,
    ExpensesReportSort? sort,
    bool? sortAscending,
    ExpensesReport? data,
    List<ExpenseReportRow>? sortedRows,
  }) => ExpensesReportState(
    status: status ?? this.status,
    range: range ?? this.range,
    branchId: clearBranch ? null : branchId ?? this.branchId,
    categoryId: clearCategory ? null : categoryId ?? this.categoryId,
    expenseStatus: clearStatus ? null : expenseStatus ?? this.expenseStatus,
    comparePrevious: comparePrevious ?? this.comparePrevious,
    sort: sort ?? this.sort,
    sortAscending: sortAscending ?? this.sortAscending,
    data: data ?? this.data,
    sortedRows: sortedRows ?? this.sortedRows,
  );
  @override
  List<Object?> get props => <Object?>[
    status,
    range,
    branchId,
    categoryId,
    expenseStatus,
    comparePrevious,
    sort,
    sortAscending,
    data,
    sortedRows,
  ];
}

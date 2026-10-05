import 'package:equatable/equatable.dart';

/// Typed contract for the future `GET /reports/expenses` response.
/// The production repository deliberately returns an empty instance until that
/// endpoint exists; no accounting aggregation is performed in the client.
class ExpensesReport extends Equatable {
  const ExpensesReport({
    required this.currency,
    required this.branches,
    required this.categories,
    required this.statuses,
    required this.kpis,
    required this.trend,
    required this.categoryBreakdown,
    required this.branchComparison,
    required this.largestExpenses,
    required this.rows,
    required this.periodComparison,
  });

  factory ExpensesReport.empty() => const ExpensesReport(
    currency: 'SYP',
    branches: <ExpenseReportFilterOption>[],
    categories: <ExpenseReportFilterOption>[],
    statuses: <ExpenseReportStatus>[],
    kpis: ExpensesReportKpis.empty(),
    trend: <ExpenseTrendPoint>[],
    categoryBreakdown: <ExpenseCategoryBreakdownRow>[],
    branchComparison: <BranchExpenseComparisonRow>[],
    largestExpenses: <LargestExpenseRow>[],
    rows: <ExpenseReportRow>[],
    periodComparison: null,
  );

  final String currency;
  final List<ExpenseReportFilterOption> branches, categories;
  final List<ExpenseReportStatus> statuses;
  final ExpensesReportKpis kpis;
  final List<ExpenseTrendPoint> trend;
  final List<ExpenseCategoryBreakdownRow> categoryBreakdown;
  final List<BranchExpenseComparisonRow> branchComparison;
  final List<LargestExpenseRow> largestExpenses;
  final List<ExpenseReportRow> rows;
  final ExpensePeriodComparison? periodComparison;
  @override
  List<Object?> get props => <Object?>[
    currency,
    branches,
    categories,
    statuses,
    kpis,
    trend,
    categoryBreakdown,
    branchComparison,
    largestExpenses,
    rows,
    periodComparison,
  ];
}

class ExpenseReportFilterOption extends Equatable {
  const ExpenseReportFilterOption({required this.id, required this.name});
  final int id;
  final String name;
  @override
  List<Object?> get props => <Object?>[id, name];
}

class ExpenseMetric extends Equatable {
  const ExpenseMetric({this.value, this.previousValue, this.textValue});
  const ExpenseMetric.unavailable()
    : value = null,
      previousValue = null,
      textValue = null;
  final double? value, previousValue;
  final String? textValue;
  bool get available => value != null || textValue != null;
  @override
  List<Object?> get props => <Object?>[value, previousValue, textValue];
}

class ExpensesReportKpis extends Equatable {
  const ExpensesReportKpis({
    required this.total,
    required this.posted,
    required this.pending,
    required this.averageDaily,
    required this.expenseToSalesRatio,
    required this.largestCategory,
  });
  const ExpensesReportKpis.empty()
    : total = const ExpenseMetric.unavailable(),
      posted = const ExpenseMetric.unavailable(),
      pending = const ExpenseMetric.unavailable(),
      averageDaily = const ExpenseMetric.unavailable(),
      expenseToSalesRatio = const ExpenseMetric.unavailable(),
      largestCategory = const ExpenseMetric.unavailable();
  final ExpenseMetric total,
      posted,
      pending,
      averageDaily,
      expenseToSalesRatio,
      largestCategory;
  @override
  List<Object?> get props => <Object?>[
    total,
    posted,
    pending,
    averageDaily,
    expenseToSalesRatio,
    largestCategory,
  ];
}

class ExpenseTrendPoint extends Equatable {
  const ExpenseTrendPoint({
    required this.date,
    required this.value,
    this.previousValue,
  });
  final DateTime date;
  final double value;
  final double? previousValue;
  @override
  List<Object?> get props => <Object?>[date, value, previousValue];
}

class ExpenseCategoryBreakdownRow extends Equatable {
  const ExpenseCategoryBreakdownRow({
    required this.name,
    required this.amount,
    this.share,
  });
  final String name;
  final double amount;
  final double? share;
  @override
  List<Object?> get props => <Object?>[name, amount, share];
}

class BranchExpenseComparisonRow extends Equatable {
  const BranchExpenseComparisonRow({
    required this.branch,
    required this.totalExpenses,
    this.netSales,
    this.expenseToSalesRatio,
    this.previousTotalExpenses,
  });
  final String branch;
  final double totalExpenses;
  final double? netSales, expenseToSalesRatio, previousTotalExpenses;
  @override
  List<Object?> get props => <Object?>[
    branch,
    totalExpenses,
    netSales,
    expenseToSalesRatio,
    previousTotalExpenses,
  ];
}

class LargestExpenseRow extends Equatable {
  const LargestExpenseRow({
    required this.description,
    required this.category,
    required this.amount,
    required this.date,
    this.branch,
  });
  final String description, category;
  final double amount;
  final DateTime date;
  final String? branch;
  @override
  List<Object?> get props => <Object?>[
    description,
    category,
    amount,
    date,
    branch,
  ];
}

enum ExpenseReportStatus {
  draft,
  pendingApproval,
  approved,
  paid,
  rejected,
  reversed,
}

class ExpenseReportRow extends Equatable {
  const ExpenseReportRow({
    required this.date,
    required this.description,
    required this.category,
    required this.amount,
    required this.status,
    this.branch,
    this.payee,
    this.paymentMethod,
  });
  final DateTime date;
  final String description, category;
  final double amount;
  final ExpenseReportStatus status;
  final String? branch, payee, paymentMethod;
  bool get isCompanyWide => branch == null;
  @override
  List<Object?> get props => <Object?>[
    date,
    description,
    category,
    amount,
    status,
    branch,
    payee,
    paymentMethod,
  ];
}

class ExpensePeriodComparison extends Equatable {
  const ExpensePeriodComparison({
    required this.currentLabel,
    required this.previousLabel,
    required this.currentAmount,
    required this.previousAmount,
  });
  final String currentLabel, previousLabel;
  final double currentAmount, previousAmount;
  double get difference => currentAmount - previousAmount;
  double? get percentageDifference =>
      previousAmount == 0 ? null : difference / previousAmount * 100;
  @override
  List<Object?> get props => <Object?>[
    currentLabel,
    previousLabel,
    currentAmount,
    previousAmount,
  ];
}

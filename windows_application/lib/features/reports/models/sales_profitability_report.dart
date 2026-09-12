import 'package:equatable/equatable.dart';

enum SalesProfitabilityGrouping { daily, weekly, monthly }

enum ProductPerformanceView { topSelling, mostProfitable, underperforming }

enum ProductPerformanceSortField {
  name,
  category,
  quantity,
  grossSales,
  discounts,
  netSales,
  cogs,
  grossProfit,
  margin,
}

class SalesProfitabilityReport extends Equatable {
  const SalesProfitabilityReport({
    required this.currency,
    required this.branches,
    required this.kpis,
    required this.dailyTrend,
    required this.weeklyTrend,
    required this.monthlyTrend,
    required this.hourlySales,
    required this.categorySales,
    required this.branchPerformance,
    required this.products,
  });

  factory SalesProfitabilityReport.empty() => SalesProfitabilityReport(
    currency: 'SYP',
    branches: const <SalesProfitabilityBranch>[],
    kpis: const SalesProfitabilityKpis.empty(),
    dailyTrend: const <SalesProfitTrendPoint>[],
    weeklyTrend: const <SalesProfitTrendPoint>[],
    monthlyTrend: const <SalesProfitTrendPoint>[],
    hourlySales: const <HourlySalesBucket>[],
    categorySales: const <CategorySalesRow>[],
    branchPerformance: const <BranchPerformanceRow>[],
    products: const <ProductPerformanceRow>[],
  );

  final String currency;
  final List<SalesProfitabilityBranch> branches;
  final SalesProfitabilityKpis kpis;
  final List<SalesProfitTrendPoint> dailyTrend;
  final List<SalesProfitTrendPoint> weeklyTrend;
  final List<SalesProfitTrendPoint> monthlyTrend;
  final List<HourlySalesBucket> hourlySales;
  final List<CategorySalesRow> categorySales;
  final List<BranchPerformanceRow> branchPerformance;
  final List<ProductPerformanceRow> products;

  List<SalesProfitTrendPoint> trendFor(SalesProfitabilityGrouping grouping) =>
      switch (grouping) {
        SalesProfitabilityGrouping.daily => dailyTrend,
        SalesProfitabilityGrouping.weekly => weeklyTrend,
        SalesProfitabilityGrouping.monthly => monthlyTrend,
      };

  @override
  List<Object?> get props => <Object?>[
    currency,
    branches,
    kpis,
    dailyTrend,
    weeklyTrend,
    monthlyTrend,
    hourlySales,
    categorySales,
    branchPerformance,
    products,
  ];
}

class SalesProfitabilityBranch extends Equatable {
  const SalesProfitabilityBranch({required this.id, required this.name});
  final int id;
  final String name;
  @override
  List<Object?> get props => <Object?>[id, name];
}

class SalesProfitabilityKpis extends Equatable {
  const SalesProfitabilityKpis({
    required this.grossSales,
    required this.netSales,
    required this.discounts,
    required this.refunds,
    required this.cogs,
    required this.grossProfit,
    required this.grossMargin,
    required this.averageOrderValue,
  });
  const SalesProfitabilityKpis.empty()
    : grossSales = const SalesProfitabilityMetric.unavailable(),
      netSales = const SalesProfitabilityMetric.unavailable(),
      discounts = const SalesProfitabilityMetric.unavailable(),
      refunds = const SalesProfitabilityMetric.unavailable(),
      cogs = const SalesProfitabilityMetric.unavailable(),
      grossProfit = const SalesProfitabilityMetric.unavailable(),
      grossMargin = const SalesProfitabilityMetric.unavailable(),
      averageOrderValue = const SalesProfitabilityMetric.unavailable();
  final SalesProfitabilityMetric grossSales;
  final SalesProfitabilityMetric netSales;
  final SalesProfitabilityMetric discounts;
  final SalesProfitabilityMetric refunds;
  final SalesProfitabilityMetric cogs;
  final SalesProfitabilityMetric grossProfit;
  final SalesProfitabilityMetric grossMargin;
  final SalesProfitabilityMetric averageOrderValue;
  @override
  List<Object?> get props => <Object?>[
    grossSales,
    netSales,
    discounts,
    refunds,
    cogs,
    grossProfit,
    grossMargin,
    averageOrderValue,
  ];
}

class SalesProfitabilityMetric extends Equatable {
  const SalesProfitabilityMetric({this.value, this.previousValue});
  const SalesProfitabilityMetric.unavailable()
    : value = null,
      previousValue = null;
  final double? value;
  final double? previousValue;
  bool get available => value != null;
  @override
  List<Object?> get props => <Object?>[value, previousValue];
}

class SalesProfitTrendPoint extends Equatable {
  const SalesProfitTrendPoint({
    required this.date,
    required this.netSales,
    required this.grossProfit,
  });
  final DateTime date;
  final double netSales;
  final double grossProfit;
  @override
  List<Object?> get props => <Object?>[date, netSales, grossProfit];
}

class HourlySalesBucket extends Equatable {
  const HourlySalesBucket({required this.label, required this.sales});
  final String label;
  final double sales;
  @override
  List<Object?> get props => <Object?>[label, sales];
}

class CategorySalesRow extends Equatable {
  const CategorySalesRow({
    required this.name,
    required this.netSales,
    required this.percent,
  });
  final String name;
  final double netSales;
  final double percent;
  @override
  List<Object?> get props => <Object?>[name, netSales, percent];
}

class BranchPerformanceRow extends Equatable {
  const BranchPerformanceRow({
    required this.name,
    required this.netSales,
    required this.orders,
    required this.grossProfit,
    required this.margin,
  });
  final String name;
  final double netSales;
  final int orders;
  final double grossProfit;
  final double margin;
  @override
  List<Object?> get props => <Object?>[
    name,
    netSales,
    orders,
    grossProfit,
    margin,
  ];
}

class ProductPerformanceRow extends Equatable {
  const ProductPerformanceRow({
    required this.name,
    required this.category,
    required this.quantity,
    required this.grossSales,
    required this.discounts,
    required this.netSales,
    required this.cogs,
    required this.grossProfit,
    required this.margin,
  });
  final String name;
  final String category;
  final double quantity;
  final double grossSales;
  final double discounts;
  final double netSales;
  final double cogs;
  final double grossProfit;
  final double margin;
  @override
  List<Object?> get props => <Object?>[
    name,
    category,
    quantity,
    grossSales,
    discounts,
    netSales,
    cogs,
    grossProfit,
    margin,
  ];
}

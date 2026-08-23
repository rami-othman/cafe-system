import 'package:equatable/equatable.dart';

import '../../pos/models/branch.dart';
import '../../pos/models/json_helpers.dart';

class ReportsOverview extends Equatable {
  const ReportsOverview({
    required this.period,
    required this.currency,
    required this.branches,
    required this.selectedBranchId,
    required this.kpis,
    required this.salesTrend,
    required this.branchComparison,
    required this.topProducts,
    required this.recentExceptions,
  });

  factory ReportsOverview.fromJson(Map<String, dynamic> json) =>
      ReportsOverview(
        period: ReportsDateRange.fromJson(_map(json['period'])),
        currency: readString(json['currency'], fallback: 'SYP'),
        branches: readMapList(json['branches'])
            .map(
              (Map<String, dynamic> branch) => Branch(
                id: readInt(branch['id']) ?? 0,
                name: readString(branch['name']),
                currency: readString(json['currency'], fallback: 'SYP'),
                timezone: '',
                isActive: true,
              ),
            )
            .toList(growable: false),
        selectedBranchId: readInt(json['selectedBranchId']),
        kpis: ReportsKpis.fromJson(_map(json['kpis'])),
        salesTrend: readMapList(
          json['salesTrend'],
        ).map(SalesTrendPoint.fromJson).toList(growable: false),
        branchComparison: readMapList(
          json['branchComparison'],
        ).map(BranchSales.fromJson).toList(growable: false),
        topProducts: readMapList(
          json['topProducts'],
        ).map(TopProduct.fromJson).toList(growable: false),
        recentExceptions: readMapList(
          json['recentExceptions'],
        ).map(ReportException.fromJson).toList(growable: false),
      );

  final ReportsDateRange period;
  final String currency;
  final List<Branch> branches;
  final int? selectedBranchId;
  final ReportsKpis kpis;
  final List<SalesTrendPoint> salesTrend;
  final List<BranchSales> branchComparison;
  final List<TopProduct> topProducts;
  final List<ReportException> recentExceptions;

  @override
  List<Object?> get props => <Object?>[
    period,
    currency,
    branches,
    selectedBranchId,
    kpis,
    salesTrend,
    branchComparison,
    topProducts,
    recentExceptions,
  ];
}

class ReportsDateRange extends Equatable {
  const ReportsDateRange({required this.from, required this.to});
  factory ReportsDateRange.fromJson(Map<String, dynamic> json) =>
      ReportsDateRange(
        from: DateTime.tryParse(readString(json['from'])) ?? DateTime.now(),
        to: DateTime.tryParse(readString(json['to'])) ?? DateTime.now(),
      );
  final DateTime from;
  final DateTime to;
  @override
  List<Object?> get props => <Object?>[from, to];
}

class ReportsKpis extends Equatable {
  const ReportsKpis({
    required this.netSales,
    required this.grossProfit,
    required this.grossMargin,
    required this.totalExpenses,
    required this.netProfit,
  });
  factory ReportsKpis.fromJson(Map<String, dynamic> json) => ReportsKpis(
    netSales: ReportMetric.fromJson(_map(json['netSales'])),
    grossProfit: ReportMetric.fromJson(_map(json['grossProfit'])),
    grossMargin: ReportMetric.fromJson(_map(json['grossMargin'])),
    totalExpenses: ReportMetric.fromJson(_map(json['totalExpenses'])),
    netProfit: ReportMetric.fromJson(_map(json['netProfit'])),
  );
  final ReportMetric netSales;
  final ReportMetric grossProfit;
  final ReportMetric grossMargin;
  final ReportMetric totalExpenses;
  final ReportMetric netProfit;
  @override
  List<Object?> get props => <Object?>[
    netSales,
    grossProfit,
    grossMargin,
    totalExpenses,
    netProfit,
  ];
}

class ReportMetric extends Equatable {
  const ReportMetric({
    required this.value,
    required this.previousValue,
    required this.available,
    required this.reason,
  });
  factory ReportMetric.fromJson(Map<String, dynamic> json) => ReportMetric(
    value: _number(json['value']),
    previousValue: _number(json['previousValue']),
    available: readBool(json['available']),
    reason: readString(json['reason']),
  );
  final double? value;
  final double? previousValue;
  final bool available;
  final String reason;
  @override
  List<Object?> get props => <Object?>[value, previousValue, available, reason];
}

class SalesTrendPoint extends Equatable {
  const SalesTrendPoint({required this.date, required this.netSales});
  factory SalesTrendPoint.fromJson(Map<String, dynamic> json) =>
      SalesTrendPoint(
        date: DateTime.tryParse(readString(json['date'])) ?? DateTime.now(),
        netSales: readDouble(json['netSales']),
      );
  final DateTime date;
  final double netSales;
  @override
  List<Object?> get props => <Object?>[date, netSales];
}

class BranchSales extends Equatable {
  const BranchSales({
    required this.id,
    required this.name,
    required this.netSales,
  });
  factory BranchSales.fromJson(Map<String, dynamic> json) => BranchSales(
    id: readInt(json['id']) ?? 0,
    name: readString(json['name']),
    netSales: readDouble(json['netSales']),
  );
  final int id;
  final String name;
  final double netSales;
  @override
  List<Object?> get props => <Object?>[id, name, netSales];
}

class TopProduct extends Equatable {
  const TopProduct({required this.name, required this.netSales});
  factory TopProduct.fromJson(Map<String, dynamic> json) => TopProduct(
    name: readString(json['name']),
    netSales: readDouble(json['netSales']),
  );
  final String name;
  final double netSales;
  @override
  List<Object?> get props => <Object?>[name, netSales];
}

class ReportException extends Equatable {
  const ReportException({
    required this.severity,
    required this.description,
    required this.branch,
    required this.occurredAt,
  });
  factory ReportException.fromJson(Map<String, dynamic> json) =>
      ReportException(
        severity: readString(json['severity'], fallback: 'warning'),
        description: readString(json['description']),
        branch: readString(json['branch']),
        occurredAt: DateTime.tryParse(readString(json['occurredAt'])),
      );
  final String severity;
  final String description;
  final String branch;
  final DateTime? occurredAt;
  @override
  List<Object?> get props => <Object?>[
    severity,
    description,
    branch,
    occurredAt,
  ];
}

Map<String, dynamic> _map(dynamic value) =>
    Map<String, dynamic>.from(value as Map? ?? const <String, dynamic>{});

double? _number(dynamic value) => value == null ? null : readDouble(value);

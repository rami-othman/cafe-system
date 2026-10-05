import 'package:intl/intl.dart';

import '../../../core/network/dio_api_client.dart';
import '../../pos/models/json_helpers.dart';
import '../models/sales_profitability_report.dart';

/// Backed by `GET finance/reports/sales-profitability` (Phase 5) — the
/// POS+Manual-Invoice union, net of posted Sales Credit Notes. Falls back to
/// [SalesProfitabilityReport.empty] only when running without a backend
/// (`useBackend: false`), never exposing sample financial figures otherwise.
class SalesProfitabilityRepository {
  const SalesProfitabilityRepository({this.apiClient});

  final DioApiClient? apiClient;

  Future<SalesProfitabilityReport> getReport({
    required DateTime from,
    required DateTime to,
    required int? branchId,
    required bool comparePrevious,
  }) async {
    if (apiClient == null) {
      return SalesProfitabilityReport.empty();
    }

    final DateFormat dateFormat = DateFormat('yyyy-MM-dd');
    final dynamic response = await apiClient!.get(
      'finance/reports/sales-profitability',
      queryParameters: <String, dynamic>{
        'dateFrom': dateFormat.format(from),
        'dateTo': dateFormat.format(to),
        'branchId': ?branchId,
        'comparison': comparePrevious ? 'previous_period' : 'none',
      },
    );
    return _fromJson(Map<String, dynamic>.from(response as Map));
  }

  SalesProfitabilityReport _fromJson(Map<String, dynamic> json) {
    final Map<String, dynamic> kpis = Map<String, dynamic>.from(
      json['kpis'] as Map? ?? const <String, dynamic>{},
    );

    return SalesProfitabilityReport(
      currency: readString(json['currency'], fallback: 'SYP'),
      branches: readMapList(json['branches'])
          .map(
            (Map<String, dynamic> b) => SalesProfitabilityBranch(
              id: readInt(b['id']) ?? 0,
              name: readString(b['name']),
            ),
          )
          .toList(growable: false),
      kpis: SalesProfitabilityKpis(
        grossSales: _metric(kpis['grossSales']),
        netSales: _metric(kpis['netSales']),
        discounts: _metric(kpis['discounts']),
        refunds: _metric(kpis['refunds']),
        cogs: _metric(kpis['cogs']),
        grossProfit: _metric(kpis['grossProfit']),
        grossMargin: _metric(kpis['grossMargin']),
        averageOrderValue: _metric(kpis['averageOrderValue']),
        cashCollected: _metric(kpis['cashCollected']),
        bankCollected: _metric(kpis['bankCollected']),
      ),
      dailyTrend: _trend(json['dailyTrend']),
      weeklyTrend: _trend(json['weeklyTrend']),
      monthlyTrend: _trend(json['monthlyTrend']),
      hourlySales: readMapList(json['hourlySales'])
          .map(
            (Map<String, dynamic> item) => HourlySalesBucket(
              label: readString(item['label']),
              sales: readDouble(item['sales']),
            ),
          )
          .toList(growable: false),
      categorySales: _categoryRows(json['categorySales']),
      branchPerformance: readMapList(json['branchPerformance'])
          .map(
            (Map<String, dynamic> item) => BranchPerformanceRow(
              name: readString(item['name']),
              netSales: readDouble(item['netSales']),
              orders: readInt(item['orders']) ?? 0,
              grossProfit: readDouble(item['grossProfit']),
              margin: readDouble(item['margin']),
            ),
          )
          .toList(growable: false),
      products: readMapList(json['products'])
          .map(
            (Map<String, dynamic> item) => ProductPerformanceRow(
              name: readString(item['name'], fallback: 'Product'),
              category: readString(
                item['category'],
                fallback: 'Uncategorized',
              ),
              quantity: readDouble(item['quantity']),
              grossSales: readDouble(item['grossSales']),
              discounts: readDouble(item['discounts']),
              netSales: readDouble(item['netSales']),
              cogs: readDouble(item['cogs']),
              grossProfit: readDouble(item['grossProfit']),
              margin: readDouble(item['margin']),
            ),
          )
          .toList(growable: false),
      salesBySource: _categoryRows(json['salesBySource'], sourceNames: true),
    );
  }

  SalesProfitabilityMetric _metric(dynamic value) {
    if (value is! Map) {
      return const SalesProfitabilityMetric.unavailable();
    }
    final Map<String, dynamic> map = Map<String, dynamic>.from(value);

    return SalesProfitabilityMetric(
      value: map['value'] == null ? null : readDouble(map['value']),
      previousValue: map['previousValue'] == null
          ? null
          : readDouble(map['previousValue']),
    );
  }

  List<SalesProfitTrendPoint> _trend(dynamic value) => readMapList(value)
      .map(
        (Map<String, dynamic> item) => SalesProfitTrendPoint(
          date: DateTime.tryParse(readString(item['date'])) ?? DateTime.now(),
          netSales: readDouble(item['netSales']),
          grossProfit: readDouble(item['grossProfit']),
        ),
      )
      .toList(growable: false);

  List<CategorySalesRow> _categoryRows(
    dynamic value, {
    bool sourceNames = false,
  }) => readMapList(value)
      .map(
        (Map<String, dynamic> item) => CategorySalesRow(
          name: sourceNames
              ? _sourceLabel(readString(item['name'] ?? item['source']))
              : readString(item['name']),
          netSales: readDouble(item['netSales']),
          percent: readDouble(item['percent']),
        ),
      )
      .toList(growable: false);

  String _sourceLabel(String source) => switch (source) {
    'pos' => 'نقاط البيع',
    'manual_invoice' => 'فواتير يدوية',
    _ => source,
  };
}

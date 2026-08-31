import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../core/network/dio_api_client.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../pos/models/json_helpers.dart';
import '../models/daily_report_data.dart';

class ReportsRepository {
  const ReportsRepository({this.apiClient});

  final DioApiClient? apiClient;

  Future<DailyReportData> getDailyReport({
    DateTime? date,
    int? branchId,
  }) async {
    if (apiClient == null) {
      return DailyReportData.mock();
    }

    final dynamic response = await apiClient!.get(
      'reports/daily',
      queryParameters: <String, dynamic>{
        if (date != null) 'date': DateFormat('yyyy-MM-dd').format(date),
        'branchId': ?branchId,
      },
    );
    return _fromJson(Map<String, dynamic>.from(response as Map));
  }

  DailyReportData _fromJson(Map<String, dynamic> json) {
    final Map<String, dynamic> kpis = Map<String, dynamic>.from(
      json['kpis'] as Map? ?? const <String, dynamic>{},
    );
    final String currency = readString(
      (json['branch'] as Map?)?['currency'],
      fallback: 'SYP',
    );

    return DailyReportData(
      isEmpty: !readBool(json['hasData']),
      reportDate: DateTime.tryParse(readString(json['date'])),
      kpis: <ReportKpiItem>[
        _kpi(
          ReportKpiType.netSales,
          'Net Sales',
          kpis['netSales'],
          currency,
          icon: Icons.trending_up_outlined,
        ),
        _kpi(
          ReportKpiType.grossSales,
          'Gross Sales',
          kpis['grossSales'],
          currency,
        ),
        ReportKpiItem(
          type: ReportKpiType.totalOrders,
          label: 'Total Orders',
          value: '${readInt(kpis['totalOrders']) ?? 0}',
        ),
        _kpi(
          ReportKpiType.averageOrder,
          'Avg Order Value',
          kpis['averageOrder'],
          currency,
        ),
        _kpi(
          ReportKpiType.discounts,
          'Discounts',
          kpis['discounts'],
          currency,
          negative: true,
          valueColor: const Color(0xFFD97706),
        ),
        _kpi(ReportKpiType.tax, 'Tax Collected', kpis['tax'], currency),
        _kpi(
          ReportKpiType.refunds,
          'Refunds',
          kpis['refunds'],
          currency,
          negative: true,
          valueColor: const Color(0xFFBA1A1A),
        ),
        _kpi(
          ReportKpiType.expectedCash,
          'Expected Cash',
          kpis['expectedCash'],
          currency,
          icon: Icons.point_of_sale_outlined,
        ),
      ],
      hourlySales: readMapList(json['hourlySales'])
          .map(
            (Map<String, dynamic> item) => HourlySalesPoint(
              label: readString(item['label']),
              value: readDouble(item['value']),
              isPeak: readBool(item['isPeak']),
            ),
          )
          .toList(growable: false),
      paymentMethods: readMapList(json['paymentMethods'])
          .map(
            (Map<String, dynamic> item) => PaymentMethodReportItem(
              type: _paymentType(readString(item['method'])),
              label: _paymentLabel(readString(item['method'])),
              percent: readInt(item['percent']) ?? 0,
              value: _money(readDouble(item['amount']), currency),
              color: _paymentColor(readString(item['method'])),
            ),
          )
          .toList(growable: false),
      orderTypes: readMapList(json['orderTypes'])
          .map(
            (Map<String, dynamic> item) => OrderTypeReportItem(
              type: _orderType(readString(item['type'])),
              label: _orderLabel(readString(item['type'])),
              count: readInt(item['count']) ?? 0,
              value: _money(readDouble(item['amount']), currency),
              icon: _orderIcon(readString(item['type'])),
            ),
          )
          .toList(growable: false),
      topProducts: readMapList(json['topProducts'])
          .map(
            (Map<String, dynamic> item) => TopSellingProductItem(
              name: readString(item['name'], fallback: 'Product'),
              category: readString(item['category'], fallback: 'Uncategorized'),
              quantitySold: readDouble(item['quantity']).round(),
              revenueDisplay: _money(readDouble(item['revenue']), currency),
              trend: ProductTrend.neutral,
            ),
          )
          .toList(growable: false),
      refunds: readMapList(json['refunds'])
          .map(
            (Map<String, dynamic> item) => RefundReportItem(
              orderNumber: '#${readString(item['orderNumber'])}',
              reason: readString(item['reason'], fallback: 'Refund'),
              details:
                  '${_time(item['refundedAt'])} • ${readString(item['customer'], fallback: 'Walk-in')}',
              value: '-${_money(readDouble(item['amount']), currency)}',
            ),
          )
          .toList(growable: false),
      discounts: readMapList(json['discounts'])
          .map(
            (Map<String, dynamic> item) => DiscountUsageReportItem(
              name: readString(item['name'], fallback: 'Discount'),
              type: _discountType(readString(item['type'])),
              usageCount: readInt(item['usageCount']) ?? 0,
              totalValueDisplay:
                  '-${_money(readDouble(item['totalValue']), currency)}',
              revenueAfterDisplay: _money(
                readDouble(item['revenueAfter']),
                currency,
              ),
            ),
          )
          .toList(growable: false),
      transactions: readMapList(json['transactions'])
          .map(
            (Map<String, dynamic> item) => RecentTransactionReportItem(
              orderNumber: '#${readString(item['orderNumber'])}',
              time: _time(item['closedAt']),
              customer: readString(item['customer'], fallback: 'Walk-in'),
              orderType: _orderLabel(readString(item['orderType'])),
              payment: _paymentLabel(readString(item['payment'])),
              subtotal: _money(readDouble(item['subtotal']), currency),
              discount: '-${_money(readDouble(item['discount']), currency)}',
              tax: _money(readDouble(item['tax']), currency),
              total: _money(readDouble(item['total']), currency),
              status: readString(item['status']).contains('refunded')
                  ? TransactionReportStatus.refunded
                  : TransactionReportStatus.paid,
            ),
          )
          .toList(growable: false),
    );
  }

  ReportKpiItem _kpi(
    ReportKpiType type,
    String label,
    dynamic amount,
    String currency, {
    IconData? icon,
    bool negative = false,
    Color? valueColor,
  }) => ReportKpiItem(
    type: type,
    label: label,
    value: '${negative ? '-' : ''}${_money(readDouble(amount), currency)}',
    icon: icon,
    valueColor: valueColor,
  );

  String _money(double value, String currency) =>
      CurrencyFormatter.format(value, currencyCode: currency);

  String _time(dynamic value) {
    final DateTime? date = DateTime.tryParse(readString(value));
    return date == null ? '—' : DateFormat.jm().format(date.toLocal());
  }

  PaymentMethodType _paymentType(String value) => switch (value) {
    'cash' => PaymentMethodType.cash,
    'wallet' => PaymentMethodType.digitalWallet,
    'split' => PaymentMethodType.split,
    _ => PaymentMethodType.card,
  };
  String _paymentLabel(String value) => switch (value) {
    'cash' => 'Cash',
    'wallet' => 'Digital Wallet',
    'split' => 'Split',
    'card' => 'Card',
    _ => value.isEmpty ? 'Unknown' : value,
  };
  Color _paymentColor(String value) => switch (value) {
    'cash' => const Color(0xFF805437),
    'wallet' => const Color(0xFFF0B68D),
    'split' => const Color(0xFFE7E2DA),
    _ => const Color(0xFF3B2417),
  };
  ReportOrderType _orderType(String value) => switch (value) {
    'takeaway' => ReportOrderType.takeaway,
    'delivery' => ReportOrderType.delivery,
    _ => ReportOrderType.dineIn,
  };
  String _orderLabel(String value) => switch (value) {
    'dine_in' => 'DINE-IN',
    'takeaway' => 'TAKEAWAY',
    'delivery' => 'DELIVERY',
    _ => value.isEmpty ? '—' : value,
  };
  IconData _orderIcon(String value) => switch (value) {
    'takeaway' => Icons.shopping_bag_outlined,
    'delivery' => Icons.delivery_dining_outlined,
    _ => Icons.table_restaurant_outlined,
  };
  String _discountType(String value) => switch (value) {
    'percentage' => 'Percentage',
    'fixed' => 'Fixed Amount',
    _ => value,
  };
}

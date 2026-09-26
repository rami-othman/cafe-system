import '../../pos/models/json_helpers.dart';

class SalesProfitability {
  const SalesProfitability({
    required this.netRevenue,
    required this.netCogs,
    required this.grossProfit,
    this.grossMarginPercent,
  });
  final String netRevenue;
  final String netCogs;
  final String grossProfit;
  final String? grossMarginPercent;

  factory SalesProfitability.fromJson(Map<String, dynamic> json) =>
      SalesProfitability(
        netRevenue: readString(json['netRevenue']),
        netCogs: readString(json['netCogs']),
        grossProfit: readString(json['grossProfit']),
        grossMarginPercent: json['grossMarginPercent']?.toString(),
      );
}

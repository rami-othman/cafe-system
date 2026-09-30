import '../../pos/models/json_helpers.dart';

class DiscountDashboardMetrics {
  const DiscountDashboardMetrics({required this.actualSavedValueThisMonth});

  final double actualSavedValueThisMonth;

  factory DiscountDashboardMetrics.fromJson(Map<String, dynamic> json) {
    return DiscountDashboardMetrics(
      actualSavedValueThisMonth: readDouble(json['actualSavedValueThisMonth']),
    );
  }
}

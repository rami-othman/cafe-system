enum OrderSummaryType { dineIn, takeaway, delivery }

extension OrderSummaryTypeLabel on OrderSummaryType {
  String get label {
    return switch (this) {
      OrderSummaryType.dineIn => 'Dine-in',
      OrderSummaryType.takeaway => 'Takeaway',
      OrderSummaryType.delivery => 'Delivery',
    };
  }
}

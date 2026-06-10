enum OrderType { dineIn, takeaway, delivery }

extension OrderTypeLabel on OrderType {
  String get label {
    return switch (this) {
      OrderType.dineIn => 'DINE-IN',
      OrderType.takeaway => 'TAKEAWAY',
      OrderType.delivery => 'DELIVERY',
    };
  }
}

enum OrderType { dineIn, takeaway, delivery }

extension OrderTypeLabel on OrderType {
  String get label {
    return switch (this) {
      OrderType.dineIn => 'DINE-IN',
      OrderType.takeaway => 'TAKEAWAY',
      OrderType.delivery => 'DELIVERY',
    };
  }

  String get apiValue {
    return switch (this) {
      OrderType.dineIn => 'dine_in',
      OrderType.takeaway => 'takeaway',
      OrderType.delivery => 'delivery',
    };
  }
}

OrderType orderTypeFromApi(String value) {
  return switch (value) {
    'takeaway' => OrderType.takeaway,
    'delivery' => OrderType.delivery,
    _ => OrderType.dineIn,
  };
}

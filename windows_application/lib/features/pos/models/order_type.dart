enum OrderType { dineIn, takeaway, delivery }

extension OrderTypeApiValue on OrderType {
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

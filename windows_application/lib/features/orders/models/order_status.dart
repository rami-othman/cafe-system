enum OrderStatus {
  preparing,
  held,
  ready,
  paid,
  completed,
  cancelled,
  refunded,
  partiallyRefunded,
}

extension OrderStatusLabel on OrderStatus {
  String get label {
    return switch (this) {
      OrderStatus.preparing => 'PREPARING',
      OrderStatus.held => 'HELD',
      OrderStatus.ready => 'READY',
      OrderStatus.paid => 'PAID',
      OrderStatus.completed => 'COMPLETED',
      OrderStatus.cancelled => 'CANCELLED',
      OrderStatus.refunded => 'REFUNDED',
      OrderStatus.partiallyRefunded => 'PARTIAL REFUND',
    };
  }
}

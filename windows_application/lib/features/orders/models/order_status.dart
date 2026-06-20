enum OrderStatus { preparing, held, ready, completed, cancelled }

extension OrderStatusLabel on OrderStatus {
  String get label {
    return switch (this) {
      OrderStatus.preparing => 'PREPARING',
      OrderStatus.held => 'HELD',
      OrderStatus.ready => 'READY',
      OrderStatus.completed => 'COMPLETED',
      OrderStatus.cancelled => 'CANCELLED',
    };
  }
}

import '../models/order_detail.dart';
import '../models/order_payment_summary.dart';
import '../models/order_status.dart';
import '../models/order_summary.dart';
import '../models/order_summary_item.dart';
import '../models/order_timeline_event.dart';
import '../models/order_type.dart';

class OrdersRepository {
  const OrdersRepository();

  List<OrderSummary> getOrders() {
    return const <OrderSummary>[
      OrderSummary(
        id: 'ORD-1042',
        type: OrderSummaryType.dineIn,
        customerName: 'Sarah Jenkins',
        status: OrderStatus.preparing,
        itemCount: 3,
        timeAgo: '8m ago',
        items: <OrderSummaryItem>[
          OrderSummaryItem(quantity: 2, name: 'Oat Flat White', total: 11),
          OrderSummaryItem(quantity: 1, name: 'Almond Croissant', total: 5.50),
        ],
        total: 16.50,
      ),
      OrderSummary(
        id: 'ORD-1043',
        type: OrderSummaryType.takeaway,
        customerName: 'Walk-in 4',
        status: OrderStatus.held,
        itemCount: 1,
        timeAgo: '12m ago',
        items: <OrderSummaryItem>[
          OrderSummaryItem(quantity: 1, name: 'Batch Brew', total: 4),
        ],
        total: 4,
      ),
      OrderSummary(
        id: 'ORD-1041',
        type: OrderSummaryType.takeaway,
        customerName: 'Marcus T.',
        status: OrderStatus.ready,
        itemCount: 4,
        timeAgo: '21m ago',
        items: <OrderSummaryItem>[
          OrderSummaryItem(quantity: 2, name: 'Iced Latte', total: 12),
          OrderSummaryItem(
            quantity: 2,
            name: 'Ham & Cheese Toastie',
            total: 18,
          ),
        ],
        total: 30,
      ),
      OrderSummary(
        id: 'ORD-1044',
        type: OrderSummaryType.dineIn,
        customerName: 'Table 12',
        status: OrderStatus.preparing,
        itemCount: 5,
        timeAgo: '5m ago',
        items: <OrderSummaryItem>[
          OrderSummaryItem(quantity: 3, name: 'Cortado', total: 13.50),
          OrderSummaryItem(quantity: 2, name: 'Avo Toast', total: 28),
        ],
        total: 41.50,
      ),
    ];
  }

  Future<OrderDetail> getOrderDetail(String orderId) async {
    final OrderSummary summary = getOrders().firstWhere(
      (OrderSummary order) => order.id == orderId,
      orElse: () => throw StateError('Order not found.'),
    );

    final List<OrderDetailItem> items = switch (orderId) {
      'ORD-1042' => const <OrderDetailItem>[
        OrderDetailItem(
          quantity: 2,
          name: 'Oat Flat White',
          modifiers: <String>['Size: Large (+\$0.50)', 'Milk: Oat Milk'],
          total: 11,
        ),
        OrderDetailItem(
          quantity: 1,
          name: 'Almond Croissant',
          modifiers: <String>['Warmed', 'Butter on side'],
          total: 5.50,
        ),
      ],
      'ORD-1043' => const <OrderDetailItem>[
        OrderDetailItem(
          quantity: 1,
          name: 'Batch Brew',
          modifiers: <String>['Medium roast', 'No room'],
          total: 4,
        ),
      ],
      'ORD-1041' => const <OrderDetailItem>[
        OrderDetailItem(
          quantity: 2,
          name: 'Iced Latte',
          modifiers: <String>['Size: Large (+\$0.50)', 'Vanilla (+\$0.75)'],
          total: 12,
        ),
        OrderDetailItem(
          quantity: 2,
          name: 'Ham & Cheese Toastie',
          modifiers: <String>['Extra toasted', 'Dijon on side'],
          total: 18,
        ),
      ],
      'ORD-1044' => const <OrderDetailItem>[
        OrderDetailItem(
          quantity: 3,
          name: 'Cortado',
          modifiers: <String>['Ceramic cup', 'Extra hot'],
          total: 13.50,
        ),
        OrderDetailItem(
          quantity: 2,
          name: 'Avo Toast',
          modifiers: <String>['Add Poached Egg (+\$1.50)', 'Chili Flakes'],
          total: 28,
        ),
      ],
      _ =>
        summary.items
            .map(
              (OrderSummaryItem item) => OrderDetailItem(
                quantity: item.quantity,
                name: item.name,
                modifiers: const <String>[],
                total: item.total,
              ),
            )
            .toList(growable: false),
    };

    final double subtotal = items.fold<double>(
      0,
      (double total, OrderDetailItem item) => total + item.total,
    );
    final double tax = _roundCurrency(subtotal * 0.085);
    final double tip = _roundCurrency(subtotal * 0.15);
    final double total = _roundCurrency(subtotal + tax + tip);
    final DateTime createdAt = DateTime(2023, 10, 24, 10, 42);

    return OrderDetail(
      id: summary.id,
      displayNumber: '#${summary.id}',
      status: summary.status,
      orderType: summary.type.label,
      createdAt: createdAt,
      customerName: _customerNameFor(summary),
      customerPhone: _customerPhoneFor(summary),
      customerEmail: _customerEmailFor(summary),
      items: items,
      subtotal: subtotal,
      tax: tax,
      tip: tip,
      total: total,
      payment: OrderPaymentSummary(
        methodLabel: 'Visa ending in 4242',
        statusLabel: summary.status == OrderStatus.held
            ? 'Pending'
            : 'Approved',
        authCode: summary.status == OrderStatus.held ? '-' : '098765',
        amount: total,
      ),
      timeline: _timelineFor(createdAt, summary.status),
    );
  }

  double _roundCurrency(double value) {
    return (value * 100).roundToDouble() / 100;
  }

  String _customerNameFor(OrderSummary order) {
    if (order.customerName.startsWith('Walk-in') ||
        order.customerName.startsWith('Table')) {
      return '';
    }

    return order.customerName;
  }

  String _customerPhoneFor(OrderSummary order) {
    return switch (order.id) {
      'ORD-1041' => '(555) 222-0141',
      'ORD-1042' => '(555) 123-4567',
      _ => '',
    };
  }

  String _customerEmailFor(OrderSummary order) {
    return switch (order.id) {
      'ORD-1041' => 'marcus@example.com',
      'ORD-1042' => 'sarah@example.com',
      _ => '',
    };
  }

  List<OrderTimelineEvent> _timelineFor(
    DateTime createdAt,
    OrderStatus status,
  ) {
    final List<OrderTimelineEvent> events = <OrderTimelineEvent>[
      OrderTimelineEvent(
        title: 'Order Created',
        subtitle: 'POS Register 2',
        time: createdAt,
      ),
      OrderTimelineEvent(
        title: 'Payment Received',
        subtitle: 'Terminal 1',
        time: createdAt.add(const Duration(minutes: 3)),
      ),
    ];

    if (status == OrderStatus.completed || status == OrderStatus.ready) {
      events.insert(
        0,
        OrderTimelineEvent(
          title: status == OrderStatus.completed
              ? 'Order Completed'
              : 'Order Ready',
          subtitle: 'Verified by Barista Sarah',
          time: createdAt.add(const Duration(minutes: 6)),
        ),
      );
    } else if (status == OrderStatus.held) {
      events.insert(
        0,
        OrderTimelineEvent(
          title: 'Order Held',
          subtitle: 'Waiting for customer confirmation',
          time: createdAt.add(const Duration(minutes: 4)),
        ),
      );
    } else {
      events.insert(
        0,
        OrderTimelineEvent(
          title: 'Order Preparing',
          subtitle: 'Kitchen display station',
          time: createdAt.add(const Duration(minutes: 4)),
        ),
      );
    }

    return events;
  }
}

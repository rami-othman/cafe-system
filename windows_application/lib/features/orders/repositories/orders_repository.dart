import '../models/order_status.dart';
import '../models/order_summary.dart';
import '../models/order_summary_item.dart';
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
}

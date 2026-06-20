import 'package:flutter_test/flutter_test.dart';
import 'package:windows_application/features/orders/controllers/orders_cubit.dart';
import 'package:windows_application/features/orders/controllers/orders_state.dart';
import 'package:windows_application/features/orders/models/order_status.dart';
import 'package:windows_application/features/orders/models/order_type.dart';
import 'package:windows_application/features/orders/repositories/orders_repository.dart';

void main() {
  late OrdersCubit cubit;

  setUp(() {
    cubit = OrdersCubit(repository: const OrdersRepository());
  });

  tearDown(() {
    cubit.close();
  });

  test('loads fake orders with active orders selected by default', () async {
    await cubit.loadOrders();

    expect(cubit.state.orders, hasLength(4));
    expect(cubit.state.selectedFilter, OrdersFilter.activeOrders);
    expect(cubit.state.filteredOrders.map((order) => order.id), <String>[
      'ORD-1042',
      'ORD-1041',
      'ORD-1044',
    ]);
  });

  test('filters held, dine-in, and takeaway orders', () async {
    await cubit.loadOrders();

    cubit.selectFilter(OrdersFilter.heldOrders);
    expect(cubit.state.filteredOrders.map((order) => order.id), <String>[
      'ORD-1043',
    ]);

    cubit.selectFilter(OrdersFilter.dineIn);
    expect(
      cubit.state.filteredOrders.every((order) {
        return order.type == OrderSummaryType.dineIn;
      }),
      isTrue,
    );

    cubit.selectFilter(OrdersFilter.takeaway);
    expect(
      cubit.state.filteredOrders.every((order) {
        return order.type == OrderSummaryType.takeaway;
      }),
      isTrue,
    );
  });

  test('cancel and complete update order status locally', () async {
    await cubit.loadOrders();

    cubit.cancelOrder('ORD-1043');
    expect(
      cubit.state.orders.singleWhere((order) => order.id == 'ORD-1043').status,
      OrderStatus.cancelled,
    );

    cubit.completeOrder('ORD-1041');
    expect(
      cubit.state.orders.singleWhere((order) => order.id == 'ORD-1041').status,
      OrderStatus.completed,
    );
  });
}

import 'package:flutter_test/flutter_test.dart';
import 'package:windows_application/features/orders/controllers/orders_cubit.dart';
import 'package:windows_application/features/orders/controllers/orders_state.dart';
import 'package:windows_application/features/orders/models/order_status.dart';
import 'package:windows_application/features/orders/models/order_type.dart';
import 'package:windows_application/features/orders/models/refund_result.dart';
import 'package:windows_application/features/orders/models/refund_type.dart';
import 'package:windows_application/features/orders/repositories/orders_repository.dart';

void main() {
  late OrdersCubit cubit;

  setUp(() {
    cubit = OrdersCubit(repository: const OrdersRepository());
  });

  tearDown(() {
    cubit.close();
  });

  test(
    'loads active fake orders with active orders selected by default',
    () async {
      await cubit.loadOrders();

      expect(cubit.state.orders, hasLength(3));
      expect(cubit.state.selectedFilter, OrdersFilter.activeOrders);
      expect(cubit.state.filteredOrders.map((order) => order.id), <String>[
        '1042',
        '1041',
        '1044',
      ]);
    },
  );

  test('filters held, dine-in, and takeaway orders', () async {
    await cubit.loadOrders();

    await cubit.selectFilter(OrdersFilter.heldOrders);
    expect(cubit.state.filteredOrders.map((order) => order.id), <String>[
      '1043',
    ]);

    await cubit.selectFilter(OrdersFilter.dineIn);
    expect(
      cubit.state.filteredOrders.every((order) {
        return order.type == OrderSummaryType.dineIn;
      }),
      isTrue,
    );

    await cubit.selectFilter(OrdersFilter.takeaway);
    expect(
      cubit.state.filteredOrders.every((order) {
        return order.type == OrderSummaryType.takeaway;
      }),
      isTrue,
    );
  });

  test('cancel and complete update order status locally', () async {
    await cubit.loadOrders();

    await cubit.selectFilter(OrdersFilter.heldOrders);
    cubit.cancelOrder('1043');
    expect(
      cubit.state.orders.singleWhere((order) => order.id == '1043').status,
      OrderStatus.cancelled,
    );

    await cubit.selectFilter(OrdersFilter.activeOrders);
    cubit.completeOrder('1041');
    expect(
      cubit.state.orders.singleWhere((order) => order.id == '1041').status,
      OrderStatus.completed,
    );
  });

  test('repository returns fake detail data for an order', () async {
    final detail = await const OrdersRepository().getOrderDetail(1042);

    expect(detail.id, '1042');
    expect(detail.displayNumber, '#ORD-1042');
    expect(detail.customerName, 'Sarah Jenkins');
    expect(detail.items, isNotEmpty);
    expect(detail.payment.methodLabel, contains('Visa'));
    expect(detail.timeline, isNotEmpty);
  });

  test('opens and closes selected order details', () async {
    await cubit.loadOrders();

    await cubit.openOrderDetails('1042');

    expect(cubit.state.selectedOrderDetail?.id, '1042');
    expect(cubit.state.isDetailsLoading, isFalse);
    expect(cubit.state.detailsErrorMessage, isNull);

    cubit.closeOrderDetails();

    expect(cubit.state.selectedOrderDetail, isNull);
  });

  test('confirm refund updates selected order detail locally', () async {
    await cubit.loadOrders();
    await cubit.openOrderDetails('1042');

    final double total = cubit.state.selectedOrderDetail!.total;

    cubit.confirmRefund(
      RefundResult(
        orderId: '1042',
        type: RefundType.full,
        amount: total,
        reason: 'Customer Request',
        managerNotes: 'Approved by manager.',
        refundedAt: DateTime(2026, 6, 20, 10, 30),
      ),
    );

    final detail = cubit.state.selectedOrderDetail!;
    expect(detail.status, OrderStatus.refunded);
    expect(detail.isRefunded, isTrue);
    expect(detail.refundedAmount, total);
    expect(detail.refundedAt, DateTime(2026, 6, 20, 10, 30));
  });

  test('confirm partial refund keeps order open with partial marker', () async {
    await cubit.loadOrders();
    await cubit.openOrderDetails('1042');

    cubit.confirmRefund(
      RefundResult(
        orderId: '1042',
        type: RefundType.partial,
        amount: 5,
        reason: 'Item Quality Issue',
        managerNotes: '',
        refundedAt: DateTime(2026, 6, 20, 11),
      ),
    );

    final detail = cubit.state.selectedOrderDetail!;
    expect(detail.status, OrderStatus.partiallyRefunded);
    expect(detail.isRefunded, isFalse);
    expect(detail.refundedAmount, 5);
  });
}

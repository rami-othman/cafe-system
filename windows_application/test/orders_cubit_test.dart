import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:windows_application/core/network/api_exception.dart';
import 'package:windows_application/features/pos/models/branch.dart';
import 'package:windows_application/features/orders/controllers/orders_cubit.dart';
import 'package:windows_application/features/orders/controllers/orders_state.dart';
import 'package:windows_application/features/orders/models/order_detail.dart';
import 'package:windows_application/features/orders/models/order_payment_summary.dart';
import 'package:windows_application/features/orders/models/order_status.dart';
import 'package:windows_application/features/orders/models/order_summary.dart';
import 'package:windows_application/features/orders/models/order_summary_item.dart';
import 'package:windows_application/features/orders/models/order_timeline_event.dart';
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
      expect(cubit.state.selectedBranchId, 1);
      expect(cubit.state.branches.single.name, 'Downtown');
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

  test(
    'ignores an older list response after the selected filter changes',
    () async {
      final _ControlledOrdersRepository repository =
          _ControlledOrdersRepository();
      cubit = OrdersCubit(repository: repository);

      final Future<void> activeLoad = cubit.loadOrders();
      await _drainMicrotasks();
      final Future<void> heldLoad = cubit.selectFilter(OrdersFilter.heldOrders);
      await _drainMicrotasks();

      expect(repository.orderRequests, hasLength(2));
      expect(repository.orderRequests[0].filter, OrdersFilter.activeOrders);
      expect(repository.orderRequests[1].filter, OrdersFilter.heldOrders);

      repository.orderRequests[1].complete(<OrderSummary>[_summary('held')]);
      await heldLoad;
      expect(cubit.state.orders.single.id, 'held');

      repository.orderRequests[0].complete(<OrderSummary>[_summary('active')]);
      await activeLoad;

      expect(cubit.state.selectedFilter, OrdersFilter.heldOrders);
      expect(cubit.state.orders.single.id, 'held');
      expect(cubit.state.isLoading, isFalse);
    },
  );

  test(
    'does not reopen the panel when an older detail response arrives',
    () async {
      final _ControlledOrdersRepository repository =
          _ControlledOrdersRepository();
      cubit = OrdersCubit(repository: repository);

      final Future<void> firstDetail = cubit.openOrderDetails('1');
      await _drainMicrotasks();
      final Future<void> secondDetail = cubit.openOrderDetails('2');
      await _drainMicrotasks();

      repository.detailRequests[1].complete(_detail('2'));
      await secondDetail;
      expect(cubit.state.selectedOrderDetail?.id, '2');

      repository.detailRequests[0].complete(_detail('1'));
      await firstDetail;
      expect(cubit.state.selectedOrderDetail?.id, '2');

      final Future<void> closingDetail = cubit.openOrderDetails('3');
      await _drainMicrotasks();
      cubit.closeOrderDetails();
      repository.detailRequests[2].complete(_detail('3'));
      await closingDetail;
      expect(cubit.state.selectedOrderDetail, isNull);
      expect(cubit.state.isDetailsLoading, isFalse);
    },
  );

  test('keeps actionable API messages for list and detail failures', () async {
    final _ControlledOrdersRepository repository =
        _ControlledOrdersRepository();
    cubit = OrdersCubit(repository: repository);

    final Future<void> listLoad = cubit.loadOrders();
    await _drainMicrotasks();
    repository.orderRequests.single.fail(
      const ApiException(message: 'Backend is not reachable.'),
    );
    await listLoad;
    expect(cubit.state.errorMessage, 'Backend is not reachable.');

    final Future<void> detailLoad = cubit.openOrderDetails('1');
    await _drainMicrotasks();
    repository.detailRequests.single.fail(
      const ApiException(message: 'Order access is not allowed.'),
    );
    await detailLoad;
    expect(cubit.state.detailsErrorMessage, 'Order access is not allowed.');
  });
}

Future<void> _drainMicrotasks() => Future<void>.delayed(Duration.zero);

class _ControlledOrdersRepository extends OrdersRepository {
  _ControlledOrdersRepository();

  final List<_OrderRequest> orderRequests = <_OrderRequest>[];
  final List<_DetailRequest> detailRequests = <_DetailRequest>[];

  @override
  Future<List<Branch>> getBranches() async => const <Branch>[
    Branch(
      id: 1,
      name: 'Downtown',
      currency: 'SYP',
      timezone: 'Asia/Damascus',
      isActive: true,
    ),
  ];

  @override
  Future<List<OrderSummary>> getOrders({
    required int branchId,
    OrdersFilter? filter,
  }) {
    final _OrderRequest request = _OrderRequest(filter);
    orderRequests.add(request);
    return request.completer.future;
  }

  @override
  Future<OrderDetail> getOrderDetail(int orderId) {
    final _DetailRequest request = _DetailRequest();
    detailRequests.add(request);
    return request.completer.future;
  }
}

class _OrderRequest {
  _OrderRequest(this.filter);

  final OrdersFilter? filter;
  final Completer<List<OrderSummary>> completer =
      Completer<List<OrderSummary>>();

  void complete(List<OrderSummary> orders) => completer.complete(orders);
  void fail(Object error) => completer.completeError(error);
}

class _DetailRequest {
  final Completer<OrderDetail> completer = Completer<OrderDetail>();

  void complete(OrderDetail detail) => completer.complete(detail);
  void fail(Object error) => completer.completeError(error);
}

OrderSummary _summary(String id) {
  return OrderSummary(
    id: id,
    type: OrderSummaryType.takeaway,
    customerName: 'Walk-in',
    status: OrderStatus.preparing,
    itemCount: 1,
    timeAgo: 'Just now',
    items: const <OrderSummaryItem>[],
    total: 4,
  );
}

OrderDetail _detail(String id) {
  return OrderDetail(
    id: id,
    displayNumber: '#$id',
    status: OrderStatus.preparing,
    orderType: 'Takeaway',
    createdAt: DateTime(2026),
    customerName: 'Walk-in',
    customerPhone: '',
    customerEmail: '',
    items: const <OrderDetailItem>[],
    subtotal: 4,
    tax: 0,
    tip: 0,
    total: 4,
    payment: const OrderPaymentSummary(
      methodLabel: 'Cash',
      statusLabel: 'Completed',
      authCode: '1',
      amount: 4,
    ),
    timeline: const <OrderTimelineEvent>[],
  );
}

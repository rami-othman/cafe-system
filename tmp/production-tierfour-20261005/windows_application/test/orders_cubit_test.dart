import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:windows_application/core/network/api_exception.dart';
import 'package:windows_application/features/pos/models/branch.dart';
import 'package:windows_application/features/orders/controllers/orders_cubit.dart';
import 'package:windows_application/features/orders/controllers/orders_state.dart';
import 'package:windows_application/features/orders/models/order_detail.dart';
import 'package:windows_application/features/orders/models/order_page.dart';
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

  test('initial load requests page one with the bounded page size', () async {
    final _ControlledOrdersRepository repository =
        _ControlledOrdersRepository();
    cubit = OrdersCubit(repository: repository);

    final Future<void> load = cubit.loadOrders();
    await _drainMicrotasks();

    expect(repository.orderRequests.single.page, 1);
    expect(repository.orderRequests.single.perPage, 25);
    repository.orderRequests.single.completePage(
      const OrderPage(
        orders: <OrderSummary>[],
        currentPage: 1,
        lastPage: 3,
        perPage: 25,
        total: 51,
      ),
    );
    await load;

    expect(cubit.state.currentPage, 1);
    expect(cubit.state.lastPage, 3);
    expect(cubit.state.total, 51);
  });

  test(
    'coalesces identical initial loads while branches are loading',
    () async {
      final _ControlledOrdersRepository repository =
          _ControlledOrdersRepository();
      cubit = OrdersCubit(repository: repository);

      final Future<void> first = cubit.loadOrders();
      final Future<void> duplicate = cubit.loadOrders();
      await _drainMicrotasks();

      expect(repository.branchLoadCount, 1);
      expect(repository.orderRequests, hasLength(1));

      repository.orderRequests.single.completePage(
        const OrderPage(
          orders: <OrderSummary>[],
          currentPage: 1,
          lastPage: 1,
          perPage: 25,
          total: 0,
        ),
      );
      await first;
      await duplicate;
    },
  );

  test(
    'an older completed request cannot clear newer in-flight ownership',
    () async {
      final _ControlledOrdersRepository repository =
          _ControlledOrdersRepository();
      cubit = OrdersCubit(repository: repository);

      final Future<void> older = cubit.loadOrders();
      await _drainMicrotasks();
      final Future<void> newer = cubit.selectFilter(OrdersFilter.heldOrders);
      await _drainMicrotasks();
      expect(repository.orderRequests, hasLength(2));

      repository.orderRequests[0].complete(<OrderSummary>[_summary('old')]);
      await older;

      final Future<void> duplicate = cubit.loadOrders(
        filter: OrdersFilter.heldOrders,
        page: 1,
      );
      await _drainMicrotasks();
      expect(repository.orderRequests, hasLength(2));

      repository.orderRequests[1].completePage(
        const OrderPage(
          orders: <OrderSummary>[],
          currentPage: 1,
          lastPage: 1,
          perPage: 25,
          total: 0,
        ),
      );
      await newer;
      await duplicate;
    },
  );

  test(
    'an older failed request cannot clear newer in-flight ownership',
    () async {
      final _ControlledOrdersRepository repository =
          _ControlledOrdersRepository();
      cubit = OrdersCubit(repository: repository);

      final Future<void> older = cubit.loadOrders();
      await _drainMicrotasks();
      final Future<void> newer = cubit.selectFilter(OrdersFilter.heldOrders);
      await _drainMicrotasks();
      expect(repository.orderRequests, hasLength(2));

      repository.orderRequests[0].fail(
        const ApiException(message: 'Older request failed.'),
      );
      await older;

      final Future<void> duplicate = cubit.loadOrders(
        filter: OrdersFilter.heldOrders,
        page: 1,
      );
      await _drainMicrotasks();
      expect(repository.orderRequests, hasLength(2));

      repository.orderRequests[1].completePage(
        const OrderPage(
          orders: <OrderSummary>[],
          currentPage: 1,
          lastPage: 1,
          perPage: 25,
          total: 0,
        ),
      );
      await newer;
      await duplicate;
    },
  );

  test('filter and branch changes reset pagination to page one', () async {
    final _ControlledOrdersRepository repository =
        _ControlledOrdersRepository();
    cubit = OrdersCubit(repository: repository);

    final Future<void> initial = cubit.loadOrders();
    await _drainMicrotasks();
    repository.orderRequests.single.completePage(
      const OrderPage(
        orders: <OrderSummary>[],
        currentPage: 2,
        lastPage: 3,
        perPage: 25,
        total: 60,
      ),
    );
    await initial;

    final Future<void> filtered = cubit.selectFilter(OrdersFilter.heldOrders);
    await _drainMicrotasks();
    expect(repository.orderRequests[1].page, 1);
    repository.orderRequests[1].complete(<OrderSummary>[]);
    await filtered;

    final Future<void> branched = cubit.applyBranchContext(2);
    await _drainMicrotasks();
    expect(repository.orderRequests[2].branchId, 2);
    expect(repository.orderRequests[2].page, 1);
    repository.orderRequests[2].complete(<OrderSummary>[]);
    await branched;
  });

  test('pagination respects boundaries and coalesces duplicate taps', () async {
    final _ControlledOrdersRepository repository =
        _ControlledOrdersRepository();
    cubit = OrdersCubit(repository: repository);

    final Future<void> initial = cubit.loadOrders();
    await _drainMicrotasks();
    repository.orderRequests.single.completePage(
      OrderPage(
        orders: <OrderSummary>[_summary('page-1')],
        currentPage: 1,
        lastPage: 2,
        perPage: 1,
        total: 2,
      ),
    );
    await initial;

    expect(cubit.state.canGoPrevious, isFalse);
    expect(cubit.state.canGoNext, isTrue);

    final Future<void> next = cubit.nextPage();
    final Future<void> duplicate = cubit.nextPage();
    await _drainMicrotasks();
    expect(repository.orderRequests, hasLength(2));
    expect(repository.orderRequests[1].page, 2);
    expect(cubit.state.isPageLoading, isTrue);
    repository.orderRequests[1].completePage(
      OrderPage(
        orders: <OrderSummary>[_summary('page-2')],
        currentPage: 2,
        lastPage: 2,
        perPage: 1,
        total: 2,
      ),
    );
    await next;
    await duplicate;

    expect(cubit.state.canGoNext, isFalse);
    expect(cubit.state.canGoPrevious, isTrue);
    await cubit.nextPage();
    expect(repository.orderRequests, hasLength(2));

    final Future<void> previous = cubit.previousPage();
    await _drainMicrotasks();
    expect(repository.orderRequests[2].page, 1);
    repository.orderRequests[2].completePage(
      OrderPage(
        orders: <OrderSummary>[_summary('page-1')],
        currentPage: 1,
        lastPage: 2,
        perPage: 1,
        total: 2,
      ),
    );
    await previous;
  });

  test(
    'page failure preserves rendered orders and exposes retry state',
    () async {
      final _ControlledOrdersRepository repository =
          _ControlledOrdersRepository();
      cubit = OrdersCubit(repository: repository);

      final Future<void> initial = cubit.loadOrders();
      await _drainMicrotasks();
      repository.orderRequests.single.completePage(
        OrderPage(
          orders: <OrderSummary>[_summary('existing')],
          currentPage: 1,
          lastPage: 2,
          perPage: 1,
          total: 2,
        ),
      );
      await initial;

      final Future<void> next = cubit.nextPage();
      await _drainMicrotasks();
      repository.orderRequests[1].fail(
        const ApiException(message: 'Page is temporarily unavailable.'),
      );
      await next;

      expect(cubit.state.orders.single.id, 'existing');
      expect(cubit.state.currentPage, 1);
      expect(cubit.state.errorMessage, 'Page is temporarily unavailable.');
    },
  );

  test(
    'refresh preserves the selected branch, filter, and current page',
    () async {
      final _ControlledOrdersRepository repository =
          _ControlledOrdersRepository();
      cubit = OrdersCubit(repository: repository);

      final Future<void> initial = cubit.loadOrders();
      await _drainMicrotasks();
      repository.orderRequests.single.completePage(
        const OrderPage(
          orders: <OrderSummary>[],
          currentPage: 2,
          lastPage: 2,
          perPage: 25,
          total: 30,
        ),
      );
      await initial;
      final Future<void> filter = cubit.selectFilter(OrdersFilter.takeaway);
      await _drainMicrotasks();
      repository.orderRequests[1].completePage(
        const OrderPage(
          orders: <OrderSummary>[],
          currentPage: 1,
          lastPage: 2,
          perPage: 25,
          total: 30,
        ),
      );
      await filter;

      final Future<void> page = cubit.nextPage();
      await _drainMicrotasks();
      expect(repository.orderRequests[2].page, 2);
      repository.orderRequests[2].completePage(
        const OrderPage(
          orders: <OrderSummary>[],
          currentPage: 2,
          lastPage: 2,
          perPage: 25,
          total: 30,
        ),
      );
      await page;

      final Future<void> refresh = cubit.refreshOrders();
      await _drainMicrotasks();
      expect(repository.orderRequests[3].branchId, 1);
      expect(repository.orderRequests[3].filter, OrdersFilter.takeaway);
      expect(repository.orderRequests[3].page, 2);
      repository.orderRequests[3].completePage(
        const OrderPage(
          orders: <OrderSummary>[],
          currentPage: 2,
          lastPage: 2,
          perPage: 25,
          total: 30,
        ),
      );
      await refresh;
    },
  );

  test(
    'refresh recovers an out-of-range page exactly once with authoritative data',
    () async {
      final _ControlledOrdersRepository repository =
          _ControlledOrdersRepository();
      cubit = OrdersCubit(repository: repository);

      final Future<void> initial = cubit.loadOrders();
      await _drainMicrotasks();
      repository.orderRequests.single.completePage(
        OrderPage(
          orders: <OrderSummary>[_summary('page-1')],
          currentPage: 1,
          lastPage: 2,
          perPage: 1,
          total: 2,
        ),
      );
      await initial;

      final Future<void> page = cubit.nextPage();
      await _drainMicrotasks();
      repository.orderRequests[1].completePage(
        OrderPage(
          orders: <OrderSummary>[_summary('page-2')],
          currentPage: 2,
          lastPage: 2,
          perPage: 1,
          total: 2,
        ),
      );
      await page;

      final Future<void> refresh = cubit.refreshOrders();
      await _drainMicrotasks();
      repository.orderRequests[2].completePage(
        const OrderPage(
          orders: <OrderSummary>[],
          currentPage: 2,
          lastPage: 1,
          perPage: 1,
          total: 1,
        ),
      );
      await _drainMicrotasks();

      expect(repository.orderRequests, hasLength(4));
      expect(repository.orderRequests[3].branchId, 1);
      expect(repository.orderRequests[3].filter, OrdersFilter.activeOrders);
      expect(repository.orderRequests[3].page, 1);
      expect(repository.orderRequests[3].perPage, 1);
      expect(cubit.state.orders.single.id, 'page-2');
      expect(cubit.state.currentPage, 2);
      expect(cubit.state.lastPage, 2);

      final Future<void> duplicateRefresh = cubit.refreshOrders();
      await _drainMicrotasks();
      expect(repository.orderRequests, hasLength(4));

      repository.orderRequests[3].completePage(
        OrderPage(
          orders: <OrderSummary>[_summary('authoritative-page-1')],
          currentPage: 1,
          lastPage: 1,
          perPage: 1,
          total: 1,
        ),
      );
      await refresh;
      await duplicateRefresh;

      expect(cubit.state.orders.single.id, 'authoritative-page-1');
      expect(cubit.state.currentPage, 1);
      expect(cubit.state.lastPage, 1);
      expect(cubit.state.currentPage, lessThanOrEqualTo(cubit.state.lastPage));
    },
  );

  test(
    'correction failure preserves rendered data and exposes retry state',
    () async {
      final _ControlledOrdersRepository repository =
          _ControlledOrdersRepository();
      cubit = OrdersCubit(repository: repository);

      final Future<void> initial = cubit.loadOrders();
      await _drainMicrotasks();
      repository.orderRequests.single.completePage(
        OrderPage(
          orders: <OrderSummary>[_summary('page-2')],
          currentPage: 2,
          lastPage: 2,
          perPage: 1,
          total: 2,
        ),
      );
      await initial;

      final Future<void> refresh = cubit.refreshOrders();
      await _drainMicrotasks();
      repository.orderRequests[1].completePage(
        const OrderPage(
          orders: <OrderSummary>[],
          currentPage: 2,
          lastPage: 1,
          perPage: 1,
          total: 1,
        ),
      );
      await _drainMicrotasks();
      expect(repository.orderRequests, hasLength(3));

      repository.orderRequests[2].fail(
        const ApiException(
          message: 'Page recovery is temporarily unavailable.',
        ),
      );
      await refresh;

      expect(repository.orderRequests, hasLength(3));
      expect(cubit.state.orders.single.id, 'page-2');
      expect(cubit.state.currentPage, 2);
      expect(cubit.state.lastPage, 2);
      expect(
        cubit.state.errorMessage,
        'Page recovery is temporarily unavailable.',
      );
      expect(cubit.state.isPageLoading, isFalse);
      expect(cubit.state.currentPage, lessThanOrEqualTo(cubit.state.lastPage));
    },
  );

  test(
    'a stale page correction cannot overwrite a newer filter result',
    () async {
      final _ControlledOrdersRepository repository =
          _ControlledOrdersRepository();
      cubit = OrdersCubit(repository: repository);

      final Future<void> initial = cubit.loadOrders();
      await _drainMicrotasks();
      repository.orderRequests.single.completePage(
        OrderPage(
          orders: <OrderSummary>[_summary('active-page-2')],
          currentPage: 2,
          lastPage: 2,
          perPage: 1,
          total: 2,
        ),
      );
      await initial;

      final Future<void> refresh = cubit.refreshOrders();
      await _drainMicrotasks();
      repository.orderRequests[1].completePage(
        const OrderPage(
          orders: <OrderSummary>[],
          currentPage: 2,
          lastPage: 1,
          perPage: 1,
          total: 1,
        ),
      );
      await _drainMicrotasks();

      final Future<void> newerFilter = cubit.selectFilter(
        OrdersFilter.heldOrders,
      );
      await _drainMicrotasks();
      expect(repository.orderRequests, hasLength(4));
      repository.orderRequests[3].completePage(
        OrderPage(
          orders: <OrderSummary>[_summary('held-result')],
          currentPage: 1,
          lastPage: 1,
          perPage: 1,
          total: 1,
        ),
      );
      await newerFilter;

      repository.orderRequests[2].completePage(
        OrderPage(
          orders: <OrderSummary>[_summary('stale-correction')],
          currentPage: 1,
          lastPage: 1,
          perPage: 1,
          total: 1,
        ),
      );
      await refresh;

      expect(cubit.state.selectedFilter, OrdersFilter.heldOrders);
      expect(cubit.state.orders.single.id, 'held-result');
      expect(cubit.state.currentPage, 1);
      expect(cubit.state.lastPage, 1);
    },
  );

  test(
    'a stale page correction cannot overwrite a newer branch result',
    () async {
      final _ControlledOrdersRepository repository =
          _ControlledOrdersRepository();
      cubit = OrdersCubit(repository: repository);

      final Future<void> initial = cubit.loadOrders();
      await _drainMicrotasks();
      repository.orderRequests.single.completePage(
        OrderPage(
          orders: <OrderSummary>[_summary('branch-1-page-2')],
          currentPage: 2,
          lastPage: 2,
          perPage: 1,
          total: 2,
        ),
      );
      await initial;

      final Future<void> refresh = cubit.refreshOrders();
      await _drainMicrotasks();
      repository.orderRequests[1].completePage(
        const OrderPage(
          orders: <OrderSummary>[],
          currentPage: 2,
          lastPage: 1,
          perPage: 1,
          total: 1,
        ),
      );
      await _drainMicrotasks();

      final Future<void> newerBranch = cubit.applyBranchContext(2);
      await _drainMicrotasks();
      expect(repository.orderRequests, hasLength(4));
      repository.orderRequests[3].completePage(
        OrderPage(
          orders: <OrderSummary>[_summary('branch-2-result')],
          currentPage: 1,
          lastPage: 1,
          perPage: 1,
          total: 1,
        ),
      );
      await newerBranch;

      repository.orderRequests[2].completePage(
        OrderPage(
          orders: <OrderSummary>[_summary('stale-correction')],
          currentPage: 1,
          lastPage: 1,
          perPage: 1,
          total: 1,
        ),
      );
      await refresh;

      expect(cubit.state.selectedBranchId, 2);
      expect(cubit.state.orders.single.id, 'branch-2-result');
      expect(cubit.state.currentPage, 1);
      expect(cubit.state.lastPage, 1);
    },
  );

  test('does not emit after disposal while an order page is pending', () async {
    final _ControlledOrdersRepository repository =
        _ControlledOrdersRepository();
    cubit = OrdersCubit(repository: repository);

    final Future<void> pending = cubit.loadOrders();
    await _drainMicrotasks();
    await cubit.close();
    repository.orderRequests.single.complete(const <OrderSummary>[]);

    await pending;
  });

  test('lifecycle actions never report local-only success', () async {
    await cubit.loadOrders();

    await cubit.selectFilter(OrdersFilter.heldOrders);
    final OrdersActionOutcome cancelOutcome = await cubit.cancelOrder('1043');
    expect(cancelOutcome, OrdersActionOutcome.retryableFailure);
    expect(
      cubit.state.orders.singleWhere((order) => order.id == '1043').status,
      OrderStatus.held,
    );
    expect(cubit.state.orderActionErrorMessage, isNotNull);
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

  test('ignores an older page response after a newer branch request', () async {
    final _ControlledOrdersRepository repository =
        _ControlledOrdersRepository();
    cubit = OrdersCubit(repository: repository);

    final Future<void> initial = cubit.loadOrders();
    await _drainMicrotasks();
    repository.orderRequests.single.completePage(
      const OrderPage(
        orders: <OrderSummary>[_summaryConst],
        currentPage: 1,
        lastPage: 2,
        perPage: 1,
        total: 2,
      ),
    );
    await initial;

    final Future<void> oldPage = cubit.nextPage();
    await _drainMicrotasks();
    final Future<void> newBranch = cubit.applyBranchContext(2);
    await _drainMicrotasks();

    expect(repository.orderRequests[1].branchId, 1);
    expect(repository.orderRequests[1].page, 2);
    expect(repository.orderRequests[2].branchId, 2);
    expect(repository.orderRequests[2].page, 1);

    repository.orderRequests[2].completePage(
      OrderPage(
        orders: <OrderSummary>[_summary('branch-2')],
        currentPage: 1,
        lastPage: 1,
        perPage: 1,
        total: 1,
      ),
    );
    await newBranch;
    repository.orderRequests[1].completePage(
      OrderPage(
        orders: <OrderSummary>[_summary('old-page')],
        currentPage: 2,
        lastPage: 2,
        perPage: 1,
        total: 2,
      ),
    );
    await oldPage;

    expect(cubit.state.selectedBranchId, 2);
    expect(cubit.state.orders.single.id, 'branch-2');
    expect(cubit.state.currentPage, 1);
  });

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

  int branchLoadCount = 0;
  final List<_OrderRequest> orderRequests = <_OrderRequest>[];
  final List<_DetailRequest> detailRequests = <_DetailRequest>[];

  @override
  Future<List<Branch>> getBranches() async {
    branchLoadCount++;
    return const <Branch>[
      Branch(
        id: 1,
        name: 'Downtown',
        currency: 'SYP',
        timezone: 'Asia/Damascus',
        isActive: true,
      ),
      Branch(
        id: 2,
        name: 'Uptown',
        currency: 'SYP',
        timezone: 'Asia/Damascus',
        isActive: true,
      ),
    ];
  }

  @override
  Future<OrderPage> getOrders({
    required int branchId,
    OrdersFilter? filter,
    int page = 1,
    int perPage = 25,
  }) {
    final _OrderRequest request = _OrderRequest(
      branchId: branchId,
      filter: filter,
      page: page,
      perPage: perPage,
    );
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
  _OrderRequest({
    required this.branchId,
    required this.filter,
    required this.page,
    required this.perPage,
  });

  final int branchId;
  final OrdersFilter? filter;
  final int page;
  final int perPage;
  final Completer<OrderPage> completer = Completer<OrderPage>();

  void complete(List<OrderSummary> orders) => completer.complete(
    OrderPage.fromOrders(orders, page: page, perPage: perPage),
  );
  void completePage(OrderPage page) => completer.complete(page);
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

const OrderSummary _summaryConst = OrderSummary(
  id: 'initial',
  type: OrderSummaryType.takeaway,
  customerName: 'Walk-in',
  status: OrderStatus.preparing,
  itemCount: 1,
  timeAgo: 'Just now',
  items: <OrderSummaryItem>[],
  total: 4,
);

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

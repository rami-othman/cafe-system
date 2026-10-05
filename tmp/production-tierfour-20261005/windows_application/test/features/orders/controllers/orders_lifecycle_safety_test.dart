import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:windows_application/core/network/api_exception.dart';
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
import 'package:windows_application/features/orders/repositories/orders_repository.dart';
import 'package:windows_application/features/pos/models/branch.dart';

void main() {
  late _LifecycleRepository repository;
  late OrdersCubit cubit;

  setUp(() async {
    repository = _LifecycleRepository();
    cubit = OrdersCubit(repository: repository);
    await cubit.loadOrders();
  });

  tearDown(() => cubit.close());

  test(
    'cancel preflights current detail and confirms through one DELETE',
    () async {
      final OrdersActionOutcome outcome = await cubit.cancelOrder('7');

      expect(outcome, OrdersActionOutcome.confirmed);
      expect(repository.detailRequests, 1);
      expect(repository.cancelRequests, 1);
      expect(repository.orderPageRequests, 2);
      expect(cubit.state.orders, isEmpty);
      expect(cubit.state.orderActionStatus, OrdersActionStatus.confirmed);
    },
  );

  test(
    'confirmed cancellation keeps success when list refresh recovers its page',
    () async {
      repository.pageResponses = <OrderPage>[
        const OrderPage(
          orders: <OrderSummary>[],
          currentPage: 2,
          lastPage: 1,
          perPage: 25,
          total: 0,
        ),
        const OrderPage(
          orders: <OrderSummary>[],
          currentPage: 1,
          lastPage: 1,
          perPage: 25,
          total: 0,
        ),
      ];

      expect(await cubit.cancelOrder('7'), OrdersActionOutcome.confirmed);
      expect(cubit.state.currentPage, 1);
      expect(repository.orderPageRequests, 3);
    },
  );

  test(
    'successful DELETE remains confirmed when its list refresh is superseded',
    () async {
      final Completer<OrderPage> refresh = Completer<OrderPage>();
      repository.refreshStarted = Completer<void>();
      repository.refreshFuture = refresh.future;

      final Future<OrdersActionOutcome> cancellation = cubit.cancelOrder('7');
      await repository.refreshStarted!.future;

      final Future<void> branchChange = cubit.applyBranchContext(2);
      refresh.complete(
        const OrderPage(
          orders: <OrderSummary>[],
          currentPage: 1,
          lastPage: 1,
          perPage: 25,
          total: 0,
        ),
      );
      await branchChange;

      expect(await cancellation, OrdersActionOutcome.confirmed);
      expect(cubit.state.selectedBranchId, 2);
      expect(repository.cancelRequests, 1);
    },
  );

  test(
    'verified cancellation remains confirmed when its list refresh is superseded',
    () async {
      final Completer<OrderPage> refresh = Completer<OrderPage>();
      repository.refreshStarted = Completer<void>();
      repository.refreshFuture = refresh.future;
      repository.cancelError = const ApiException(
        message: 'Connection lost.',
        type: ApiErrorType.receiveTimeout,
      );
      repository.detailResponses['7'] = <Object>[
        _activeDetail(),
        _cancelledDetail(),
      ];

      final Future<OrdersActionOutcome> cancellation = cubit.cancelOrder('7');
      await repository.refreshStarted!.future;

      final Future<void> branchChange = cubit.applyBranchContext(2);
      refresh.complete(
        const OrderPage(
          orders: <OrderSummary>[],
          currentPage: 1,
          lastPage: 1,
          perPage: 25,
          total: 0,
        ),
      );
      await branchChange;

      expect(await cancellation, OrdersActionOutcome.confirmed);
      expect(repository.cancelRequests, 1);
      expect(repository.detailRequests, 2);
    },
  );

  test('duplicate cancel calls cannot issue a second DELETE', () async {
    final Completer<OrderDetail> pending = Completer<OrderDetail>();
    repository.detailFuture = pending.future;

    final Future<OrdersActionOutcome> first = cubit.cancelOrder('7');
    final Future<OrdersActionOutcome> duplicate = cubit.cancelOrder('7');

    expect(repository.detailRequests, 1);
    expect(repository.cancelRequests, 0);
    expect(await duplicate, OrdersActionOutcome.retryableFailure);
    pending.complete(_activeDetail());
    expect(await first, OrdersActionOutcome.confirmed);
    expect(repository.cancelRequests, 1);
  });

  test(
    'definite cancellation failure retains the order and backend message',
    () async {
      repository.cancelError = const ApiException(
        message: 'Paid or closed orders cannot be cancelled.',
        statusCode: 422,
      );

      final OrdersActionOutcome outcome = await cubit.cancelOrder('7');

      expect(outcome, OrdersActionOutcome.retryableFailure);
      expect(repository.cancelRequests, 1);
      expect(cubit.state.orders.single.id, '7');
      expect(cubit.state.orderActionErrorMessage, contains('Paid or closed'));
      expect(cubit.state.uncertainOrderActionMessage, isNull);
    },
  );

  test(
    'uncertain cancellation verifies and blocks another DELETE until checked',
    () async {
      repository.cancelError = const ApiException(
        message: 'Connection lost.',
        type: ApiErrorType.connectionTimeout,
      );
      repository.detailResponses['7'] = <Object>[
        _activeDetail(),
        const ApiException(message: 'Status unavailable.'),
      ];

      final OrdersActionOutcome outcome = await cubit.cancelOrder('7');

      expect(outcome, OrdersActionOutcome.uncertain);
      expect(repository.cancelRequests, 1);
      expect(cubit.state.uncertainOrderActionMessage, contains('Check status'));
      expect(await cubit.cancelOrder('7'), OrdersActionOutcome.uncertain);
      expect(repository.cancelRequests, 1);

      repository.detailResponses['7']!.add(
        const ApiException(message: 'Order not found.', statusCode: 404),
      );
      expect(
        await cubit.checkUncertainOrderActionStatus(),
        OrdersActionOutcome.confirmed,
      );
      expect(cubit.state.orders, isEmpty);
    },
  );

  test(
    'verification of an active order permits explicit retry without auto DELETE',
    () async {
      repository.cancelError = const ApiException(
        message: 'Connection lost.',
        type: ApiErrorType.networkUnavailable,
      );
      repository.detailResponses['7'] = <Object>[
        _activeDetail(),
        _activeDetail(),
      ];

      expect(
        await cubit.cancelOrder('7'),
        OrdersActionOutcome.retryableFailure,
      );
      expect(repository.cancelRequests, 1);
      expect(cubit.state.orderActionErrorMessage, contains('still active'));
      expect(cubit.state.uncertainOrderActionMessage, isNull);
    },
  );

  test(
    'stale cancellation verification cannot overwrite a newer branch state',
    () async {
      final Completer<OrderDetail> pending = Completer<OrderDetail>();
      repository.cancelError = const ApiException(
        message: 'Connection lost.',
        type: ApiErrorType.receiveTimeout,
      );
      repository.verificationStarted = Completer<void>();
      repository.detailResponses['7'] = <Object>[
        _activeDetail(),
        pending.future,
      ];

      final Future<OrdersActionOutcome> cancellation = cubit.cancelOrder('7');
      await repository.verificationStarted!.future;
      final Future<void> branchChange = cubit.applyBranchContext(2);
      pending.complete(_activeDetail());
      await branchChange;

      expect(await cancellation, OrdersActionOutcome.stale);
      expect(cubit.state.selectedBranchId, 2);
      expect(
        cubit.state.orderActionStatus,
        OrdersActionStatus.retryableFailure,
      );
      expect(cubit.state.uncertainOrderActionMessage, isNull);
    },
  );

  test(
    'held Resume loads authoritative detail once and navigates one context',
    () async {
      repository.detailResponses['8'] = <Object>[_heldDetail()];
      final List<String> loadedIds = <String>[];

      final OrdersActionOutcome outcome = await cubit.resumeOrder(
        '8',
        loadIntoPos: (String orderId) async {
          loadedIds.add(orderId);
          return true;
        },
      );

      expect(outcome, OrdersActionOutcome.confirmed);
      expect(repository.detailRequests, 1);
      expect(loadedIds, <String>['8']);
      expect(cubit.state.orderActionStatus, OrdersActionStatus.confirmed);
    },
  );

  test(
    'Resume rejects paid or non-held authoritative orders and does not create one',
    () async {
      repository.detailResponses['8'] = <Object>[_activeDetail()];
      int loadCalls = 0;

      expect(
        await cubit.resumeOrder(
          '8',
          loadIntoPos: (_) async {
            loadCalls++;
            return true;
          },
        ),
        OrdersActionOutcome.retryableFailure,
      );
      expect(loadCalls, 0);

      repository.detailResponses['8'] = <Object>[
        _heldDetail(paymentStatus: 'paid'),
      ];
      expect(
        await cubit.resumeOrder(
          '8',
          loadIntoPos: (_) async {
            loadCalls++;
            return true;
          },
        ),
        OrdersActionOutcome.retryableFailure,
      );
      expect(loadCalls, 0);
    },
  );

  test('Resume honors the server resume eligibility blocker', () async {
    repository.detailResponses['8'] = <Object>[
      _heldDetail(serverCanResume: false),
    ];
    int loadCalls = 0;

    expect(
      await cubit.resumeOrder(
        '8',
        loadIntoPos: (_) async {
          loadCalls++;
          return true;
        },
      ),
      OrdersActionOutcome.retryableFailure,
    );
    expect(loadCalls, 0);
  });

  test(
    'stale Resume response cannot invoke POS after branch context changes',
    () async {
      final Completer<OrderDetail> pending = Completer<OrderDetail>();
      repository.detailFuture = pending.future;
      final List<String> loadedIds = <String>[];

      final Future<OrdersActionOutcome> resume = cubit.resumeOrder(
        '8',
        loadIntoPos: (String orderId) async {
          loadedIds.add(orderId);
          return true;
        },
      );
      final Future<void> branchChange = cubit.applyBranchContext(2);
      pending.complete(_heldDetail());
      await branchChange;

      expect(await resume, OrdersActionOutcome.stale);
      expect(loadedIds, isEmpty);
    },
  );
}

class _LifecycleRepository extends OrdersRepository {
  _LifecycleRepository() : super();

  final Map<String, OrderDetail> details = <String, OrderDetail>{
    '7': _activeDetail(),
    '8': _heldDetail(),
  };
  final Map<String, List<Object>> detailResponses = <String, List<Object>>{};
  Object? cancelError;
  Future<OrderDetail>? detailFuture;
  Completer<void>? verificationStarted;
  Completer<void>? refreshStarted;
  Future<OrderPage>? refreshFuture;
  int detailRequests = 0;
  int cancelRequests = 0;
  int orderPageRequests = 0;
  List<OrderPage> pageResponses = <OrderPage>[];

  @override
  bool get usesBackend => true;

  @override
  Future<List<Branch>> getBranches() async => const <Branch>[
    Branch(
      id: 1,
      name: 'Main',
      currency: 'SYP',
      timezone: 'Asia/Damascus',
      isActive: true,
    ),
    Branch(
      id: 2,
      name: 'Other',
      currency: 'SYP',
      timezone: 'Asia/Damascus',
      isActive: true,
    ),
  ];

  @override
  Future<OrderPage> getOrders({
    required int branchId,
    OrdersFilter? filter,
    int page = 1,
    int perPage = 25,
  }) async {
    orderPageRequests++;
    if (branchId == 1 && orderPageRequests == 2 && refreshFuture != null) {
      refreshStarted?.complete();
      return refreshFuture!;
    }
    if (pageResponses.isNotEmpty) {
      return pageResponses.removeAt(0);
    }
    final List<OrderSummary> orders = cancelRequests > 0
        ? const <OrderSummary>[]
        : <OrderSummary>[_summary('7')];
    return OrderPage.fromOrders(orders, page: page, perPage: perPage);
  }

  @override
  Future<OrderDetail> getOrderDetail(int orderId) async {
    detailRequests++;
    if (detailFuture != null) {
      return detailFuture!;
    }
    final List<Object>? responses = detailResponses[orderId.toString()];
    if (responses != null && responses.isNotEmpty) {
      final Object response = responses.removeAt(0);
      if (response is OrderDetail) {
        return response;
      }
      if (response is Future<OrderDetail>) {
        verificationStarted?.complete();
        return response;
      }
      throw response;
    }
    return details[orderId.toString()]!;
  }

  @override
  Future<void> cancelOrder(int orderId) async {
    cancelRequests++;
    if (cancelError != null) {
      throw cancelError!;
    }
  }
}

OrderSummary _summary(String id) => OrderSummary(
  id: id,
  backendId: int.parse(id),
  displayNumber: '#ORD-$id',
  type: OrderSummaryType.takeaway,
  customerName: 'Walk-in',
  status: OrderStatus.preparing,
  itemCount: 1,
  timeAgo: 'Just now',
  items: const <OrderSummaryItem>[],
  total: 5,
);

OrderDetail _activeDetail() => _detail(
  status: OrderStatus.preparing,
  paymentStatus: 'unpaid',
  paymentStatusLabel: 'Pending',
  paymentRecordStatus: 'pending',
);

OrderDetail _heldDetail({
  String paymentStatus = 'unpaid',
  bool? serverCanResume,
}) => _detail(
  status: OrderStatus.held,
  paymentStatus: paymentStatus,
  paymentStatusLabel: paymentStatus == 'paid' ? 'Approved' : 'Pending',
  paymentRecordStatus: paymentStatus == 'paid' ? 'completed' : 'pending',
  serverCanResume: serverCanResume,
);

OrderDetail _cancelledDetail() => _detail(
  status: OrderStatus.cancelled,
  paymentStatus: 'unpaid',
  paymentStatusLabel: 'Pending',
  paymentRecordStatus: 'pending',
);

OrderDetail _detail({
  required OrderStatus status,
  required String paymentStatus,
  required String paymentStatusLabel,
  required String paymentRecordStatus,
  bool? serverCanResume,
}) {
  return OrderDetail(
    id: status == OrderStatus.held ? '8' : '7',
    displayNumber: status == OrderStatus.held ? '#ORD-8' : '#ORD-7',
    status: status,
    orderType: 'Takeaway',
    createdAt: DateTime(2026),
    customerName: 'Walk-in',
    customerPhone: '',
    customerEmail: '',
    items: const <OrderDetailItem>[],
    subtotal: 5,
    tax: 0,
    tip: 0,
    total: 5,
    payment: OrderPaymentSummary(
      methodLabel: 'Cash',
      statusLabel: paymentStatusLabel,
      authCode: paymentRecordStatus == 'completed' ? '1' : '-',
      amount: 5,
      status: paymentRecordStatus,
    ),
    timeline: const <OrderTimelineEvent>[],
    paymentStatus: paymentStatus,
    branchId: 1,
    serverCanResume: serverCanResume,
  );
}

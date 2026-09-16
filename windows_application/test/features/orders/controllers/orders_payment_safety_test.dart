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
import 'package:windows_application/features/orders/models/order_timeline_event.dart';
import 'package:windows_application/features/orders/repositories/orders_repository.dart';
import 'package:windows_application/features/pos/models/branch.dart';
import 'package:windows_application/features/pos/models/order_receipt.dart';
import 'package:windows_application/features/pos/models/payment_method.dart';
import 'package:windows_application/features/pos/models/payment_result.dart';
import 'package:windows_application/features/pos/models/payment_summary.dart';
import 'package:windows_application/features/pos/models/receipt_line_item.dart';

void main() {
  late _PaymentOrdersRepository repository;
  late OrdersCubit cubit;

  setUp(() {
    repository = _PaymentOrdersRepository();
    cubit = OrdersCubit(
      repository: repository,
      operationKeyGenerator: (_) => 'payment-key-1',
    );
  });

  tearDown(() async {
    await cubit.close();
  });

  test('prepares from authoritative payment data, not the list card', () async {
    repository.summary = _summary(outstandingAmount: 7);

    final PaymentSummary? result = await cubit.preparePayment('7');

    expect(repository.summaryRequests, 1);
    expect(result?.amountDue, 7);
    expect(cubit.state.paymentSummary?.amountDue, 7);
    expect(cubit.state.paymentStatus, OrdersPaymentStatus.ready);
  });

  test(
    'paid, terminal, zero-balance, and inaccessible orders cannot pay',
    () async {
      repository.summary = _summary(
        paymentStatus: 'paid',
        orderStatus: 'paid',
        canPay: false,
        outstandingAmount: 0,
        blockedReason: 'A completed payment already exists for this order.',
      );
      expect(await cubit.preparePayment('7'), isNull);
      expect(cubit.state.paymentStatus, OrdersPaymentStatus.retryableFailure);

      repository.summary = _summary(
        orderStatus: 'cancelled',
        canPay: false,
        blockedReason: 'This order cannot be paid in its current state.',
      );
      expect(await cubit.preparePayment('7'), isNull);

      repository.summary = _summary(
        orderStatus: 'refunded',
        paymentStatus: 'refunded',
        canPay: false,
        outstandingAmount: 0,
        blockedReason: 'This order cannot be paid in its current state.',
      );
      expect(await cubit.preparePayment('7'), isNull);

      repository.summary = _summary(
        canPay: false,
        outstandingAmount: 0,
        blockedReason: 'There is no outstanding balance.',
      );
      expect(await cubit.preparePayment('7'), isNull);

      repository.summaryError = const ApiException(
        message: 'You do not have permission to perform this action.',
        statusCode: 403,
        type: ApiErrorType.forbidden,
      );
      expect(await cubit.preparePayment('7'), isNull);
      expect(cubit.state.paymentErrorMessage, contains('permission'));
    },
  );

  test('double Pay taps make one preparation request', () async {
    final Completer<PaymentSummary> preparation = Completer<PaymentSummary>();
    repository.summaryFuture = preparation.future;

    final Future<PaymentSummary?> first = cubit.preparePayment('7');
    final Future<PaymentSummary?> second = cubit.preparePayment('7');

    expect(identical(first, second), isTrue);
    expect(repository.summaryRequests, 1);
    expect(cubit.state.paymentStatus, OrdersPaymentStatus.preparing);
    expect(cubit.state.isPaymentPreparing, isTrue);
    preparation.complete(_summary());
    await first;
  });

  test('a stale preparation cannot update a newly selected order', () async {
    final Completer<PaymentSummary> preparation = Completer<PaymentSummary>();
    repository.summaryFuture = preparation.future;
    repository.detailById[8] = _detail(id: 8);

    final Future<PaymentSummary?> pending = cubit.preparePayment('7');
    await cubit.openOrderDetails('8');
    preparation.complete(_summary());
    await pending;

    expect(cubit.state.paymentOrderId, isNull);
    expect(cubit.state.paymentSummary, isNull);
    expect(cubit.state.selectedOrderDetail?.id, '8');
  });

  test('double Confirm taps make one payment request', () async {
    repository.detailById[7] = _paidDetail(id: 7, key: 'payment-key-1');
    final Completer<PaymentResult> payment = Completer<PaymentResult>();
    repository.paymentFuture = payment.future;
    await cubit.preparePayment('7');

    final Future<OrdersPaymentStatus> first = cubit.submitPayment(_cash());
    final Future<OrdersPaymentStatus> second = cubit.submitPayment(_cash());

    expect(repository.payCalls, hasLength(1));
    expect(cubit.state.paymentStatus, OrdersPaymentStatus.submitting);
    expect(cubit.state.isPaymentSubmitting, isTrue);
    expect(await second, OrdersPaymentStatus.uncertain);
    payment.complete(_cash(status: 'completed'));
    expect(await first, OrdersPaymentStatus.confirmed);
  });

  test('generates a non-empty web-safe idempotency key', () async {
    repository.detailById[7] = _paidDetail(id: 7, key: 'web-safe-key');
    await cubit.preparePayment('7');

    await cubit.submitPayment(_cash());

    expect(
      repository.payCalls.single.idempotencyKey,
      matches(RegExp(r'^[A-Za-z0-9._~-]+$')),
    );
    expect(repository.payCalls.single.idempotencyKey, isNotEmpty);
  });

  test(
    'key-generation failure sends zero payment requests and unlocks submission',
    () async {
      await cubit.close();
      cubit = OrdersCubit(
        repository: repository,
        operationKeyGenerator: (_) => throw StateError('key generation failed'),
      );
      await cubit.preparePayment('7');

      final OrdersPaymentStatus status = await cubit.submitPayment(_cash());

      expect(status, OrdersPaymentStatus.retryableFailure);
      expect(repository.payCalls, isEmpty);
      expect(cubit.state.isPaymentSubmitting, isFalse);
    },
  );

  test(
    'identical definite retry reuses the key and changed payload gets a new key',
    () async {
      final List<String> generatedKeys = <String>['key-1', 'key-2'];
      await cubit.close();
      cubit = OrdersCubit(
        repository: repository,
        operationKeyGenerator: (_) => generatedKeys.removeAt(0),
      );
      repository.payOutcomes.add(
        const ApiException(
          message: 'Amount is invalid.',
          statusCode: 422,
          type: ApiErrorType.validation,
        ),
      );
      repository.payOutcomes.add(
        const ApiException(
          message: 'Amount is invalid.',
          statusCode: 422,
          type: ApiErrorType.validation,
        ),
      );
      repository.payOutcomes.add(
        const PaymentResult(
          method: PaymentMethod.cash,
          totalDue: 10,
          amountReceived: 10,
          changeDue: 0,
          status: 'completed',
        ),
      );
      repository.detailById[7] = _paidDetail(id: 7, key: 'key-2');
      await cubit.preparePayment('7');

      expect(
        await cubit.submitPayment(_cash()),
        OrdersPaymentStatus.retryableFailure,
      );
      expect(
        await cubit.submitPayment(_cash()),
        OrdersPaymentStatus.retryableFailure,
      );
      expect(
        await cubit.submitPayment(_cash(amount: 11)),
        OrdersPaymentStatus.confirmed,
      );

      expect(repository.payCalls.map((call) => call.idempotencyKey), <String>[
        'key-1',
        'key-1',
        'key-2',
      ]);
    },
  );

  test('a changed order receives a new key', () async {
    final List<String> generatedKeys = <String>['order-key-1', 'order-key-2'];
    await cubit.close();
    cubit = OrdersCubit(
      repository: repository,
      operationKeyGenerator: (_) => generatedKeys.removeAt(0),
    );
    repository.payOutcomes.add(
      const ApiException(
        message: 'Temporary validation failure.',
        statusCode: 422,
        type: ApiErrorType.validation,
      ),
    );
    repository.summary = _summary(orderId: 7);
    await cubit.preparePayment('7');
    expect(
      await cubit.submitPayment(_cash()),
      OrdersPaymentStatus.retryableFailure,
    );

    repository.summary = _summary(orderId: 8);
    repository.detailById[8] = _paidDetail(id: 8, key: 'order-key-2');
    await cubit.openOrderDetails('8');
    await cubit.preparePayment('8');
    expect(await cubit.submitPayment(_cash()), OrdersPaymentStatus.confirmed);

    expect(repository.payCalls.map((call) => call.idempotencyKey), <String>[
      'order-key-1',
      'order-key-2',
    ]);
  });

  test(
    'definite API failure never reports success and retains the actionable message',
    () async {
      repository.payOutcomes.add(
        const ApiException(
          message: 'The cash amount is too low.',
          statusCode: 422,
          type: ApiErrorType.validation,
        ),
      );
      await cubit.preparePayment('7');

      final OrdersPaymentStatus status = await cubit.submitPayment(_cash());

      expect(status, OrdersPaymentStatus.retryableFailure);
      expect(cubit.state.paymentStatus, OrdersPaymentStatus.retryableFailure);
      expect(cubit.state.paymentErrorMessage, 'The cash amount is too low.');
    },
  );

  test(
    'timeout verifies authoritative state and confirms a matching payment',
    () async {
      repository.payOutcomes.add(
        const ApiException(
          message: 'The server response timed out.',
          statusCode: 500,
          type: ApiErrorType.server,
        ),
      );
      repository.detailById[7] = _paidDetail(id: 7, key: 'payment-key-1');
      await cubit.preparePayment('7');

      final OrdersPaymentStatus status = await cubit.submitPayment(_cash());

      expect(status, OrdersPaymentStatus.confirmed);
      expect(repository.detailRequests, contains(7));
      expect(cubit.state.paymentStatus, OrdersPaymentStatus.confirmed);
    },
  );

  test(
    'uncertain payment with definitely absent payment reuses the key for an explicit retry',
    () async {
      repository.payOutcomes.add(
        const ApiException(
          message: 'Connection interrupted.',
          statusCode: 500,
          type: ApiErrorType.server,
        ),
      );
      repository.payOutcomes.add(
        const PaymentResult(
          method: PaymentMethod.cash,
          totalDue: 10,
          amountReceived: 10,
          changeDue: 0,
          status: 'completed',
        ),
      );
      repository.detailById[7] = _detail(id: 7);
      await cubit.preparePayment('7');

      expect(
        await cubit.submitPayment(_cash()),
        OrdersPaymentStatus.retryableFailure,
      );
      expect(cubit.state.uncertainPaymentMessage, isNull);
      repository.detailById[7] = _paidDetail(id: 7, key: 'payment-key-1');
      expect(await cubit.submitPayment(_cash()), OrdersPaymentStatus.confirmed);
      expect(repository.payCalls.map((call) => call.idempotencyKey), <String>[
        'payment-key-1',
        'payment-key-1',
      ]);
    },
  );

  test('failed authoritative verification blocks another submission', () async {
    repository.payOutcomes.add(
      const ApiException(
        message: 'Connection interrupted.',
        statusCode: 500,
        type: ApiErrorType.server,
      ),
    );
    repository.detailErrors.add(
      const ApiException(
        message: 'Status endpoint unavailable.',
        statusCode: 503,
      ),
    );
    await cubit.preparePayment('7');

    expect(await cubit.submitPayment(_cash()), OrdersPaymentStatus.uncertain);
    expect(cubit.state.uncertainPaymentMessage, isNotNull);
    expect(await cubit.submitPayment(_cash()), OrdersPaymentStatus.uncertain);
    expect(repository.payCalls, hasLength(1));
  });

  test(
    'check status verifies without another pay request and recovers success',
    () async {
      repository.payOutcomes.add(
        const ApiException(
          message: 'Connection interrupted.',
          statusCode: 500,
          type: ApiErrorType.server,
        ),
      );
      repository.detailErrors.add(
        const ApiException(
          message: 'Status endpoint unavailable.',
          statusCode: 503,
        ),
      );
      await cubit.preparePayment('7');

      expect(await cubit.submitPayment(_cash()), OrdersPaymentStatus.uncertain);
      expect(repository.payCalls, hasLength(1));

      repository.detailById[7] = _paidDetail(id: 7, key: 'payment-key-1');
      expect(
        await cubit.checkUncertainPaymentStatus(),
        OrdersPaymentStatus.confirmed,
      );
      expect(repository.payCalls, hasLength(1));
      expect(repository.detailRequests, <int>[7, 7]);
      expect(cubit.state.paymentReceipt, isNotNull);
    },
  );

  test(
    'stale payment confirmation cannot replace a newer selected detail',
    () async {
      repository.detailById[8] = _detail(id: 8);
      await cubit.preparePayment('7');
      final Future<OrdersPaymentStatus> payment = cubit.submitPayment(_cash());
      await _drainMicrotasks();
      await cubit.openOrderDetails('8');
      expect(cubit.state.selectedOrderDetail?.id, '8');
      repository.pendingDetails.first.complete(
        _paidDetail(id: 7, key: 'payment-key-1'),
      );

      expect(await payment, OrdersPaymentStatus.confirmed);
      expect(cubit.state.selectedOrderDetail?.id, '8');
    },
  );

  test(
    'successful payment refreshes the current list and matching open detail',
    () async {
      repository.detailById[7] = _paidDetail(id: 7, key: 'payment-key-1');
      await cubit.openOrderDetails('7');
      await cubit.preparePayment('7');

      expect(await cubit.submitPayment(_cash()), OrdersPaymentStatus.confirmed);
      expect(repository.orderRequests, isNotEmpty);
      expect(cubit.state.orders, isEmpty);
      expect(cubit.state.selectedOrderDetail?.paymentStatus, 'paid');
      expect(cubit.state.isPaymentBlocked, isFalse);
    },
  );

  test('receipt failure is recoverable without repeating payment', () async {
    repository.detailById[7] = _paidDetail(id: 7, key: 'payment-key-1');
    repository.receiptErrorsRemaining = 1;
    await cubit.preparePayment('7');

    expect(await cubit.submitPayment(_cash()), OrdersPaymentStatus.confirmed);
    expect(cubit.state.receiptErrorMessage, isNotNull);
    expect(repository.payCalls, hasLength(1));

    await cubit.retryPaymentReceipt();

    expect(cubit.state.receiptErrorMessage, isNull);
    expect(cubit.state.paymentReceipt, isNotNull);
    expect(repository.payCalls, hasLength(1));
  });

  test(
    'disposed Cubit does not emit after a pending payment completes',
    () async {
      final Completer<PaymentResult> payment = Completer<PaymentResult>();
      repository.paymentFuture = payment.future;
      await cubit.preparePayment('7');
      final Future<OrdersPaymentStatus> pending = cubit.submitPayment(_cash());

      await cubit.close();
      payment.complete(_cash(status: 'completed'));

      expect(await pending, OrdersPaymentStatus.uncertain);
    },
  );
}

Future<void> _drainMicrotasks() => Future<void>.delayed(Duration.zero);

PaymentSummary _summary({
  int orderId = 7,
  double outstandingAmount = 10,
  String orderStatus = 'draft',
  String paymentStatus = 'unpaid',
  bool canPay = true,
  String? blockedReason,
  List<String> methods = const <String>['cash', 'card'],
}) {
  return PaymentSummary(
    orderId: orderId,
    orderNumber: '#ORD-$orderId',
    totalDue: 99,
    itemCount: 2,
    amountReceived: outstandingAmount,
    changeDue: 0,
    methods: methods,
    quickAmounts: <double>[outstandingAmount],
    outstandingAmount: outstandingAmount,
    orderStatus: orderStatus,
    paymentStatus: paymentStatus,
    canPay: canPay,
    blockedReason: blockedReason,
  );
}

PaymentResult _cash({double amount = 10, String? status}) {
  return PaymentResult(
    method: PaymentMethod.cash,
    totalDue: 10,
    amountReceived: amount,
    changeDue: amount > 10 ? amount - 10 : 0,
    status: status,
  );
}

OrderDetail _detail({required int id}) {
  return OrderDetail(
    id: id.toString(),
    displayNumber: '#ORD-$id',
    status: OrderStatus.preparing,
    orderType: 'Takeaway',
    createdAt: DateTime(2026, 9, 14),
    customerName: 'Test Customer',
    customerPhone: '',
    customerEmail: '',
    items: const <OrderDetailItem>[],
    subtotal: 10,
    tax: 0,
    tip: 0,
    total: 10,
    payment: const OrderPaymentSummary(
      methodLabel: 'No payment recorded yet.',
      statusLabel: '',
      authCode: '',
      amount: 0,
      hasPayment: false,
    ),
    timeline: const <OrderTimelineEvent>[],
  );
}

OrderDetail _paidDetail({required int id, required String key}) {
  final OrderPaymentSummary payment = OrderPaymentSummary(
    methodLabel: 'Cash',
    statusLabel: 'Completed',
    authCode: '',
    amount: 10,
    method: 'cash',
    status: 'completed',
    paymentId: 41,
    idempotencyKey: key,
  );
  return OrderDetail(
    id: id.toString(),
    displayNumber: '#ORD-$id',
    status: OrderStatus.completed,
    orderType: 'Takeaway',
    createdAt: DateTime(2026, 9, 14),
    customerName: 'Test Customer',
    customerPhone: '',
    customerEmail: '',
    items: const <OrderDetailItem>[],
    subtotal: 10,
    tax: 0,
    tip: 0,
    total: 10,
    payment: payment,
    payments: <OrderPaymentSummary>[payment],
    paymentStatus: 'paid',
    timeline: const <OrderTimelineEvent>[],
  );
}

class _PaymentOrdersRepository extends OrdersRepository {
  _PaymentOrdersRepository();

  @override
  bool get usesBackend => true;

  PaymentSummary summary = _summary();
  Object? summaryError;
  Future<PaymentSummary>? summaryFuture;
  int summaryRequests = 0;
  final List<_PayCall> payCalls = <_PayCall>[];
  final List<Object> payOutcomes = <Object>[];
  Future<PaymentResult>? paymentFuture;
  final Map<int, OrderDetail> detailById = <int, OrderDetail>{};
  final List<int> detailRequests = <int>[];
  final List<Object> detailErrors = <Object>[];
  final List<_PendingDetailCall> pendingDetails = <_PendingDetailCall>[];
  final List<int> orderRequests = <int>[];
  int receiptErrorsRemaining = 0;
  int receiptRequests = 0;

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
  Future<OrderPage> getOrders({
    required int branchId,
    OrdersFilter? filter,
    int page = 1,
    int perPage = 25,
  }) async {
    orderRequests.add(page);
    return OrderPage(
      orders: const <OrderSummary>[],
      currentPage: page,
      lastPage: 1,
      perPage: perPage,
      total: 0,
    );
  }

  @override
  Future<PaymentSummary> getPaymentSummary({
    required int orderId,
    double? amountReceived,
  }) {
    summaryRequests++;
    if (summaryError != null) {
      return Future<PaymentSummary>.error(summaryError!);
    }
    if (summaryFuture != null) {
      return summaryFuture!;
    }
    return Future<PaymentSummary>.value(summary);
  }

  @override
  Future<PaymentResult> payOrder({
    required int orderId,
    required String method,
    required double amount,
    required String idempotencyKey,
    String? reference,
    required double totalDue,
  }) {
    payCalls.add(
      _PayCall(
        orderId: orderId,
        method: method,
        amount: amount,
        idempotencyKey: idempotencyKey,
        reference: reference,
      ),
    );
    if (payOutcomes.isNotEmpty) {
      final Object outcome = payOutcomes.removeAt(0);
      if (outcome is PaymentResult) {
        return Future<PaymentResult>.value(outcome);
      }
      return Future<PaymentResult>.error(outcome);
    }
    if (paymentFuture != null) {
      return paymentFuture!;
    }
    return Future<PaymentResult>.value(
      PaymentResult(
        method: paymentMethodFromApi(method),
        totalDue: totalDue,
        amountReceived: amount,
        changeDue: amount > totalDue ? amount - totalDue : 0,
        status: 'completed',
      ),
    );
  }

  @override
  Future<OrderDetail> getOrderDetail(int orderId) {
    detailRequests.add(orderId);
    if (detailErrors.isNotEmpty) {
      return Future<OrderDetail>.error(detailErrors.removeAt(0));
    }
    final OrderDetail? detail = detailById[orderId];
    if (detail != null) {
      return Future<OrderDetail>.value(detail);
    }
    final _PendingDetailCall call = _PendingDetailCall(orderId);
    pendingDetails.add(call);
    return call.completer.future;
  }

  @override
  Future<OrderReceipt> getReceipt(int orderId) async {
    receiptRequests++;
    if (receiptErrorsRemaining > 0) {
      receiptErrorsRemaining--;
      throw const ApiException(
        message: 'Receipt unavailable.',
        statusCode: 503,
      );
    }
    return _receipt();
  }
}

class _PayCall {
  const _PayCall({
    required this.orderId,
    required this.method,
    required this.amount,
    required this.idempotencyKey,
    required this.reference,
  });

  final int orderId;
  final String method;
  final double amount;
  final String idempotencyKey;
  final String? reference;
}

class _PendingDetailCall {
  _PendingDetailCall(this.orderId);

  final int orderId;
  final Completer<OrderDetail> completer = Completer<OrderDetail>();

  void complete(OrderDetail detail) => completer.complete(detail);
}

OrderReceipt _receipt() {
  return OrderReceipt(
    orderNumber: '#ORD-7',
    branchName: 'Downtown',
    cashierName: 'Test Cashier',
    completedAt: DateTime(2026, 9, 14),
    items: <ReceiptLineItem>[],
    subtotal: 10,
    discountTotal: 0,
    discountLabel: null,
    tax: 0,
    total: 10,
    payment: PaymentResult(
      method: PaymentMethod.cash,
      totalDue: 10,
      amountReceived: 10,
      changeDue: 0,
    ),
  );
}

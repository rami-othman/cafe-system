import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:windows_application/core/network/api_exception.dart';
import 'package:windows_application/features/orders/controllers/orders_cubit.dart';
import 'package:windows_application/features/orders/controllers/orders_state.dart';
import 'package:windows_application/features/orders/models/order_detail.dart';
import 'package:windows_application/features/orders/models/order_payment_summary.dart';
import 'package:windows_application/features/orders/models/order_refund.dart';
import 'package:windows_application/features/orders/models/order_page.dart';
import 'package:windows_application/features/orders/models/order_status.dart';
import 'package:windows_application/features/orders/models/order_summary.dart';
import 'package:windows_application/features/orders/models/order_summary_item.dart';
import 'package:windows_application/features/orders/models/order_timeline_event.dart';
import 'package:windows_application/features/orders/models/order_type.dart';
import 'package:windows_application/features/orders/models/refund_result.dart';
import 'package:windows_application/features/orders/models/refund_type.dart';
import 'package:windows_application/features/orders/repositories/orders_repository.dart';
import 'package:windows_application/features/pos/models/branch.dart';

void main() {
  late _RefundRepository repository;
  late OrdersCubit cubit;

  setUp(() async {
    repository = _RefundRepository();
    cubit = OrdersCubit(repository: repository);
    await cubit.openOrderDetails('42');
  });

  tearDown(() => cubit.close());

  test('generates a refund key on all supported platforms', () async {
    final RefundCompletionStatus status = await cubit.submitRefund(_request());

    expect(status, RefundCompletionStatus.completed);
    expect(repository.lastIdempotencyKey, startsWith('refund-'));
  });

  test('key-generation failure happens before repository submission', () async {
    final OrdersCubit failingCubit = OrdersCubit(
      repository: repository,
      operationKeyGenerator: (_) => throw StateError('key generation failed'),
    );
    addTearDown(failingCubit.close);
    await failingCubit.openOrderDetails('42');

    final RefundCompletionStatus status = await failingCubit.submitRefund(
      _request(),
    );

    expect(status, RefundCompletionStatus.retryableFailure);
    expect(repository.refundCalls, 0);
    expect(failingCubit.state.isRefundSubmitting, isFalse);
  });

  test('unpaid order cannot confirm a refund', () async {
    repository.details['42'] = _detail(
      '42',
      paymentStatus: 'Pending',
      refundableAmount: 0,
    );
    await cubit.openOrderDetails('42');

    expect(
      await cubit.submitRefund(_request()),
      RefundCompletionStatus.retryableFailure,
    );
    expect(repository.refundCalls, 0);
    expect(cubit.state.isRefundSubmitting, isFalse);
  });

  test('API failure cannot produce a false success state', () async {
    repository.submitError = const ApiException(
      message: 'Refund amount exceeds the refundable balance.',
      statusCode: 422,
    );

    expect(
      await cubit.submitRefund(_request()),
      RefundCompletionStatus.retryableFailure,
    );
    expect(cubit.state.refundErrorMessage, contains('exceeds'));
    expect(cubit.state.uncertainRefundMessage, isNull);
  });

  test('double confirmation sends exactly one refund request', () async {
    repository.refundCompleter = Completer<RefundResult>();

    final Future<RefundCompletionStatus> first = cubit.submitRefund(_request());
    final Future<RefundCompletionStatus> second = cubit.submitRefund(
      _request(),
    );

    expect(repository.refundCalls, 1);
    expect(cubit.state.isRefundSubmitting, isTrue);
    expect(await second, RefundCompletionStatus.uncertain);

    repository.refundCompleter!.complete(_result(_request()));
    expect(await first, RefundCompletionStatus.completed);
    expect(cubit.state.isRefundSubmitting, isFalse);
  });

  test('identical definite retry reuses the same idempotency key', () async {
    repository.submitError = const ApiException(
      message: 'Refund amount exceeds the refundable balance.',
      statusCode: 422,
    );

    expect(
      await cubit.submitRefund(_request()),
      RefundCompletionStatus.retryableFailure,
    );
    final String firstKey = repository.lastIdempotencyKey!;

    repository.submitError = null;
    expect(
      await cubit.submitRefund(_request()),
      RefundCompletionStatus.completed,
    );
    expect(repository.lastIdempotencyKey, firstKey);
  });

  test('changed payload creates a new operation key', () async {
    repository.submitError = const ApiException(
      message: 'Refund amount exceeds the refundable balance.',
      statusCode: 422,
    );
    await cubit.submitRefund(_request());
    final String firstKey = repository.lastIdempotencyKey!;

    repository.submitError = null;
    await cubit.submitRefund(_request(amount: 11));

    expect(repository.lastIdempotencyKey, isNot(firstKey));
  });

  test('different order creates a new operation key', () async {
    repository.submitError = const ApiException(
      message: 'Refund amount exceeds the refundable balance.',
      statusCode: 422,
    );
    await cubit.submitRefund(_request());
    final String firstKey = repository.lastIdempotencyKey!;

    repository.submitError = null;
    repository.details['43'] = _detail('43');
    await cubit.openOrderDetails('43');
    await cubit.submitRefund(_request(orderId: '43'));

    expect(repository.lastIdempotencyKey, isNot(firstKey));
  });

  test('uncertain submission verifies the authoritative order', () async {
    repository.submitError = StateError('connection lost');
    repository.authoritativeRefundOnVerification = true;

    expect(
      await cubit.submitRefund(_request()),
      RefundCompletionStatus.completed,
    );
    expect(repository.refundCalls, 1);
    expect(repository.detailCalls, 2);
    expect(cubit.state.uncertainRefundMessage, isNull);
  });

  test(
    'definitely absent refund may be explicitly retried with the same key',
    () async {
      repository.submitError = StateError('connection lost');

      expect(
        await cubit.submitRefund(_request()),
        RefundCompletionStatus.retryableFailure,
      );
      final String firstKey = repository.lastIdempotencyKey!;
      expect(cubit.state.isRefundSubmitting, isFalse);

      repository.submitError = null;
      expect(
        await cubit.submitRefund(_request()),
        RefundCompletionStatus.completed,
      );
      expect(repository.lastIdempotencyKey, firstKey);
    },
  );

  test('failed verification blocks another refund submission', () async {
    repository.submitError = StateError('connection lost');
    repository.detailErrorAfterFirstRead = StateError('still offline');

    expect(
      await cubit.submitRefund(_request()),
      RefundCompletionStatus.uncertain,
    );
    expect(cubit.state.uncertainRefundMessage, isNotNull);

    expect(
      await cubit.submitRefund(_request()),
      RefundCompletionStatus.uncertain,
    );
    expect(repository.refundCalls, 1);
  });

  test(
    'successful refund reloads details and keeps cumulative backend totals',
    () async {
      repository.details['42'] = _detail(
        '42',
        refundedAmount: 20,
        refundableAmount: 80,
        refunds: <OrderRefund>[_refund(amount: 20, key: 'old-key')],
      );

      expect(
        await cubit.submitRefund(_request(amount: 10)),
        RefundCompletionStatus.completed,
      );

      expect(repository.detailCalls, greaterThan(1));
      expect(repository.listCalls, greaterThan(0));
      expect(cubit.state.selectedOrderDetail?.refundedAmount, 30);
      expect(cubit.state.selectedOrderDetail?.refundableAmount, 70);
    },
  );

  test(
    'stale refund refresh cannot overwrite a newer selected order',
    () async {
      repository.refundCompleter = Completer<RefundResult>();
      final Future<RefundCompletionStatus> submission = cubit.submitRefund(
        _request(),
      );
      await Future<void>.delayed(Duration.zero);

      repository.details['43'] = _detail('43');
      final Future<void> newerDetails = cubit.openOrderDetails('43');
      await newerDetails;

      repository.refundCompleter!.complete(_result(_request()));
      await submission;

      expect(cubit.state.selectedOrderDetail?.id, '43');
    },
  );
}

RefundResult _request({String orderId = '42', double amount = 10}) {
  return RefundResult(
    orderId: orderId,
    type: RefundType.partial,
    amount: amount,
    reason: 'Customer request',
    managerNotes: 'Manager approved',
    refundedAt: DateTime(2026, 9, 14, 12),
  );
}

RefundResult _result(RefundResult request) {
  return RefundResult(
    orderId: request.orderId,
    type: request.type,
    amount: request.amount,
    reason: request.reason,
    managerNotes: request.managerNotes,
    refundedAt: DateTime(2026, 9, 14, 12, 1),
  );
}

OrderRefund _refund({required double amount, required String key}) {
  return OrderRefund(
    id: 'refund-$key',
    type: RefundType.partial,
    amount: amount,
    reason: 'Customer request',
    managerNotes: 'Manager approved',
    status: 'completed',
    idempotencyKey: key,
    refundedAt: DateTime(2026, 9, 14, 12, 1),
  );
}

OrderDetail _detail(
  String id, {
  double refundedAmount = 0,
  double refundableAmount = 100,
  List<OrderRefund> refunds = const <OrderRefund>[],
  String paymentStatus = 'Completed',
}) {
  return OrderDetail(
    id: id,
    displayNumber: '#$id',
    status: refundedAmount >= 100
        ? OrderStatus.refunded
        : refundedAmount > 0
        ? OrderStatus.partiallyRefunded
        : OrderStatus.completed,
    orderType: 'Takeaway',
    createdAt: DateTime(2026),
    customerName: 'Walk-in',
    customerPhone: '',
    customerEmail: '',
    items: const <OrderDetailItem>[],
    subtotal: 100,
    tax: 0,
    tip: 0,
    total: 100,
    payment: OrderPaymentSummary(
      methodLabel: 'Cash',
      statusLabel: paymentStatus,
      authCode: '1',
      amount: 100,
    ),
    timeline: const <OrderTimelineEvent>[],
    refundedAmount: refundedAmount,
    refundableAmount: refundableAmount,
    refunds: refunds,
  );
}

class _RefundRepository extends OrdersRepository {
  int refundCalls = 0;
  int detailCalls = 0;
  int listCalls = 0;
  String? lastIdempotencyKey;
  Object? submitError;
  Object? detailErrorAfterFirstRead;
  Completer<RefundResult>? refundCompleter;
  bool authoritativeRefundOnVerification = false;
  final Map<String, OrderDetail> details = <String, OrderDetail>{
    '42': _detail('42'),
  };

  @override
  bool get usesBackend => true;

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
    listCalls += 1;
    return OrderPage.fromOrders(
      <OrderSummary>[_summary('42')],
      page: page,
      perPage: perPage,
    );
  }

  @override
  Future<OrderDetail> getOrderDetail(int orderId) async {
    detailCalls += 1;
    if (detailCalls > 1 && detailErrorAfterFirstRead != null) {
      throw detailErrorAfterFirstRead!;
    }
    if (detailCalls > 1 && authoritativeRefundOnVerification) {
      return _detail(
        orderId.toString(),
        refundedAmount: 10,
        refundableAmount: 90,
        refunds: <OrderRefund>[_refund(amount: 10, key: lastIdempotencyKey!)],
      );
    }
    return details[orderId.toString()]!;
  }

  @override
  Future<RefundResult> submitRefund({
    required RefundResult request,
    required String idempotencyKey,
  }) async {
    refundCalls += 1;
    lastIdempotencyKey = idempotencyKey;
    if (submitError != null) {
      throw submitError!;
    }
    final RefundResult result = refundCompleter == null
        ? _result(request)
        : await refundCompleter!.future;
    final OrderDetail current = details[request.orderId]!;
    final double refunded = current.refundedAmount + result.amount;
    details[request.orderId] = _detail(
      request.orderId,
      refundedAmount: refunded,
      refundableAmount: current.refundableAmount - result.amount,
      refunds: <OrderRefund>[
        ...current.refunds,
        _refund(amount: result.amount, key: idempotencyKey),
      ],
    );
    return result;
  }
}

OrderSummary _summary(String id) {
  return OrderSummary(
    id: id,
    backendId: int.parse(id),
    displayNumber: '#$id',
    type: OrderSummaryType.takeaway,
    customerName: 'Walk-in',
    status: OrderStatus.completed,
    itemCount: 0,
    timeAgo: 'Just now',
    items: const <OrderSummaryItem>[],
    total: 100,
  );
}

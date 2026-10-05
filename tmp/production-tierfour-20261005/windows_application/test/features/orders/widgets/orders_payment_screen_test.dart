import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
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
import 'package:windows_application/features/orders/views/orders_screen.dart';
import 'package:windows_application/features/pos/models/branch.dart';
import 'package:windows_application/features/pos/controllers/pos_cubit.dart';
import 'package:windows_application/features/pos/models/payment_method.dart';
import 'package:windows_application/features/pos/models/payment_result.dart';
import 'package:windows_application/features/pos/models/payment_summary.dart';
import 'package:windows_application/features/pos/widgets/payment_summary_panel.dart';

void main() {
  test('maps payment statuses without collapsing uncertainty', () {
    expect(
      paymentCompletionStatusFor(OrdersPaymentStatus.confirmed),
      PaymentCompletionStatus.completed,
    );
    expect(
      paymentCompletionStatusFor(OrdersPaymentStatus.retryableFailure),
      PaymentCompletionStatus.retryableFailure,
    );
    expect(
      paymentCompletionStatusFor(OrdersPaymentStatus.uncertain),
      PaymentCompletionStatus.uncertain,
    );
    for (final OrdersPaymentStatus status in <OrdersPaymentStatus>[
      OrdersPaymentStatus.idle,
      OrdersPaymentStatus.preparing,
      OrdersPaymentStatus.ready,
      OrdersPaymentStatus.submitting,
    ]) {
      expect(
        paymentCompletionStatusFor(status),
        PaymentCompletionStatus.uncertain,
      );
    }
  });

  testWidgets(
    'Pay loads authoritative outstanding amount before opening dialog',
    (WidgetTester tester) async {
      final _ScreenPaymentRepository repository = _ScreenPaymentRepository();
      final OrdersCubit cubit = OrdersCubit(repository: repository);
      addTearDown(cubit.close);
      tester.view.physicalSize = const Size(1280, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(
        MaterialApp(
          home: BlocProvider<OrdersCubit>.value(
            value: cubit,
            child: const OrdersScreen(),
          ),
        ),
      );
      await cubit.loadOrders();
      await tester.pumpAndSettle();

      await tester.tap(find.text('PAY'));
      await tester.pumpAndSettle();

      expect(repository.summaryRequests, 1);
      expect(find.text('Order #AUTH-7'), findsOneWidget);
      expect(find.text('Total Due'), findsOneWidget);
      expect(
        find.descendant(
          of: find.byType(PaymentSummaryPanel),
          matching: find.text('7 SYP'),
        ),
        findsOneWidget,
      );
      expect(find.text('2 Items'), findsWidgets);
    },
  );

  testWidgets('paid list-card data disables Pay and cannot open confirmation', (
    WidgetTester tester,
  ) async {
    final _ScreenPaymentRepository repository = _ScreenPaymentRepository(
      listPaymentStatus: 'paid',
    );
    final OrdersCubit cubit = OrdersCubit(repository: repository);
    addTearDown(cubit.close);
    tester.view.physicalSize = const Size(1280, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(
      MaterialApp(
        home: BlocProvider<OrdersCubit>.value(
          value: cubit,
          child: const OrdersScreen(),
        ),
      ),
    );
    await cubit.loadOrders();
    await tester.pumpAndSettle();

    expect(tester.widget<Text>(find.text('PAY')).style?.color, isNotNull);
    await tester.tap(find.text('PAY'));
    await tester.pumpAndSettle();

    expect(repository.summaryRequests, 0);
    expect(find.text('Total Due'), findsNothing);
  });

  testWidgets('double Pay taps make one authoritative preparation request', (
    WidgetTester tester,
  ) async {
    final _ScreenPaymentRepository repository = _ScreenPaymentRepository();
    final Completer<PaymentSummary> summary = Completer<PaymentSummary>();
    repository.summaryFuture = summary.future;
    final OrdersCubit cubit = OrdersCubit(repository: repository);
    addTearDown(cubit.close);
    tester.view.physicalSize = const Size(1280, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(
      MaterialApp(
        home: BlocProvider<OrdersCubit>.value(
          value: cubit,
          child: const OrdersScreen(),
        ),
      ),
    );
    await cubit.loadOrders();
    await tester.pumpAndSettle();

    await tester.tap(find.text('PAY'));
    await tester.pump();
    expect(repository.summaryRequests, 1);
    summary.complete(repository.authoritativeSummary);
    await tester.pumpAndSettle();

    expect(repository.summaryRequests, 1);
    expect(find.text('Total Due'), findsOneWidget);
  });

  testWidgets('details-panel Pay uses the same authoritative workflow', (
    WidgetTester tester,
  ) async {
    final _ScreenPaymentRepository repository = _ScreenPaymentRepository();
    final OrdersCubit cubit = OrdersCubit(repository: repository);
    addTearDown(cubit.close);
    tester.view.physicalSize = const Size(1280, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(
      MaterialApp(
        home: BlocProvider<OrdersCubit>.value(
          value: cubit,
          child: const OrdersScreen(),
        ),
      ),
    );
    await cubit.loadOrders();
    await tester.pumpAndSettle();
    await tester.tap(find.text('DETAILS'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Pay'));
    await tester.pumpAndSettle();

    expect(repository.summaryRequests, 1);
    expect(find.text('Order #AUTH-7'), findsOneWidget);
  });

  testWidgets('warehouse-blocked summary does not open the payment dialog', (
    WidgetTester tester,
  ) async {
    const String reason =
        'No active branch-main warehouse is configured. Configure one before paying.';
    final _ScreenPaymentRepository repository = _ScreenPaymentRepository(
      summary: const PaymentSummary(
        orderId: 7,
        orderNumber: '#AUTH-7',
        totalDue: 99,
        outstandingAmount: 99,
        itemCount: 2,
        amountReceived: 99,
        changeDue: 0,
        methods: <String>['cash'],
        quickAmounts: <double>[99],
        orderStatus: 'draft',
        paymentStatus: 'unpaid',
        canPay: false,
        blockerCode: 'WAREHOUSE_NOT_CONFIGURED',
        blockedReason: reason,
      ),
    );
    final OrdersCubit cubit = OrdersCubit(repository: repository);
    addTearDown(cubit.close);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: BlocProvider<OrdersCubit>.value(
            value: cubit,
            child: const OrdersScreen(),
          ),
        ),
      ),
    );
    await cubit.loadOrders();
    await tester.pumpAndSettle();

    await tester.tap(find.text('PAY'));
    await tester.pumpAndSettle();

    expect(repository.summaryRequests, 1);
    expect(repository.payRequests, 0);
    expect(find.text('Total Due'), findsNothing);
    expect(find.text(reason), findsOneWidget);
  });
}

class _ScreenPaymentRepository extends OrdersRepository {
  _ScreenPaymentRepository({this.listPaymentStatus = 'unpaid', this.summary});

  final String listPaymentStatus;
  final PaymentSummary? summary;
  int summaryRequests = 0;
  int payRequests = 0;
  Future<PaymentSummary>? summaryFuture;

  PaymentSummary get authoritativeSummary =>
      summary ??
      const PaymentSummary(
        orderId: 7,
        orderNumber: '#AUTH-7',
        totalDue: 99,
        outstandingAmount: 7,
        itemCount: 2,
        amountReceived: 7,
        changeDue: 0,
        methods: <String>['cash', 'card'],
        quickAmounts: <double>[7],
        orderStatus: 'draft',
        paymentStatus: 'unpaid',
        canPay: true,
      );

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
    return OrderPage(
      orders: <OrderSummary>[
        OrderSummary(
          id: '7',
          backendId: 7,
          displayNumber: '#AUTH-7',
          type: OrderSummaryType.takeaway,
          customerName: 'Authoritative Customer',
          status: OrderStatus.preparing,
          paymentStatus: listPaymentStatus,
          itemCount: 2,
          timeAgo: 'Just now',
          items: const <OrderSummaryItem>[],
          total: 99,
        ),
      ],
      currentPage: page,
      lastPage: 1,
      perPage: perPage,
      total: 1,
    );
  }

  @override
  Future<PaymentSummary> getPaymentSummary({
    required int orderId,
    double? amountReceived,
  }) {
    summaryRequests++;
    return summaryFuture ?? Future<PaymentSummary>.value(authoritativeSummary);
  }

  @override
  Future<PaymentResult> payOrder({
    required int orderId,
    required String method,
    required double amount,
    required String idempotencyKey,
    String? reference,
    required double totalDue,
  }) async {
    payRequests++;
    return PaymentResult(
      method: PaymentMethod.cash,
      totalDue: totalDue,
      amountReceived: amount,
      changeDue: 0,
      status: 'completed',
    );
  }

  @override
  Future<OrderDetail> getOrderDetail(int orderId) async => OrderDetail(
    id: orderId.toString(),
    displayNumber: '#AUTH-$orderId',
    status: OrderStatus.preparing,
    orderType: 'Takeaway',
    createdAt: DateTime(2026, 9, 14),
    customerName: 'Authoritative Customer',
    customerPhone: '',
    customerEmail: '',
    items: const <OrderDetailItem>[],
    subtotal: 99,
    tax: 0,
    tip: 0,
    total: 99,
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

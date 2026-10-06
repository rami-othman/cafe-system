import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:windows_application/app/localization/localization_extensions.dart';
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
import 'package:windows_application/features/pos/models/order_receipt.dart';
import 'package:windows_application/features/pos/widgets/receipt_preview_dialog.dart';
import 'package:windows_application/features/pos/widgets/payment_summary_panel.dart';

void main() {
  for (final String transition in <String>[
    'A to B',
    'A to B to A',
    'close/reopen',
  ]) {
    for (final bool fails in <bool>[false, true]) {
      testWidgets('stale history receipt is silent after $transition '
          '(fails: $fails)', (WidgetTester tester) async {
        final repository = _ScreenPaymentRepository();
        final cubit = OrdersCubit(repository: repository);
        addTearDown(cubit.close);
        tester.view.physicalSize = const Size(1280, 900);
        tester.view.devicePixelRatio = 1;
        addTearDown(() {
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
        });
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
        await cubit.loadOrders(branchId: 1);
        await cubit.openOrderDetails('7');
        await tester.pumpAndSettle();
        final pending = Completer<OrderReceipt>();
        repository.receiptFuture = pending.future;
        await tester.tap(find.byTooltip('Print order'));
        await tester.pump();
        expect(repository.receiptRequests, 1);

        if (transition == 'close/reopen') {
          cubit.closeOrderDetails();
          await cubit.openOrderDetails('7');
        } else {
          await cubit.applyBranchContext(2);
          if (transition == 'A to B to A') {
            await cubit.applyBranchContext(1);
            await cubit.openOrderDetails('7');
          }
        }
        if (fails) {
          pending.completeError(StateError('private backend error'));
        } else {
          pending.complete(_historyReceipt());
        }
        await tester.pumpAndSettle();

        expect(find.byType(ReceiptPreviewDialog), findsNothing);
        expect(find.byType(SnackBar), findsNothing);
        expect(tester.takeException(), isNull);
        expect(repository.payRequests, 0);
        expect(repository.summaryRequests, 0);
      });
    }
  }

  testWidgets(
    'current history receipt failure shows safe message and retries',
    (WidgetTester tester) async {
      final repository = _ScreenPaymentRepository();
      final cubit = OrdersCubit(repository: repository);
      addTearDown(cubit.close);
      tester.view.physicalSize = const Size(1280, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });
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
      await cubit.openOrderDetails('7');
      await tester.pumpAndSettle();
      for (int attempt = 1; attempt <= 2; attempt++) {
        final pending = Completer<OrderReceipt>();
        repository.receiptFuture = pending.future;
        await tester.tap(find.byTooltip('Print order'));
        await tester.pump();
        pending.completeError(StateError('private backend error'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));
        expect(repository.receiptRequests, attempt);
        expect(
          find.text(
            tester
                .element(find.byType(OrdersScreen))
                .l10n
                .posReceiptUnavailable,
          ),
          findsOneWidget,
        );
        expect(find.textContaining('private backend error'), findsNothing);
        ScaffoldMessenger.of(
          tester.element(find.byType(OrdersScreen)),
        ).removeCurrentSnackBar();
        await tester.pumpAndSettle();
      }
      expect(repository.payRequests, 0);
      expect(repository.summaryRequests, 0);
    },
  );

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
  Future<OrderReceipt>? receiptFuture;
  int receiptRequests = 0;

  @override
  Future<OrderReceipt> getReceipt(int orderId) {
    receiptRequests++;
    return receiptFuture ?? Future<OrderReceipt>.value(_historyReceipt());
  }

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
    Branch(
      id: 2,
      name: 'Branch B',
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

OrderReceipt _historyReceipt() => OrderReceipt(
  orderNumber: '#AUTH-7',
  branchName: 'Downtown',
  cashierName: 'Cashier',
  completedAt: DateTime(2026, 10, 6),
  items: const [],
  subtotal: 99,
  discountTotal: 0,
  discountLabel: null,
  tax: 0,
  total: 99,
  payment: const PaymentResult(
    method: PaymentMethod.cash,
    totalDue: 99,
    amountReceived: 99,
    changeDue: 0,
  ),
);

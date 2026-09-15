import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:windows_application/app/app.dart';
import 'package:windows_application/features/orders/controllers/orders_cubit.dart';
import 'package:windows_application/features/orders/controllers/orders_state.dart';
import 'package:windows_application/features/orders/models/order_page.dart';
import 'package:windows_application/features/orders/models/order_status.dart';
import 'package:windows_application/features/orders/models/order_summary.dart';
import 'package:windows_application/features/orders/models/order_summary_item.dart';
import 'package:windows_application/features/orders/models/order_type.dart';
import 'package:windows_application/features/orders/repositories/orders_repository.dart';
import 'package:windows_application/features/orders/views/orders_screen.dart';
import 'package:windows_application/features/pos/models/branch.dart';
import 'package:windows_application/core/services/service_locator.dart';

void main() {
  testWidgets('opens Orders from sidebar and hides POS cart panel', (
    WidgetTester tester,
  ) async {
    await _setupTestLocator();
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(const App());
    await tester.pumpAndSettle();

    expect(find.text('PAY 0 SYP'), findsOneWidget);

    await tester.tap(find.text('Orders'));
    await tester.pumpAndSettle();

    expect(find.text('Order Management'), findsOneWidget);
    expect(
      find.text('View and manage all active, held, and recent orders.'),
      findsOneWidget,
    );
    expect(find.text('PAY 0 SYP'), findsNothing);
    expect(find.text('Sarah Jenkins'), findsOneWidget);
    expect(find.text('Walk-in 4'), findsNothing);

    await tester.tap(find.text('HELD ORDERS'));
    await tester.pumpAndSettle();

    expect(find.text('Sarah Jenkins'), findsNothing);
    expect(find.text('Walk-in 4'), findsOneWidget);

    await tester.tap(find.text('RESUME'));
    await tester.pump();

    expect(
      find.text('Resume held order will be connected to POS later.'),
      findsNothing,
    );

    await tester.tap(find.text('POS'));
    await tester.pumpAndSettle();

    expect(find.text('Search products...'), findsOneWidget);
    expect(find.text('PAY 0 SYP'), findsOneWidget);
  });

  testWidgets('opens and closes order details panel from an order card', (
    WidgetTester tester,
  ) async {
    await _setupTestLocator();
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(const App());
    await tester.pumpAndSettle();

    await tester.tap(find.text('Orders'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('DETAILS').first);
    await tester.pumpAndSettle();

    expect(find.text('Customer'), findsOneWidget);
    expect(find.text('Order Items'), findsOneWidget);
    expect(find.text('Payment'), findsOneWidget);
    expect(find.text('Timeline'), findsOneWidget);
    expect(find.text('Sarah Jenkins'), findsWidgets);

    await tester.tap(find.byTooltip('Close order details'));
    await tester.pumpAndSettle();

    expect(find.text('Order Items'), findsNothing);
  });

  testWidgets('opens refund dialog and validates partial amount', (
    WidgetTester tester,
  ) async {
    await _setupTestLocator();
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(const App());
    await tester.pumpAndSettle();

    await tester.tap(find.text('Orders'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('DETAILS').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Refund'));
    await tester.pumpAndSettle();

    expect(find.textContaining('Refund Order #ORD-1042'), findsOneWidget);
    expect(find.text('Full Refund'), findsOneWidget);
    expect(find.text('Partial Refund'), findsOneWidget);
    expect(find.text('Confirm Refund'), findsOneWidget);

    await tester.tap(find.text('Partial Refund'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('refundAmountInput')),
      '999',
    );
    await tester.pumpAndSettle();

    expect(
      find.text('Refund amount cannot exceed refundable balance.'),
      findsOneWidget,
    );
    final ElevatedButton button = tester.widget<ElevatedButton>(
      find.widgetWithText(ElevatedButton, 'Confirm Refund'),
    );
    expect(button.onPressed, isNull);
  });

  testWidgets('confirming full refund updates order details panel', (
    WidgetTester tester,
  ) async {
    await _setupTestLocator();
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(const App());
    await tester.pumpAndSettle();

    await tester.tap(find.text('Orders'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('DETAILS').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Refund'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(ElevatedButton, 'Confirm Refund'));
    await tester.pumpAndSettle();

    expect(find.text('REFUNDED'), findsOneWidget);
    expect(find.text('Refunded'), findsWidgets);
    expect(find.text('Refund recorded.'), findsOneWidget);
  });

  testWidgets(
    'renders authoritative count, preview, page indicator, and boundaries',
    (WidgetTester tester) async {
      final _WidgetOrdersRepository repository = _WidgetOrdersRepository();
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

      expect(find.text('7 Items'), findsOneWidget);
      expect(find.text('1.5x Latte'), findsOneWidget);
      expect(find.text('Page 1 of 2'), findsOneWidget);
      final OutlinedButton previous = tester.widget<OutlinedButton>(
        find.byKey(const ValueKey<String>('ordersPreviousPage')),
      );
      expect(previous.onPressed, isNull);

      await tester.tap(find.byKey(const ValueKey<String>('ordersNextPage')));
      await tester.pump();
      expect(repository.pageRequests, <int>[1, 2]);
      expect(cubit.state.isPageLoading, isTrue);
      expect(
        tester
            .widget<OutlinedButton>(
              find.byKey(const ValueKey<String>('ordersNextPage')),
            )
            .onPressed,
        isNull,
      );

      repository.completePageTwo();
      await tester.pumpAndSettle();
      expect(find.text('Page 2 of 2'), findsOneWidget);
      expect(
        tester
            .widget<OutlinedButton>(
              find.byKey(const ValueKey<String>('ordersNextPage')),
            )
            .onPressed,
        isNull,
      );
      expect(
        tester
            .widget<OutlinedButton>(
              find.byKey(const ValueKey<String>('ordersPreviousPage')),
            )
            .onPressed,
        isNotNull,
      );
    },
  );
}

class _WidgetOrdersRepository extends OrdersRepository {
  final List<int> pageRequests = <int>[];
  final Completer<OrderPage> pageTwo = Completer<OrderPage>();

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
  }) {
    pageRequests.add(page);
    if (page == 2) {
      return pageTwo.future;
    }
    return Future<OrderPage>.value(
      const OrderPage(
        orders: <OrderSummary>[
          OrderSummary(
            id: '7',
            backendId: 7,
            displayNumber: '#ORD-007',
            type: OrderSummaryType.takeaway,
            customerName: 'Widget Customer',
            status: OrderStatus.preparing,
            itemCount: 7,
            timeAgo: 'Just now',
            items: <OrderSummaryItem>[
              OrderSummaryItem(quantity: 1.5, name: 'Latte', total: 4.5),
            ],
            total: 12.5,
          ),
        ],
        currentPage: 1,
        lastPage: 2,
        perPage: 1,
        total: 2,
      ),
    );
  }

  void completePageTwo() {
    pageTwo.complete(
      const OrderPage(
        orders: <OrderSummary>[
          OrderSummary(
            id: '8',
            backendId: 8,
            displayNumber: '#ORD-008',
            type: OrderSummaryType.takeaway,
            customerName: 'Second Widget Customer',
            status: OrderStatus.preparing,
            itemCount: 1,
            timeAgo: 'Just now',
            items: <OrderSummaryItem>[
              OrderSummaryItem(quantity: 1, name: 'Espresso', total: 2),
            ],
            total: 2,
          ),
        ],
        currentPage: 2,
        lastPage: 2,
        perPage: 1,
        total: 2,
      ),
    );
  }
}

Future<void> _setupTestLocator() async {
  await serviceLocator.reset();
  setupServiceLocator(useBackend: false);
}

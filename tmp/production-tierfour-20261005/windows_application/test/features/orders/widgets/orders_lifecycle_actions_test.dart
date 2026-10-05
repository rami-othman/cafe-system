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
import 'package:windows_application/features/orders/widgets/order_card_actions.dart';
import 'package:windows_application/features/pos/controllers/pos_cubit.dart';
import 'package:windows_application/features/pos/models/branch.dart';
import 'package:windows_application/features/pos/repositories/pos_repository.dart';

void main() {
  testWidgets(
    'Cancel confirmation dismisses without DELETE and confirms once',
    (WidgetTester tester) async {
      final _LifecycleScreenRepository repository =
          _LifecycleScreenRepository();
      final OrdersCubit ordersCubit = OrdersCubit(repository: repository);
      final PosCubit posCubit = PosCubit(repository: _ScreenPosRepository());
      addTearDown(ordersCubit.close);
      addTearDown(posCubit.close);

      await tester.pumpWidget(
        MultiBlocProvider(
          providers: [
            BlocProvider<OrdersCubit>.value(value: ordersCubit),
            BlocProvider<PosCubit>.value(value: posCubit),
          ],
          child: const MaterialApp(home: Scaffold(body: OrdersScreen())),
        ),
      );
      await ordersCubit.loadOrders();
      await tester.pumpAndSettle();

      await tester.tap(find.text('CANCEL'));
      await tester.pumpAndSettle();
      expect(find.text('Cancel order?'), findsOneWidget);
      expect(
        find.text('Cancel #ORD-7? This cannot be undone.'),
        findsOneWidget,
      );
      expect(find.textContaining('This cannot be undone.'), findsOneWidget);

      await tester.tap(find.text('Keep order'));
      await tester.pumpAndSettle();
      expect(repository.cancelRequests, 0);
      expect(find.text('Cancel order?'), findsNothing);

      await tester.tap(find.text('CANCEL'));
      await tester.pumpAndSettle();
      repository.cancelCompleter = Completer<void>();
      await tester.tap(find.byType(FilledButton));
      await tester.pump();
      await tester.tap(find.byType(FilledButton));
      await tester.pump();

      expect(repository.cancelRequests, 1);
      repository.cancelCompleter!.complete();
      await tester.pumpAndSettle();
      expect(find.text('Order cancelled.'), findsOneWidget);
    },
  );

  testWidgets('ready orders expose no actionable Complete control', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: OrderCardActionsForTest(
            order: _summary(status: OrderStatus.ready),
          ),
        ),
      ),
    );

    expect(find.text('COMPLETE'), findsNothing);
    expect(find.text('DETAILS'), findsOneWidget);
  });
}

/// A small public wrapper keeps this test focused on the production action
/// widget without depending on OrdersScreen's private layout classes.
class OrderCardActionsForTest extends StatelessWidget {
  const OrderCardActionsForTest({super.key, required this.order});

  final OrderSummary order;

  @override
  Widget build(BuildContext context) {
    return _ActionHarness(order: order);
  }
}

class _ActionHarness extends StatelessWidget {
  const _ActionHarness({required this.order});

  final OrderSummary order;

  @override
  Widget build(BuildContext context) {
    return OrderCardActions(
      order: order,
      onDetails: () {},
      onPay: () {},
      onResume: () {},
      onCancel: () {},
    );
  }
}

class _LifecycleScreenRepository extends OrdersRepository {
  _LifecycleScreenRepository() : super();

  int cancelRequests = 0;
  bool cancelled = false;
  Completer<void>? cancelCompleter;

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
  ];

  @override
  Future<OrderPage> getOrders({
    required int branchId,
    OrdersFilter? filter,
    int page = 1,
    int perPage = 25,
  }) async {
    return OrderPage.fromOrders(
      cancelled ? const <OrderSummary>[] : <OrderSummary>[_summary()],
      page: page,
      perPage: perPage,
    );
  }

  @override
  Future<OrderDetail> getOrderDetail(int orderId) async => _screenDetail();

  @override
  Future<void> cancelOrder(int orderId) async {
    cancelRequests++;
    if (cancelCompleter != null) {
      await cancelCompleter!.future;
    }
    cancelled = true;
  }
}

class _ScreenPosRepository extends PosRepository {
  _ScreenPosRepository() : super();

  @override
  bool get usesBackend => true;
}

OrderSummary _summary({OrderStatus status = OrderStatus.preparing}) =>
    OrderSummary(
      id: '7',
      backendId: 7,
      displayNumber: '#ORD-7',
      type: OrderSummaryType.takeaway,
      customerName: 'Walk-in',
      status: status,
      itemCount: 1,
      timeAgo: 'Just now',
      items: const <OrderSummaryItem>[],
      total: 5,
    );

OrderDetail _screenDetail() => OrderDetail(
  id: '7',
  displayNumber: '#ORD-7',
  status: OrderStatus.preparing,
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
  payment: const OrderPaymentSummary(
    methodLabel: 'Cash',
    statusLabel: 'Pending',
    authCode: '-',
    amount: 5,
    status: 'pending',
  ),
  timeline: const <OrderTimelineEvent>[],
  branchId: 1,
);

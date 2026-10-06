import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:windows_application/core/network/api_exception.dart';
import 'package:windows_application/features/orders/controllers/orders_cubit.dart';
import 'package:windows_application/features/orders/controllers/orders_state.dart';
import 'package:windows_application/features/orders/models/order_page.dart';
import 'package:windows_application/features/orders/models/order_summary.dart';
import 'package:windows_application/features/orders/models/order_status.dart';
import 'package:windows_application/features/orders/models/order_type.dart';
import 'package:windows_application/features/orders/repositories/orders_repository.dart';
import 'package:windows_application/features/orders/views/orders_screen.dart';
import 'package:windows_application/features/pos/models/branch.dart';
import 'package:windows_application/features/pos/models/payment_summary.dart';
import 'package:windows_application/features/pos/controllers/pos_cubit.dart';
import 'package:windows_application/features/pos/widgets/quoted_payment_dialog.dart';
import 'package:windows_application/l10n/app_localizations.dart';
import '../../pos/discount_engine_fixture.dart';

class QuotedOrdersFake extends OrdersRepository {
  QuotedOrdersFake(this.engine);
  final EngineFake engine;
  Object? summaryError;
  @override
  Future<List<Branch>> getBranches() async => const [
    Branch(
      id: 1,
      name: 'Branch',
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
  }) async => OrderPage(
    orders: const [
      OrderSummary(
        id: '42',
        backendId: 42,
        displayNumber: '#42',
        type: OrderSummaryType.takeaway,
        customerName: 'Test',
        status: OrderStatus.preparing,
        paymentStatus: 'unpaid',
        itemCount: 1,
        timeAgo: 'Now',
        items: [],
        total: 10,
      ),
    ],
    currentPage: 1,
    lastPage: 1,
    perPage: 25,
    total: 1,
  );
  @override
  Future<PaymentSummary> getPaymentSummary({
    required int orderId,
    double? amountReceived,
  }) async {
    if (summaryError != null) throw summaryError!;
    final s = await engine.getPaymentSummary(orderId: orderId);
    return PaymentSummary(
      orderId: 42,
      orderNumber: '42',
      totalDue: s.totalDue,
      itemCount: 1,
      amountReceived: 10,
      changeDue: 0,
      methods: s.methods,
      quickAmounts: s.quickAmounts,
      paymentMethods: s.paymentMethods,
      discountCapabilities: engine.caps,
      discounts: s.discounts,
    );
  }
}

void main() {
  test('operational preflight never retains raw server messages', () async {
    final engine = EngineFake();
    final repository = QuotedOrdersFake(engine)
      ..summaryError = const ApiException(
        message: 'private server details',
        statusCode: 500,
      );
    final orders = OrdersCubit(
      repository: repository,
      operationalRepository: engine,
    );
    await orders.loadOrders();
    expect(await orders.preparePayment('42'), null);
    expect(orders.state.paymentErrorMessage, 'd2:D2_GENERIC');
    await orders.close();
  });
  for (final language in ['en', 'ar']) {
    testWidgets(
      '$language Orders quote keeps POS cart and requires actual tender selection',
      (tester) async {
        tester.view.physicalSize = const Size(1280, 900);
        tester.view.devicePixelRatio = 1;
        addTearDown(() {
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
        });
        final engine = EngineFake();
        final currentCart = PosCubit(repository: EngineFake());
        await currentCart.loadInitialData();
        await currentCart.addCustomizedProductToCart(publishedItem());
        final orders = OrdersCubit(
          repository: QuotedOrdersFake(engine),
          operationalRepository: engine,
        );
        await orders.loadOrders();
        await tester.pumpWidget(
          MultiBlocProvider(
            providers: [
              BlocProvider.value(value: orders),
              BlocProvider.value(value: currentCart),
            ],
            child: MaterialApp(
              locale: Locale(language),
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              home: const Scaffold(body: OrdersScreen()),
            ),
          ),
        );
        await tester.pumpAndSettle();
        await tester.tap(find.text('PAY'));
        await tester.pumpAndSettle();
        expect(find.byType(QuotedPaymentDialog), findsOneWidget);
        expect(engine.paymentRequests, isEmpty);
        expect(currentCart.state.currentOrderId, 42);
        await tester.tap(find.byType(DropdownButtonFormField<int>));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Till cash').last);
        await tester.pumpAndSettle();
        final dedicated = tester
            .element(find.byType(QuotedPaymentDialog))
            .read<PosCubit>();
        expect(dedicated.state.discounts.quote!.paymentMethodId, 7);
        expect(identical(dedicated, currentCart), false);
        expect(currentCart.state.cartItems.single.quantity, 1);
        expect(engine.paymentRequests, isEmpty);
        expect(tester.takeException(), null);
        await tester.pumpWidget(const SizedBox());
        await orders.close();
        await currentCart.close();
      },
    );
  }
}

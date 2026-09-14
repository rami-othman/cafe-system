import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:windows_application/features/customer_management/controllers/customer_order_history_cubit.dart';
import 'package:windows_application/features/customer_management/models/customer_models.dart';
import 'package:windows_application/features/customer_management/models/customer_queries.dart';
import 'package:windows_application/features/customer_management/repositories/customer_management_repository.dart';
import 'package:windows_application/features/customer_management/views/customer_order_history_screen.dart';
import 'package:windows_application/l10n/app_localizations.dart';

void main() {
  testWidgets('uses the desktop table at 760 and LTR isolates order values', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(760, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: BlocProvider(
          create: (_) => CustomerOrderHistoryCubit(_OrdersRepository()),
          child: const Scaffold(
            body: CustomerOrderHistoryScreen(customerId: 1),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('customer-detail-header')), findsOneWidget);
    expect(find.byKey(const Key('customer-detail-tabs')), findsOneWidget);
    expect(
      find.byKey(const Key('customer-detail-overview-tab')),
      findsOneWidget,
    );
    expect(find.byKey(const Key('customer-detail-orders-tab')), findsOneWidget);
    expect(find.byType(DataTable), findsOneWidget);
    expect(
      find.byKey(const Key('customer-orders-table-width')),
      findsOneWidget,
    );
    expect(find.text('All'), findsNWidgets(2));
    expect(find.textContaining('ORD-1'), findsOneWidget);
    expect(find.text('Completed'), findsOneWidget);
    expect(find.text('Paid'), findsOneWidget);
    expect(find.text('Main'), findsWidgets);
  });

  testWidgets('uses localized semantic badges and cards below 760 in RTL', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(759, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('ar'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: BlocProvider(
          create: (_) => CustomerOrderHistoryCubit(_OrdersRepository()),
          child: const Scaffold(
            body: CustomerOrderHistoryScreen(customerId: 1),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(DataTable), findsNothing);
    expect(find.text('رقم الطلب'), findsOneWidget);
    expect(find.text('مكتمل'), findsOneWidget);
    expect(find.text('مدفوع'), findsOneWidget);
    expect(find.textContaining('01/09/2026 00:00'), findsOneWidget);
    expect(tester.getSemantics(find.text('مكتمل')).label, contains('مكتمل'));
  });

  testWidgets('opens the order date range in a bounded dialog', (tester) async {
    tester.view.physicalSize = const Size(1200, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: BlocProvider(
          create: (_) => CustomerOrderHistoryCubit(_OrdersRepository()),
          child: const Scaffold(
            body: CustomerOrderHistoryScreen(customerId: 1),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final Finder dateRange = find.byKey(
      const Key('customer-order-date-filter'),
    );
    expect(dateRange, findsOneWidget);
    await tester.tap(dateRange);
    await tester.pumpAndSettle();

    expect(find.byType(DateRangePickerDialog), findsOneWidget);
    expect(
      find.byWidgetPredicate(
        (Widget widget) =>
            widget is Theme &&
            widget.data.dialogTheme.constraints ==
                const BoxConstraints(maxWidth: 560, maxHeight: 660),
      ),
      findsWidgets,
    );
  });
}

class _OrdersRepository implements CustomerManagementRepository {
  @override
  Future<Customer> getCustomer(int id) async => const Customer(
    id: 1,
    customerNumber: 'C-001',
    name: 'Ada',
    lifecycle: CustomerLifecycle.active,
    phones: <CustomerPhone>[],
    groups: <CustomerGroupSummary>[],
    allowedActions: <String>{},
  );

  @override
  Future<List<CustomerOrderBranch>> listPermittedOrderBranches() async =>
      const <CustomerOrderBranch>[
        CustomerOrderBranch(id: 1, name: 'Main'),
        CustomerOrderBranch(id: 2, name: 'Airport'),
      ];
  @override
  Future<CustomerPage<CustomerOrder>> listCustomerOrders(
    int id,
    CustomerOrderQuery query,
  ) async => CustomerPage<CustomerOrder>(
    items: <CustomerOrder>[
      CustomerOrder(
        id: 1,
        orderNumber: 'ORD-1',
        branchId: 1,
        branchName: 'Main',
        createdAt: DateTime(2026, 9, 1),
        status: 'paid',
        paymentStatus: 'paid',
        totalAmount: '20.00',
        currency: 'SYP',
      ),
    ],
    meta: const CustomerPageMeta(
      currentPage: 1,
      lastPage: 1,
      perPage: 25,
      total: 1,
    ),
  );
  @override
  noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

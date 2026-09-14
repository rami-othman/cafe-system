import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:windows_application/core/network/api_exception.dart';
import 'package:windows_application/features/customer_management/controllers/customer_detail_cubit.dart';
import 'package:windows_application/features/customer_management/models/customer_models.dart';
import 'package:windows_application/features/customer_management/repositories/customer_management_repository.dart';
import 'package:windows_application/features/customer_management/views/customer_detail_screen.dart';
import 'package:windows_application/features/customer_management/widgets/customer_management_surface.dart';
import 'package:windows_application/l10n/app_localizations.dart';

void main() {
  testWidgets('renders the authoritative overview through its recent orders', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1440, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: BlocProvider<CustomerDetailCubit>(
          create: (_) => CustomerDetailCubit(_DetailRepository()),
          child: const Scaffold(body: CustomerDetailScreen(customerId: 7)),
        ),
      ),
    );
    await tester.pump();
    expect(find.text('C-007'), findsWidgets);
    expect(find.text('Primary'), findsOneWidget);
    expect(find.text('Work'), findsOneWidget);
    expect(find.text('\u2066ada@example.test\u2069'), findsOneWidget);
    expect(find.text('Archived Group'), findsOneWidget);
    expect(find.byType(CustomerManagementSurface), findsNWidgets(5));
    expect(
      find.byKey(const Key('customer-detail-information')),
      findsOneWidget,
    );
    expect(find.byKey(const Key('customer-detail-raw-number')), findsOneWidget);
    expect(find.byKey(const Key('customer-detail-phones')), findsOneWidget);
    expect(find.byKey(const Key('customer-detail-groups')), findsOneWidget);
    expect(find.byKey(const Key('customer-detail-notes')), findsOneWidget);
    expect(find.text('Total orders'), findsOneWidget);
    expect(find.text('Recent orders'), findsOneWidget);
    expect(
      find.byKey(const Key('customer-detail-recent-orders-table')),
      findsOneWidget,
    );
    expect(find.text('\u2066ORD-007\u2069'), findsOneWidget);
    expect(find.byKey(const Key('customer-detail-header')), findsOneWidget);
    expect(find.byKey(const Key('customer-detail-tabs')), findsOneWidget);
    expect(
      find.byKey(const Key('customer-detail-overview-tab')),
      findsOneWidget,
    );
    expect(find.byKey(const Key('customer-detail-orders-tab')), findsOneWidget);
  });

  testWidgets('renders localized absence values for an incomplete profile', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: BlocProvider<CustomerDetailCubit>(
          create: (_) =>
              CustomerDetailCubit(_DetailRepository(incomplete: true)),
          child: const Scaffold(body: CustomerDetailScreen(customerId: 8)),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('No phone'), findsOneWidget);
    expect(find.text('Not available'), findsAtLeastNWidgets(4));
  });

  testWidgets('uses order cards below the 760 logical-pixel breakpoint', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(740, 1200);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: BlocProvider<CustomerDetailCubit>(
          create: (_) => CustomerDetailCubit(_DetailRepository()),
          child: const Scaffold(body: CustomerDetailScreen(customerId: 7)),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.byKey(const Key('customer-detail-recent-orders-table')),
      findsNothing,
    );
    expect(find.text('Order number'), findsWidgets);
  });

  testWidgets(
    'keeps screenshot lifecycle actions visible beside the customer identity',
    (tester) async {
      final CustomerManagementRepository repository = _DetailRepository(
        active: true,
      );
      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: BlocProvider<CustomerDetailCubit>(
            create: (_) => CustomerDetailCubit(repository),
            child: Scaffold(
              body: CustomerDetailScreen(
                customerId: 7,
                lifecycleRepository: repository,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final AppLocalizations l10n = AppLocalizations.of(
        tester.element(find.byType(CustomerDetailScreen)),
      );
      expect(find.text('C-007'), findsWidgets);
      expect(find.byTooltip(l10n.cmvpOpenActions), findsNothing);
      expect(
        find.byKey(const Key('customer-lifecycle-deactivate')),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('customer-lifecycle-archive')),
        findsOneWidget,
      );
    },
  );

  testWidgets('View all orders opens the preserved customer orders route', (
    tester,
  ) async {
    final GoRouter router = GoRouter(
      initialLocation: '/customers/7',
      routes: <RouteBase>[
        GoRoute(
          path: '/customers/:customerId',
          builder: (_, _) => BlocProvider<CustomerDetailCubit>(
            create: (_) => CustomerDetailCubit(_DetailRepository()),
            child: const Scaffold(body: CustomerDetailScreen(customerId: 7)),
          ),
        ),
        GoRoute(
          path: '/customers/:customerId/orders',
          builder: (_, _) => const Scaffold(body: Text('orders-route')),
        ),
      ],
    );
    addTearDown(router.dispose);
    await tester.pumpWidget(
      MaterialApp.router(
        routerConfig: router,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
      ),
    );
    await tester.pumpAndSettle();
    final Finder viewAll = find.byKey(
      const Key('customer-detail-view-all-orders'),
    );
    await tester.drag(
      find.byKey(const Key('customer-detail-scroll')),
      const Offset(0, -1100),
    );
    await tester.pumpAndSettle();
    await tester.tap(viewAll);
    await tester.pumpAndSettle();

    expect(router.state.uri.path, '/customers/7/orders');
    expect(find.text('orders-route'), findsOneWidget);
  });

  testWidgets('renders a forbidden detail state without retry', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: BlocProvider<CustomerDetailCubit>(
          create: (_) => CustomerDetailCubit(
            _DetailRepository(
              error: const ApiException(
                message: 'forbidden',
                statusCode: 403,
                type: ApiErrorType.forbidden,
              ),
            ),
          ),
          child: const Scaffold(body: CustomerDetailScreen(customerId: 9)),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.text('You do not have permission to view this content.'),
      findsOneWidget,
    );
    expect(find.text('Retry'), findsNothing);
  });
}

class _DetailRepository implements CustomerManagementRepository {
  _DetailRepository({this.incomplete = false, this.active = false, this.error});
  final bool incomplete;
  final bool active;
  final Object? error;

  @override
  Future<Customer> getCustomer(int id) async {
    if (error != null) throw error!;
    if (incomplete) {
      return Customer(
        id: id,
        customerNumber: 'C-$id',
        name: 'Incomplete',
        lifecycle: CustomerLifecycle.active,
        phones: const <CustomerPhone>[],
        groups: const <CustomerGroupSummary>[],
        allowedActions: const <String>{},
      );
    }
    if (active) {
      return const Customer(
        id: 7,
        customerNumber: 'C-007',
        name: 'Ada',
        lifecycle: CustomerLifecycle.active,
        phones: <CustomerPhone>[
          CustomerPhone(id: 1, rawNumber: '+1', type: 'work', isPrimary: true),
        ],
        groups: <CustomerGroupSummary>[],
        allowedActions: <String>{'update', 'deactivate', 'archive'},
      );
    }
    return const Customer(
      id: 7,
      customerNumber: 'C-007',
      name: 'Ada',
      lifecycle: CustomerLifecycle.archived,
      email: 'ada@example.test',
      birthDate: null,
      notes: 'Note',
      phones: <CustomerPhone>[
        CustomerPhone(id: 1, rawNumber: '+1', type: 'work', isPrimary: true),
        CustomerPhone(id: 2, rawNumber: '+2', type: 'home', isPrimary: false),
      ],
      groups: <CustomerGroupSummary>[
        CustomerGroupSummary(
          id: 1,
          name: 'Archived Group',
          lifecycle: CustomerLifecycle.archived,
        ),
      ],
      allowedActions: <String>{},
    );
  }

  @override
  Future<CustomerOverview> getCustomerOverview(int id) async {
    final Customer customer = await getCustomer(id);
    return CustomerOverview(
      customer: customer,
      summary: CustomerOrderSummary(
        totalOrders: incomplete ? 0 : 1,
        totalSpending: incomplete
            ? null
            : const CustomerMoney(amount: '25.00', currency: 'SYP'),
        averageOrderValue: incomplete
            ? null
            : const CustomerMoney(amount: '25.00', currency: 'SYP'),
        lastOrderAt: incomplete ? null : DateTime.utc(2026, 9, 8),
      ),
      recentOrders: incomplete
          ? const <CustomerOrder>[]
          : <CustomerOrder>[
              CustomerOrder(
                id: 1,
                orderNumber: 'ORD-007',
                branchId: 1,
                branchName: 'Main',
                createdAt: DateTime.utc(2026, 9, 8),
                status: 'paid',
                paymentStatus: 'paid',
                totalAmount: '25.00',
                currency: 'SYP',
              ),
            ],
    );
  }

  @override
  noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

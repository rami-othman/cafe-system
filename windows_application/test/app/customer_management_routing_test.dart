import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:windows_application/app/app.dart';
import 'package:windows_application/app/app_router.dart';
import 'package:windows_application/app/customer_management_route_locations.dart';
import 'package:windows_application/app/app_shell.dart';
import 'package:windows_application/core/services/service_locator.dart';
import 'package:windows_application/features/auth/models/auth_session.dart';
import 'package:windows_application/features/auth/repositories/auth_session_storage.dart';
import 'package:windows_application/features/customer_management/widgets/customer_management_module_tabs.dart';
import 'package:windows_application/features/customer_management/models/customer_group_models.dart';
import 'package:windows_application/features/customer_management/models/customer_models.dart';
import 'package:windows_application/features/customer_management/models/customer_queries.dart';
import 'package:windows_application/features/customer_management/controllers/customer_group_list_cubit.dart';
import 'package:windows_application/features/customer_management/repositories/customer_management_repository.dart';
import 'package:windows_application/l10n/app_localizations.dart';
import 'package:windows_application/features/customer_management/views/customer_group_list_screen.dart';
import 'package:windows_application/features/customer_management/views/customer_group_form_screen.dart';

void main() {
  tearDown(() async {
    appRouter.go(AppRoutes.pos);
    await serviceLocator.reset();
  });

  test(
    'builds every direct Customer Management route without cached records',
    () {
      expect(CustomerManagementRouteLocations.customers, '/customers');
      expect(CustomerManagementRouteLocations.customerCreate, '/customers/new');
      expect(CustomerManagementRouteLocations.customer(1), '/customers/1');
      expect(
        CustomerManagementRouteLocations.editCustomer(1),
        '/customers/1/edit',
      );
      expect(CustomerManagementRouteLocations.groups, '/customers/groups');
      expect(
        CustomerManagementRouteLocations.groupCreate,
        '/customers/groups/new',
      );
      expect(CustomerManagementRouteLocations.group(2), '/customers/groups/2');
      expect(
        CustomerManagementRouteLocations.editGroup(2),
        '/customers/groups/2/edit',
      );
      expect(CustomerManagementRouteLocations.parseId('0'), isNull);
      expect(CustomerManagementRouteLocations.parseId('2'), 2);
    },
  );

  testWidgets('direct /customers navigation is denied without capability', (
    WidgetTester tester,
  ) async {
    await _configureAuthenticatedApp(canManageCustomers: false);
    appRouter.go(CustomerManagementRouteLocations.customers);

    await _pumpApp(tester);

    expect(appRouter.state.uri.path, AppRoutes.pos);
  });

  testWidgets('direct /customers navigation is permitted with capability', (
    WidgetTester tester,
  ) async {
    await _configureAuthenticatedApp(canManageCustomers: true);
    appRouter.go(CustomerManagementRouteLocations.customers);

    await _pumpApp(tester);

    expect(
      appRouter.state.uri.path,
      CustomerManagementRouteLocations.customers,
    );
    expect(find.byType(AppShell), findsOneWidget);
    expect(find.byType(CustomerManagementModuleTabs), findsOneWidget);
    expect(
      find.byKey(const ValueKey<String>('customer-management-page-title')),
      findsOneWidget,
    );
    expect(
      find.byKey(
        const ValueKey<String>('customer-management-page-description'),
      ),
      findsOneWidget,
    );
    expect(find.text('Customers'), findsWidgets);
  });

  testWidgets(
    'all Customer Management routes keep their localized hierarchy and tab',
    (WidgetTester tester) async {
      await _configureAuthenticatedApp(
        canManageCustomers: true,
        repository: _RouterRepository(),
      );
      appRouter.go(CustomerManagementRouteLocations.customers);

      await _pumpApp(tester);
      final AppLocalizations l10n = AppLocalizations.of(
        tester.element(find.byType(AppShell).first),
      );
      final List<_RouteExpectation> routes = <_RouteExpectation>[
        _RouteExpectation(
          path: CustomerManagementRouteLocations.customers,
          title: l10n.customerManagementCustomers,
          description: l10n.cmvpCustomersDescription,
          breadcrumb: l10n.cmvpBreadcrumbCustomers,
          groupsSelected: false,
        ),
        _RouteExpectation(
          path: CustomerManagementRouteLocations.customerCreate,
          title: l10n.customerManagementCreateTitle,
          description: l10n.cmvpCustomerFormDescription,
          breadcrumb: l10n.cmvpBreadcrumbCreate,
          groupsSelected: false,
        ),
        _RouteExpectation(
          path: CustomerManagementRouteLocations.customer(7),
          title: 'Ada',
          description: '',
          breadcrumb: 'Ada',
          groupsSelected: false,
        ),
        _RouteExpectation(
          path: CustomerManagementRouteLocations.editCustomer(7),
          title: l10n.customerManagementEditTitle,
          description: l10n.cmvpCustomerFormDescription,
          breadcrumb: l10n.cmvpBreadcrumbEdit,
          groupsSelected: false,
        ),
        _RouteExpectation(
          path: CustomerManagementRouteLocations.groups,
          title: l10n.customerManagementGroups,
          description: l10n.cmvpGroupsDescription,
          breadcrumb: l10n.cmvpBreadcrumbGroups,
          groupsSelected: true,
        ),
        _RouteExpectation(
          path: CustomerManagementRouteLocations.groupCreate,
          title: l10n.customerManagementCreateGroup,
          description: l10n.cmvpGroupFormDescription,
          breadcrumb: l10n.cmvpBreadcrumbCreate,
          groupsSelected: true,
        ),
        _RouteExpectation(
          path: CustomerManagementRouteLocations.group(3),
          title: 'VIP',
          description: '',
          breadcrumb: 'VIP',
          groupsSelected: true,
        ),
        _RouteExpectation(
          path: CustomerManagementRouteLocations.editGroup(3),
          title: l10n.customerManagementEdit,
          description: l10n.cmvpGroupFormDescription,
          breadcrumb: l10n.cmvpBreadcrumbEdit,
          groupsSelected: true,
        ),
      ];

      for (final _RouteExpectation route in routes) {
        appRouter.go(route.path);
        await tester.pumpAndSettle();
        while (tester.takeException() != null) {}

        expect(appRouter.state.uri.path, route.path);
        expect(find.byType(CustomerManagementModuleTabs), findsOneWidget);
        if (route.path == CustomerManagementRouteLocations.groups) {
          expect(find.byType(CustomerGroupListScreen), findsOneWidget);
        }
        if (route.path == CustomerManagementRouteLocations.groupCreate) {
          expect(find.byType(CustomerGroupListScreen), findsOneWidget);
          expect(
            find.byKey(const Key('customer-group-create-dialog')),
            findsOneWidget,
          );
        }
        final CustomerManagementModuleTabs tabs = tester.widget(
          find.byType(CustomerManagementModuleTabs),
        );
        expect(tabs.groupsSelected, route.groupsSelected);
        expect(
          find.byKey(const ValueKey<String>('customer-management-page-title')),
          findsOneWidget,
          reason: 'route ${route.path} should expose its page header',
        );
        expect(find.text(route.title), findsWidgets);
        if (route.description.isEmpty) {
          expect(find.text(l10n.cmvpGroupDetailDescription), findsNothing);
        } else {
          expect(find.text(route.description), findsWidgets);
        }
        if (route.path != CustomerManagementRouteLocations.groupCreate) {
          expect(find.text(route.breadcrumb), findsWidgets);
        }
      }
    },
  );

  testWidgets('direct create route loads its mounted group list once', (
    WidgetTester tester,
  ) async {
    final _ModalRouterRepository repository = _ModalRouterRepository();
    await _configureAuthenticatedApp(
      canManageCustomers: true,
      repository: repository,
    );
    appRouter.go(CustomerManagementRouteLocations.groupCreate);

    await _pumpApp(tester);

    expect(find.byType(CustomerGroupListScreen), findsOneWidget);
    expect(find.byType(CustomerGroupFormScreen), findsOneWidget);
    expect(repository.groupRequests, 1);
  });

  testWidgets(
    'clean create modal dismisses by Cancel, Escape, backdrop, and Back',
    (WidgetTester tester) async {
      final _ModalRouterRepository repository = _ModalRouterRepository();
      await _configureAuthenticatedApp(
        canManageCustomers: true,
        repository: repository,
      );
      appRouter.go(CustomerManagementRouteLocations.groups);
      await _pumpApp(tester);

      for (final Future<void> Function(WidgetTester) dismiss
          in <Future<void> Function(WidgetTester)>[
            (tester) async =>
                tester.tap(find.byKey(const Key('customer-group-form-cancel'))),
            (tester) async => tester.sendKeyEvent(LogicalKeyboardKey.escape),
            (tester) async => tester.tapAt(const Offset(8, 8)),
            (tester) async => appRouter.pop(),
          ]) {
        await tester.tap(find.byKey(const Key('customer-group-create')));
        await tester.pumpAndSettle();
        expect(find.byType(CustomerGroupFormScreen), findsOneWidget);
        for (int index = 0; index < 4; index++) {
          await tester.sendKeyEvent(LogicalKeyboardKey.tab);
        }
        expect(
          FocusManager.instance.primaryFocus?.context
              ?.findAncestorWidgetOfExactType<Dialog>(),
          isNotNull,
          reason: 'tab traversal must remain inside the create modal',
        );
        await dismiss(tester);
        await tester.pumpAndSettle();
        expect(find.byType(CustomerGroupFormScreen), findsNothing);
        expect(find.byType(CustomerGroupListScreen), findsOneWidget);
        expect(repository.groupRequests, 1);
        expect(
          Focus.of(
            tester.element(find.byKey(const Key('customer-group-create'))),
          ).hasFocus,
          isTrue,
        );
      }
    },
  );

  testWidgets(
    'dirty create modal retains its draft on Keep Editing and leaves on Back',
    (WidgetTester tester) async {
      await _configureAuthenticatedApp(
        canManageCustomers: true,
        repository: _ModalRouterRepository(),
      );
      appRouter.go(CustomerManagementRouteLocations.groups);
      await _pumpApp(tester);
      await tester.tap(find.byKey(const Key('customer-group-create')));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const Key('customer-group-name')),
        'VIP',
      );

      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();
      expect(find.text('Discard unsaved changes?'), findsOneWidget);
      await tester.tap(find.text('Keep editing'));
      await tester.pumpAndSettle();
      expect(find.byType(CustomerGroupFormScreen), findsOneWidget);
      expect(
        tester
            .widget<EditableText>(
              find.descendant(
                of: find.byKey(const Key('customer-group-name')),
                matching: find.byType(EditableText),
              ),
            )
            .controller
            .text,
        'VIP',
      );

      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(find.text('Discard unsaved changes?'), findsOneWidget);
      await tester.tap(find.text('Leave'));
      await tester.pumpAndSettle();
      expect(find.byType(CustomerGroupFormScreen), findsNothing);
      expect(find.byType(CustomerGroupListScreen), findsOneWidget);
    },
  );

  testWidgets(
    'create dialog retains the mounted group list criteria, page, and scroll',
    (WidgetTester tester) async {
      final _RetainedListRepository repository = _RetainedListRepository();
      await _configureAuthenticatedApp(
        canManageCustomers: true,
        repository: repository,
      );
      appRouter.go(CustomerManagementRouteLocations.groups);
      await _pumpApp(tester);

      await tester.enterText(find.byType(TextField).first, 'VIP');
      await tester.testTextInput.receiveAction(TextInputAction.search);
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('customer-group-status-active')));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Next page'));
      await tester.pumpAndSettle();

      final ScrollableState listScroll = tester.state<ScrollableState>(
        find
            .descendant(
              of: find.byKey(const Key('customer-group-list-scroll')),
              matching: find.byType(Scrollable),
            )
            .first,
      );
      listScroll.position.jumpTo(24);
      await tester.pump();
      final CustomerGroupListCubit mountedCubit =
          BlocProvider.of<CustomerGroupListCubit>(
            tester.element(find.byType(CustomerGroupListScreen)),
          );
      final int requestsBeforeDialog = repository.groupRequests;

      await tester.tap(find.byKey(const Key('customer-group-create')));
      await tester.pumpAndSettle();
      expect(
        BlocProvider.of<CustomerGroupListCubit>(
          tester.element(find.byType(CustomerGroupListScreen)),
        ),
        same(mountedCubit),
      );
      expect(repository.groupRequests, requestsBeforeDialog);

      await tester.tap(find.byKey(const Key('customer-group-form-cancel')));
      await tester.pumpAndSettle();
      expect(find.byType(CustomerGroupFormScreen), findsNothing);
      expect(find.text('VIP'), findsWidgets);
      expect(find.text('Active'), findsWidgets);
      expect(find.text('Page 2 of 2'), findsOneWidget);
      expect(listScroll.position.pixels, 24);

      await tester.tap(find.byKey(const Key('customer-group-create')));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const Key('customer-group-name')),
        'Draft',
      );
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Keep editing'));
      await tester.pumpAndSettle();
      expect(repository.groupRequests, requestsBeforeDialog);
      expect(listScroll.position.pixels, 24);
    },
  );

  testWidgets('create success navigates with the backend returned group id', (
    WidgetTester tester,
  ) async {
    await _configureAuthenticatedApp(
      canManageCustomers: true,
      repository: _ModalRouterRepository(createId: 41),
    );
    appRouter.go(CustomerManagementRouteLocations.groups);
    await _pumpApp(tester);
    await tester.tap(find.byKey(const Key('customer-group-create')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('customer-group-name')), 'VIP');
    await tester.tap(find.byKey(const Key('customer-group-save')));
    await tester.pumpAndSettle();

    expect(
      appRouter.state.uri.path,
      CustomerManagementRouteLocations.group(41),
    );
  });
}

Future<void> _configureAuthenticatedApp({
  required bool canManageCustomers,
  CustomerManagementRepository? repository,
}) async {
  await serviceLocator.reset();
  serviceLocator.registerLazySingleton<AuthSessionStorage>(
    () => MemoryAuthSessionStorage(
      AuthSession(
        accessToken: 'test-session-token',
        user: const AuthUser(
          id: 1,
          name: 'Test Manager',
          role: 'manager',
          email: 'manager@example.test',
        ),
        tenant: const AuthTenant(id: 1, name: 'Test Cafe'),
        mustChangePassword: false,
        lastValidatedAt: DateTime.utc(2026, 9, 11),
        offlineSessionMaxAgeSeconds: 43200,
        customerManagementAllowed: canManageCustomers,
      ),
    ),
  );
  setupServiceLocator(useBackend: false);
  if (repository != null) {
    await serviceLocator.unregister<CustomerManagementRepository>();
    serviceLocator.registerLazySingleton<CustomerManagementRepository>(
      () => repository,
    );
  }
}

Future<void> _pumpApp(WidgetTester tester) async {
  tester.view.physicalSize = const Size(1280, 1200);
  tester.view.devicePixelRatio = 1;
  addTearDown(() {
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });
  await tester.pumpWidget(const App());
  await tester.pumpAndSettle();
  while (tester.takeException() != null) {}
}

class _RouteExpectation {
  const _RouteExpectation({
    required this.path,
    required this.title,
    required this.description,
    required this.breadcrumb,
    required this.groupsSelected,
  });

  final String path;
  final String title;
  final String description;
  final String breadcrumb;
  final bool groupsSelected;
}

class _RouterRepository implements CustomerManagementRepository {
  static const Customer _customer = Customer(
    id: 7,
    customerNumber: 'C-000007',
    name: 'Ada',
    lifecycle: CustomerLifecycle.active,
    phones: <CustomerPhone>[
      CustomerPhone(
        id: 1,
        rawNumber: '+963 11 000 0000',
        type: 'mobile',
        isPrimary: true,
      ),
    ],
    groups: <CustomerGroupSummary>[
      CustomerGroupSummary(
        id: 3,
        name: 'VIP',
        lifecycle: CustomerLifecycle.active,
      ),
    ],
    allowedActions: <String>{'update'},
  );

  static const CustomerGroup _group = CustomerGroup(
    id: 3,
    name: 'VIP',
    lifecycle: CustomerLifecycle.active,
    memberCount: 1,
  );

  static const CustomerPageMeta _meta = CustomerPageMeta(
    currentPage: 1,
    lastPage: 1,
    perPage: 25,
    total: 1,
  );

  @override
  Future<Customer> getCustomer(int id) async => _customer;

  @override
  Future<CustomerOverview> getCustomerOverview(int id) async =>
      const CustomerOverview(
        customer: _customer,
        summary: CustomerOrderSummary(totalOrders: 0),
        recentOrders: <CustomerOrder>[],
      );

  @override
  Future<CustomerGroup> getGroup(int id) async => _group;

  @override
  Future<CustomerPage<Customer>> listCustomers(CustomerListQuery query) async =>
      const CustomerPage<Customer>(items: <Customer>[_customer], meta: _meta);

  @override
  Future<CustomerPage<CustomerGroup>> listGroups(
    CustomerGroupListQuery query,
  ) async => const CustomerPage<CustomerGroup>(
    items: <CustomerGroup>[_group],
    meta: _meta,
  );

  @override
  Future<CustomerPage<Customer>> listGroupMembers(
    int groupId,
    CustomerGroupListQuery query,
  ) async =>
      const CustomerPage<Customer>(items: <Customer>[_customer], meta: _meta);

  @override
  noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _ModalRouterRepository implements CustomerManagementRepository {
  _ModalRouterRepository({this.createId});

  final int? createId;
  int groupRequests = 0;

  static const CustomerGroup _group = CustomerGroup(
    id: 3,
    name: 'VIP',
    lifecycle: CustomerLifecycle.active,
    memberCount: 1,
  );

  static const CustomerPageMeta _meta = CustomerPageMeta(
    currentPage: 1,
    lastPage: 1,
    perPage: 25,
    total: 1,
  );

  @override
  Future<CustomerPage<CustomerGroup>> listGroups(
    CustomerGroupListQuery query,
  ) async {
    groupRequests++;
    return const CustomerPage<CustomerGroup>(
      items: <CustomerGroup>[_group],
      meta: _meta,
    );
  }

  @override
  Future<CustomerGroup> createGroup(_) async => CustomerGroup(
    id: createId ?? 3,
    name: 'VIP',
    lifecycle: CustomerLifecycle.active,
    memberCount: 0,
  );

  @override
  Future<CustomerGroup> getGroup(int id) async => CustomerGroup(
    id: id,
    name: 'VIP',
    lifecycle: CustomerLifecycle.active,
    memberCount: 1,
  );

  @override
  Future<CustomerPage<Customer>> listGroupMembers(int groupId, _) async =>
      const CustomerPage<Customer>(items: <Customer>[], meta: _meta);

  @override
  noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _RetainedListRepository extends _ModalRouterRepository {
  @override
  Future<CustomerPage<CustomerGroup>> listGroups(
    CustomerGroupListQuery query,
  ) async {
    groupRequests++;
    return CustomerPage<CustomerGroup>(
      items: List<CustomerGroup>.generate(
        40,
        (int index) => CustomerGroup(
          id: query.page * 100 + index,
          name: 'VIP ${query.page}-$index',
          lifecycle: CustomerLifecycle.active,
          memberCount: index + 1,
        ),
      ),
      meta: CustomerPageMeta(
        currentPage: query.page,
        lastPage: 2,
        perPage: 25,
        total: 40,
      ),
    );
  }
}

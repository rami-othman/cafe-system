import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:windows_application/app/app_shell.dart';
import 'package:windows_application/core/network/dio_api_client.dart';
import 'package:windows_application/features/auth/controllers/auth_session_cubit.dart';
import 'package:windows_application/features/auth/models/auth_session.dart';
import 'package:windows_application/features/auth/repositories/auth_repository.dart';
import 'package:windows_application/features/auth/repositories/auth_session_storage.dart';
import 'package:windows_application/shared/widgets/app_sidebar.dart';

void main() {
  testWidgets(
    'Owner with server capability sees Customers and Cafe Configuration',
    (WidgetTester tester) async {
      final AuthSessionCubit cubit = await _authenticatedCubit(
        _session(role: 'owner', canManageCustomers: true),
      );
      addTearDown(cubit.close);

      await _pumpShell(tester, cubit);

      expect(find.text('Customers'), findsOneWidget);
      expect(find.text('Cafe Configuration'), findsOneWidget);
      expect(find.text('Menu Management'), findsOneWidget);
      expect(find.text('Reports'), findsOneWidget);
    },
  );

  testWidgets('Granted Manager sees Customers but not Cafe Configuration', (
    WidgetTester tester,
  ) async {
    final AuthSessionCubit cubit = await _authenticatedCubit(
      _session(role: 'manager', canManageCustomers: true),
    );
    addTearDown(cubit.close);

    await _pumpShell(tester, cubit);

    expect(find.text('Customers'), findsOneWidget);
    expect(find.text('Cafe Configuration'), findsNothing);
    expect(find.text('Menu Management'), findsOneWidget);
    expect(find.text('Reports'), findsOneWidget);
  });

  testWidgets('Owner without server capability does not see Customers', (
    WidgetTester tester,
  ) async {
    final AuthSessionCubit cubit = await _authenticatedCubit(
      _session(role: 'owner', canManageCustomers: false),
    );
    addTearDown(cubit.close);

    await _pumpShell(tester, cubit);

    expect(find.text('Customers'), findsNothing);
  });

  testWidgets(
    'Ungranted Manager does not see Customers or Cafe Configuration',
    (WidgetTester tester) async {
      final AuthSessionCubit cubit = await _authenticatedCubit(
        _session(role: 'manager', canManageCustomers: false),
      );
      addTearDown(cubit.close);

      await _pumpShell(tester, cubit);

      expect(find.text('Customers'), findsNothing);
      expect(find.text('Cafe Configuration'), findsNothing);
      expect(find.text('Menu Management'), findsOneWidget);
      expect(find.text('Reports'), findsOneWidget);
    },
  );

  testWidgets(
    'mounted sidebar updates after auth refresh replaces legacy Owner capability',
    (WidgetTester tester) async {
      final _SessionRepository repository = _SessionRepository(
        loginSession: _session(role: 'owner', canManageCustomers: false),
        refreshedSession: _session(role: 'owner', canManageCustomers: true),
      );
      final _SessionStorage storage = _SessionStorage();
      final AuthSessionCubit cubit = _cubit(
        repository: repository,
        storage: storage,
      );
      addTearDown(cubit.close);
      await cubit.login(identifier: 'owner@example.test', password: 'password');

      await _pumpShell(tester, cubit);
      expect(find.text('Customers'), findsNothing);

      await cubit.restore();
      await tester.pump();

      expect(find.text('Customers'), findsOneWidget);
      expect((await storage.read())?.customerManagementAllowed, isTrue);
    },
  );

  testWidgets(
    'mounted sidebar removes Customers after Manager capability revocation',
    (WidgetTester tester) async {
      final _SessionRepository repository = _SessionRepository(
        loginSession: _session(role: 'manager', canManageCustomers: true),
        refreshedSession: _session(role: 'manager', canManageCustomers: false),
      );
      final AuthSessionCubit cubit = _cubit(
        repository: repository,
        storage: _SessionStorage(),
      );
      addTearDown(cubit.close);
      await cubit.login(
        identifier: 'manager@example.test',
        password: 'password',
      );

      await _pumpShell(tester, cubit);
      expect(find.text('Customers'), findsOneWidget);

      await cubit.restore();
      await tester.pump();

      expect(find.text('Customers'), findsNothing);
    },
  );

  // The till roles now get the Cashier operational navigation rather than a
  // trimmed copy of the management one: Reports is a management surface and is
  // no longer offered to them. `employee` is the role code the authentication
  // API returns; `cashier` is its legacy alias. Both must behave identically.
  for (final String role in <String>['employee', 'cashier']) {
    testWidgets('$role gets the Cashier navigation, not the management one', (
      WidgetTester tester,
    ) async {
      await _pumpSidebar(
        tester,
        role,
        financeCapabilities: const <String>{'finance.vouchers.view'},
      );

      expect(find.text('Menu Management'), findsNothing);
      expect(find.text('Reports'), findsNothing);
      expect(find.text('Home'), findsOneWidget);
      expect(find.text('POS'), findsOneWidget);
      expect(find.text('Inventory'), findsOneWidget);
      expect(find.text('Finance'), findsOneWidget);
    });
  }

  testWidgets('Cashier without Finance access does not see its sidebar link', (
    WidgetTester tester,
  ) async {
    await _pumpSidebar(tester, 'cashier');

    expect(find.text('Finance'), findsNothing);
  });

  testWidgets('Owner sees Menu Management and retains Reports', (
    WidgetTester tester,
  ) async {
    await _pumpSidebar(tester, 'owner');

    expect(find.text('Menu Management'), findsOneWidget);
    expect(find.text('Reports'), findsOneWidget);
  });

  testWidgets('Manager sees Menu Management and retains Reports', (
    WidgetTester tester,
  ) async {
    await _pumpSidebar(tester, 'manager');

    expect(find.text('Menu Management'), findsOneWidget);
    expect(find.text('Reports'), findsOneWidget);
  });

  testWidgets('Owner sees Cafe Configuration', (WidgetTester tester) async {
    await _pumpSidebar(tester, 'owner');

    expect(find.text('Cafe Configuration'), findsOneWidget);
  });

  testWidgets('Manager does not see Cafe Configuration', (
    WidgetTester tester,
  ) async {
    await _pumpSidebar(tester, 'manager');

    expect(find.text('Cafe Configuration'), findsNothing);
  });

  testWidgets('Employee does not see Cafe Configuration', (
    WidgetTester tester,
  ) async {
    await _pumpSidebar(tester, 'employee');

    expect(find.text('Cafe Configuration'), findsNothing);
  });

  testWidgets('Employee and Cashier both reach the operational stock view', (
    WidgetTester tester,
  ) async {
    for (final String role in <String>['employee', 'cashier']) {
      await _pumpSidebar(tester, role);
      expect(find.text('Inventory'), findsOneWidget, reason: role);
    }
  });
}

Future<AuthSessionCubit> _authenticatedCubit(AuthSession session) async {
  final AuthSessionCubit cubit = _cubit(
    repository: _SessionRepository(
      loginSession: session,
      refreshedSession: session,
    ),
    storage: _SessionStorage(),
  );
  await cubit.login(identifier: session.user.email!, password: 'password');
  return cubit;
}

AuthSessionCubit _cubit({
  required _SessionRepository repository,
  required _SessionStorage storage,
}) => AuthSessionCubit(
  repository: repository,
  storage: storage,
  apiClient: DioApiClient(),
  now: () => DateTime.utc(2026, 9, 11),
);

Future<void> _pumpShell(WidgetTester tester, AuthSessionCubit cubit) async {
  tester.view.physicalSize = const Size(1280, 1200);
  tester.view.devicePixelRatio = 1;
  addTearDown(() {
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });
  await tester.pumpWidget(
    MaterialApp(
      home: BlocProvider<AuthSessionCubit>.value(
        value: cubit,
        child: const AppShell(
          activeLabel: 'POS',
          topBar: SizedBox.shrink(),
          child: SizedBox.shrink(),
        ),
      ),
    ),
  );
  await tester.pump();
}

Future<void> _pumpSidebar(
  WidgetTester tester,
  String role, {
  Set<String> financeCapabilities = const <String>{},
}) async {
  // Explicit, tall-enough surface: the default test surface is too short to
  // mount every sidebar item's Element (ListView/Sliver virtualization only
  // builds what's within the viewport + cache extent) now that the owner
  // role's item count grew with Cafe Configuration — without this, `find`
  // can miss items pushed past the cache extent, not because they're absent.
  tester.view.physicalSize = const Size(1280, 900);
  tester.view.devicePixelRatio = 1;
  addTearDown(() {
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: AppSidebar(
          activeLabel: 'POS',
          actorRole: role,
          financeCapabilities: financeCapabilities,
        ),
      ),
    ),
  );
  await tester.pump();
}

AuthSession _session({
  required String role,
  required bool canManageCustomers,
}) => AuthSession(
  accessToken: 'opaque-token',
  user: AuthUser(id: 7, name: role, role: role, email: '$role@example.test'),
  tenant: const AuthTenant(id: 4, name: 'Cafe 618'),
  mustChangePassword: false,
  lastValidatedAt: DateTime.utc(2026, 9, 11),
  offlineSessionMaxAgeSeconds: 43200,
  customerManagementAllowed: canManageCustomers,
);

class _SessionStorage implements AuthSessionStorage {
  AuthSession? _session;

  @override
  Future<void> clear() async => _session = null;

  @override
  Stream<void> get changes => const Stream<void>.empty();

  @override
  Future<AuthSession?> read() async => _session;

  @override
  Future<void> write(AuthSession session) async => _session = session;
}

class _SessionRepository implements AuthRepository {
  _SessionRepository({
    required this.loginSession,
    required this.refreshedSession,
  });

  final AuthSession loginSession;
  final AuthSession refreshedSession;

  @override
  Future<void> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {}

  @override
  Future<AuthSession> login({
    required String identifier,
    required String password,
  }) async => loginSession;

  @override
  Future<void> logout() async {}

  @override
  Future<AuthSession> me(AuthSession cachedSession) async => refreshedSession;
}

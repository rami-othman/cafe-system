import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:windows_application/app/app.dart';
import 'package:windows_application/app/app_router.dart';
import 'package:windows_application/app/customer_management_route_locations.dart';
import 'package:windows_application/core/services/service_locator.dart';
import 'package:windows_application/features/auth/models/auth_session.dart';
import 'package:windows_application/features/auth/repositories/auth_session_storage.dart';

/// Proves cashier route restrictions are enforced centrally at the router
/// level (see CashierAccess/_cashierAccessRedirect in app_router.dart), not
/// only by hiding sidebar items — a direct URL/deep link into a forbidden
/// module must still redirect back to POS.
void main() {
  tearDown(() async {
    appRouter.go(AppRoutes.pos);
    await serviceLocator.reset();
  });

  testWidgets('cashier cannot open admin/privileged routes by direct navigation', (
    WidgetTester tester,
  ) async {
    await _configureAuthenticatedApp(role: 'employee');

    for (final String forbidden in <String>[
      AppRoutes.inventory,
      AppRoutes.finance,
      AppRoutes.reports,
      AppRoutes.cafeConfigurationOverview,
      AppRoutes.menuManagementProducts,
    ]) {
      appRouter.go(forbidden);
      await _pumpApp(tester);
      expect(
        appRouter.state.uri.path,
        AppRoutes.pos,
        reason: '$forbidden must redirect a cashier back to POS',
      );
    }
  });

  testWidgets(
    'cashier (legacy "cashier" role spelling) cannot open admin routes either',
    (WidgetTester tester) async {
      await _configureAuthenticatedApp(role: 'cashier');

      appRouter.go(AppRoutes.inventory);
      await _pumpApp(tester);
      expect(appRouter.state.uri.path, AppRoutes.pos);
    },
  );

  testWidgets('cashier keeps direct access to POS, Orders, Discounts, Settings', (
    WidgetTester tester,
  ) async {
    await _configureAuthenticatedApp(role: 'employee');

    for (final String allowed in <String>[
      AppRoutes.orders,
      AppRoutes.discounts,
      AppRoutes.settings,
      AppRoutes.shiftClose,
    ]) {
      appRouter.go(allowed);
      await _pumpApp(tester);
      expect(
        appRouter.state.uri.path,
        allowed,
        reason: '$allowed must remain reachable for a cashier',
      );
    }
  });

  testWidgets('cashier with granted customer capability keeps /customers', (
    WidgetTester tester,
  ) async {
    await _configureAuthenticatedApp(role: 'employee', canManageCustomers: true);

    appRouter.go(CustomerManagementRouteLocations.customers);
    await _pumpApp(tester);

    expect(
      appRouter.state.uri.path,
      CustomerManagementRouteLocations.customers,
    );
  });

  testWidgets('owner and manager admin route access is unchanged', (
    WidgetTester tester,
  ) async {
    await _configureAuthenticatedApp(role: 'owner');
    appRouter.go(AppRoutes.inventory);
    await _pumpApp(tester);
    expect(appRouter.state.uri.path, AppRoutes.inventory);

    await _configureAuthenticatedApp(role: 'manager');
    appRouter.go(AppRoutes.finance);
    await _pumpApp(tester);
    expect(appRouter.state.uri.path, AppRoutes.finance);
  });
}

Future<void> _configureAuthenticatedApp({
  required String role,
  bool canManageCustomers = false,
}) async {
  await serviceLocator.reset();
  serviceLocator.registerLazySingleton<AuthSessionStorage>(
    () => MemoryAuthSessionStorage(
      AuthSession(
        accessToken: 'test-session-token',
        user: AuthUser(
          id: 1,
          name: 'Test User',
          role: role,
          email: '$role@example.test',
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

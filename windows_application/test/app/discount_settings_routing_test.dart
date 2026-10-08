import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:windows_application/app/app.dart';
import 'package:windows_application/app/app_router.dart';
import 'package:windows_application/core/network/api_exception.dart';
import 'package:windows_application/core/services/service_locator.dart';
import 'package:windows_application/features/auth/models/auth_session.dart';
import 'package:windows_application/features/auth/repositories/auth_session_storage.dart';
import 'package:windows_application/features/cafe_configuration/controllers/discount_settings_cubit.dart';
import 'package:windows_application/features/cafe_configuration/repositories/discount_settings_repository.dart';
import 'package:windows_application/features/cafe_configuration/views/discount_settings_screen.dart';
import '../features/cafe_configuration/discount_settings_test.dart'
    show SettingsFake;

void main() {
  tearDown(() async {
    appRouter.go(AppRoutes.pos);
    await serviceLocator.reset();
  });
  for (final role in ['owner', 'manager', 'employee', 'cashier', 'admin']) {
    testWidgets(
      'direct settings access for $role stays within configuration scope',
      (tester) async {
        await configure(role);
        final r = SettingsFake();
        await serviceLocator.unregister<DiscountSettingsRepository>();
        serviceLocator.registerLazySingleton<DiscountSettingsRepository>(
          () => r,
        );
        await pumpApp(tester);
        appRouter.go(AppRoutes.cafeConfigurationDiscountSettings);
        await tester.pumpAndSettle();
        if (role == 'owner' || role == 'manager') {
          // The old configuration path is an alias of Discounts → Settings.
          expect(find.byType(DiscountSettingsScreen), findsOneWidget);
          expect(appRouter.state.uri.path, AppRoutes.discountSettings);
        } else {
          expect(
            appRouter.state.uri.path,
            role == 'employee' || role == 'cashier'
                ? AppRoutes.dashboard
                : AppRoutes.pos,
          );
          expect(find.byType(DiscountSettingsScreen), findsNothing);
        }
        if (role == 'manager') {
          for (final path in [
            AppRoutes.cafeConfigurationProfile,
            AppRoutes.cafeConfigurationTax,
            AppRoutes.cafeConfigurationBranches,
            AppRoutes.cafeConfigurationTeam,
          ]) {
            appRouter.go(path);
            await tester.pumpAndSettle();
            expect(appRouter.state.uri.path, AppRoutes.pos);
          }
        }
        checkBaselineDiagnostics(tester);
      },
    );
  }
  for (final role in ['owner', 'manager', 'employee']) {
    testWidgets('Discounts → Settings tab and route for $role', (tester) async {
      await configure(role);
      final r = SettingsFake();
      await serviceLocator.unregister<DiscountSettingsRepository>();
      serviceLocator.registerLazySingleton<DiscountSettingsRepository>(() => r);
      await pumpApp(tester);
      appRouter.go(AppRoutes.discountSettings);
      await tester.pumpAndSettle();
      final allowed = role != 'employee';
      expect(
        find.byType(DiscountSettingsScreen),
        allowed ? findsOneWidget : findsNothing,
      );
      if (allowed) {
        expect(appRouter.state.uri.path, AppRoutes.discountSettings);
        expect(find.byKey(const Key('discounts-area-tabs')), findsOneWidget);
        await tester.tap(find.byKey(const Key('discounts-tab-policies')));
        await tester.pumpAndSettle();
        expect(appRouter.state.uri.path, AppRoutes.discounts);
        expect(find.byKey(const Key('discounts-tab-settings')), findsOneWidget);
      }
      checkBaselineDiagnostics(tester);
    });
  }
  testWidgets(
    'server revocation on a direct Manager route clears draft and forbids save',
    (tester) async {
      await configure('manager');
      final r = SettingsFake();
      r.readError = const ApiException(
        message: 'private backend content',
        statusCode: 403,
      );
      await serviceLocator.unregister<DiscountSettingsRepository>();
      serviceLocator.registerLazySingleton<DiscountSettingsRepository>(() => r);
      appRouter.go(AppRoutes.cafeConfigurationDiscountSettings);
      await pumpApp(tester);
      final element = tester.element(find.byType(DiscountSettingsScreen));
      final c = serviceLocator<DiscountSettingsCubit>();
      // Verify rendered denial, without manufacturing a successful capability.
      expect(
        find.descendant(
          of: find.byType(DiscountSettingsScreen),
          matching: find.byType(TextField),
        ),
        findsNothing,
      );
      expect(find.textContaining('private backend'), findsNothing);
      expect(element.mounted, true);
      await c.load();
      expect(c.state.status, DiscountSettingsStatus.forbidden);
      await c.close();
    },
  );
}

Future<void> configure(String role) async {
  await serviceLocator.reset();
  serviceLocator.registerLazySingleton<AuthSessionStorage>(
    () => MemoryAuthSessionStorage(
      AuthSession(
        accessToken: 'settings-$role',
        user: AuthUser(id: 1, name: 'Settings actor', role: role),
        tenant: const AuthTenant(id: 1, name: 'Test Cafe'),
        mustChangePassword: false,
        lastValidatedAt: DateTime.now().toUtc().subtract(
          const Duration(minutes: 1),
        ),
        offlineSessionMaxAgeSeconds: 43200,
      ),
    ),
  );
  setupServiceLocator(useBackend: false);
}

Future<void> pumpApp(WidgetTester tester) async {
  tester.view.physicalSize = const Size(1280, 1200);
  tester.view.devicePixelRatio = 1;
  addTearDown(() {
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });
  await tester.pumpWidget(const App());
  await tester.pumpAndSettle();
  checkBaselineDiagnostics(tester);
}

void checkBaselineDiagnostics(WidgetTester tester) {
  // Existing POS ListTile/ColoredBox debug diagnostic also appears in the
  // pre-existing routing suites. Keep every unexpected/layout error fatal.
  Object? error;
  while ((error = tester.takeException()) != null) {
    expect(
      error.toString(),
      startsWith('ListTile background color or ink splashes may be invisible.'),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'package:windows_application/app/app.dart';
import 'package:windows_application/core/services/service_locator.dart';
import 'package:windows_application/features/auth/repositories/auth_session_storage_contract.dart';

/// Real end-to-end check: runs the actual compiled app (via
/// `IntegrationTestWidgetsFlutterBinding`, which does not fake HTTP the way
/// plain `flutter test` does) against the live local backend, logging in as
/// a person would. Requires `docker compose up backend` running with the
/// factory phase migrations applied and the `ManufacturingDemoSeeder` demo
/// user seeded (`factory.demo@cafe618.test` / `FactoryDemo123`, bound to
/// "المعمل التجريبي" — see the Phase 1 report). Run with:
///   flutter test integration_test/factory_manager_live_flow_test.dart -d windows
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'factory_manager: branch context, sidebar, and every module tab load '
    'against the real local backend',
    (WidgetTester tester) async {
      // flutter_secure_storage's Windows plugin needs a real installed app
      // identity to create its credential store; under the integration_test
      // runner that is flaky and is not what this test verifies (session
      // persistence). Use in-memory storage; `useBackend: true` still wires
      // the real Dio-based AuthRepository against the live local backend.
      serviceLocator.registerLazySingleton<AuthSessionStorage>(
        MemoryAuthSessionStorage.new,
      );
      setupServiceLocator();

      await tester.pumpWidget(const App());
      await tester.pumpAndSettle(const Duration(seconds: 5));

      // Land on the real login screen (no dev auto-login is used here).
      expect(find.byKey(const Key('auth-identifier-field')), findsOneWidget);

      await tester.enterText(
        find.byKey(const Key('auth-identifier-field')),
        'factory.demo@cafe618.test',
      );
      await tester.enterText(
        find.byKey(const Key('auth-password-field')),
        'FactoryDemo123',
      );
      await tester.tap(find.byKey(const Key('auth-login-submit-button')));
      await tester.pumpAndSettle(const Duration(seconds: 5));

      // Phase 1: factory_manager lands on /manufacturing directly, not POS.
      expect(find.text('نقطة البيع'), findsNothing);
      expect(find.text('POS'), findsNothing);

      // Phase 2: dedicated sidebar labelled المعمل (not التصنيع, which is
      // the Owner's shared entry), the overview page titled نظرة عامة, one
      // factory branch so the top bar shows a context title rather than
      // branch tabs, and no shift badge.
      expect(find.text('المعمل'), findsWidgets);
      expect(find.text('نظرة عامة'), findsWidgets);
      expect(find.textContaining('وردية'), findsNothing);
      expect(find.text('لوحة التحكم'), findsNothing);
      expect(find.text('Dashboard'), findsNothing);

      // Materials.
      await tester.tap(find.text('المواد والأرصدة').first);
      await tester.pumpAndSettle(const Duration(seconds: 3));
      expect(find.text('المواد'), findsWidgets);

      // Recipes.
      await tester.tap(find.text('الوصفات').first);
      await tester.pumpAndSettle(const Duration(seconds: 3));
      expect(find.text('الوصفات'), findsWidgets);

      // Production.
      await tester.tap(find.text('الإنتاج').first);
      await tester.pumpAndSettle(const Duration(seconds: 3));
      expect(find.text('سجل الإنتاج'), findsOneWidget);

      // Stock counts (الجرد) — Phase 2's new tab, factory warehouse only.
      await tester.tap(find.text('الجرد').first);
      await tester.pumpAndSettle(const Duration(seconds: 3));
      expect(find.text('الجرد المخزني'), findsOneWidget);

      // Purchasing (shared Finance screen, reused as-is).
      await tester.tap(find.text('المشتريات').first);
      await tester.pumpAndSettle(const Duration(seconds: 3));
      expect(find.text('المشتريات'), findsWidgets);

      // Sales (shared Finance screen, reused as-is).
      await tester.tap(find.text('المبيعات').first);
      await tester.pumpAndSettle(const Duration(seconds: 3));
      expect(find.text('المبيعات'), findsWidgets);

      // Full Finance workspace.
      await tester.tap(find.text('المالية').first);
      await tester.pumpAndSettle(const Duration(seconds: 3));

      // Reports.
      await tester.tap(find.text('تقارير المعمل').first);
      await tester.pumpAndSettle(const Duration(seconds: 3));
    },
  );
}

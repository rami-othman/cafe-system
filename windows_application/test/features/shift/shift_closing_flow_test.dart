import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:windows_application/app/shift_route_locations.dart';
import 'package:windows_application/features/shift/controllers/shift_closing_cubit.dart';
import 'package:windows_application/features/shift/controllers/shift_closing_state.dart';
import 'package:windows_application/features/shift/repositories/shift_mock_repository.dart';
import 'package:windows_application/features/shift/views/shift_closing_screen.dart';
import 'package:windows_application/l10n/app_localizations.dart';

/// One integration-level test walking the full five-step closing wizard for
/// the balanced scenario: operations review -> cash count (exact match,
/// no reason needed) -> bar count (accept-all-matching) -> final review ->
/// confirm dialog -> sealed success screen.
///
/// This is the single high-value wizard test: it proves the cubit and the
/// five step views actually agree on state across navigation, which unit
/// tests on the cubit alone cannot catch. Per-scenario/per-field coverage is
/// intentionally left for a follow-up pass.
void main() {
  testWidgets('closes a balanced shift through all five wizard steps', (
    WidgetTester tester,
  ) async {
    // A realistic desktop window instead of the default 800x600 test
    // surface: several wizard steps (bar count, final review, success) are
    // long-form content meant to scroll on their own page, not fight a
    // tiny viewport in this test.
    tester.view.physicalSize = const Size(1280, 1600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final ShiftMockRepository repository = ShiftMockRepository(
      clock: () => DateTime(2026, 9, 15, 16, 7),
    );
    final ShiftClosingCubit cubit = ShiftClosingCubit(repository: repository);
    addTearDown(cubit.close);

    final GoRouter router = GoRouter(
      initialLocation: ShiftRouteLocations.closing,
      routes: <RouteBase>[
        GoRoute(
          path: ShiftRouteLocations.closing,
          builder: (context, state) => Scaffold(
            body: BlocProvider<ShiftClosingCubit>.value(
              value: cubit,
              child: const ShiftClosingScreen(),
            ),
          ),
        ),
        GoRoute(
          path: ShiftRouteLocations.reportPattern,
          builder: (context, state) => Scaffold(
            body: Center(
              key: const Key('shift-report-route-marker'),
              child: Text('report:${state.pathParameters['shiftNumber']}'),
            ),
          ),
        ),
      ],
    );
    addTearDown(router.dispose);

    await tester.pumpWidget(
      MaterialApp.router(
        routerConfig: router,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        locale: const Locale('ar'),
        builder: (context, child) =>
            Directionality(textDirection: TextDirection.rtl, child: child!),
      ),
    );
    await tester.pumpAndSettle();

    // Step 1 — operations review: just advance.
    await tester.tap(find.byKey(const Key('shift-wizard-next')));
    await tester.pumpAndSettle();

    // Step 2 — cash count: enter the exact expected amount so no
    // difference-reason field appears, then advance.
    await tester.enterText(
      find.byKey(const Key('shift-cash-actual-field')),
      '21750',
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('shift-wizard-next')));
    await tester.pumpAndSettle();

    // Step 3 — bar count: accept every uncounted item as matching, then
    // advance.
    await tester.tap(find.byKey(const Key('shift-bar-accept-all')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('shift-bar-accept-all-confirm')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('shift-wizard-next')));
    await tester.pumpAndSettle();

    // Step 4 — final review: the confirm button sits below the fold on a
    // short test surface, same as it would on a small window — scroll it
    // into view before opening the confirmation dialog.
    final Finder confirmCloseButton = find.byKey(const Key('shift-open-confirm-close'));
    expect(confirmCloseButton, findsOneWidget);
    await tester.ensureVisible(confirmCloseButton);
    await tester.pumpAndSettle();
    await tester.tap(confirmCloseButton);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('shift-close-acknowledge-checkbox')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('shift-close-confirm-button')));
    await tester.pumpAndSettle();

    // Step 5 — success.
    final Finder viewReportButton = find.byKey(const Key('shift-success-view-report'));
    expect(viewReportButton, findsOneWidget);
    expect(cubit.state.status, ShiftClosingStatus.closed);
    expect(cubit.state.result, isNotNull);
    expect(cubit.state.result!.cash.isBalanced, isTrue);

    await tester.ensureVisible(viewReportButton);
    await tester.pumpAndSettle();
    await tester.tap(viewReportButton);
    await tester.pumpAndSettle();
    expect(
      find.text('report:${cubit.state.result!.snapshot.identity.shiftNumber}'),
      findsOneWidget,
      reason: '"عرض التقرير" must push the sealed shift\'s report route',
    );
  });
}

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:windows_application/features/pos/controllers/pos_print_state.dart';
import 'package:windows_application/features/pos/widgets/pos_print_failure_dialog.dart';
import 'package:windows_application/l10n/app_localizations.dart';

void main() {
  testWidgets(
    'Printer Setup from a print failure raised inside another modal closes '
    'both dialogs and leaves nothing stacked over Settings',
    (WidgetTester tester) async {
      final GoRouter router = GoRouter(
        initialLocation: '/',
        routes: <RouteBase>[
          GoRoute(
            path: '/',
            builder: (BuildContext context, GoRouterState state) => Scaffold(
              body: Center(
                child: ElevatedButton(
                  key: const Key('open-owning-modal'),
                  onPressed: () => showDialog<void>(
                    context: context,
                    // Stands in for ReceiptPreviewDialog: a modal that owns
                    // the print action and is still open when the print
                    // fails.
                    builder: (BuildContext dialogContext) => AlertDialog(
                      key: const Key('owning-modal'),
                      content: ElevatedButton(
                        key: const Key('trigger-print'),
                        onPressed: () => showPosPrintFailure(
                          context: dialogContext,
                          outcome: const PosPrintOutcome.failed(
                            PosPrintFailure.printerNotConfigured,
                          ),
                          retry: () async => const PosPrintOutcome.failed(
                            PosPrintFailure.printerNotConfigured,
                          ),
                          onOpenPrinterSetup: () =>
                              Navigator.of(dialogContext).pop(),
                        ),
                        child: const Text('Print'),
                      ),
                    ),
                  ),
                  child: const Text('Open preview'),
                ),
              ),
            ),
          ),
          GoRoute(
            path: '/settings',
            builder: (BuildContext context, GoRouterState state) =>
                const Scaffold(body: Text('Settings screen marker')),
          ),
        ],
      );

      await tester.pumpWidget(
        MaterialApp.router(
          routerConfig: router,
          locale: const Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
        ),
      );

      await tester.tap(find.byKey(const Key('open-owning-modal')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('owning-modal')), findsOneWidget);

      await tester.tap(find.byKey(const Key('trigger-print')));
      await tester.pumpAndSettle();
      // Both the owning modal (underneath) and the failure dialog (on top)
      // are AlertDialogs at this point.
      expect(find.byType(AlertDialog), findsNWidgets(2));

      await tester.tap(find.text('Printer Setup'));
      await tester.pumpAndSettle();

      // Neither dialog is left stacked over Settings.
      expect(find.byType(AlertDialog), findsNothing);
      expect(find.byKey(const Key('owning-modal')), findsNothing);
      expect(find.text('Settings screen marker'), findsOneWidget);
    },
  );

  testWidgets(
    'Printer Setup from a print failure with no owning modal navigates '
    'without popping unrelated routes',
    (WidgetTester tester) async {
      final GoRouter router = GoRouter(
        initialLocation: '/',
        routes: <RouteBase>[
          GoRoute(
            path: '/',
            builder: (BuildContext context, GoRouterState state) => Scaffold(
              body: Center(
                child: ElevatedButton(
                  key: const Key('trigger-print'),
                  onPressed: () => showPosPrintFailure(
                    context: context,
                    outcome: const PosPrintOutcome.failed(
                      PosPrintFailure.printerNotConfigured,
                    ),
                    retry: () async => const PosPrintOutcome.failed(
                      PosPrintFailure.printerNotConfigured,
                    ),
                  ),
                  child: const Text('Print'),
                ),
              ),
            ),
          ),
          GoRoute(
            path: '/settings',
            builder: (BuildContext context, GoRouterState state) =>
                const Scaffold(body: Text('Settings screen marker')),
          ),
        ],
      );

      await tester.pumpWidget(
        MaterialApp.router(
          routerConfig: router,
          locale: const Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
        ),
      );

      await tester.tap(find.byKey(const Key('trigger-print')));
      await tester.pumpAndSettle();
      expect(find.byType(AlertDialog), findsOneWidget);

      await tester.tap(find.text('Printer Setup'));
      await tester.pumpAndSettle();

      expect(find.byType(AlertDialog), findsNothing);
      expect(find.text('Settings screen marker'), findsOneWidget);
    },
  );
}

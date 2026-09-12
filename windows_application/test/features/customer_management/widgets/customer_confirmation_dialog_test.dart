import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:windows_application/features/customer_management/widgets/customer_confirmation_dialog.dart';
import 'package:windows_application/l10n/app_localizations.dart';

void main() {
  testWidgets('confirmation dialog exposes localized consequence and cancel', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: Builder(
            builder: (BuildContext context) => FilledButton(
              onPressed: () => showDialog<bool>(
                context: context,
                builder: (_) => const CustomerConfirmationDialog(
                  title: 'Archive VIP?',
                  message: 'The group remains in history.',
                  confirmLabel: 'Archive',
                ),
              ),
              child: const Text('Open'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();

    expect(
      find.byKey(const Key('customer-confirmation-dialog')),
      findsOneWidget,
    );
    expect(find.text('Archive VIP?'), findsOneWidget);
    expect(find.text('The group remains in history.'), findsOneWidget);
    expect(find.text('Cancel'), findsOneWidget);
    expect(find.text('Archive'), findsOneWidget);
    expect(find.byType(AlertDialog), findsOneWidget);
  });

  testWidgets('pending confirmation disables actions and shows progress', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: const Scaffold(
          body: CustomerConfirmationDialog(
            title: 'Remove member?',
            message: 'The member will be removed.',
            confirmLabel: 'Remove',
            isPending: true,
          ),
        ),
      ),
    );
    await tester.pump();

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(
      tester
          .widget<TextButton>(
            find.byKey(const Key('customer-confirmation-cancel')),
          )
          .onPressed,
      isNull,
    );
    expect(
      tester
          .widget<FilledButton>(
            find.byKey(const Key('customer-confirmation-confirm')),
          )
          .onPressed,
      isNull,
    );
  });
}

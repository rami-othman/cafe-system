import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:windows_application/features/pos/controllers/pos_cubit.dart';
import 'package:windows_application/features/pos/models/delivery_company.dart';
import 'package:windows_application/features/pos/models/order_type.dart';
import 'package:windows_application/features/pos/models/payment_method.dart';
import 'package:windows_application/features/pos/models/payment_result.dart';
import 'package:windows_application/features/pos/widgets/payment_dialog.dart';
import 'package:windows_application/l10n/app_localizations.dart';

void main() {
  testWidgets('cash amount updates change due', (WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        locale: Locale('en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(body: PaymentDialog(totalDue: 24.5, itemCount: 3)),
      ),
    );

    await tester.enterText(find.byType(TextField), '30');
    await tester.pump();

    expect(find.text('Change Due'), findsOneWidget);
    expect(find.text('5.5 SYP'), findsOneWidget);
  });

  testWidgets('order type is mandatory; delivery is cash-now unless on account', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(1000, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
    PaymentResult? submitted;
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: PaymentDialog(
            totalDue: 24.5,
            itemCount: 3,
            requireOrderType: true,
            deliveryCompanies: const <DeliveryCompany>[
              DeliveryCompany(id: 1, name: 'Lista'),
              DeliveryCompany(id: 2, name: 'Other'),
            ],
            onSubmit: (PaymentResult result) async {
              submitted = result;
              return PaymentCompletionStatus.retryableFailure;
            },
          ),
        ),
      ),
    );

    FilledButton confirm() => tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, 'Confirm Payment'),
    );

    expect(find.text('Choose the order type to continue.'), findsOneWidget);
    expect(confirm().onPressed, isNull);

    await tester.tap(find.text('Takeaway'));
    await tester.pump();
    expect(find.text('Choose the order type to continue.'), findsNothing);
    expect(confirm().onPressed, isNotNull);

    // Delivery: cash now by default, no company required.
    await tester.tap(find.text('Delivery'));
    await tester.pump();
    expect(confirm().onPressed, isNotNull);
    expect(find.byKey(const Key('delivery-collect-now')), findsNothing);

    // Picking a company reveals the collection choice (cash now by default).
    await tester.tap(find.byKey(const Key('delivery-company-1')));
    await tester.pump();
    expect(find.byKey(const Key('delivery-collect-now')), findsOneWidget);
    expect(confirm().onPressed, isNotNull);

    await tester.tap(find.byKey(const Key('delivery-collect-on-account')));
    await tester.pump();
    expect(confirm().onPressed, isNotNull);

    await tester.tap(find.widgetWithText(FilledButton, 'Confirm Payment'));
    await tester.pump();

    expect(submitted?.orderType, OrderType.delivery);
    expect(submitted?.deliveryCompanyId, 1);
    expect(submitted?.onDeliveryAccount, isTrue);
  });

  testWidgets('cash confirm is disabled when amount is too low', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        locale: Locale('en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(body: PaymentDialog(totalDue: 24.5, itemCount: 3)),
      ),
    );

    await tester.enterText(find.byType(TextField), '20');
    await tester.pump();

    final FilledButton confirmButton = tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, 'Confirm Payment'),
    );
    expect(
      find.text('Amount received is less than total due.'),
      findsOneWidget,
    );
    expect(confirmButton.onPressed, isNull);
  });

  testWidgets('card payment returns fake local payment result', (
    WidgetTester tester,
  ) async {
    PaymentResult? paymentResult;

    await tester.pumpWidget(
      _PaymentDialogHost(
        onResult: (PaymentResult result) => paymentResult = result,
      ),
    );

    await tester.tap(find.text('Open Payment'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Card'));
    await tester.pump();
    await tester.tap(find.text('Confirm Payment'));
    await tester.pumpAndSettle();

    expect(paymentResult?.method, PaymentMethod.card);
    expect(paymentResult?.totalDue, 24.5);
    expect(paymentResult?.amountReceived, 24.5);
    expect(paymentResult?.changeDue, 0);
  });

  testWidgets('wallet is preselected when the customer balance covers the total', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(1000, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
    PaymentResult? submitted;
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: PaymentDialog(
            totalDue: 24.5,
            itemCount: 3,
            walletBalance: 50,
            onSubmit: (PaymentResult result) async {
              submitted = result;
              return PaymentCompletionStatus.retryableFailure;
            },
          ),
        ),
      ),
    );

    expect(
      find.text(
        "The customer's wallet is selected because it covers this order (balance 50 SYP).",
      ),
      findsOneWidget,
    );
    await tester.tap(find.widgetWithText(FilledButton, 'Confirm Payment'));
    await tester.pump();
    expect(submitted?.method, PaymentMethod.wallet);
  });

  testWidgets('wallet is not preselected when the balance is too low', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(1000, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
    await tester.pumpWidget(
      const MaterialApp(
        locale: Locale('en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: PaymentDialog(totalDue: 24.5, itemCount: 3, walletBalance: 10),
        ),
      ),
    );

    expect(find.textContaining('wallet is selected'), findsNothing);
    expect(find.text('Change Due'), findsOneWidget);
  });

  testWidgets('split payment is disabled for now', (WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        locale: Locale('en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(body: PaymentDialog(totalDue: 24.5, itemCount: 3)),
      ),
    );

    await tester.tap(find.text('Split'));
    await tester.pump();

    final FilledButton confirmButton = tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, 'Confirm Payment'),
    );
    expect(find.text('Split payment will be supported later.'), findsOneWidget);
    expect(confirmButton.onPressed, isNull);
  });

  testWidgets('confirm ignores a second click while payment is submitting', (
    WidgetTester tester,
  ) async {
    final Completer<PaymentCompletionStatus> completion =
        Completer<PaymentCompletionStatus>();
    int submissions = 0;

    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: PaymentDialog(
            totalDue: 24.5,
            itemCount: 3,
            onSubmit: (_) {
              submissions += 1;
              return completion.future;
            },
          ),
        ),
      ),
    );

    await tester.tap(find.text('Confirm Payment'));
    await tester.pump();
    await tester.tap(find.byType(FilledButton));
    await tester.pump();

    expect(submissions, 1);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(
      tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
      isNull,
    );

    completion.complete(PaymentCompletionStatus.retryableFailure);
    await tester.pump();

    expect(find.byType(CircularProgressIndicator), findsNothing);
    expect(
      tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
      isNotNull,
    );
  });

  testWidgets('uncertain completion closes without re-enabling confirmation', (
    WidgetTester tester,
  ) async {
    int submissions = 0;

    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Builder(
          builder: (BuildContext context) {
            return Scaffold(
              body: FilledButton(
                onPressed: () async {
                  await showDialog<void>(
                    context: context,
                    builder: (BuildContext dialogContext) {
                      return PaymentDialog(
                        totalDue: 24.5,
                        itemCount: 3,
                        onSubmit: (_) async {
                          submissions++;
                          return PaymentCompletionStatus.uncertain;
                        },
                      );
                    },
                  );
                },
                child: const Text('Open Payment'),
              ),
            );
          },
        ),
      ),
    );

    await tester.tap(find.text('Open Payment'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Confirm Payment'));
    await tester.pumpAndSettle();

    expect(submissions, 1);
    expect(find.byType(PaymentDialog), findsNothing);
  });

  testWidgets('payment dialog does not overflow in compact layouts', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(320, 560);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(
      const MaterialApp(
        locale: Locale('en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(body: PaymentDialog(totalDue: 24.5, itemCount: 3)),
      ),
    );
    await tester.pump();

    expect(tester.takeException(), isNull);
    expect(find.text('Payment'), findsOneWidget);
    expect(find.text('Confirm Payment'), findsOneWidget);
  });
}

class _PaymentDialogHost extends StatelessWidget {
  const _PaymentDialogHost({required this.onResult});

  final ValueChanged<PaymentResult> onResult;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      locale: const Locale('en'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Builder(
        builder: (BuildContext context) {
          return Scaffold(
            body: Center(
              child: FilledButton(
                onPressed: () async {
                  final PaymentResult? result = await showDialog<PaymentResult>(
                    context: context,
                    builder: (BuildContext context) {
                      return const PaymentDialog(totalDue: 24.5, itemCount: 3);
                    },
                  );

                  if (result != null) {
                    onResult(result);
                  }
                },
                child: const Text('Open Payment'),
              ),
            ),
          );
        },
      ),
    );
  }
}

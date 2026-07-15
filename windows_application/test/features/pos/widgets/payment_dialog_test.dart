import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:windows_application/features/pos/controllers/pos_cubit.dart';
import 'package:windows_application/features/pos/models/payment_method.dart';
import 'package:windows_application/features/pos/models/payment_result.dart';
import 'package:windows_application/features/pos/widgets/payment_dialog.dart';

void main() {
  testWidgets('cash amount updates change due', (WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: PaymentDialog(totalDue: 24.5, itemCount: 3)),
      ),
    );

    await tester.enterText(find.byType(TextField), '30');
    await tester.pump();

    expect(find.text('Change Due'), findsOneWidget);
    expect(find.text('\$5.50'), findsOneWidget);
  });

  testWidgets('cash confirm is disabled when amount is too low', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
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

  testWidgets('split payment is disabled for now', (WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(
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

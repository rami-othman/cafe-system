import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:windows_application/features/orders/models/order_detail.dart';
import 'package:windows_application/features/orders/models/order_payment_summary.dart';
import 'package:windows_application/features/orders/models/order_status.dart';
import 'package:windows_application/features/orders/models/order_timeline_event.dart';
import 'package:windows_application/features/orders/widgets/order_details_header.dart';
import 'package:windows_application/features/orders/widgets/refund_dialog.dart';

void main() {
  testWidgets('full refund uses the authoritative refundable amount', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      _host(
        RefundDialog(
          orderDetail: _detail(refundableAmount: 25, refundedAmount: 20),
        ),
      ),
    );

    expect(
      tester
          .widget<TextField>(find.byKey(const ValueKey('refundAmountInput')))
          .controller
          ?.text,
      '25.00',
    );
  });

  testWidgets('partial refund above refundable amount is disabled', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      _host(
        RefundDialog(
          orderDetail: _detail(refundableAmount: 25, refundedAmount: 20),
        ),
      ),
    );

    await tester.tap(find.text('Partial Refund'));
    await tester.enterText(
      find.byKey(const ValueKey('refundAmountInput')),
      '26',
    );
    await tester.pump();

    expect(
      find.text('Refund amount cannot exceed refundable balance.'),
      findsOneWidget,
    );
    expect(
      tester
          .widget<ElevatedButton>(
            find.widgetWithText(ElevatedButton, 'Confirm Refund'),
          )
          .onPressed,
      isNull,
    );
  });

  testWidgets('unpaid order cannot open the refund action', (
    WidgetTester tester,
  ) async {
    bool tapped = false;
    await tester.pumpWidget(
      _host(
        OrderDetailsHeader(
          detail: _detail(refundableAmount: 0, paymentStatus: 'Pending'),
          onClose: () {},
          onPrint: () {},
          onCopy: () {},
          onRefund: () => tapped = true,
        ),
      ),
    );

    final OutlinedButton refundButton = tester.widget<OutlinedButton>(
      find.widgetWithText(OutlinedButton, 'Refund'),
    );
    expect(refundButton.onPressed, isNull);
    await tester.tap(find.text('Refund'));
    expect(tapped, isFalse);
  });

  testWidgets(
    'refundable balance enables refund despite a localized payment label',
    (WidgetTester tester) async {
      bool tapped = false;
      await tester.pumpWidget(
        _host(
          OrderDetailsHeader(
            detail: _detail(refundableAmount: 25, paymentStatus: 'تم الدفع'),
            onClose: () {},
            onPrint: () {},
            onCopy: () {},
            onRefund: () => tapped = true,
          ),
        ),
      );

      final OutlinedButton refundButton = tester.widget<OutlinedButton>(
        find.widgetWithText(OutlinedButton, 'Refund'),
      );
      expect(refundButton.onPressed, isNotNull);
      await tester.tap(find.text('Refund'));
      expect(tapped, isTrue);
    },
  );

  testWidgets('no-payment order keeps a disabled Refund action', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      _host(
        OrderDetailsHeader(
          detail: _detail(
            refundableAmount: 0,
            hasPayment: false,
            paymentStatus: '',
          ),
          onClose: () {},
          onPrint: () {},
          onCopy: () {},
          onRefund: () {},
        ),
      ),
    );

    final OutlinedButton refundButton = tester.widget<OutlinedButton>(
      find.widgetWithText(OutlinedButton, 'Refund'),
    );
    expect(refundButton.onPressed, isNull);
  });

  testWidgets('fully refunded order shows a disabled Refunded action', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      _host(
        OrderDetailsHeader(
          detail: _detail(
            refundableAmount: 0,
            refundedAmount: 25,
            isRefunded: true,
          ),
          onClose: () {},
          onPrint: () {},
          onCopy: () {},
          onRefund: () {},
        ),
      ),
    );

    final OutlinedButton refundButton = tester.widget<OutlinedButton>(
      find.widgetWithText(OutlinedButton, 'Refunded'),
    );
    expect(refundButton.onPressed, isNull);
  });
}

Widget _host(Widget child) {
  return MaterialApp(home: Scaffold(body: child));
}

OrderDetail _detail({
  required double refundableAmount,
  double refundedAmount = 0,
  String paymentStatus = 'Completed',
  bool hasPayment = true,
  bool isRefunded = false,
}) {
  return OrderDetail(
    id: '42',
    displayNumber: '#42',
    status: OrderStatus.completed,
    orderType: 'Takeaway',
    createdAt: DateTime(2026),
    customerName: 'Walk-in',
    customerPhone: '',
    customerEmail: '',
    items: const <OrderDetailItem>[],
    subtotal: 100,
    tax: 0,
    tip: 0,
    total: 100,
    payment: OrderPaymentSummary(
      methodLabel: 'Cash',
      statusLabel: paymentStatus,
      authCode: '1',
      amount: 100,
      hasPayment: hasPayment,
    ),
    timeline: const <OrderTimelineEvent>[],
    refundedAmount: refundedAmount,
    refundableAmount: refundableAmount,
    isRefunded: isRefunded,
  );
}

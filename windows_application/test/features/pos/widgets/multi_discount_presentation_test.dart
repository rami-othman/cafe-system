import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:windows_application/core/utils/currency_formatter.dart';
import 'package:windows_application/features/orders/models/order_detail.dart';
import 'package:windows_application/features/orders/models/order_payment_summary.dart';
import 'package:windows_application/features/orders/models/order_status.dart';
import 'package:windows_application/features/orders/models/order_timeline_event.dart';
import 'package:windows_application/features/orders/widgets/order_detail_totals_section.dart';
import 'package:windows_application/features/pos/models/discount_engine.dart';
import 'package:windows_application/features/pos/models/order_receipt_mapper.dart';
import 'package:windows_application/features/pos/widgets/receipt_preview_paper.dart';
import 'package:windows_application/features/printer/models/printer_config.dart';
import 'package:windows_application/features/printer/models/receipt_data.dart';
import 'package:windows_application/features/printer/services/receipt_renderer.dart';
import 'package:windows_application/l10n/app_localizations.dart';

/// Discount V3 Phase 3: receipt, printed receipt and order history show every
/// backend discount line and its total; historical single-discount orders
/// render as before. Nothing is recalculated on the client.
Map<String, dynamic> _discount(
  int id,
  String name,
  String amount,
  String source, {
  int? sequence,
}) => {
  'id': id,
  'discountId': id,
  'name': name,
  'source': source,
  'stage': 'order',
  'type': 'percentage',
  'value': '10.00',
  'amount': amount,
  'sequence': ?sequence,
  'allocations': <Map<String, dynamic>>[],
};

final List<Map<String, dynamic>> _three = [
  _discount(1, 'Latte 10%', '1.00', 'configured_manual', sequence: 1),
  _discount(2, 'WELCOME', '0.50', 'code', sequence: 2),
  _discount(3, 'Bundle Offer', '0.75', 'configured_manual', sequence: 3),
];

Map<String, dynamic> _receiptJson(List<Map<String, dynamic>> discounts) => {
  'orderNumber': '20261008-0001',
  'branchName': 'Main Branch',
  'cashierName': 'Cafe Owner',
  'date': '2026-10-08T10:00:00Z',
  'items': [
    {'name': 'Latte', 'quantity': 1, 'unitPrice': 10, 'lineTotal': 10},
  ],
  'subtotal': 10,
  'discountTotal': discounts.isEmpty ? 0 : (discounts.length == 1 ? 1 : 2.25),
  'discounts': discounts,
  'taxTotal': 0,
  'total': discounts.length == 1 ? 9 : 7.75,
  'payment': {'method': 'cash', 'amount': 10},
};

OrderDetail _detail(List<Map<String, dynamic>> discounts, double total) =>
    OrderDetail(
      id: '9',
      displayNumber: '#9',
      status: OrderStatus.completed,
      orderType: 'Takeaway',
      createdAt: DateTime(2026, 10, 8),
      customerName: 'Walk-in',
      customerPhone: '',
      customerEmail: '',
      items: const <OrderDetailItem>[],
      subtotal: 10,
      tax: 0,
      tip: 0,
      total: 10 - total,
      payment: const OrderPaymentSummary(
        methodLabel: 'Cash',
        statusLabel: 'Paid',
        authCode: '-',
        amount: 7.75,
        status: 'completed',
      ),
      timeline: const <OrderTimelineEvent>[],
      discounts: [for (final d in discounts) SavedDiscount.fromJson(d)],
      discountTotal: total,
    );

Future<AppLocalizations> _pump(
  WidgetTester tester,
  String language,
  Widget child,
) async {
  late AppLocalizations l;
  await tester.pumpWidget(
    MaterialApp(
      locale: Locale(language),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Builder(
        builder: (context) {
          l = AppLocalizations.of(context);
          return Scaffold(body: SingleChildScrollView(child: child));
        },
      ),
    ),
  );
  await tester.pumpAndSettle();
  return l;
}

void main() {
  for (final language in ['en', 'ar']) {
    testWidgets('$language receipt preview lists each discount and the total', (
      tester,
    ) async {
      final receipt = orderReceiptFromJson(_receiptJson(_three));
      final l = await _pump(
        tester,
        language,
        ReceiptPreviewPaper(receipt: receipt),
      );
      expect(find.text('1. Latte 10%'), findsOneWidget);
      expect(find.text('2. WELCOME'), findsOneWidget);
      expect(find.text('3. Bundle Offer'), findsOneWidget);
      for (final amount in [1.0, 0.5, 0.75]) {
        expect(
          find.text('-${CurrencyFormatter.format(amount)}'),
          findsOneWidget,
        );
      }
      expect(find.text(l.d2SourceCode), findsOneWidget);
      expect(find.text(l.d3TotalDiscounts.toUpperCase()), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets(
      '$language historical single-discount receipt keeps its layout',
      (tester) async {
        final receipt = orderReceiptFromJson(
          _receiptJson([_discount(1, 'Old discount', '1.00', 'code')]),
        );
        final l = await _pump(
          tester,
          language,
          ReceiptPreviewPaper(receipt: receipt),
        );
        expect(find.text('Old discount'), findsOneWidget);
        expect(find.text(l.posDiscount.toUpperCase()), findsOneWidget);
        expect(find.text(l.d3TotalDiscounts.toUpperCase()), findsNothing);
      },
    );

    testWidgets('$language order detail shows every persisted discount line', (
      tester,
    ) async {
      final l = await _pump(
        tester,
        language,
        OrderDetailTotalsSection(detail: _detail(_three, 2.25)),
      );
      expect(find.text('1. Latte 10%'), findsOneWidget);
      expect(find.text('3. Bundle Offer'), findsOneWidget);
      expect(find.text(l.d3TotalDiscounts), findsOneWidget);
      expect(find.text(l.posDiscount), findsNothing);
    });

    testWidgets('$language old single-discount order detail is unchanged', (
      tester,
    ) async {
      final l = await _pump(
        tester,
        language,
        OrderDetailTotalsSection(
          detail: _detail([_discount(1, 'Legacy', '1.00', 'code')], 1),
        ),
      );
      expect(find.text('Legacy'), findsOneWidget);
      expect(find.text(l.posDiscount), findsOneWidget);
      expect(find.text(l.d3TotalDiscounts), findsNothing);
    });
  }

  test(
    'printed receipt grows with each discount line on 58mm and 80mm',
    () async {
      TestWidgetsFlutterBinding.ensureInitialized();
      final renderer = ReceiptRenderer();
      for (final width in PrinterPaperWidth.values) {
        for (final locale in const [Locale('en'), Locale('ar')]) {
          final single = await renderer.render(
            ReceiptData.fromJson(
              _receiptJson([
                _discount(1, 'Latte 10%', '1.00', 'configured_manual'),
              ]),
            ),
            locale: locale,
            paperWidth: width,
          );
          final multi = await renderer.render(
            ReceiptData.fromJson(_receiptJson(_three)),
            locale: locale,
            paperWidth: width,
          );
          expect(multi.height, greaterThan(single.height));
        }
      }
      final data = ReceiptData.fromJson(_receiptJson(_three));
      expect(data.discounts.map((d) => d.name), [
        'Latte 10%',
        'WELCOME',
        'Bundle Offer',
      ]);
    },
  );
}

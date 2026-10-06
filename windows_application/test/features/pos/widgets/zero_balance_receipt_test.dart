import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:windows_application/features/pos/models/order_receipt_mapper.dart';
import 'package:windows_application/features/pos/widgets/receipt_preview_paper.dart';
import 'package:windows_application/l10n/app_localizations.dart';

void main() {
  for (final language in ['en', 'ar']) {
    testWidgets('$language zero-balance receipt does not claim cash tender', (
      tester,
    ) async {
      final receipt = orderReceiptFromJson({
        'orderNumber': '20261004-0017',
        'branchName': 'Main Branch',
        'cashierName': 'Cafe Owner',
        'date': '2026-10-04T16:18:12Z',
        'items': [
          {'name': 'Acc Tea', 'quantity': 1, 'unitPrice': 10, 'lineTotal': 10},
        ],
        'subtotal': 10,
        'discountTotal': 10,
        'discountLabel': 'DISCOUNT',
        'taxTotal': 0,
        'total': 0,
        'payment': {'method': 'zero_balance', 'amount': 0},
      });
      late AppLocalizations l;
      await tester.pumpWidget(
        MaterialApp(
          locale: Locale(language),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Builder(
            builder: (context) {
              l = AppLocalizations.of(context);
              return Scaffold(
                body: SingleChildScrollView(
                  child: ReceiptPreviewPaper(receipt: receipt),
                ),
              );
            },
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text(l.d2ZeroBalance), findsOneWidget);
      expect(find.text(l.posPaymentMethodCash), findsNothing);
      expect(find.text(l.posDiscount.toUpperCase()), findsOneWidget);
      if (language == 'ar') {
        expect(find.text('DISCOUNT'), findsNothing);
      }
      expect(receipt.total, 0);
      expect(receipt.discountTotal, 10);
      expect(receipt.settlementMethod, 'zero_balance');
      expect(tester.takeException(), isNull);
    });
  }
}

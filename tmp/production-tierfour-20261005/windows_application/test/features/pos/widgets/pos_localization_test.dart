import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:windows_application/features/pos/models/applied_discount.dart';
import 'package:windows_application/features/pos/models/order_receipt.dart';
import 'package:windows_application/features/pos/models/order_type.dart';
import 'package:windows_application/features/pos/models/payment_method.dart';
import 'package:windows_application/features/pos/models/payment_result.dart';
import 'package:windows_application/features/pos/models/pos_product.dart';
import 'package:windows_application/features/pos/models/receipt_line_item.dart';
import 'package:windows_application/features/pos/widgets/discount_dialog.dart';
import 'package:windows_application/features/pos/widgets/order_totals_panel.dart';
import 'package:windows_application/features/pos/widgets/order_type_selector.dart';
import 'package:windows_application/features/pos/widgets/payment_dialog.dart';
import 'package:windows_application/features/pos/widgets/pos_action_buttons.dart';
import 'package:windows_application/features/pos/widgets/pos_localization.dart';
import 'package:windows_application/features/pos/widgets/product_customization_dialog.dart';
import 'package:windows_application/features/pos/widgets/receipt_preview_dialog.dart';
import 'package:windows_application/l10n/app_localizations.dart';
import 'package:windows_application/l10n/app_localizations_ar.dart';
import 'package:windows_application/l10n/app_localizations_en.dart';

void main() {
  testWidgets('cart PRINT invokes the pre-bill action once', (
    WidgetTester tester,
  ) async {
    var printCalls = 0;
    await _pump(
      tester,
      PosActionButtons(
        total: 12,
        onPrint: () => printCalls++,
        isPrintEnabled: true,
      ),
      locale: const Locale('en'),
    );

    await tester.tap(find.text('Print'));
    expect(printCalls, 1);
  });

  testWidgets(
    'discount dialog localizes coupon validation search and empty states',
    (WidgetTester tester) async {
      await _pump(
        tester,
        const DiscountDialog(subtotal: 20),
        locale: const Locale('ar'),
      );
      expect(find.text('تطبيق خصم'), findsOneWidget);
      expect(find.text('رمز القسيمة'), findsOneWidget);
      expect(find.text('الخصومات المتاحة'), findsOneWidget);
      await tester.tap(find.text('تطبيق'));
      await tester.pump();
      expect(find.text('أدخل رمز القسيمة.'), findsOneWidget);
      expect(find.text('لا توجد خصومات متاحة لهذا الطلب.'), findsOneWidget);
      await tester.enterText(
        find.byKey(const Key('pos-discount-search-field')),
        'missing',
      );
      await tester.pump();
      expect(find.text('لا توجد خصومات تطابق بحثك.'), findsOneWidget);
    },
  );

  testWidgets('payment dialog renders every localized method and cash labels', (
    WidgetTester tester,
  ) async {
    await _pump(
      tester,
      const PaymentDialog(totalDue: 20, itemCount: 2),
      locale: const Locale('ar'),
    );
    for (final String label in <String>[
      'نقداً',
      'بطاقة',
      'محفظة',
      'دفع مقسم',
    ]) {
      expect(find.text(label), findsOneWidget);
    }
    expect(find.text('النقد المستلم'), findsOneWidget);
    expect(find.text('الباقي المستحق'), findsOneWidget);
    expect(find.text('تأكيد الدفع'), findsOneWidget);
  });

  testWidgets('order types cart totals and primary actions are localized', (
    WidgetTester tester,
  ) async {
    await _pump(
      tester,
      Column(
        children: <Widget>[
          OrderTypeSelector(
            selectedOrderType: OrderType.dineIn,
            onOrderTypeSelected: (_) {},
          ),
          const OrderTotalsPanel(
            subtotal: 10,
            discountTotal: 0,
            tax: 1,
            total: 11,
            taxRate: 0.1,
          ),
          const PosActionButtons(total: 11),
        ],
      ),
      locale: const Locale('ar'),
    );
    for (final String label in <String>[
      'طلب محلي',
      'طلب سفري',
      'توصيل',
      'المجموع الفرعي',
      'الإجمالي',
      'تعليق الطلب',
      'إلغاء الطلب',
    ]) {
      expect(find.text(label), findsOneWidget);
    }
  });

  testWidgets(
    'product customization localizes chrome but preserves product content',
    (WidgetTester tester) async {
      await _pump(
        tester,
        const ProductCustomizationDialog(product: _product),
        locale: const Locale('ar'),
        size: const Size(900, 700),
      );
      expect(find.text('Latte Business Name'), findsOneWidget);
      expect(find.text('تخصيص العنصر'), findsOneWidget);
      expect(find.text('درجة الحرارة'), findsOneWidget);
      expect(find.text('الحجم'), findsOneWidget);
      expect(find.text('إضافة إلى الطلب'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('receipt preview and actions render visible Arabic labels', (
    WidgetTester tester,
  ) async {
    var printCalls = 0;
    await _pump(
      tester,
      ReceiptPreviewDialog(
        receipt: _receipt,
        onPrintReceipt: () => printCalls++,
      ),
      locale: const Locale('ar'),
      size: const Size(700, 700),
    );
    expect(find.text('معاينة الإيصال'), findsOneWidget);
    expect(find.text('المجموع الفرعي'), findsOneWidget);
    expect(find.text('الإجمالي'), findsOneWidget);
    expect(find.text('طريقة الدفع:'), findsOneWidget);
    expect(find.text('نقداً'), findsOneWidget);
    expect(find.text('إرسال عبر واتساب'), findsOneWidget);
    expect(find.text('طباعة الإيصال'), findsOneWidget);
    await tester.tap(find.text('طباعة الإيصال'));
    expect(printCalls, 1);
    expect(find.text('معاينة الإيصال'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  test('presentation localization keeps API identities unchanged', () {
    final AppLocalizations en = AppLocalizationsEn();
    final AppLocalizations ar = AppLocalizationsAr();
    const AppliedDiscount discount = AppliedDiscount(
      id: 'p',
      title: 'Policy Name',
      type: AppliedDiscountType.percentage,
      value: 15,
    );
    expect(discount.localizedDisplayLabel(en), '15% off');
    expect(discount.localizedDisplayLabel(ar), 'خصم 15%');
    expect(PaymentMethod.cash.apiValue, 'cash');
    expect(PaymentMethod.split.apiValue, 'split');
    expect(OrderType.dineIn.apiValue, 'dine_in');
    expect(OrderType.takeaway.apiValue, 'takeaway');
  });

  test('known failures localize and unknown failures never leak raw text', () {
    final AppLocalizations en = AppLocalizationsEn();
    final AppLocalizations ar = AppLocalizationsAr();
    expect(
      localizedPosFailure(en, 'MENU_VERSION_STALE: internal detail'),
      'The menu changed. Refresh the POS menu and review the order.',
    );
    expect(
      localizedPosFailure(ar, 'NO_OPEN_SHIFT'),
      'افتح وردية قبل المتابعة.',
    );
    const String secret = 'SocketException: backend-secret';
    expect(localizedPosFailure(en, secret), en.posOperationFailed);
    expect(localizedPosFailure(en, secret), isNot(contains('backend-secret')));
    expect(localizedPosFailure(ar, Exception(secret)), ar.posOperationFailed);
  });

  testWidgets(
    'English has no Arabic operational error and Arabic has no known English labels',
    (WidgetTester tester) async {
      await _pump(tester, const PaymentDialog(totalDue: 10, itemCount: 1));
      expect(find.textContaining('لا توجد طريقة دفع'), findsNothing);
      await _pump(
        tester,
        const PaymentDialog(totalDue: 10, itemCount: 1),
        locale: const Locale('ar'),
        size: const Size(360, 640),
      );
      for (final String label in <String>[
        'Payment',
        'Cash',
        'Card',
        'Wallet',
        'Split',
        'Change Due',
      ]) {
        expect(find.text(label), findsNothing);
      }
      expect(
        Directionality.of(tester.element(find.byType(PaymentDialog))),
        TextDirection.rtl,
      );
      expect(tester.takeException(), isNull);
    },
  );
}

Future<void> _pump(
  WidgetTester tester,
  Widget child, {
  Locale locale = const Locale('en'),
  Size size = const Size(800, 700),
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(() {
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });
  await tester.pumpWidget(
    MaterialApp(
      locale: locale,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(body: child),
    ),
  );
  await tester.pumpAndSettle();
}

const PosProduct _product = PosProduct(
  id: '1',
  name: 'Latte Business Name',
  category: 'Coffee',
  size: 'Regular',
  price: 5,
  isAvailable: true,
);

final OrderReceipt _receipt = OrderReceipt(
  orderNumber: '618-1',
  branchName: 'Damascus',
  cashierName: 'Rami',
  completedAt: DateTime(2026, 9, 19),
  items: <ReceiptLineItem>[
    ReceiptLineItem(
      name: 'Latte Business Name',
      quantity: 1,
      unitPrice: 10,
      lineTotal: 10,
    ),
  ],
  subtotal: 10,
  discountTotal: 0,
  discountLabel: null,
  tax: 0,
  total: 10,
  payment: PaymentResult(
    method: PaymentMethod.cash,
    totalDue: 10,
    amountReceived: 10,
    changeDue: 0,
  ),
);

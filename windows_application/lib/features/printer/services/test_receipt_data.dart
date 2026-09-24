import '../models/receipt_data.dart';
import '../models/receipt_template.dart';

/// A fixed sample receipt used only by "Test Print". Feeding it through the
/// exact same pipeline a real order's receipt uses (renderer → raster →
/// ESC/POS image encoding → TCP send) means a successful test print proves
/// the actual print path can reach the printer, not just that a hand-built
/// diagnostic payload can. It creates no order and no payment, and the
/// header/footer both spell out that this is a test receipt.
///
/// Content is bilingual regardless of the locale passed to the renderer
/// (which only controls section-label language, layout direction and font),
/// so a single call exercises English, Arabic and mixed text, a phone
/// number, an item with a modifier, every totals field, and the footer, on
/// whatever 58mm/80mm width the [PrinterConfig] under test specifies. The
/// default template is used with an explicit footer override, so the logo
/// area is exercised too (with no `logoUrl`, the renderer's normal
/// logo-fallback path is what runs).
ReceiptData buildTestReceiptData() => ReceiptData(
  orderNumber: 'TEST-0000',
  date: DateTime.now().toUtc().toIso8601String(),
  cafeName: 'TEST RECEIPT — NOT A SALE',
  branchName: 'Sample Branch — فرع تجريبي',
  address: '123 Test Street — شارع تجريبي',
  phone: '+963 11 123 4567',
  orderType: 'dine_in',
  cashierName: 'Test Cashier',
  items: const <ReceiptItem>[
    ReceiptItem(
      name: 'Cappuccino / كابتشينو',
      quantity: 2,
      unitPrice: 2.5,
      lineTotal: 5,
      modifiers: <String>['Extra shot / إضافة إسبريسو'],
      note: 'No sugar / بدون سكر',
    ),
  ],
  subtotal: 5,
  discountTotal: 0.5,
  taxTotal: 0.25,
  total: 4.75,
  payment: const ReceiptPayment(method: 'cash', amount: 4.75, changeDue: 0),
  footerText: 'TEST RECEIPT — NOT A SALE',
  template: const ReceiptTemplate.defaultTemplate().copyWith(
    footer: const ReceiptTemplateFooter(
      text: 'TEST RECEIPT — NOT A SALE / إيصال تجريبي — ليس عملية بيع',
    ),
  ),
);

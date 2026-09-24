import 'package:flutter_test/flutter_test.dart';
import 'package:windows_application/features/printer/models/receipt_template.dart';

void main() {
  test('defaultTemplate matches the spec defaults exactly', () {
    const template = ReceiptTemplate.defaultTemplate();

    expect(template.header.showLogo, true);
    expect(template.header.showCafeName, true);
    expect(template.header.showBranchName, true);
    expect(template.header.showAddress, true);
    expect(template.header.showPhone, true);

    expect(template.orderInfo.showOrderNumber, true);
    expect(template.orderInfo.showDateTime, true);
    expect(template.orderInfo.showCashier, true);
    expect(template.orderInfo.showCustomer, false);
    expect(template.orderInfo.showOrderType, true);

    expect(template.items.showProductName, true);
    expect(template.items.showQuantity, true);
    expect(template.items.showUnitPrice, true);
    expect(template.items.showModifiers, true);
    expect(template.items.showNotes, true);

    expect(template.totals.showSubtotal, true);
    expect(template.totals.showDiscount, true);
    expect(template.totals.showTax, true);
    expect(template.totals.showTotal, true);

    expect(template.payment.showPaymentMethod, true);
    expect(template.payment.showPaidAmount, true);
    expect(template.payment.showChange, true);

    expect(template.footer.enabled, true);
    expect(template.footer.text, 'Thank you for visiting');

    expect(template.sectionOrder, const <ReceiptTemplateSection>[
      ReceiptTemplateSection.header,
      ReceiptTemplateSection.orderInfo,
      ReceiptTemplateSection.items,
      ReceiptTemplateSection.totals,
      ReceiptTemplateSection.payment,
      ReceiptTemplateSection.footer,
    ]);
  });

  test('fromJson/toJson round-trips a saved template', () {
    const template = ReceiptTemplate(
      header: ReceiptTemplateHeader(showLogo: false, showPhone: false),
      orderInfo: ReceiptTemplateOrderInfo(showCustomer: true),
      footer: ReceiptTemplateFooter(enabled: true, text: 'شكراً لزيارتكم'),
      sectionOrder: <ReceiptTemplateSection>[
        ReceiptTemplateSection.footer,
        ReceiptTemplateSection.header,
        ReceiptTemplateSection.orderInfo,
        ReceiptTemplateSection.items,
        ReceiptTemplateSection.totals,
        ReceiptTemplateSection.payment,
      ],
    );

    final roundTripped = ReceiptTemplate.fromJson(template.toJson());

    expect(roundTripped, template);
  });

  test('fromJson defaults to ReceiptTemplate.defaultTemplate on bad input', () {
    expect(
      ReceiptTemplate.fromJson(null),
      const ReceiptTemplate.defaultTemplate(),
    );
    expect(
      ReceiptTemplate.fromJson('not a map'),
      const ReceiptTemplate.defaultTemplate(),
    );
    expect(
      ReceiptTemplate.fromJson(<String, dynamic>{}),
      const ReceiptTemplate.defaultTemplate(),
    );
  });

  test('showProductName and showTotal cannot be turned off from JSON', () {
    final items = ReceiptTemplateItems.fromJson(<String, dynamic>{
      'showProductName': false,
    });
    final totals = ReceiptTemplateTotals.fromJson(<String, dynamic>{
      'showTotal': false,
    });

    expect(items.showProductName, true);
    expect(totals.showTotal, true);
  });

  test('moveSection reorders and clamps at the list boundaries', () {
    const template = ReceiptTemplate.defaultTemplate();

    final movedUp = template.moveSection(1, up: true);
    expect(movedUp.sectionOrder.first, ReceiptTemplateSection.orderInfo);
    expect(movedUp.sectionOrder[1], ReceiptTemplateSection.header);

    final noopAtTop = template.moveSection(0, up: true);
    expect(noopAtTop.sectionOrder, template.sectionOrder);

    final noopAtBottom = template.moveSection(
      template.sectionOrder.length - 1,
      up: false,
    );
    expect(noopAtBottom.sectionOrder, template.sectionOrder);
  });

  test('ReceiptTemplateSection api value round-trips', () {
    for (final section in ReceiptTemplateSection.values) {
      expect(ReceiptTemplateSection.fromApiValue(section.apiValue), section);
    }
    expect(ReceiptTemplateSection.fromApiValue('unknown'), isNull);
  });
}

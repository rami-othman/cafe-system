import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:windows_application/features/printer/models/printer_config.dart';
import 'package:windows_application/features/printer/models/receipt_data.dart';
import 'package:windows_application/features/printer/services/receipt_renderer.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final renderer = ReceiptRenderer();

  Map<String, dynamic> data({
    String name = 'Coffee',
    double total = 10,
    Map<String, dynamic>? payment,
  }) => <String, dynamic>{
    'orderNumber': 'ORD-42',
    'date': '2026-09-23T12:00:00Z',
    'branchName': 'Downtown',
    'cashierName': 'Sam',
    'items': <Map<String, dynamic>>[
      <String, dynamic>{
        'name': name,
        'quantity': 2,
        'unitPrice': 5,
        'lineTotal': 10,
        'modifiers': <Map<String, dynamic>>[
          <String, dynamic>{'name': 'Extra milk'},
        ],
        'note': 'No ice',
      },
    ],
    'subtotal': 12,
    'discountTotal': 3,
    'taxTotal': 1,
    'total': total,
    'customerName': 'Alex',
    'payment': payment ?? <String, dynamic>{'method': 'card', 'amount': total},
  };

  test(
    '58mm and 80mm produce inspectable PNGs at printer dot widths',
    () async {
      final receipt = ReceiptData.fromJson(data());
      final narrow = await renderer.render(
        receipt,
        locale: const Locale('en'),
        paperWidth: PrinterPaperWidth.mm58,
      );
      final wide = await renderer.render(
        receipt,
        locale: const Locale('en'),
        paperWidth: PrinterPaperWidth.mm80,
      );
      expect(narrow.width, 384);
      expect(wide.width, 576);
      expect(narrow.height, greaterThan(0));
      expect(wide.height, greaterThan(0));
      expect(narrow.png.take(8), <int>[137, 80, 78, 71, 13, 10, 26, 10]);
      expect(narrow.rgba.length, narrow.width * narrow.height * 4);
      expect(wide.rgba.length, wide.width * wide.height * 4);
    },
  );

  test(
    'Arabic RTL and mixed product names render with bundled fonts',
    () async {
      for (final name in <String>['قهوة عربية', 'قهوة Espresso لاتيه']) {
        final raster = await renderer.render(
          ReceiptData.fromJson(data(name: name)),
          locale: const Locale('ar'),
          paperWidth: PrinterPaperWidth.mm58,
        );
        expect(raster.png.length, greaterThan(1000));
        expect(raster.rgba.where((byte) => byte == 0).length, greaterThan(100));
      }
    },
  );

  test(
    'long names and authoritative optional fields affect the raster',
    () async {
      final base = await renderer.render(
        ReceiptData.fromJson(data()),
        locale: const Locale('en'),
        paperWidth: PrinterPaperWidth.mm58,
      );
      final changed = data(
        name:
            'Very long Arabic قهوة and English product name that wraps over several lines',
      );
      (changed['items'] as List).first['modifiers'] = <Map<String, dynamic>>[
        <String, dynamic>{'name': 'حليب إضافي'},
      ];
      changed['customerName'] = 'Long Customer';
      final expanded = await renderer.render(
        ReceiptData.fromJson(changed),
        locale: const Locale('en'),
        paperWidth: PrinterPaperWidth.mm58,
      );
      expect(expanded.height, greaterThan(base.height));
      expect(expanded.png, isNot(base.png));
      final receipt = ReceiptData.fromJson(changed);
      expect(receipt.items.single.quantity, 2);
      expect(receipt.items.single.lineTotal, 10);
      expect(receipt.discountTotal, 3);
      expect(receipt.taxTotal, 1);
      expect(receipt.customerName, 'Long Customer');
      expect(receipt.items.single.modifiers, <String>['حليب إضافي']);
    },
  );

  test('zero balance ignores even a stale cash payment record', () async {
    final withCash = ReceiptData.fromJson(
      data(total: 0, payment: <String, dynamic>{'method': 'cash', 'amount': 0}),
    );
    final withoutPayment = ReceiptData.fromJson(
      data(total: 0)..remove('payment'),
    );
    final a = await renderer.render(
      withCash,
      locale: const Locale('en'),
      paperWidth: PrinterPaperWidth.mm80,
    );
    final b = await renderer.render(
      withoutPayment,
      locale: const Locale('en'),
      paperWidth: PrinterPaperWidth.mm80,
    );
    expect(a.png, b.png);
    expect(withCash.total, 0);
  });

  test('pre-bill status is labeled ORDER CHECK and NOT PAID', () {
    expect(
      ReceiptRenderer.documentStatusLines(const Locale('en'), isPreBill: true),
      <String>['ORDER CHECK', 'NOT PAID'],
    );
    expect(
      ReceiptRenderer.documentStatusLines(const Locale('ar'), isPreBill: true),
      <String>['فحص الطلب', 'غير مدفوع'],
    );
    expect(
      ReceiptRenderer.documentStatusLines(const Locale('en'), isPreBill: false),
      isEmpty,
    );
  });

  test('write development receipt PNG previews when requested', () async {
    if (!const bool.fromEnvironment('receiptPreview')) return;
    final output = Directory('build/receipt_previews');
    await output.create(recursive: true);
    final english = await renderer.render(
      ReceiptData.fromJson(data()),
      locale: const Locale('en'),
      paperWidth: PrinterPaperWidth.mm58,
    );
    final arabicData = data(name: 'قهوة عربية Espresso');
    arabicData['branchName'] = 'فرع دمشق';
    arabicData['customerName'] = 'أحمد';
    (arabicData['items'] as List).first['modifiers'] = <Map<String, dynamic>>[
      <String, dynamic>{'name': 'حليب إضافي'},
    ];
    final arabic = await renderer.render(
      ReceiptData.fromJson(arabicData),
      locale: const Locale('ar'),
      paperWidth: PrinterPaperWidth.mm80,
    );
    await File('${output.path}/english_58mm.png').writeAsBytes(english.png);
    await File('${output.path}/arabic_mixed_80mm.png').writeAsBytes(arabic.png);
  });
}

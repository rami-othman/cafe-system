import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:intl/date_symbol_data_local.dart';

import '../../../core/utils/backend_datetime.dart';
import '../models/printer_config.dart';
import '../models/receipt_data.dart';

class ReceiptRenderException implements Exception {
  const ReceiptRenderException();
}

class ReceiptRaster {
  const ReceiptRaster({
    required this.width,
    required this.height,
    required this.rgba,
    required this.png,
  });

  final int width;
  final int height;
  final Uint8List rgba;

  /// Can be saved or shown in tests/development without a printer.
  final Uint8List png;
}

/// Lays out text through Flutter's shaping engine, then rasterizes the whole
/// receipt. Printer code pages and installed system fonts are never involved.
class ReceiptRenderer {
  static Future<void>? _fontsReady;

  static List<String> documentStatusLines(
    Locale locale, {
    required bool isPreBill,
  }) {
    if (!isPreBill) return const <String>[];
    return locale.languageCode == 'ar'
        ? const <String>['فحص الطلب', 'غير مدفوع']
        : const <String>['ORDER CHECK', 'NOT PAID'];
  }

  Future<ReceiptRaster> render(
    ReceiptData receipt, {
    required Locale locale,
    required PrinterPaperWidth paperWidth,
    bool isPreBill = false,
  }) async {
    try {
      await (_fontsReady ??= _loadFonts());
      await initializeDateFormatting(locale.languageCode);
      final width = paperWidth == PrinterPaperWidth.mm58 ? 384 : 576;
      final rtl = locale.languageCode == 'ar';
      final direction = rtl ? ui.TextDirection.rtl : ui.TextDirection.ltr;
      final recorder = ui.PictureRecorder();
      final canvas = Canvas(recorder);
      canvas.drawColor(Colors.white, BlendMode.src);
      final contentWidth = width - 36.0;
      double y = 18;
      final money = NumberFormat.decimalPatternDigits(
        locale: 'en',
        decimalDigits: 2,
      );
      String amount(double value) => money.format(value);
      final parsedDate = parseBackendDateTime(receipt.date);
      final formattedDate = parsedDate == null
          ? receipt.date
          : DateFormat.yMd(locale.toLanguageTag()).add_jm().format(parsedDate);
      String quantity(double value) => value == value.roundToDouble()
          ? value.toInt().toString()
          : value.toString();

      TextPainter painter(
        String value, {
        bool bold = false,
        double size = 22,
        ui.TextDirection? textDirection,
        double? maxWidth,
      }) {
        final p = TextPainter(
          text: TextSpan(
            text: value,
            style: TextStyle(
              fontFamily: rtl ? 'IBMPlexSansArabic' : 'Manrope',
              fontFamilyFallback: const ['IBMPlexSansArabic', 'Manrope'],
              fontSize: size,
              fontWeight: bold ? FontWeight.w700 : FontWeight.w400,
              color: Colors.black,
              height: 1.35,
            ),
          ),
          textDirection: textDirection ?? direction,
          maxLines: null,
        )..layout(maxWidth: maxWidth ?? contentWidth);
        return p;
      }

      void line(
        String? value, {
        bool bold = false,
        bool center = false,
        double size = 22,
      }) {
        if (value == null || value.trim().isEmpty) return;
        final p = painter(value, bold: bold, size: size);
        final x = center
            ? (width - p.width) / 2
            : rtl
            ? width - 18 - p.width
            : 18.0;
        p.paint(canvas, Offset(x, y));
        y += p.height + 5;
      }

      void rule() {
        y += 7;
        canvas.drawLine(
          Offset(18, y),
          Offset(width - 18, y),
          Paint()
            ..color = Colors.black
            ..strokeWidth = 1,
        );
        y += 12;
      }

      void row(String label, String value, {bool bold = false}) {
        final numeric = painter(
          value,
          bold: bold,
          textDirection: RegExp(r'[\u0600-\u06ff]').hasMatch(value)
              ? ui.TextDirection.rtl
              : ui.TextDirection.ltr,
          maxWidth: contentWidth * .42,
        );
        final text = painter(
          label,
          bold: bold,
          maxWidth: contentWidth - numeric.width - 14,
        );
        final textX = rtl ? width - 18 - text.width : 18.0;
        final numberX = rtl ? 18.0 : width - 18 - numeric.width;
        text.paint(canvas, Offset(textX, y));
        numeric.paint(canvas, Offset(numberX, y));
        y += (text.height > numeric.height ? text.height : numeric.height) + 5;
      }

      line(receipt.title, center: true, bold: true, size: 26);
      line(receipt.branchName, center: true, bold: true, size: 26);
      for (final value in receipt.addressLines) {
        line(value, center: true);
      }
      for (final String status in documentStatusLines(
        locale,
        isPreBill: isPreBill,
      )) {
        line(status, center: true, bold: true);
      }
      rule();
      row(rtl ? 'الطلب' : 'Order', receipt.orderNumber);
      row(rtl ? 'التاريخ' : 'Date', formattedDate);
      if (receipt.cashierName != null) {
        row(rtl ? 'أمين الصندوق' : 'Cashier', receipt.cashierName!);
      }
      if (receipt.customerName != null) {
        row(rtl ? 'العميل' : 'Customer', receipt.customerName!);
      }
      rule();
      for (final item in receipt.items) {
        line(item.name, bold: true);
        row(
          '${quantity(item.quantity)} × ${amount(item.unitPrice)}',
          amount(item.lineTotal),
        );
        for (final modifier in item.modifiers) {
          line('• $modifier', size: 19);
        }
        line(item.note, size: 19);
        y += 7;
      }
      rule();
      row(rtl ? 'المجموع الفرعي' : 'Subtotal', amount(receipt.subtotal));
      if (receipt.discountTotal != 0) {
        row(rtl ? 'الخصم' : 'Discount', amount(receipt.discountTotal));
      }
      row(rtl ? 'الضريبة' : 'Tax', amount(receipt.taxTotal));
      row(rtl ? 'الإجمالي' : 'Total', amount(receipt.total), bold: true);
      rule();
      if (receipt.total == 0) {
        line(rtl ? 'لا يلزم دفع' : 'No payment required', center: true);
      } else if (!isPreBill && receipt.payment != null) {
        final method = receipt.payment!.method;
        if (method != null) {
          final label = switch (method.toLowerCase()) {
            'cash' => rtl ? 'نقداً' : 'Cash',
            'card' => rtl ? 'بطاقة' : 'Card',
            'wallet' => rtl ? 'محفظة' : 'Wallet',
            'split' => rtl ? 'دفع مقسم' : 'Split',
            _ => method,
          };
          row(rtl ? 'طريقة الدفع' : 'Payment', label);
        }
        row(rtl ? 'المدفوع' : 'Paid', amount(receipt.payment!.amount));
        final change = receipt.payment!.changeDue;
        if (change != null && change > 0) {
          row(rtl ? 'الباقي' : 'Change', amount(change));
        }
        if (receipt.payment!.reference != null) {
          row(rtl ? 'المرجع' : 'Reference', receipt.payment!.reference!);
        }
      }
      for (final value in receipt.footerLines) {
        line(value, center: true);
      }
      y += 18;
      final height = y.ceil();
      final picture = recorder.endRecording();
      final image = await picture.toImage(width, height);
      final raw = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
      final png = await image.toByteData(format: ui.ImageByteFormat.png);
      image.dispose();
      picture.dispose();
      if (raw == null || png == null) throw const ReceiptRenderException();
      return ReceiptRaster(
        width: width,
        height: height,
        rgba: raw.buffer.asUint8List(),
        png: png.buffer.asUint8List(),
      );
    } catch (_) {
      throw const ReceiptRenderException();
    }
  }

  static Future<void> _loadFonts() async {
    for (final (family, path) in <(String, String)>[
      ('IBMPlexSansArabic', 'assets/fonts/IBMPlexSansArabic-Regular.ttf'),
      ('IBMPlexSansArabic', 'assets/fonts/IBMPlexSansArabic-Bold.ttf'),
      ('Manrope', 'assets/fonts/Manrope-Regular.ttf'),
      ('Manrope', 'assets/fonts/Manrope-Bold.ttf'),
    ]) {
      final bytes = await rootBundle.load(path);
      await (FontLoader(family)..addFont(Future.value(bytes))).load();
    }
  }
}

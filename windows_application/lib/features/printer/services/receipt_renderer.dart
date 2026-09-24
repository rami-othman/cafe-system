import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:intl/date_symbol_data_local.dart';

import '../../../core/utils/backend_datetime.dart';
import '../models/printer_config.dart';
import '../models/receipt_data.dart';
import '../models/receipt_template.dart';

class ReceiptRenderException implements Exception {
  const ReceiptRenderException();
}

/// Digit-group tokens (phone numbers, IP-like dotted quads) and dash-joined
/// alphanumeric codes (order/coupon/reference IDs) — the class of "structured
/// LTR values" whose internal character order the Unicode bidi algorithm
/// scrambles when they're painted inside an RTL paragraph (e.g. a phone
/// number like "+963 11 123 4567" visually reversing on an Arabic receipt).
final RegExp _structuredLtrToken = RegExp(
  r'(\+?\d[\d\s\-().]{3,}\d|\b[A-Za-z]+-[A-Za-z0-9-]+\b|\b\d{1,3}(?:\.\d{1,3}){3}\b)',
);

// Left-to-Right Isolate / Pop Directional Isolate (Unicode Bidi formatting
// characters), built from their code points rather than typed as literal
// glyphs: as literal glyphs they are themselves invisible bidi-control
// characters and would make this source file's own text render misleadingly
// in bidi-aware editors/diffs.
final String _lri = String.fromCharCode(0x2066);
final String _pdi = String.fromCharCode(0x2069);

/// Wraps structured LTR tokens in Unicode directional isolates (U+2066 LRI …
/// U+2069 PDI) so their internal character order survives being painted
/// inside an RTL paragraph, without forcing the surrounding text's own
/// direction to LTR. This is the fix applied uniformly to every string this
/// renderer paints, so it also protects structured tokens embedded inside
/// otherwise-Arabic text (e.g. a coupon code inside footer text), not only
/// whole-line values.
@visibleForTesting
String applyBidiIsolation(String value) => value.replaceAllMapped(
  _structuredLtrToken,
  (Match match) => '$_lri${match[0]}$_pdi',
);

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
///
/// Section visibility and order come from [ReceiptData.template]; hidden
/// fields are skipped and sections render in `template.sectionOrder`. A
/// receipt without a product name or a total is never produced regardless of
/// what the template says (see [ReceiptTemplateItems.showProductName] /
/// [ReceiptTemplateTotals.showTotal]).
class ReceiptRenderer {
  static Future<void>? _fontsReady;
  static final Map<String, ui.Image> _logoCache = <String, ui.Image>{};

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
      final template = receipt.template;
      final logoUrl = receipt.logoUrl;
      final ui.Image? logo =
          template.header.showLogo && logoUrl != null && logoUrl.isNotEmpty
          ? await _loadLogo(logoUrl)
          : null;
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
      String orderTypeLabel(String type) => switch (type) {
        'dine_in' => rtl ? 'صالة' : 'Dine-in',
        'takeaway' => rtl ? 'سفري' : 'Takeaway',
        'delivery' => rtl ? 'توصيل' : 'Delivery',
        _ => type,
      };

      TextPainter painter(
        String value, {
        bool bold = false,
        double size = 22,
        ui.TextDirection? textDirection,
        double? maxWidth,
      }) {
        final p = TextPainter(
          text: TextSpan(
            text: applyBidiIsolation(value),
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
          textDirection: RegExp(r'[؀-ۿ]').hasMatch(value)
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

      void drawLogo(ui.Image image) {
        const maxHeight = 120.0;
        final scale = math.min(
          contentWidth / image.width,
          maxHeight / image.height,
        );
        final w = image.width * scale;
        final h = image.height * scale;
        canvas.drawImageRect(
          image,
          Rect.fromLTWH(0, 0, image.width.toDouble(), image.height.toDouble()),
          Rect.fromLTWH((width - w) / 2, y, w, h),
          Paint(),
        );
        y += h + 5;
      }

      bool renderHeader() {
        final start = y;
        if (template.header.showLogo && logo != null) drawLogo(logo);
        if (template.header.showCafeName) {
          line(receipt.cafeName, center: true, bold: true, size: 26);
        }
        if (template.header.showBranchName) {
          line(receipt.branchName, center: true, bold: true, size: 26);
        }
        if (template.header.showAddress) line(receipt.address, center: true);
        if (template.header.showPhone) line(receipt.phone, center: true);
        for (final String status in documentStatusLines(
          locale,
          isPreBill: isPreBill,
        )) {
          line(status, center: true, bold: true);
        }
        return y > start;
      }

      bool renderOrderInfo() {
        final start = y;
        final info = template.orderInfo;
        if (info.showOrderNumber) {
          row(rtl ? 'الطلب' : 'Order', receipt.orderNumber);
        }
        if (info.showDateTime) row(rtl ? 'التاريخ' : 'Date', formattedDate);
        if (info.showCashier && receipt.cashierName != null) {
          row(rtl ? 'أمين الصندوق' : 'Cashier', receipt.cashierName!);
        }
        if (info.showCustomer && receipt.customerName != null) {
          row(rtl ? 'العميل' : 'Customer', receipt.customerName!);
        }
        if (info.showOrderType && receipt.orderType != null) {
          row(
            rtl ? 'نوع الطلب' : 'Order type',
            orderTypeLabel(receipt.orderType!),
          );
        }
        return y > start;
      }

      bool renderItems() {
        final start = y;
        final cfg = template.items;
        for (final item in receipt.items) {
          line(item.name, bold: true);
          final leftParts = <String>[
            if (cfg.showQuantity) quantity(item.quantity),
            if (cfg.showUnitPrice) '× ${amount(item.unitPrice)}',
          ];
          row(leftParts.join(' '), amount(item.lineTotal));
          if (cfg.showModifiers) {
            for (final modifier in item.modifiers) {
              line('• $modifier', size: 19);
            }
          }
          if (cfg.showNotes) line(item.note, size: 19);
          y += 7;
        }
        return y > start;
      }

      bool renderTotals() {
        final start = y;
        final cfg = template.totals;
        if (cfg.showSubtotal) {
          row(rtl ? 'المجموع الفرعي' : 'Subtotal', amount(receipt.subtotal));
        }
        if (cfg.showDiscount && receipt.discountTotal != 0) {
          row(rtl ? 'الخصم' : 'Discount', amount(receipt.discountTotal));
        }
        if (cfg.showTax) row(rtl ? 'الضريبة' : 'Tax', amount(receipt.taxTotal));
        // showTotal is always true: a receipt with no total is meaningless.
        row(rtl ? 'الإجمالي' : 'Total', amount(receipt.total), bold: true);
        return y > start;
      }

      bool renderPayment() {
        final start = y;
        final cfg = template.payment;
        if (receipt.total == 0) {
          line(rtl ? 'لا يلزم دفع' : 'No payment required', center: true);
        } else if (!isPreBill && receipt.payment != null) {
          final method = receipt.payment!.method;
          if (cfg.showPaymentMethod && method != null) {
            final label = switch (method.toLowerCase()) {
              'cash' => rtl ? 'نقداً' : 'Cash',
              'card' => rtl ? 'بطاقة' : 'Card',
              'wallet' => rtl ? 'محفظة' : 'Wallet',
              'split' => rtl ? 'دفع مقسم' : 'Split',
              _ => method,
            };
            row(rtl ? 'طريقة الدفع' : 'Payment', label);
          }
          if (cfg.showPaidAmount) {
            row(rtl ? 'المدفوع' : 'Paid', amount(receipt.payment!.amount));
          }
          final change = receipt.payment!.changeDue;
          if (cfg.showChange && change != null && change > 0) {
            row(rtl ? 'الباقي' : 'Change', amount(change));
          }
          if (receipt.payment!.reference != null) {
            row(rtl ? 'المرجع' : 'Reference', receipt.payment!.reference!);
          }
        }
        return y > start;
      }

      bool renderFooter() {
        final start = y;
        if (template.footer.enabled) {
          final text = template.footer.text.trim().isEmpty
              ? receipt.footerText
              : template.footer.text;
          line(text, center: true);
        }
        return y > start;
      }

      bool renderSection(ReceiptTemplateSection section) => switch (section) {
        ReceiptTemplateSection.header => renderHeader(),
        ReceiptTemplateSection.orderInfo => renderOrderInfo(),
        ReceiptTemplateSection.items => renderItems(),
        ReceiptTemplateSection.totals => renderTotals(),
        ReceiptTemplateSection.payment => renderPayment(),
        ReceiptTemplateSection.footer => renderFooter(),
      };

      final sections = template.sectionOrder;
      for (var i = 0; i < sections.length; i++) {
        final rendered = renderSection(sections[i]);
        final isLast = i == sections.length - 1;
        final nextIsFooter =
            !isLast && sections[i + 1] == ReceiptTemplateSection.footer;
        if (rendered && !isLast && !nextIsFooter) rule();
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

  /// Never lets a broken logo abort the receipt: any failure (offline, 404,
  /// timeout, corrupt image) is swallowed and the header simply skips it.
  static Future<ui.Image?> _loadLogo(String url) async {
    final cached = _logoCache[url];
    if (cached != null) return cached;
    HttpClient? client;
    try {
      client = HttpClient()..connectionTimeout = const Duration(seconds: 5);
      final request = await client.getUrl(Uri.parse(url));
      final response = await request.close().timeout(
        const Duration(seconds: 5),
      );
      if (response.statusCode != 200) return null;
      final builder = BytesBuilder(copy: false);
      await for (final chunk in response) {
        builder.add(chunk);
      }
      final codec = await ui.instantiateImageCodec(builder.takeBytes());
      final frame = await codec.getNextFrame();
      _logoCache[url] = frame.image;
      return frame.image;
    } catch (_) {
      return null;
    } finally {
      client?.close(force: true);
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

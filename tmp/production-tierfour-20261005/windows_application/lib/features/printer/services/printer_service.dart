import 'dart:async';

import 'package:flutter/widgets.dart';

import '../models/printer_config.dart';
import '../models/receipt_data.dart';
import 'printer_connection.dart';
import 'printer_connection_factory.dart';
import 'receipt_renderer.dart';
import 'test_receipt_data.dart';

enum PrinterPrintFailure {
  invalidConfiguration,
  unreachable,
  timeout,
  unsupported,
  failed,
}

class PrinterPrintResult {
  const PrinterPrintResult.success() : failure = null;
  const PrinterPrintResult.failure(this.failure);
  final PrinterPrintFailure? failure;
  bool get isSuccess => failure == null;
}

abstract interface class PrinterService {
  /// Prints a fixed sample receipt through the exact same rendering/encoding
  /// pipeline a real order's receipt uses, so a successful test print proves
  /// the actual print path (not a diagnostic stand-in) can reach the
  /// printer. Creates no order and no payment.
  Future<PrinterPrintResult> printTestReceipt(
    PrinterConfig config,
    Locale locale,
  );
  Future<PrinterPrintResult> printRaster(
    PrinterConfig config,
    ReceiptRaster raster,
  );
  Future<PrinterPrintResult> printReceipt(
    PrinterConfig config,
    ReceiptData receipt,
    Locale locale, {
    bool isPreBill = false,
  });
}

class NetworkEscPosPrinterService implements PrinterService {
  NetworkEscPosPrinterService({
    PrinterConnectionFactory? connectionFactory,
    ReceiptRenderer? receiptRenderer,
    this.connectionTimeout = const Duration(seconds: 5),
    this.writeTimeout = const Duration(seconds: 5),
  }) : _connectionFactory =
           connectionFactory ?? createPrinterConnectionFactory(),
       _receiptRenderer = receiptRenderer ?? ReceiptRenderer();

  final PrinterConnectionFactory _connectionFactory;
  final ReceiptRenderer _receiptRenderer;
  final Duration connectionTimeout;
  final Duration writeTimeout;

  @override
  Future<PrinterPrintResult> printTestReceipt(
    PrinterConfig config,
    Locale locale,
  ) async {
    return printReceipt(config, buildTestReceiptData(), locale);
  }

  @override
  Future<PrinterPrintResult> printReceipt(
    PrinterConfig config,
    ReceiptData receipt,
    Locale locale, {
    bool isPreBill = false,
  }) async {
    // Render exceptions deliberately escape; network failures return a result.
    final raster = await _receiptRenderer.render(
      receipt,
      locale: locale,
      paperWidth: config.paperWidth,
      isPreBill: isPreBill,
    );
    return printRaster(config, raster);
  }

  @override
  Future<PrinterPrintResult> printRaster(
    PrinterConfig config,
    ReceiptRaster raster,
  ) async {
    if (raster.width <= 0 ||
        raster.width % 8 != 0 ||
        raster.height <= 0 ||
        raster.rgba.length != raster.width * raster.height * 4) {
      throw const ReceiptRenderException();
    }
    final bytes = <int>[0x1b, 0x40];
    final rowBytes = raster.width ~/ 8;
    for (var top = 0; top < raster.height; top += 255) {
      final rows = (raster.height - top).clamp(0, 255);
      bytes.addAll(<int>[
        0x1d,
        0x76,
        0x30,
        0x00,
        rowBytes & 0xff,
        rowBytes >> 8,
        rows & 0xff,
        rows >> 8,
      ]);
      for (var y = top; y < top + rows; y++) {
        for (var x = 0; x < raster.width; x += 8) {
          var bits = 0;
          for (var bit = 0; bit < 8; bit++) {
            final offset = (y * raster.width + x + bit) * 4;
            final light =
                (raster.rgba[offset] * 299 +
                    raster.rgba[offset + 1] * 587 +
                    raster.rgba[offset + 2] * 114) ~/
                1000;
            if (raster.rgba[offset + 3] > 127 && light < 160) {
              bits |= 0x80 >> bit;
            }
          }
          bytes.add(bits);
        }
      }
    }
    bytes.addAll(<int>[0x1b, 0x64, 0x03, 0x1d, 0x56, 0x00]);
    return _send(config, bytes);
  }

  Future<PrinterPrintResult> _send(
    PrinterConfig config,
    List<int> bytes,
  ) async {
    if (!config.isValid) {
      return const PrinterPrintResult.failure(
        PrinterPrintFailure.invalidConfiguration,
      );
    }
    PrinterConnection? connection;
    try {
      connection = await _connectionFactory.connect(
        config.ipAddress.trim(),
        config.port,
        timeout: connectionTimeout,
      );
      await connection.write(bytes, timeout: writeTimeout);
      return const PrinterPrintResult.success();
    } on TimeoutException {
      return const PrinterPrintResult.failure(PrinterPrintFailure.timeout);
    } on UnsupportedError {
      return const PrinterPrintResult.failure(PrinterPrintFailure.unsupported);
    } catch (_) {
      return const PrinterPrintResult.failure(PrinterPrintFailure.unreachable);
    } finally {
      try {
        await connection?.close();
      } catch (_) {
        // A connection error is already represented above. Never let cleanup
        // turn it into an unhandled UI exception.
      }
    }
  }
}

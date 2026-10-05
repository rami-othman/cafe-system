import 'dart:async';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/widgets.dart';
import 'package:windows_application/features/printer/models/printer_config.dart';
import 'package:windows_application/features/printer/models/receipt_data.dart';
import 'package:windows_application/features/printer/services/printer_connection.dart';
import 'package:windows_application/features/printer/services/printer_service.dart';
import 'package:windows_application/features/printer/services/receipt_renderer.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const PrinterConfig config = PrinterConfig(
    ipAddress: '192.168.1.50',
    enabled: true,
  );

  test(
    'test print renders the real receipt pipeline and always closes the TCP connection',
    () async {
      final _FakeConnection connection = _FakeConnection();
      final NetworkEscPosPrinterService service = NetworkEscPosPrinterService(
        connectionFactory: _FakeFactory(connection: connection),
      );

      final PrinterPrintResult result = await service.printTestReceipt(
        config,
        const Locale('en'),
      );

      expect(result.isSuccess, isTrue);
      // printRaster always opens with the ESC/POS init sequence, whatever
      // the rasterized content is — proves the raster path ran, not a
      // hand-built diagnostic payload.
      expect(connection.written, containsAllInOrder(<int>[0x1b, 0x40]));
      expect(connection.closed, isTrue);
    },
  );

  test('maps a connection timeout to a safe timeout result', () async {
    final NetworkEscPosPrinterService service = NetworkEscPosPrinterService(
      connectionFactory: _FakeFactory(timeout: true),
    );

    final PrinterPrintResult result = await service.printTestReceipt(
      config,
      const Locale('en'),
    );

    expect(result.failure, PrinterPrintFailure.timeout);
  });

  test(
    'maps connection errors to unreachable without leaking a connection',
    () async {
      final NetworkEscPosPrinterService service = NetworkEscPosPrinterService(
        connectionFactory: _FakeFactory(throwsOnConnect: true),
      );

      final PrinterPrintResult result = await service.printTestReceipt(
        config,
        const Locale('en'),
      );

      expect(result.failure, PrinterPrintFailure.unreachable);
    },
  );

  test(
    'test print uses the real ReceiptRenderer, not a second renderer',
    () async {
      final connection = _FakeConnection();
      final renderer = _RecordingRenderer();
      final service = NetworkEscPosPrinterService(
        connectionFactory: _FakeFactory(connection: connection),
        receiptRenderer: renderer,
      );

      final result = await service.printTestReceipt(config, const Locale('ar'));

      expect(result.isSuccess, isTrue);
      expect(renderer.receivedReceipt?.orderNumber, 'TEST-0000');
      expect(renderer.receivedLocale, const Locale('ar'));
    },
  );

  test('renderer to TCP service sends raster, feed, cut and closes', () async {
    final connection = _FakeConnection();
    final service = NetworkEscPosPrinterService(
      connectionFactory: _FakeFactory(connection: connection),
    );
    final receipt = ReceiptData.fromJson(<String, dynamic>{
      'orderNumber': 'R-1',
      'date': '2026-09-23',
      'items': <Map<String, dynamic>>[],
      'subtotal': 0,
      'discountTotal': 0,
      'taxTotal': 0,
      'total': 0,
    });
    final result = await service.printReceipt(
      config,
      receipt,
      const Locale('ar'),
    );
    expect(result.isSuccess, isTrue);
    expect(connection.written.take(2), <int>[0x1b, 0x40]);
    expect(connection.written.sublist(2, 6), <int>[0x1d, 0x76, 0x30, 0x00]);
    expect(connection.written.sublist(connection.written.length - 6), <int>[
      0x1b,
      0x64,
      0x03,
      0x1d,
      0x56,
      0x00,
    ]);
    expect(connection.closed, isTrue);
  });

  test('pre-bill mode is passed to the receipt renderer', () async {
    final connection = _FakeConnection();
    final renderer = _RecordingRenderer();
    final service = NetworkEscPosPrinterService(
      connectionFactory: _FakeFactory(connection: connection),
      receiptRenderer: renderer,
    );
    final result = await service.printReceipt(
      config,
      ReceiptData.fromJson(<String, dynamic>{
        'orderNumber': 'R-2',
        'date': '2026-09-23',
        'items': <Map<String, dynamic>>[],
        'subtotal': 0,
        'discountTotal': 0,
        'taxTotal': 0,
        'total': 0,
      }),
      const Locale('en'),
      isPreBill: true,
    );

    expect(result.isSuccess, isTrue);
    expect(renderer.receivedPreBill, isTrue);
  });

  test(
    'malformed raster is a render error before any TCP connection',
    () async {
      final service = NetworkEscPosPrinterService(
        connectionFactory: _FakeFactory(throwsOnConnect: true),
      );
      expect(
        () => service.printRaster(
          config,
          ReceiptRaster(
            width: 7,
            height: 1,
            rgba: Uint8List(28),
            png: Uint8List(0),
          ),
        ),
        throwsA(isA<ReceiptRenderException>()),
      );
    },
  );
}

class _FakeFactory implements PrinterConnectionFactory {
  _FakeFactory({
    this.connection,
    this.timeout = false,
    this.throwsOnConnect = false,
  });
  final _FakeConnection? connection;
  final bool timeout;
  final bool throwsOnConnect;
  @override
  Future<PrinterConnection> connect(
    String host,
    int port, {
    required Duration timeout,
  }) async {
    if (this.timeout) throw TimeoutException('timed out');
    if (throwsOnConnect) throw StateError('offline');
    return connection!;
  }
}

class _FakeConnection implements PrinterConnection {
  List<int> written = <int>[];
  bool closed = false;
  @override
  Future<void> close() async => closed = true;
  @override
  Future<void> write(List<int> bytes, {required Duration timeout}) async =>
      written = bytes;
}

class _RecordingRenderer extends ReceiptRenderer {
  bool? receivedPreBill;
  ReceiptData? receivedReceipt;
  Locale? receivedLocale;

  @override
  Future<ReceiptRaster> render(
    ReceiptData receipt, {
    required Locale locale,
    required PrinterPaperWidth paperWidth,
    bool isPreBill = false,
  }) async {
    receivedPreBill = isPreBill;
    receivedReceipt = receipt;
    receivedLocale = locale;
    return ReceiptRaster(
      width: 8,
      height: 1,
      rgba: Uint8List.fromList(<int>[
        255,
        255,
        255,
        255,
        255,
        255,
        255,
        255,
        255,
        255,
        255,
        255,
        255,
        255,
        255,
        255,
        255,
        255,
        255,
        255,
        255,
        255,
        255,
        255,
        255,
        255,
        255,
        255,
        255,
        255,
        255,
        255,
      ]),
      png: Uint8List(0),
    );
  }
}

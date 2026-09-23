import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:windows_application/features/printer/models/printer_config.dart';
import 'package:windows_application/features/printer/services/printer_connection.dart';
import 'package:windows_application/features/printer/services/printer_service.dart';

void main() {
  const PrinterConfig config = PrinterConfig(
    ipAddress: '192.168.1.50',
    enabled: true,
  );

  test('sends a test job and always closes the TCP connection', () async {
    final _FakeConnection connection = _FakeConnection();
    final NetworkEscPosPrinterService service = NetworkEscPosPrinterService(
      connectionFactory: _FakeFactory(connection: connection),
    );

    final PrinterPrintResult result = await service.printTest(config);

    expect(result.isSuccess, isTrue);
    expect(connection.written, containsAllInOrder(<int>[0x1b, 0x40]));
    expect(connection.closed, isTrue);
  });

  test('maps a connection timeout to a safe timeout result', () async {
    final NetworkEscPosPrinterService service = NetworkEscPosPrinterService(
      connectionFactory: _FakeFactory(timeout: true),
    );

    final PrinterPrintResult result = await service.printTest(config);

    expect(result.failure, PrinterPrintFailure.timeout);
  });

  test(
    'maps connection errors to unreachable without leaking a connection',
    () async {
      final NetworkEscPosPrinterService service = NetworkEscPosPrinterService(
        connectionFactory: _FakeFactory(throwsOnConnect: true),
      );

      final PrinterPrintResult result = await service.printTest(config);

      expect(result.failure, PrinterPrintFailure.unreachable);
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

import 'dart:async';

import '../models/printer_config.dart';
import 'printer_connection.dart';
import 'printer_connection_factory.dart';

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
  Future<PrinterPrintResult> printTest(PrinterConfig config);
}

class NetworkEscPosPrinterService implements PrinterService {
  NetworkEscPosPrinterService({
    PrinterConnectionFactory? connectionFactory,
    this.connectionTimeout = const Duration(seconds: 5),
    this.writeTimeout = const Duration(seconds: 5),
  }) : _connectionFactory =
           connectionFactory ?? createPrinterConnectionFactory();

  final PrinterConnectionFactory _connectionFactory;
  final Duration connectionTimeout;
  final Duration writeTimeout;

  @override
  Future<PrinterPrintResult> printTest(PrinterConfig config) async {
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
      await connection.write(_testJob(config), timeout: writeTimeout);
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

  List<int> _testJob(PrinterConfig config) {
    final String separator = List<String>.filled(
      config.paperWidth.columns,
      '-',
    ).join();
    return <int>[
      0x1b, 0x40, // initialize
      0x1b, 0x61, 0x01, // center alignment
      ...'CAFE SYSTEM\nPrinter Test\n\nWindows / Android\n${config.paperWidth.apiValue}\n\nPrinter connection successful.\n\n$separator\nTest Print OK\n\n\n'
          .codeUnits,
      0x1d,
      0x56,
      0x00, // full cut (ignored safely by printers without a cutter)
    ];
  }
}

import 'printer_connection.dart';

PrinterConnectionFactory createPrinterConnectionFactory() =>
    _UnsupportedPrinterConnectionFactory();

class _UnsupportedPrinterConnectionFactory implements PrinterConnectionFactory {
  @override
  Future<PrinterConnection> connect(
    String host,
    int port, {
    required Duration timeout,
  }) => Future<PrinterConnection>.error(
    UnsupportedError(
      'Network ESC/POS printing is unavailable on this platform.',
    ),
  );
}

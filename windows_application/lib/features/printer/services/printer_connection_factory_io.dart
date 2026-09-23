import 'dart:io';

import 'printer_connection.dart';

PrinterConnectionFactory createPrinterConnectionFactory() =>
    _IoPrinterConnectionFactory();

class _IoPrinterConnectionFactory implements PrinterConnectionFactory {
  @override
  Future<PrinterConnection> connect(
    String host,
    int port, {
    required Duration timeout,
  }) async =>
      _IoPrinterConnection(await Socket.connect(host, port, timeout: timeout));
}

class _IoPrinterConnection implements PrinterConnection {
  _IoPrinterConnection(this._socket);
  final Socket _socket;

  @override
  Future<void> write(List<int> bytes, {required Duration timeout}) async {
    _socket.add(bytes);
    await _socket.flush().timeout(timeout);
  }

  @override
  Future<void> close() async => _socket.destroy();
}

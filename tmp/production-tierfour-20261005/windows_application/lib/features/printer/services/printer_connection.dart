abstract interface class PrinterConnection {
  Future<void> write(List<int> bytes, {required Duration timeout});
  Future<void> close();
}

abstract interface class PrinterConnectionFactory {
  Future<PrinterConnection> connect(
    String host,
    int port, {
    required Duration timeout,
  });
}

class AppException implements Exception {
  const AppException(this.message, {this.code});

  final String message;
  final String? code;

  @override
  String toString() {
    if (code == null) {
      return 'AppException: $message';
    }

    return 'AppException($code): $message';
  }
}

enum ApiErrorType {
  networkUnavailable,
  connectionTimeout,
  sendTimeout,
  receiveTimeout,
  unauthenticated,
  forbidden,
  validation,
  conflict,
  server,
  unknown,
}

class ApiException implements Exception {
  const ApiException({
    required this.message,
    this.statusCode,
    this.validationErrors,
    this.code,
    this.type = ApiErrorType.unknown,
  });

  final String message;
  final int? statusCode;
  final Map<String, List<String>>? validationErrors;
  final String? code;
  final ApiErrorType type;

  @override
  String toString() => message;
}

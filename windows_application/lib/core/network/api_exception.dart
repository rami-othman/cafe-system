class ApiException implements Exception {
  const ApiException({
    required this.message,
    this.statusCode,
    this.validationErrors,
  });

  final String message;
  final int? statusCode;
  final Map<String, List<String>>? validationErrors;

  @override
  String toString() => message;
}

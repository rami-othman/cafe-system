import '../../../core/network/api_exception.dart';

enum CustomerFailureKind {
  forbidden,
  notFound,
  conflict,
  validation,
  timeout,
  network,
  server,
  unknown,
}

class CustomerFailure {
  const CustomerFailure({
    required this.kind,
    this.code,
    this.fieldErrors = const <String, List<String>>{},
  });

  final CustomerFailureKind kind;
  final String? code;
  final Map<String, List<String>> fieldErrors;

  factory CustomerFailure.fromError(Object error) {
    if (error is! ApiException) {
      return const CustomerFailure(kind: CustomerFailureKind.unknown);
    }
    final CustomerFailureKind kind = switch (error.type) {
      ApiErrorType.forbidden => CustomerFailureKind.forbidden,
      ApiErrorType.validation => CustomerFailureKind.validation,
      ApiErrorType.conflict => CustomerFailureKind.conflict,
      ApiErrorType.connectionTimeout ||
      ApiErrorType.sendTimeout ||
      ApiErrorType.receiveTimeout => CustomerFailureKind.timeout,
      ApiErrorType.networkUnavailable => CustomerFailureKind.network,
      ApiErrorType.server => CustomerFailureKind.server,
      _ when error.statusCode == 404 => CustomerFailureKind.notFound,
      _ => CustomerFailureKind.unknown,
    };
    return CustomerFailure(
      kind: kind,
      code: error.code,
      fieldErrors: error.validationErrors ?? const <String, List<String>>{},
    );
  }
}

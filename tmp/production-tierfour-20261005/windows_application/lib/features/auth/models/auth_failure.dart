import 'package:equatable/equatable.dart';

/// Presentation-safe Auth failures. These values never expose server messages.
enum AuthFailureKind {
  invalidCredentials,
  tooManyAttempts,
  networkUnavailable,
  connectionTimeout,
  serverUnavailable,
  validation,
  invalidResponse,
  secureStorageFailure,
  verifiedSessionSaveFailed,
  secureStorageReadFailure,
  corruptSavedSession,
  unableToVerifySession,
  offlineVerificationRequired,
  passwordChangedSessionSaveFailed,
  unexpected,
  incorrectCurrentPassword,
  weakNewPassword,
  passwordConfirmationMismatch,
}

enum AuthField {
  identifier,
  password,
  currentPassword,
  newPassword,
  confirmation,
}

/// The only backend Auth codes interpreted by Flutter. UI text is always
/// derived from [AuthFailureKind], never from a server-provided message.
abstract final class AuthBackendCode {
  static const String authRequired = 'AUTH_REQUIRED';
  static const String sessionInvalid = 'AUTH_SESSION_INVALID';
  static const String tenantNotOperational = 'TENANT_NOT_OPERATIONAL';
  static const String invalidCredentials = 'INVALID_CREDENTIALS';
  static const String loginRateLimited = 'LOGIN_RATE_LIMITED';
  static const String loginValidationFailed = 'AUTH_LOGIN_VALIDATION_FAILED';
  static const String passwordChangeValidationFailed =
      'PASSWORD_CHANGE_VALIDATION_FAILED';
  static const String incorrectCurrentPassword =
      'INCORRECT_CURRENT_PASSWORD';

  static bool isAuthoritativeInvalidation(String? code) =>
      code == authRequired || code == sessionInvalid;

  static bool isTenantNotOperational(String? code) =>
      code == tenantNotOperational;

  static AuthFailureKind? loginFailureKind(String? code) => switch (code) {
    invalidCredentials => AuthFailureKind.invalidCredentials,
    loginRateLimited => AuthFailureKind.tooManyAttempts,
    _ => null,
  };

  static bool isIncorrectCurrentPassword(String? code) =>
      code == incorrectCurrentPassword;
}

class AuthFailure extends Equatable {
  const AuthFailure(
    this.kind, {
    this.fieldErrors = const <AuthField, AuthFailureKind>{},
  });

  final AuthFailureKind kind;
  final Map<AuthField, AuthFailureKind> fieldErrors;

  AuthFailure? clearField(AuthField field) {
    if (fieldErrors.isEmpty) return null;
    final Map<AuthField, AuthFailureKind> remaining =
        Map<AuthField, AuthFailureKind>.of(fieldErrors)..remove(field);
    if (remaining.isEmpty) return null;
    return AuthFailure(kind, fieldErrors: remaining);
  }

  @override
  List<Object> get props => <Object>[kind, fieldErrors];
}

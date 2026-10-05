import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/network/dio_api_client.dart';
import '../models/auth_failure.dart';
import '../models/auth_session.dart';
import '../repositories/auth_repository.dart';
import '../repositories/auth_session_storage.dart';
import 'auth_session_state.dart';

class AuthSessionCubit extends Cubit<AuthSessionState> {
  AuthSessionCubit({
    required AuthRepository repository,
    required AuthSessionStorage storage,
    required DioApiClient apiClient,
    DateTime Function()? now,
  }) : this._(repository, storage, apiClient, now ?? DateTime.now);

  AuthSessionCubit._(
    this._repository,
    this._storage,
    this._apiClient,
    this._now,
  ) : super(const AuthSessionState()) {
    _storageChanges = _storage.changes.listen((_) => _onStorageChanged());
  }

  final AuthRepository _repository;
  final AuthSessionStorage _storage;
  final DioApiClient _apiClient;
  final DateTime Function() _now;
  late final StreamSubscription<void> _storageChanges;

  Future<void>? _verificationInFlight;
  Future<void>? _expirationInFlight;
  Future<void> _storageMutationTail = Future<void>.value();
  int _operation = 0;
  bool _restoreQueued = false;
  bool _discardStoredSessionForRun = false;
  bool _isRevokingForRecovery = false;

  @override
  Future<void> close() async {
    _operation++;
    await _storageChanges.cancel();
    return super.close();
  }

  /// Coalesces startup, cross-tab, and user retry verification. A storage
  /// event during verification invalidates the old result and schedules only
  /// one fresh read after it settles.
  Future<void> restore() {
    if (isClosed) return Future<void>.value();
    if (_verificationInFlight != null) return _verificationInFlight!;
    final int operation = _beginOperation();
    return _trackVerification(_restoreFromStorage(operation));
  }

  Future<void> retryVerification() {
    if (isClosed ||
        state.verificationInProgress ||
        (state.status != AuthSessionStatus.verificationRequired &&
            state.status != AuthSessionStatus.tenantNotOperational)) {
      return Future<void>.value();
    }
    if (_verificationInFlight != null) return _verificationInFlight!;

    final int operation = _beginOperation();
    final AuthSession? cached = state.session;
    _emitIfCurrent(
      operation,
      state.copyWith(verificationInProgress: true, clearFailure: true),
    );
    return _trackVerification(
      cached == null
          ? _retryFromStorage(operation)
          : _verifyCached(
              cached,
              operation,
              allowOffline: false,
              remainTenantBlockedOnTemporaryFailure:
                  state.status == AuthSessionStatus.tenantNotOperational,
            ),
    );
  }

  Future<void> _restoreFromStorage(int operation) async {
    _emitIfCurrent(
      operation,
      const AuthSessionState(status: AuthSessionStatus.restoring),
    );
    if (_discardStoredSessionForRun) {
      _clearApiContext();
      _emitIfCurrent(
        operation,
        const AuthSessionState(status: AuthSessionStatus.unauthenticated),
      );
      return;
    }

    final AuthSession? cached = await _readCachedSession(operation);
    if (cached == null || !_isCurrent(operation)) return;
    await _verifyCached(cached, operation, allowOffline: true);
  }

  Future<void> _retryFromStorage(int operation) async {
    if (_discardStoredSessionForRun) {
      _emitIfCurrent(
        operation,
        const AuthSessionState(status: AuthSessionStatus.unauthenticated),
      );
      return;
    }
    final AuthSession? cached = await _readCachedSession(
      operation,
      retrying: true,
    );
    if (cached == null || !_isCurrent(operation)) return;
    await _verifyCached(cached, operation, allowOffline: true);
  }

  Future<AuthSession?> _readCachedSession(
    int operation, {
    bool retrying = false,
  }) async {
    try {
      if (await _storage.isAuthoritativelyInvalidated()) {
        _discardStoredSessionForRun = true;
        _clearApiContext();
        await _clearStoredSessionBestEffort(operation);
        _emitIfCurrent(
          operation,
          const AuthSessionState(
            status: AuthSessionStatus.unauthenticated,
            message: AuthMessage.sessionExpired,
          ),
        );
        return null;
      }
      final AuthSession? cached = await _storage.read();
      if (!_isCurrent(operation)) return null;
      if (cached == null) {
        _clearApiContext();
        _emitIfCurrent(
          operation,
          const AuthSessionState(status: AuthSessionStatus.unauthenticated),
        );
        return null;
      }
      if (!cached.isValidForRestore(_now())) {
        await _handleCorruptCachedSession(operation);
        return null;
      }
      return cached;
    } on AuthSessionStorageCorruptException {
      await _handleCorruptCachedSession(operation);
      return null;
    } catch (_) {
      _clearApiContext();
      _emitIfCurrent(
        operation,
        const AuthSessionState(
          status: AuthSessionStatus.verificationRequired,
          failure: AuthFailure(AuthFailureKind.secureStorageReadFailure),
        ),
      );
      return null;
    }
  }

  Future<void> _handleCorruptCachedSession(int operation) async {
    _discardStoredSessionForRun = true;
    _clearApiContext();
    await _clearStoredSessionBestEffort(operation);
    _emitIfCurrent(
      operation,
      const AuthSessionState(
        status: AuthSessionStatus.unauthenticated,
        failure: AuthFailure(AuthFailureKind.corruptSavedSession),
      ),
    );
  }

  Future<void> _verifyCached(
    AuthSession cached,
    int operation, {
    required bool allowOffline,
    bool remainTenantBlockedOnTemporaryFailure = false,
  }) async {
    if (!_isCurrent(operation)) return;
    _apiClient.setAccessToken(cached.accessToken);
    _apiClient.setAuthenticatedTenantId(cached.tenant.id);
    try {
      final AuthSession verified = await _repository.me(cached);
      if (!_isCurrent(operation)) return;
      try {
        await _writeStoredSession(verified);
      } catch (_) {
        await _handleVerifiedSessionSaveFailure(verified, operation);
        return;
      }
      _discardStoredSessionForRun = false;
      _enterIfCurrent(verified, operation);
    } on AuthInvalidResponseException {
      await _handleInvalidVerificationResponse(cached, operation);
    } on ApiException catch (error) {
      await _handleVerificationFailure(
        cached,
        error,
        operation,
        allowOffline: allowOffline,
        remainTenantBlockedOnTemporaryFailure:
            remainTenantBlockedOnTemporaryFailure,
      );
    } catch (_) {
      await _handleTemporaryVerificationFailure(
        cached,
        operation,
        allowOffline: allowOffline,
        remainTenantBlockedOnTemporaryFailure:
            remainTenantBlockedOnTemporaryFailure,
      );
    }
  }

  Future<void> _handleInvalidVerificationResponse(
    AuthSession cached,
    int operation,
  ) async {
    if (!_isCurrent(operation)) return;
    _discardStoredSessionForRun = true;
    _clearApiContext();
    _emitIfCurrent(
      operation,
      AuthSessionState(
        status: AuthSessionStatus.verificationRequired,
        session: cached,
        failure: const AuthFailure(AuthFailureKind.invalidResponse),
      ),
    );
  }

  Future<void> _handleVerifiedSessionSaveFailure(
    AuthSession verified,
    int operation,
  ) async {
    if (!_isCurrent(operation)) return;
    // The previous cache can carry roles or permissions that are no longer
    // authoritative. Remove it before offering a retry, and never allow this
    // process to fall back to it while storage remains unavailable.
    _discardStoredSessionForRun = true;
    await _clearLocalBestEffort(operation);
    _emitIfCurrent(
      operation,
      AuthSessionState(
        status: AuthSessionStatus.verificationRequired,
        session: verified,
        failure: const AuthFailure(AuthFailureKind.verifiedSessionSaveFailed),
      ),
    );
  }

  Future<void> _handleVerificationFailure(
    AuthSession cached,
    ApiException error,
    int operation, {
    required bool allowOffline,
    required bool remainTenantBlockedOnTemporaryFailure,
  }) async {
    if (!_isCurrent(operation)) return;
    if (_isTenantNotOperational(error)) {
      _clearApiContext();
      _emitIfCurrent(
        operation,
        AuthSessionState(
          status: AuthSessionStatus.tenantNotOperational,
          session: cached,
        ),
      );
      return;
    }
    if (_isAuthoritativeInvalidation(error)) {
      _discardStoredSessionForRun = true;
      await _markAuthoritativeInvalidation();
      await _clearLocalBestEffort(operation);
      _emitIfCurrent(
        operation,
        const AuthSessionState(
          status: AuthSessionStatus.unauthenticated,
          message: AuthMessage.sessionExpired,
        ),
      );
      return;
    }
    if (_isTemporaryVerificationFailure(error)) {
      await _handleTemporaryVerificationFailure(
        cached,
        operation,
        allowOffline: allowOffline,
        remainTenantBlockedOnTemporaryFailure:
            remainTenantBlockedOnTemporaryFailure,
      );
      return;
    }

    // A normal 403 is neither a suspended tenant nor proof that this token is
    // invalid. Keep credentials, but do not grant offline application access.
    _clearApiContext();
    _emitIfCurrent(
      operation,
      AuthSessionState(
        status: remainTenantBlockedOnTemporaryFailure
            ? AuthSessionStatus.tenantNotOperational
            : AuthSessionStatus.verificationRequired,
        session: cached,
        failure: const AuthFailure(AuthFailureKind.unableToVerifySession),
      ),
    );
  }

  Future<void> _handleTemporaryVerificationFailure(
    AuthSession cached,
    int operation, {
    required bool allowOffline,
    required bool remainTenantBlockedOnTemporaryFailure,
  }) async {
    if (!_isCurrent(operation)) return;
    if (allowOffline && _canRestoreOffline(cached)) {
      _enterIfCurrent(cached, operation);
      return;
    }
    _clearApiContext();
    _emitIfCurrent(
      operation,
      AuthSessionState(
        status: remainTenantBlockedOnTemporaryFailure
            ? AuthSessionStatus.tenantNotOperational
            : AuthSessionStatus.verificationRequired,
        session: cached,
        failure: AuthFailure(
          allowOffline
              ? AuthFailureKind.offlineVerificationRequired
              : AuthFailureKind.unableToVerifySession,
        ),
      ),
    );
  }

  bool _canRestoreOffline(AuthSession cached) {
    final DateTime now = _now();
    return cached.isValidForRestore(now) &&
        !cached.isAbsoluteExpiryPassed(now) &&
        cached.canRestoreOffline(now);
  }

  Future<void> login({
    required String identifier,
    required String password,
  }) async {
    if (state.status == AuthSessionStatus.submitting) return;
    final int operation = _beginOperation();
    _emitIfCurrent(
      operation,
      const AuthSessionState(status: AuthSessionStatus.submitting),
    );
    try {
      final AuthSession session = await _repository.login(
        identifier: identifier,
        password: password,
      );
      if (!session.isValidForLogin) throw const AuthInvalidResponseException();
      if (!_isCurrent(operation)) return;
      _apiClient.setAccessToken(session.accessToken);
      _apiClient.setAuthenticatedTenantId(session.tenant.id);
      try {
        await _persistAndEnter(session, operation);
      } catch (_) {
        await _revokeAndClearLocal(operation);
        _emitIfCurrent(
          operation,
          const AuthSessionState(
            status: AuthSessionStatus.unauthenticated,
            failure: AuthFailure(AuthFailureKind.secureStorageFailure),
          ),
        );
      }
    } on AuthInvalidResponseException {
      _clearApiContext();
      _emitIfCurrent(
        operation,
        const AuthSessionState(
          status: AuthSessionStatus.unauthenticated,
          failure: AuthFailure(AuthFailureKind.invalidResponse),
        ),
      );
    } on ApiException catch (error) {
      _clearApiContext();
      _emitIfCurrent(
        operation,
        AuthSessionState(
          status: AuthSessionStatus.unauthenticated,
          failure: _loginFailure(error),
        ),
      );
    } catch (_) {
      _clearApiContext();
      _emitIfCurrent(
        operation,
        const AuthSessionState(
          status: AuthSessionStatus.unauthenticated,
          failure: AuthFailure(AuthFailureKind.unexpected),
        ),
      );
    }
  }

  Future<void> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    final AuthSession? session = state.session;
    if (session == null || state.status == AuthSessionStatus.submitting) return;
    final int operation = _beginOperation();
    _emitIfCurrent(
      operation,
      state.copyWith(
        status: AuthSessionStatus.submitting,
        clearMessage: true,
        clearFailure: true,
      ),
    );
    bool passwordChanged = false;
    try {
      await _repository.changePassword(
        currentPassword: currentPassword,
        newPassword: newPassword,
      );
      passwordChanged = true;
      if (!_isCurrent(operation)) return;
      await _persistAndEnter(
        session.copyWith(mustChangePassword: false),
        operation,
      );
    } catch (error) {
      if (!_isCurrent(operation)) return;
      if (passwordChanged) {
        await _revokeAndClearLocal(operation);
        _emitIfCurrent(
          operation,
          const AuthSessionState(
            status: AuthSessionStatus.unauthenticated,
            failure: AuthFailure(
              AuthFailureKind.passwordChangedSessionSaveFailed,
            ),
          ),
        );
        return;
      }
      _emitIfCurrent(
        operation,
        state.copyWith(
          status: AuthSessionStatus.mustChangePassword,
          failure: error is ApiException
              ? _changePasswordFailure(error)
              : const AuthFailure(AuthFailureKind.unexpected),
        ),
      );
    }
  }

  void clearFailureFor(AuthField field) {
    final AuthFailure? failure = state.failure;
    if (failure == null || isClosed) return;
    final AuthFailure? updated = failure.clearField(field);
    emit(state.copyWith(failure: updated, clearFailure: updated == null));
  }

  /// Called by Dio only for a request that carried [requestToken]. The token
  /// comparison prevents a late old-session response from replacing a newer
  /// login or restore.
  Future<void> handleAuthenticatedFailure(
    ApiException error,
    String? requestToken,
  ) {
    if (isClosed ||
        (requestToken != null && requestToken != _apiClient.accessToken)) {
      return Future<void>.value();
    }
    if (_isTenantNotOperational(error)) return _enterTenantBlocked();
    return _isAuthoritativeInvalidation(error)
        ? expire()
        : Future<void>.value();
  }

  Future<void> expire() {
    if (isClosed ||
        _isRevokingForRecovery ||
        state.status == AuthSessionStatus.unauthenticated ||
        state.status == AuthSessionStatus.verificationRequired ||
        state.status == AuthSessionStatus.tenantNotOperational ||
        (state.status == AuthSessionStatus.submitting &&
            state.session == null)) {
      return Future<void>.value();
    }
    if (_expirationInFlight != null) return _expirationInFlight!;
    final int operation = _beginOperation();
    final Future<void> future = _expire(operation);
    _expirationInFlight = future;
    return future.whenComplete(() {
      if (identical(_expirationInFlight, future)) {
        _expirationInFlight = null;
      }
    });
  }

  Future<void> _expire(int operation) async {
    _discardStoredSessionForRun = true;
    await _markAuthoritativeInvalidation();
    await _clearLocalBestEffort(operation);
    _emitIfCurrent(
      operation,
      const AuthSessionState(
        status: AuthSessionStatus.unauthenticated,
        message: AuthMessage.sessionExpired,
      ),
    );
  }

  Future<void> _enterTenantBlocked() async {
    final AuthSession? cached = state.session;
    if (cached == null ||
        state.status == AuthSessionStatus.tenantNotOperational) {
      return;
    }
    final int operation = _beginOperation();
    _clearApiContext();
    _emitIfCurrent(
      operation,
      AuthSessionState(
        status: AuthSessionStatus.tenantNotOperational,
        session: cached,
      ),
    );
  }

  /// Recovery UI exits locally and deliberately issues no auth/me request.
  Future<void> returnToLogin() async {
    final int operation = _beginOperation();
    _discardStoredSessionForRun = true;
    await _clearLocalBestEffort(operation);
    _emitIfCurrent(
      operation,
      const AuthSessionState(status: AuthSessionStatus.unauthenticated),
    );
  }

  Future<void> logout() async {
    final AuthSession? session = state.session;
    final int operation = _beginOperation();
    if (session != null && _apiClient.accessToken == null) {
      _apiClient.setAccessToken(session.accessToken);
      _apiClient.setAuthenticatedTenantId(session.tenant.id);
    }
    try {
      await _repository.logout();
    } catch (_) {
      // Local logout must complete when the server is unreachable.
    } finally {
      if (_isCurrent(operation)) {
        _discardStoredSessionForRun = true;
        await _clearLocalBestEffort(operation);
        _emitIfCurrent(
          operation,
          const AuthSessionState(status: AuthSessionStatus.unauthenticated),
        );
      }
    }
  }

  Future<void> _persistAndEnter(AuthSession session, int operation) async {
    await _writeStoredSession(session);
    _enterIfCurrent(session, operation);
  }

  Future<void> _writeStoredSession(AuthSession session) =>
      _runStorageMutation(() => _storage.write(session));

  Future<void> _markAuthoritativeInvalidation() => _runStorageMutation(() async {
    try {
      await _storage.markAuthoritativelyInvalidated();
    } catch (_) {
      // The current process remains fail-closed if secure storage is down.
    }
  });

  Future<void> _clearStoredSessionBestEffort(int operation) async {
    if (!_isCurrent(operation)) return;
    await _runStorageMutation(() async {
      try {
        await _storage.clear();
      } catch (_) {
        // API context was already cleared; lifecycle must still settle.
      }
    });
  }

  Future<void> _clearLocalBestEffort(int operation) async {
    if (!_isCurrent(operation)) return;
    _clearApiContext();
    await _clearStoredSessionBestEffort(operation);
  }

  Future<void> _revokeAndClearLocal(int operation) async {
    _isRevokingForRecovery = true;
    try {
      try {
        await _repository.logout();
      } catch (_) {
        // The original persistence failure remains user-visible.
      }
      await _clearLocalBestEffort(operation);
    } finally {
      _isRevokingForRecovery = false;
    }
  }

  Future<void> _runStorageMutation(Future<void> Function() mutation) {
    final Future<void> next = _storageMutationTail
        .catchError((_) {})
        .then((_) => mutation());
    _storageMutationTail = next.catchError((_) {});
    return next;
  }

  Future<void> _trackVerification(Future<void> future) {
    _verificationInFlight = future;
    return future.whenComplete(() {
      if (identical(_verificationInFlight, future)) {
        _verificationInFlight = null;
      }
      if (_restoreQueued && !isClosed) {
        _restoreQueued = false;
        unawaited(restore());
      }
    });
  }

  void _onStorageChanged() {
    if (isClosed || _discardStoredSessionForRun) return;
    if (_verificationInFlight != null) {
      _beginOperation();
      _clearApiContext();
      _restoreQueued = true;
      return;
    }
    unawaited(restore());
  }

  int _beginOperation() => ++_operation;

  bool _isCurrent(int operation) => !isClosed && operation == _operation;

  void _emitIfCurrent(int operation, AuthSessionState next) {
    if (_isCurrent(operation)) emit(next);
  }

  void _enterIfCurrent(AuthSession session, int operation) {
    _emitIfCurrent(
      operation,
      AuthSessionState(
        status: session.mustChangePassword
            ? AuthSessionStatus.mustChangePassword
            : AuthSessionStatus.authenticated,
        session: session,
      ),
    );
  }

  void _clearApiContext() {
    _apiClient.setAccessToken(null);
    _apiClient.setAuthenticatedTenantId(null);
  }

  bool _isAuthoritativeInvalidation(ApiException error) =>
      error.statusCode == 401 ||
      AuthBackendCode.isAuthoritativeInvalidation(error.code);

  bool _isTemporaryVerificationFailure(ApiException error) {
    final int? statusCode = error.statusCode;
    if (statusCode != null && statusCode >= 400 && statusCode < 500) {
      return false;
    }
    return error.type == ApiErrorType.networkUnavailable ||
        _isTimeout(error) ||
        error.type == ApiErrorType.server ||
        (statusCode ?? 0) >= 500;
  }

  bool _isTenantNotOperational(ApiException error) =>
      error.statusCode == 403 &&
      AuthBackendCode.isTenantNotOperational(error.code);

  AuthFailure _loginFailure(ApiException error) {
    final AuthFailureKind? codeFailure = AuthBackendCode.loginFailureKind(
      error.code,
    );
    if (codeFailure != null) return AuthFailure(codeFailure);
    if (error.statusCode == 401) {
      return const AuthFailure(AuthFailureKind.invalidCredentials);
    }
    if (error.statusCode == 429) {
      return const AuthFailure(AuthFailureKind.tooManyAttempts);
    }
    if (error.type == ApiErrorType.networkUnavailable) {
      return const AuthFailure(AuthFailureKind.networkUnavailable);
    }
    if (_isTimeout(error)) {
      return const AuthFailure(AuthFailureKind.connectionTimeout);
    }
    if (error.type == ApiErrorType.server || (error.statusCode ?? 0) >= 500) {
      return const AuthFailure(AuthFailureKind.serverUnavailable);
    }
    if (error.type == ApiErrorType.validation || error.statusCode == 422) {
      return AuthFailure(
        AuthFailureKind.validation,
        fieldErrors: _loginValidationErrors(error.validationErrors),
      );
    }
    return const AuthFailure(AuthFailureKind.unexpected);
  }

  AuthFailure _changePasswordFailure(ApiException error) {
    if (error.type == ApiErrorType.networkUnavailable) {
      return const AuthFailure(AuthFailureKind.networkUnavailable);
    }
    if (_isTimeout(error)) {
      return const AuthFailure(AuthFailureKind.connectionTimeout);
    }
    if (error.type == ApiErrorType.server || (error.statusCode ?? 0) >= 500) {
      return const AuthFailure(AuthFailureKind.serverUnavailable);
    }
    if (_isCurrentPasswordCode(error.code)) {
      return const AuthFailure(
        AuthFailureKind.incorrectCurrentPassword,
        fieldErrors: <AuthField, AuthFailureKind>{
          AuthField.currentPassword: AuthFailureKind.incorrectCurrentPassword,
        },
      );
    }
    if (error.type == ApiErrorType.validation || error.statusCode == 422) {
      return AuthFailure(
        AuthFailureKind.validation,
        fieldErrors: _changePasswordValidationErrors(error.validationErrors),
      );
    }
    return const AuthFailure(AuthFailureKind.unexpected);
  }

  bool _isTimeout(ApiException error) =>
      error.type == ApiErrorType.connectionTimeout ||
      error.type == ApiErrorType.sendTimeout ||
      error.type == ApiErrorType.receiveTimeout;

  bool _isCurrentPasswordCode(String? code) =>
      AuthBackendCode.isIncorrectCurrentPassword(code);

  Map<AuthField, AuthFailureKind> _loginValidationErrors(
    Map<String, List<String>>? validationErrors,
  ) {
    final Set<String> fields =
        validationErrors?.keys.toSet() ?? const <String>{};
    return <AuthField, AuthFailureKind>{
      if (fields.any(<String>{'identifier', 'email', 'username'}.contains))
        AuthField.identifier: AuthFailureKind.validation,
      if (fields.contains('password'))
        AuthField.password: AuthFailureKind.validation,
    };
  }

  Map<AuthField, AuthFailureKind> _changePasswordValidationErrors(
    Map<String, List<String>>? validationErrors,
  ) {
    final Set<String> fields =
        validationErrors?.keys.toSet() ?? const <String>{};
    return <AuthField, AuthFailureKind>{
      if (fields.contains('currentPassword') ||
          fields.contains('current_password'))
        AuthField.currentPassword: AuthFailureKind.incorrectCurrentPassword,
      if (fields.contains('newPassword') || fields.contains('new_password'))
        AuthField.newPassword: AuthFailureKind.weakNewPassword,
      if (fields.contains('newPassword_confirmation') ||
          fields.contains('new_password_confirmation') ||
          fields.contains('confirmation'))
        AuthField.confirmation: AuthFailureKind.passwordConfirmationMismatch,
    };
  }
}

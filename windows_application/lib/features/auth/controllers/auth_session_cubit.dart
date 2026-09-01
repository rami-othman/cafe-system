import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/network/dio_api_client.dart';
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
  ) : super(const AuthSessionState());

  final AuthRepository _repository;
  final AuthSessionStorage _storage;
  final DioApiClient _apiClient;
  final DateTime Function() _now;

  Future<void> restore() async {
    emit(const AuthSessionState(status: AuthSessionStatus.restoring));
    final AuthSession? cached = await _storage.read();
    if (cached == null) {
      emit(const AuthSessionState(status: AuthSessionStatus.unauthenticated));
      return;
    }

    _apiClient.setAccessToken(cached.accessToken);
    _apiClient.setAuthenticatedTenantId(cached.tenant.id);
    try {
      final AuthSession verified = await _repository.me(cached);
      await _persistAndEnter(verified);
    } on ApiException catch (error) {
      if (error.type == ApiErrorType.networkUnavailable &&
          cached.canRestoreOffline(_now())) {
        await _enter(cached);
        return;
      }
      await _clearLocal();
      emit(
        AuthSessionState(
          status: AuthSessionStatus.unauthenticated,
          message: error.type == ApiErrorType.networkUnavailable
              ? AuthMessage.offlineSessionExpired
              : AuthMessage.sessionExpired,
        ),
      );
    } catch (_) {
      await _clearLocal();
      emit(const AuthSessionState(status: AuthSessionStatus.unauthenticated));
    }
  }

  Future<void> login({
    required String identifier,
    required String password,
  }) async {
    emit(const AuthSessionState(status: AuthSessionStatus.submitting));
    try {
      final AuthSession session = await _repository.login(
        identifier: identifier,
        password: password,
      );
      _apiClient.setAccessToken(session.accessToken);
      _apiClient.setAuthenticatedTenantId(session.tenant.id);
      await _persistAndEnter(session);
    } catch (_) {
      _apiClient.setAccessToken(null);
      emit(
        const AuthSessionState(
          status: AuthSessionStatus.unauthenticated,
          message: AuthMessage.loginFailed,
        ),
      );
    }
  }

  Future<void> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    final AuthSession? session = state.session;
    if (session == null) return;
    emit(
      state.copyWith(status: AuthSessionStatus.submitting, clearMessage: true),
    );
    try {
      await _repository.changePassword(
        currentPassword: currentPassword,
        newPassword: newPassword,
      );
      await _persistAndEnter(session.copyWith(mustChangePassword: false));
    } catch (_) {
      emit(
        state.copyWith(
          status: AuthSessionStatus.mustChangePassword,
          message: AuthMessage.passwordChangeFailed,
        ),
      );
    }
  }

  /// A 401 from any authenticated repository arrives here through Dio's shared
  /// failure hook. Clearing first prevents an invalid route from being restored.
  Future<void> expire() async {
    if (state.status == AuthSessionStatus.unauthenticated) return;
    await _clearLocal();
    emit(
      const AuthSessionState(
        status: AuthSessionStatus.unauthenticated,
        message: AuthMessage.sessionExpired,
      ),
    );
  }

  Future<void> logout() async {
    try {
      await _repository.logout();
    } catch (_) {
      // Local logout must still complete if the server is temporarily offline.
    } finally {
      await _clearLocal();
      emit(const AuthSessionState(status: AuthSessionStatus.unauthenticated));
    }
  }

  Future<void> _persistAndEnter(AuthSession session) async {
    await _storage.write(session);
    await _enter(session);
  }

  Future<void> _enter(AuthSession session) async {
    emit(
      AuthSessionState(
        status: session.mustChangePassword
            ? AuthSessionStatus.mustChangePassword
            : AuthSessionStatus.authenticated,
        session: session,
      ),
    );
  }

  Future<void> _clearLocal() async {
    _apiClient.setAccessToken(null);
    _apiClient.setAuthenticatedTenantId(null);
    await _storage.clear();
  }
}

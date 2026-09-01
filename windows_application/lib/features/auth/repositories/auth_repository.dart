import '../../../core/network/dio_api_client.dart';
import '../models/auth_session.dart';

abstract interface class AuthRepository {
  Future<AuthSession> login({
    required String identifier,
    required String password,
  });
  Future<AuthSession> me(AuthSession cachedSession);
  Future<void> changePassword({
    required String currentPassword,
    required String newPassword,
  });
  Future<void> logout();
}

class ApiAuthRepository implements AuthRepository {
  ApiAuthRepository(this._apiClient);
  final DioApiClient _apiClient;

  @override
  Future<AuthSession> login({
    required String identifier,
    required String password,
  }) async {
    final String trimmedIdentifier = identifier.trim();
    final bool isEmail = trimmedIdentifier.contains('@');
    final Map<String, dynamic> loginPayload = <String, dynamic>{
      if (isEmail)
        'email': trimmedIdentifier
      else
        'username': trimmedIdentifier,
      'password': password,
      'deviceName': 'Cafe System 618 Windows',
    };
    final dynamic data = await _apiClient.post(
      'auth/login',
      data: loginPayload,
    );
    return AuthSession.fromApi(_asMap(data));
  }

  @override
  Future<AuthSession> me(AuthSession cachedSession) async {
    final dynamic data = await _apiClient.get('auth/me');
    final Map<String, dynamic> payload = _asMap(data);
    payload['accessToken'] = cachedSession.accessToken;
    return AuthSession.fromApi(payload);
  }

  @override
  Future<void> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    await _apiClient.post(
      'auth/change-password',
      data: <String, dynamic>{
        'currentPassword': currentPassword,
        'newPassword': newPassword,
        'newPassword_confirmation': newPassword,
      },
    );
  }

  @override
  Future<void> logout() => _apiClient.post('auth/logout');
}

/// Deterministic no-network repository for the established test composition.
/// Production composition always uses [ApiAuthRepository].
class OfflineAuthRepository implements AuthRepository {
  @override
  Future<void> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {}

  @override
  Future<AuthSession> login({
    required String identifier,
    required String password,
  }) =>
      throw UnsupportedError('Offline test repository does not support login.');

  @override
  Future<void> logout() async {}

  @override
  Future<AuthSession> me(AuthSession cachedSession) async => cachedSession;
}

Map<String, dynamic> _asMap(dynamic value) => value is Map<String, dynamic>
    ? value
    : value is Map
    ? value.cast<String, dynamic>()
    : <String, dynamic>{};

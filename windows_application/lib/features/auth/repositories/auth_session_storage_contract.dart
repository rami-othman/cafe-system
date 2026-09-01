import '../models/auth_session.dart';

abstract class AuthSessionStorage {
  Future<AuthSession?> read();
  Future<void> write(AuthSession session);
  Future<void> clear();

  /// Web implementations emit when another browser tab changes this session.
  /// Native secure storage has no equivalent cross-process notification.
  Stream<void> get changes => const Stream<void>.empty();
}

/// Used only by the established `useBackend: false` Flutter test harness.
class MemoryAuthSessionStorage implements AuthSessionStorage {
  MemoryAuthSessionStorage([this._session]);
  AuthSession? _session;

  @override
  Future<void> clear() async => _session = null;

  @override
  Future<AuthSession?> read() async => _session;

  @override
  Future<void> write(AuthSession session) async => _session = session;

  @override
  Stream<void> get changes => const Stream<void>.empty();
}

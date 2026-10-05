import '../models/auth_session.dart';

abstract class AuthSessionStorage {
  Future<AuthSession?> read();
  Future<void> write(AuthSession session);
  Future<void> clear();

  /// A server-side 401 must survive restart so a stale bearer token cannot
  /// re-enter through the bounded offline path.
  Future<bool> isAuthoritativelyInvalidated() async => false;

  /// This is separate from [clear] because session deletion can fail after
  /// the client has already learned that the server revoked the authority.
  /// A successful [write] clears the marker for a new login.
  Future<void> markAuthoritativelyInvalidated() async {}

  /// Web implementations emit when another browser tab changes this session.
  /// Native secure storage has no equivalent cross-process notification.
  Stream<void> get changes => const Stream<void>.empty();
}

/// Used only by the established `useBackend: false` Flutter test harness.
class MemoryAuthSessionStorage implements AuthSessionStorage {
  MemoryAuthSessionStorage([this._session]);
  AuthSession? _session;
  bool _authoritativelyInvalidated = false;

  @override
  Future<void> clear() async => _session = null;

  @override
  Future<bool> isAuthoritativelyInvalidated() async =>
      _authoritativelyInvalidated;

  @override
  Future<void> markAuthoritativelyInvalidated() async =>
      _authoritativelyInvalidated = true;

  @override
  Future<AuthSession?> read() async => _session;

  @override
  Future<void> write(AuthSession session) async {
    _session = session;
    _authoritativelyInvalidated = false;
  }

  @override
  Stream<void> get changes => const Stream<void>.empty();
}

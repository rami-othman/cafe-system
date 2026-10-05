import 'dart:async';
import 'dart:convert';
import 'dart:js_interop';

import 'package:web/web.dart' as web;

import '../models/auth_session.dart';
import 'auth_session_storage_contract.dart';

AuthSessionStorage createAuthSessionStorage() => WebAuthSessionStorage();

/// Staging Web persistence. Browser storage is deliberately documented as
/// XSS-exposed and is not presented as an equivalent to Windows secure storage.
class WebAuthSessionStorage implements AuthSessionStorage {
  WebAuthSessionStorage() {
    web.window.addEventListener('storage', _onStorageEvent.toJS);
  }

  static const String _sessionKey = 'cafe618.auth.web-session';
  static const String _invalidationKey = 'cafe618.auth.web-authoritative-invalid';
  final StreamController<void> _changes = StreamController<void>.broadcast();

  void _onStorageEvent(web.Event event) {
    final web.StorageEvent storageEvent = event as web.StorageEvent;
    if (storageEvent.key == _sessionKey ||
        storageEvent.key == _invalidationKey ||
        storageEvent.key == null) {
      _changes.add(null);
    }
  }

  @override
  Stream<void> get changes => _changes.stream;

  @override
  Future<AuthSession?> read() async {
    try {
      final String? encoded = web.window.localStorage.getItem(_sessionKey);
      if (encoded == null || encoded.isEmpty) return null;
      final dynamic decoded = jsonDecode(encoded);
      if (decoded is! Map) throw const AuthSessionStorageCorruptException();
      final Map<String, dynamic> json = Map<String, dynamic>.from(decoded);
      final String? token = json.remove('accessToken') as String?;
      if (token == null || token.isEmpty) {
        throw const AuthSessionStorageCorruptException();
      }
      return AuthSession.fromStorage(token, json);
    } on FormatException {
      await _clearCorruptEntry();
      throw const AuthSessionStorageCorruptException();
    } on AuthSessionStorageCorruptException {
      await _clearCorruptEntry();
      rethrow;
    }
  }

  Future<void> _clearCorruptEntry() async {
    try {
      await clear();
    } catch (_) {
      // The Cubit still reaches a deterministic unauthenticated state.
    }
  }

  @override
  Future<void> write(AuthSession session) async {
    final Map<String, dynamic> payload = session.toStorageJson()
      ..['accessToken'] = session.accessToken;
    web.window.localStorage.setItem(_sessionKey, jsonEncode(payload));
    web.window.localStorage.removeItem(_invalidationKey);
  }

  @override
  Future<void> clear() async => web.window.localStorage.removeItem(_sessionKey);

  @override
  Future<bool> isAuthoritativelyInvalidated() async =>
      web.window.localStorage.getItem(_invalidationKey) == '1';

  @override
  Future<void> markAuthoritativelyInvalidated() async =>
      web.window.localStorage.setItem(_invalidationKey, '1');
}

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
  final StreamController<void> _changes = StreamController<void>.broadcast();

  void _onStorageEvent(web.Event event) {
    final web.StorageEvent storageEvent = event as web.StorageEvent;
    if (storageEvent.key == _sessionKey || storageEvent.key == null) {
      _changes.add(null);
    }
  }

  @override
  Stream<void> get changes => _changes.stream;

  @override
  Future<AuthSession?> read() async {
    final String? encoded = web.window.localStorage.getItem(_sessionKey);
    if (encoded == null || encoded.isEmpty) return null;
    try {
      final dynamic decoded = jsonDecode(encoded);
      if (decoded is! Map) return null;
      final Map<String, dynamic> json = Map<String, dynamic>.from(decoded);
      final String? token = json.remove('accessToken') as String?;
      if (token == null || token.isEmpty) return null;
      return AuthSession.fromStorage(token, json);
    } on FormatException {
      await clear();
      return null;
    }
  }

  @override
  Future<void> write(AuthSession session) async {
    final Map<String, dynamic> payload = session.toStorageJson()
      ..['accessToken'] = session.accessToken;
    web.window.localStorage.setItem(_sessionKey, jsonEncode(payload));
  }

  @override
  Future<void> clear() async => web.window.localStorage.removeItem(_sessionKey);
}

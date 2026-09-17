import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../models/auth_session.dart';
import 'auth_session_storage_contract.dart';

AuthSessionStorage createAuthSessionStorage() => SecureAuthSessionStorage();

class SecureAuthSessionStorage implements AuthSessionStorage {
  SecureAuthSessionStorage({FlutterSecureStorage? secureStorage})
    : _secureStorage = secureStorage ?? const FlutterSecureStorage();

  static const String _tokenKey = 'cafe618.auth.access-token';
  static const String _metadataKey = 'cafe618.auth.session-metadata';
  static const String _invalidationKey = 'cafe618.auth.authoritative-invalid';
  final FlutterSecureStorage _secureStorage;

  @override
  Future<AuthSession?> read() async {
    try {
      final String? token = await _secureStorage.read(key: _tokenKey);
      final String? metadata = await _secureStorage.read(key: _metadataKey);
      if (token == null && metadata == null) return null;
      if (token == null || token.isEmpty || metadata == null) {
        throw const AuthSessionStorageCorruptException();
      }
      final dynamic decoded = jsonDecode(metadata);
      if (decoded is! Map<String, dynamic>) {
        throw const AuthSessionStorageCorruptException();
      }
      return AuthSession.fromStorage(token, decoded);
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
    // A failed multi-key update must not leave a previous role/capability
    // snapshot available for offline restoration. Metadata is written before
    // the token, so an interrupted write is fail-closed on the next read.
    await clear();
    await _secureStorage.write(
      key: _metadataKey,
      value: session.encodeMetadata(),
    );
    await _secureStorage.write(key: _tokenKey, value: session.accessToken);
    await _secureStorage.delete(key: _invalidationKey);
  }

  @override
  Future<void> clear() async {
    await _secureStorage.delete(key: _tokenKey);
    await _secureStorage.delete(key: _metadataKey);
  }

  @override
  Future<bool> isAuthoritativelyInvalidated() async =>
      await _secureStorage.read(key: _invalidationKey) == '1';

  @override
  Future<void> markAuthoritativelyInvalidated() =>
      _secureStorage.write(key: _invalidationKey, value: '1');

  @override
  Stream<void> get changes => const Stream<void>.empty();
}

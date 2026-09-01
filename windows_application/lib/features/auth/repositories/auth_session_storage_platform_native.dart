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
  final FlutterSecureStorage _secureStorage;

  @override
  Future<AuthSession?> read() async {
    final String? token = await _secureStorage.read(key: _tokenKey);
    final String? metadata = await _secureStorage.read(key: _metadataKey);
    if (token == null || token.isEmpty || metadata == null) return null;
    try {
      final dynamic decoded = jsonDecode(metadata);
      if (decoded is! Map<String, dynamic>) return null;
      return AuthSession.fromStorage(token, decoded);
    } on FormatException {
      await clear();
      return null;
    }
  }

  @override
  Future<void> write(AuthSession session) async {
    await _secureStorage.write(key: _tokenKey, value: session.accessToken);
    await _secureStorage.write(
      key: _metadataKey,
      value: session.encodeMetadata(),
    );
  }

  @override
  Future<void> clear() async {
    await _secureStorage.delete(key: _tokenKey);
    await _secureStorage.delete(key: _metadataKey);
  }

  @override
  Stream<void> get changes => const Stream<void>.empty();
}

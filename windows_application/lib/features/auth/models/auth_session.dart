import 'dart:convert';

class AuthUser {
  const AuthUser({
    required this.id,
    required this.name,
    required this.role,
    this.email,
    this.username,
    this.financeCapabilities = const <String>{},
  });

  final int id;
  final String name;
  final String role;
  final String? email;
  final String? username;
  final Set<String> financeCapabilities;

  factory AuthUser.fromJson(Map<String, dynamic> json) => AuthUser(
    id: (json['id'] as num?)?.toInt() ?? 0,
    name: json['name'] as String? ?? '',
    role: json['role'] as String? ?? '',
    email: json['email'] as String?,
    username: json['username'] as String?,
    financeCapabilities: _stringSet(json['financeCapabilities']),
  );

  Map<String, dynamic> toJson() => <String, dynamic>{
    'id': id,
    'name': name,
    'role': role,
    'email': email,
    'username': username,
    'financeCapabilities': financeCapabilities.toList(growable: false),
  };
}

class AuthTenant {
  const AuthTenant({required this.id, required this.name});

  final int id;
  final String name;

  factory AuthTenant.fromJson(Map<String, dynamic> json) => AuthTenant(
    id: (json['id'] as num?)?.toInt() ?? 0,
    name: json['name'] as String? ?? '',
  );

  Map<String, dynamic> toJson() => <String, dynamic>{'id': id, 'name': name};
}

/// Minimum session identity needed to restore an authenticated Windows client.
/// Passwords are never persisted; the opaque token is stored separately by the
/// secure storage implementation.
class AuthSession {
  const AuthSession({
    required this.accessToken,
    required this.user,
    required this.tenant,
    required this.mustChangePassword,
    required this.lastValidatedAt,
    required this.offlineSessionMaxAgeSeconds,
    this.customerManagementAllowed = false,
    this.expiresAt,
  });

  final String accessToken;
  final AuthUser user;
  final AuthTenant tenant;
  final bool mustChangePassword;
  final DateTime lastValidatedAt;
  final int offlineSessionMaxAgeSeconds;

  /// Server-authoritative capability. Legacy session metadata intentionally
  /// defaults closed until it is refreshed from the authenticated API.
  final bool customerManagementAllowed;
  final DateTime? expiresAt;

  bool get isValidForLogin =>
      accessToken.trim().isNotEmpty &&
      user.id > 0 &&
      tenant.id > 0 &&
      user.role.trim().isNotEmpty &&
      offlineSessionMaxAgeSeconds > 0;

  /// Cached credentials are deliberately held to a tighter contract than a
  /// fresh API payload. They may only be used for a bounded offline entry or
  /// to retry verification when every identity field is usable.
  bool isValidForRestore(DateTime now) =>
      isValidForLogin && !lastValidatedAt.isAfter(now);

  /// An absent or incoherent absolute expiry is never usable offline. Normal
  /// persistence rejects it before this point; this guard also keeps manually
  /// constructed or legacy in-memory sessions fail-closed.
  bool isAbsoluteExpiryPassed(DateTime now) =>
      expiresAt == null ||
      !expiresAt!.isAfter(lastValidatedAt) ||
      !expiresAt!.isAfter(now);

  bool canRestoreOffline(DateTime now) => !now.isAfter(
    lastValidatedAt.add(Duration(seconds: offlineSessionMaxAgeSeconds)),
  );

  AuthSession copyWith({
    bool? mustChangePassword,
    DateTime? lastValidatedAt,
    bool? customerManagementAllowed,
  }) => AuthSession(
    accessToken: accessToken,
    user: user,
    tenant: tenant,
    mustChangePassword: mustChangePassword ?? this.mustChangePassword,
    lastValidatedAt: lastValidatedAt ?? this.lastValidatedAt,
    offlineSessionMaxAgeSeconds: offlineSessionMaxAgeSeconds,
    customerManagementAllowed:
        customerManagementAllowed ?? this.customerManagementAllowed,
    expiresAt: expiresAt,
  );

  factory AuthSession.fromApi(Map<String, dynamic> json) {
    final Map<String, dynamic> session = _map(json['session']);
    return AuthSession(
      accessToken: json['accessToken'] as String? ?? '',
      user: AuthUser.fromJson(_map(json['user'])),
      tenant: AuthTenant.fromJson(_map(json['tenant'])),
      mustChangePassword: json['mustChangePassword'] == true,
      lastValidatedAt:
          DateTime.tryParse(session['lastValidatedAt'] as String? ?? '') ??
          DateTime.now(),
      offlineSessionMaxAgeSeconds:
          (session['offlineSessionMaxAgeSeconds'] as num?)?.toInt() ?? 43200,
      customerManagementAllowed: _customerManagementAllowed(json),
      expiresAt: DateTime.tryParse(session['expiresAt'] as String? ?? ''),
    );
  }

  /// Login must not authenticate a partially parsed success payload. The
  /// tolerant parser remains only for explicitly legacy local metadata.
  factory AuthSession.fromLoginApi(dynamic payload) {
    try {
      final Map<String, dynamic> json = _strictMap(payload);
      return _sessionFromAuthoritativeContract(
        json,
        accessToken: _requiredNonBlankString(json['accessToken']),
      );
    } on AuthInvalidResponseException {
      rethrow;
    } catch (_) {
      throw const AuthInvalidResponseException();
    }
  }

  /// `auth/me` is the authority refresh boundary. Unlike login, it deliberately
  /// accepts no token from the response: the bearer token that made this
  /// request is the token being verified. Every field that can affect identity,
  /// tenant scope, capabilities, session authority, or offline expiry is
  /// required so a malformed 200 response cannot grant shell access.
  factory AuthSession.fromVerifiedMeApi(
    dynamic payload, {
    required String cachedAccessToken,
  }) {
    try {
      final Map<String, dynamic> json = _strictMap(payload);
      if (json.containsKey('accessToken')) {
        throw const AuthInvalidResponseException();
      }
      return _sessionFromAuthoritativeContract(
        json,
        accessToken: _requiredNonBlankString(cachedAccessToken),
      );
    } on AuthInvalidResponseException {
      rethrow;
    } catch (_) {
      throw const AuthInvalidResponseException();
    }
  }

  factory AuthSession.fromStorage(String token, Map<String, dynamic> json) {
    try {
      final String storedToken = _requiredNonBlankString(token);
      final AuthUser user = AuthUser.fromJson(_requiredLoginMap(json['user']));
      final AuthTenant tenant = AuthTenant.fromJson(
        _requiredLoginMap(json['tenant']),
      );
      final String lastValidatedAt = _requiredNonBlankString(
        json['lastValidatedAt'],
      );
      final DateTime? parsedLastValidatedAt = DateTime.tryParse(
        lastValidatedAt,
      );
      final int offlineMaxAge = _requiredPositiveInt(
        json['offlineSessionMaxAgeSeconds'],
      );
      final DateTime expiry = _requiredAbsoluteDateTime(json['expiresAt']);
      if (parsedLastValidatedAt == null ||
          !expiry.isAfter(parsedLastValidatedAt) ||
          user.id <= 0 ||
          tenant.id <= 0 ||
          user.role.trim().isEmpty ||
          json['mustChangePassword'] is! bool) {
        throw const AuthSessionStorageCorruptException();
      }
      return AuthSession(
        accessToken: storedToken,
        user: user,
        tenant: tenant,
        mustChangePassword: json['mustChangePassword'] as bool,
        lastValidatedAt: parsedLastValidatedAt,
        offlineSessionMaxAgeSeconds: offlineMaxAge,
        customerManagementAllowed: _customerManagementAllowed(json),
        expiresAt: expiry,
      );
    } on AuthSessionStorageCorruptException {
      rethrow;
    } catch (_) {
      throw const AuthSessionStorageCorruptException();
    }
  }

  Map<String, dynamic> toStorageJson() => <String, dynamic>{
    'user': user.toJson(),
    'tenant': tenant.toJson(),
    'mustChangePassword': mustChangePassword,
    'lastValidatedAt': lastValidatedAt.toUtc().toIso8601String(),
    'offlineSessionMaxAgeSeconds': offlineSessionMaxAgeSeconds,
    'capabilities': <String, dynamic>{
      'customer': <String, dynamic>{'manage': customerManagementAllowed},
    },
    'expiresAt': expiresAt?.toUtc().toIso8601String(),
  };

  String encodeMetadata() => jsonEncode(toStorageJson());
}

class AuthInvalidResponseException implements Exception {
  const AuthInvalidResponseException();
}

/// The local encrypted metadata is malformed or only partially present.
/// Platform/storage transport failures intentionally use their original error
/// so the lifecycle owner can offer Retry without deleting credentials.
class AuthSessionStorageCorruptException implements Exception {
  const AuthSessionStorageCorruptException();
}

Map<String, dynamic> _map(dynamic value) => value is Map<String, dynamic>
    ? value
    : value is Map
    ? value.cast<String, dynamic>()
    : <String, dynamic>{};

Map<String, dynamic> _requiredLoginMap(dynamic value) {
  if (value is! Map || value.keys.any((dynamic key) => key is! String)) {
    throw const AuthInvalidResponseException();
  }
  return Map<String, dynamic>.from(value);
}

Map<String, dynamic> _strictMap(dynamic value) {
  if (!_hasOnlyStringMapKeys(value)) {
    throw const AuthInvalidResponseException();
  }
  return _requiredLoginMap(value);
}

AuthSession _sessionFromAuthoritativeContract(
  Map<String, dynamic> json, {
  required String accessToken,
}) {
  final Map<String, dynamic> user = _requiredLoginMap(json['user']);
  final Map<String, dynamic> tenant = _requiredLoginMap(json['tenant']);
  final Map<String, dynamic> capabilities = _requiredLoginMap(
    json['capabilities'],
  );
  final Map<String, dynamic> customerCapabilities = _requiredLoginMap(
    capabilities['customer'],
  );
  final Map<String, dynamic> session = _requiredLoginMap(json['session']);
  final Map<String, dynamic> branchAccess = _requiredLoginMap(
    json['branchAccess'],
  );

  if (_requiredNonBlankString(json['tokenType']) != 'Bearer' ||
      json['mustChangePassword'] is! bool ||
      customerCapabilities['manage'] is! bool ||
      branchAccess['allBranches'] is! bool) {
    throw const AuthInvalidResponseException();
  }
  final List<dynamic> branchIds = _requiredList(branchAccess['branchIds']);
  if (branchIds.any((dynamic id) => id is! int || id <= 0) ||
      branchIds.toSet().length != branchIds.length ||
      (branchAccess['allBranches'] == true && branchIds.isNotEmpty)) {
    throw const AuthInvalidResponseException();
  }

  final int userId = _requiredPositiveInt(user['id']);
  final String userName = _requiredNonBlankString(user['name']);
  final String role = _requiredNonBlankString(user['role']);
  _requiredNonBlankString(user['status']);
  final String? email = _requiredNullableString(user['email']);
  final String? username = _requiredNullableString(user['username']);
  final int tenantId = _requiredPositiveInt(tenant['id']);
  final String tenantName = _requiredNonBlankString(tenant['name']);
  _requiredNonBlankString(tenant['status']);

  _requiredPositiveInt(session['id']);
  _requiredNonBlankString(session['deviceName']);
  _requiredDateTime(session['authenticatedAt']);
  final DateTime lastValidatedAt = _requiredDateTime(session['lastValidatedAt']);
  final DateTime responseExpiry = _requiredDateTime(json['expiresAt']);
  final DateTime sessionExpiry = _requiredDateTime(session['expiresAt']);
  if (!responseExpiry.isAtSameMomentAs(sessionExpiry)) {
    throw const AuthInvalidResponseException();
  }
  final int offlineMaxAge = _requiredPositiveInt(
    session['offlineSessionMaxAgeSeconds'],
  );

  return AuthSession(
    accessToken: accessToken,
    user: AuthUser(
      id: userId,
      name: userName,
      role: role,
      email: email,
      username: username,
    ),
    tenant: AuthTenant(id: tenantId, name: tenantName),
    mustChangePassword: json['mustChangePassword'] as bool,
    lastValidatedAt: lastValidatedAt,
    offlineSessionMaxAgeSeconds: offlineMaxAge,
    customerManagementAllowed: customerCapabilities['manage'] as bool,
    expiresAt: responseExpiry,
  );
}

String _requiredNonBlankString(dynamic value) {
  if (value is! String || value.trim().isEmpty) {
    throw const AuthInvalidResponseException();
  }
  return value;
}

int _requiredPositiveInt(dynamic value) {
  if (value is! int || value <= 0) {
    throw const AuthInvalidResponseException();
  }
  return value;
}

String? _requiredNullableString(dynamic value) {
  if (value == null) return null;
  return _requiredNonBlankString(value);
}

List<dynamic> _requiredList(dynamic value) {
  if (value is! List) throw const AuthInvalidResponseException();
  return value;
}

DateTime _requiredDateTime(dynamic value) {
  final DateTime? parsed = DateTime.tryParse(_requiredNonBlankString(value));
  if (parsed == null) throw const AuthInvalidResponseException();
  return parsed;
}

/// Storage must retain an absolute instant, never a device-local date/time.
/// Laravel serializes these as ISO-8601 UTC instants, but accepting an explicit
/// numeric offset keeps the local cache format interoperable.
DateTime _requiredAbsoluteDateTime(dynamic value) {
  final String raw = _requiredNonBlankString(value);
  if (!RegExp(r'(?:Z|[+-]\d{2}:?\d{2})$', caseSensitive: false).hasMatch(raw)) {
    throw const AuthInvalidResponseException();
  }
  final DateTime? parsed = DateTime.tryParse(raw);
  if (parsed == null) throw const AuthInvalidResponseException();
  return parsed;
}

bool _hasOnlyStringMapKeys(dynamic value) {
  if (value is Map) {
    return value.keys.every((dynamic key) => key is String) &&
        value.values.every(_hasOnlyStringMapKeys);
  }
  if (value is List) return value.every(_hasOnlyStringMapKeys);
  return true;
}

bool _customerManagementAllowed(Map<String, dynamic> json) =>
    _map(_map(json['capabilities'])['customer'])['manage'] == true;

Set<String> _stringSet(dynamic value) => value is List
    ? value
          .map((dynamic item) => item.toString().trim())
          .where((String item) => item.isNotEmpty)
          .toSet()
    : const <String>{};

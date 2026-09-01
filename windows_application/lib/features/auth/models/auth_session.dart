import 'dart:convert';

class AuthUser {
  const AuthUser({
    required this.id,
    required this.name,
    required this.role,
    this.email,
    this.username,
  });

  final int id;
  final String name;
  final String role;
  final String? email;
  final String? username;

  factory AuthUser.fromJson(Map<String, dynamic> json) => AuthUser(
    id: (json['id'] as num?)?.toInt() ?? 0,
    name: json['name'] as String? ?? '',
    role: json['role'] as String? ?? '',
    email: json['email'] as String?,
    username: json['username'] as String?,
  );

  Map<String, dynamic> toJson() => <String, dynamic>{
    'id': id,
    'name': name,
    'role': role,
    'email': email,
    'username': username,
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
    this.expiresAt,
  });

  final String accessToken;
  final AuthUser user;
  final AuthTenant tenant;
  final bool mustChangePassword;
  final DateTime lastValidatedAt;
  final int offlineSessionMaxAgeSeconds;
  final DateTime? expiresAt;

  bool canRestoreOffline(DateTime now) => !now.isAfter(
    lastValidatedAt.add(Duration(seconds: offlineSessionMaxAgeSeconds)),
  );

  AuthSession copyWith({bool? mustChangePassword, DateTime? lastValidatedAt}) =>
      AuthSession(
        accessToken: accessToken,
        user: user,
        tenant: tenant,
        mustChangePassword: mustChangePassword ?? this.mustChangePassword,
        lastValidatedAt: lastValidatedAt ?? this.lastValidatedAt,
        offlineSessionMaxAgeSeconds: offlineSessionMaxAgeSeconds,
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
      expiresAt: DateTime.tryParse(session['expiresAt'] as String? ?? ''),
    );
  }

  factory AuthSession.fromStorage(String token, Map<String, dynamic> json) =>
      AuthSession(
        accessToken: token,
        user: AuthUser.fromJson(_map(json['user'])),
        tenant: AuthTenant.fromJson(_map(json['tenant'])),
        mustChangePassword: json['mustChangePassword'] == true,
        lastValidatedAt: DateTime.parse(json['lastValidatedAt'] as String),
        offlineSessionMaxAgeSeconds:
            (json['offlineSessionMaxAgeSeconds'] as num?)?.toInt() ?? 43200,
        expiresAt: DateTime.tryParse(json['expiresAt'] as String? ?? ''),
      );

  Map<String, dynamic> toStorageJson() => <String, dynamic>{
    'user': user.toJson(),
    'tenant': tenant.toJson(),
    'mustChangePassword': mustChangePassword,
    'lastValidatedAt': lastValidatedAt.toUtc().toIso8601String(),
    'offlineSessionMaxAgeSeconds': offlineSessionMaxAgeSeconds,
    'expiresAt': expiresAt?.toUtc().toIso8601String(),
  };

  String encodeMetadata() => jsonEncode(toStorageJson());
}

Map<String, dynamic> _map(dynamic value) => value is Map<String, dynamic>
    ? value
    : value is Map
    ? value.cast<String, dynamic>()
    : <String, dynamic>{};

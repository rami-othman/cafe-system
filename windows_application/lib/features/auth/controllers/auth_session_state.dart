import 'package:equatable/equatable.dart';

import '../models/auth_session.dart';

enum AuthSessionStatus {
  restoring,
  unauthenticated,
  submitting,
  authenticated,
  mustChangePassword,
}

enum AuthMessage {
  sessionExpired,
  offlineSessionExpired,
  loginFailed,
  passwordChangeFailed,
}

class AuthSessionState extends Equatable {
  const AuthSessionState({
    this.status = AuthSessionStatus.restoring,
    this.session,
    this.message,
  });

  final AuthSessionStatus status;
  final AuthSession? session;
  final AuthMessage? message;

  AuthSessionState copyWith({
    AuthSessionStatus? status,
    AuthSession? session,
    AuthMessage? message,
    bool clearMessage = false,
  }) => AuthSessionState(
    status: status ?? this.status,
    session: session ?? this.session,
    message: clearMessage ? null : message ?? this.message,
  );

  @override
  List<Object?> get props => <Object?>[status, session, message];
}

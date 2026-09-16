import 'package:equatable/equatable.dart';

import '../models/auth_failure.dart';
import '../models/auth_session.dart';

enum AuthSessionStatus {
  restoring,
  unauthenticated,
  submitting,
  authenticated,
  mustChangePassword,
  verificationRequired,
  tenantNotOperational,
}

enum AuthMessage { sessionExpired, offlineSessionExpired }

class AuthSessionState extends Equatable {
  const AuthSessionState({
    this.status = AuthSessionStatus.restoring,
    this.session,
    this.message,
    this.failure,
    this.verificationInProgress = false,
  });

  final AuthSessionStatus status;
  final AuthSession? session;
  final AuthMessage? message;
  final AuthFailure? failure;
  final bool verificationInProgress;

  AuthSessionState copyWith({
    AuthSessionStatus? status,
    AuthSession? session,
    AuthMessage? message,
    AuthFailure? failure,
    bool? verificationInProgress,
    bool clearMessage = false,
    bool clearFailure = false,
  }) => AuthSessionState(
    status: status ?? this.status,
    session: session ?? this.session,
    message: clearMessage ? null : message ?? this.message,
    failure: clearFailure ? null : failure ?? this.failure,
    verificationInProgress:
        verificationInProgress ?? this.verificationInProgress,
  );

  @override
  List<Object?> get props => <Object?>[
    status,
    session,
    message,
    failure,
    verificationInProgress,
  ];
}

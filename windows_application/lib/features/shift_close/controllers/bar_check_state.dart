import 'package:equatable/equatable.dart';

import '../models/bar_check_session.dart';

enum BarCheckStatus { loading, ready, submitting, posted, error }

class BarCheckState extends Equatable {
  const BarCheckState({
    this.status = BarCheckStatus.loading,
    this.session,
    this.blockedOnManagerReview = false,
    this.errorMessage,
  });

  final BarCheckStatus status;
  final BarCheckSession? session;

  /// True once submitted with an out-of-tolerance line that requires a
  /// manager to review it (see StockCountService::reviewLine) before this
  /// count can be approved/posted. The cashier cannot clear this themselves.
  final bool blockedOnManagerReview;
  final String? errorMessage;

  bool get isBusy =>
      status == BarCheckStatus.loading || status == BarCheckStatus.submitting;

  BarCheckState copyWith({
    BarCheckStatus? status,
    BarCheckSession? session,
    bool? blockedOnManagerReview,
    String? errorMessage,
    bool clearErrorMessage = false,
  }) => BarCheckState(
    status: status ?? this.status,
    session: session ?? this.session,
    blockedOnManagerReview:
        blockedOnManagerReview ?? this.blockedOnManagerReview,
    errorMessage: clearErrorMessage ? null : errorMessage ?? this.errorMessage,
  );

  @override
  List<Object?> get props => <Object?>[
    status,
    session,
    blockedOnManagerReview,
    errorMessage,
  ];
}

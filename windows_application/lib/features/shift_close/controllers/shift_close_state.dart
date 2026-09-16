import 'package:equatable/equatable.dart';

enum ShiftCloseStatus { idle, submitting, closed, error }

class ShiftCloseState extends Equatable {
  const ShiftCloseState({
    this.status = ShiftCloseStatus.idle,
    this.requiredBarCheckWarehouseId,
    this.errorMessage,
  });

  final ShiftCloseStatus status;

  /// Set when the backend reports a required bar check is still pending for
  /// this shift's branch; the screen navigates to the Bar Check flow for it.
  final int? requiredBarCheckWarehouseId;
  final String? errorMessage;

  bool get isSubmitting => status == ShiftCloseStatus.submitting;

  ShiftCloseState copyWith({
    ShiftCloseStatus? status,
    int? requiredBarCheckWarehouseId,
    bool clearRequiredBarCheck = false,
    String? errorMessage,
    bool clearErrorMessage = false,
  }) => ShiftCloseState(
    status: status ?? this.status,
    requiredBarCheckWarehouseId: clearRequiredBarCheck
        ? null
        : requiredBarCheckWarehouseId ?? this.requiredBarCheckWarehouseId,
    errorMessage: clearErrorMessage ? null : errorMessage ?? this.errorMessage,
  );

  @override
  List<Object?> get props => <Object?>[
    status,
    requiredBarCheckWarehouseId,
    errorMessage,
  ];
}

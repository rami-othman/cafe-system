import 'package:equatable/equatable.dart';

import '../models/customer_failure.dart';
import '../models/customer_models.dart';

enum CustomerLifecycleStatus { idle, submitting, success, failure }

class CustomerLifecycleState extends Equatable {
  const CustomerLifecycleState({
    required this.customer,
    this.status = CustomerLifecycleStatus.idle,
    this.action,
    this.failure,
  });

  final Customer customer;
  final CustomerLifecycleStatus status;
  final String? action;
  final CustomerFailure? failure;

  bool get isSubmitting => status == CustomerLifecycleStatus.submitting;

  CustomerLifecycleState copyWith({
    Customer? customer,
    CustomerLifecycleStatus? status,
    String? action,
    CustomerFailure? failure,
    bool clearFailure = false,
  }) => CustomerLifecycleState(
    customer: customer ?? this.customer,
    status: status ?? this.status,
    action: action ?? this.action,
    failure: clearFailure ? null : failure ?? this.failure,
  );

  @override
  List<Object?> get props => <Object?>[customer, status, action, failure];
}

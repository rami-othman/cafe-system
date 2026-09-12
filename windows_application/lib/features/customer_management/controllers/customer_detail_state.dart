import 'package:equatable/equatable.dart';

import '../models/customer_failure.dart';
import '../models/customer_models.dart';

enum CustomerDetailStatus { initial, loading, success, failure }

class CustomerDetailState extends Equatable {
  const CustomerDetailState({
    this.status = CustomerDetailStatus.initial,
    this.customerId,
    this.customer,
    this.failure,
  });

  final CustomerDetailStatus status;
  final int? customerId;
  final Customer? customer;
  final CustomerFailure? failure;

  CustomerDetailState copyWith({
    CustomerDetailStatus? status,
    int? customerId,
    Customer? customer,
    CustomerFailure? failure,
    bool clearFailure = false,
  }) => CustomerDetailState(
    status: status ?? this.status,
    customerId: customerId ?? this.customerId,
    customer: customer ?? this.customer,
    failure: clearFailure ? null : failure ?? this.failure,
  );

  @override
  List<Object?> get props => <Object?>[status, customerId, customer, failure];
}

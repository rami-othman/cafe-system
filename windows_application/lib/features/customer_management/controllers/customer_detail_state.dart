import 'package:equatable/equatable.dart';

import '../models/customer_failure.dart';
import '../models/customer_models.dart';

enum CustomerDetailStatus { initial, loading, success, failure }

class CustomerDetailState extends Equatable {
  const CustomerDetailState({
    this.status = CustomerDetailStatus.initial,
    this.customerId,
    this.customer,
    this.overview,
    this.failure,
  });

  final CustomerDetailStatus status;
  final int? customerId;
  final Customer? customer;
  final CustomerOverview? overview;
  final CustomerFailure? failure;

  CustomerDetailState copyWith({
    CustomerDetailStatus? status,
    int? customerId,
    Customer? customer,
    CustomerOverview? overview,
    CustomerFailure? failure,
    bool clearFailure = false,
  }) => CustomerDetailState(
    status: status ?? this.status,
    customerId: customerId ?? this.customerId,
    customer: customer ?? this.customer,
    overview: overview ?? this.overview,
    failure: clearFailure ? null : failure ?? this.failure,
  );

  @override
  List<Object?> get props => <Object?>[
    status,
    customerId,
    customer,
    overview,
    failure,
  ];
}

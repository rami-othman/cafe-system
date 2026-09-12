import 'package:equatable/equatable.dart';

import '../models/customer_failure.dart';
import '../models/customer_models.dart';
import '../models/customer_queries.dart';

enum CustomerGroupMembershipStatus {
  initial,
  loading,
  success,
  mutating,
  failure,
}

class CustomerGroupMembershipState extends Equatable {
  const CustomerGroupMembershipState({
    required this.groupId,
    this.status = CustomerGroupMembershipStatus.initial,
    this.candidates,
    this.query = const CustomerGroupListQuery(),
    this.selectedCustomerIds = const <int>{},
    this.failure,
  });

  final int groupId;
  final CustomerGroupMembershipStatus status;
  final CustomerPage<Customer>? candidates;
  final CustomerGroupListQuery query;
  final Set<int> selectedCustomerIds;
  final CustomerFailure? failure;

  bool get isMutating => status == CustomerGroupMembershipStatus.mutating;

  CustomerGroupMembershipState copyWith({
    CustomerGroupMembershipStatus? status,
    CustomerPage<Customer>? candidates,
    CustomerGroupListQuery? query,
    Set<int>? selectedCustomerIds,
    CustomerFailure? failure,
    bool clearFailure = false,
  }) => CustomerGroupMembershipState(
    groupId: groupId,
    status: status ?? this.status,
    candidates: candidates ?? this.candidates,
    query: query ?? this.query,
    selectedCustomerIds: selectedCustomerIds ?? this.selectedCustomerIds,
    failure: clearFailure ? null : failure ?? this.failure,
  );

  @override
  List<Object?> get props => <Object?>[
    groupId,
    status,
    candidates,
    query,
    selectedCustomerIds,
    failure,
  ];
}

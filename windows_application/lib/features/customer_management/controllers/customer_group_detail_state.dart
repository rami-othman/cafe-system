import 'package:equatable/equatable.dart';

import '../models/customer_failure.dart';
import '../models/customer_group_models.dart';
import '../models/customer_models.dart';
import '../models/customer_queries.dart';

enum CustomerGroupDetailStatus { initial, loading, success, failure }

class CustomerGroupDetailState extends Equatable {
  const CustomerGroupDetailState({
    this.status = CustomerGroupDetailStatus.initial,
    this.groupId,
    this.group,
    this.members,
    this.memberQuery = const CustomerGroupListQuery(),
    this.failure,
    this.memberFailure,
    this.isMutating = false,
    this.mutationAction,
  });

  final CustomerGroupDetailStatus status;
  final int? groupId;
  final CustomerGroup? group;
  final CustomerPage<Customer>? members;
  final CustomerGroupListQuery memberQuery;
  final CustomerFailure? failure;
  final CustomerFailure? memberFailure;
  final bool isMutating;
  final String? mutationAction;

  CustomerGroupDetailState copyWith({
    CustomerGroupDetailStatus? status,
    int? groupId,
    CustomerGroup? group,
    CustomerPage<Customer>? members,
    CustomerGroupListQuery? memberQuery,
    CustomerFailure? failure,
    CustomerFailure? memberFailure,
    bool clearFailure = false,
    bool clearMemberFailure = false,
    bool? isMutating,
    String? mutationAction,
    bool clearMutationAction = false,
  }) => CustomerGroupDetailState(
    status: status ?? this.status,
    groupId: groupId ?? this.groupId,
    group: group ?? this.group,
    members: members ?? this.members,
    memberQuery: memberQuery ?? this.memberQuery,
    failure: clearFailure ? null : failure ?? this.failure,
    memberFailure: clearMemberFailure
        ? null
        : memberFailure ?? this.memberFailure,
    isMutating: isMutating ?? this.isMutating,
    mutationAction: clearMutationAction
        ? null
        : mutationAction ?? this.mutationAction,
  );

  @override
  List<Object?> get props => <Object?>[
    status,
    groupId,
    group,
    members,
    memberQuery,
    failure,
    memberFailure,
    isMutating,
    mutationAction,
  ];
}

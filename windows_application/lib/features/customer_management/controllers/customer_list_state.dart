import 'package:equatable/equatable.dart';

import '../models/customer_failure.dart';
import '../models/customer_models.dart';
import '../models/customer_group_models.dart';
import '../models/customer_queries.dart';

enum CustomerListStatus { initial, loading, success, failure }

class CustomerListState extends Equatable {
  const CustomerListState({
    this.status = CustomerListStatus.initial,
    this.query = const CustomerListQuery(),
    this.page,
    this.failure,
    this.groupOptions = const <CustomerGroup>[],
  });

  final CustomerListStatus status;
  final CustomerListQuery query;
  final CustomerPage<Customer>? page;
  final CustomerFailure? failure;
  final List<CustomerGroup> groupOptions;

  bool get hasCriteria =>
      query.search.isNotEmpty || query.status != null || query.groupId != null;

  CustomerListState copyWith({
    CustomerListStatus? status,
    CustomerListQuery? query,
    CustomerPage<Customer>? page,
    CustomerFailure? failure,
    bool clearFailure = false,
    List<CustomerGroup>? groupOptions,
  }) => CustomerListState(
    status: status ?? this.status,
    query: query ?? this.query,
    page: page ?? this.page,
    failure: clearFailure ? null : failure ?? this.failure,
    groupOptions: groupOptions ?? this.groupOptions,
  );

  @override
  List<Object?> get props => <Object?>[
    status,
    query,
    page,
    failure,
    groupOptions,
  ];
}

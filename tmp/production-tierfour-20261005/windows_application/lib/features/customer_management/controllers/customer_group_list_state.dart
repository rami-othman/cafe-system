import 'package:equatable/equatable.dart';

import '../models/customer_failure.dart';
import '../models/customer_group_models.dart';
import '../models/customer_models.dart';
import '../models/customer_queries.dart';

enum CustomerGroupListStatus { initial, loading, success, failure }

class CustomerGroupListState extends Equatable {
  const CustomerGroupListState({
    this.status = CustomerGroupListStatus.initial,
    this.query = const CustomerGroupListQuery(),
    this.page,
    this.failure,
  });

  final CustomerGroupListStatus status;
  final CustomerGroupListQuery query;
  final CustomerPage<CustomerGroup>? page;
  final CustomerFailure? failure;

  bool get hasCriteria => query.search.isNotEmpty || query.status != null;

  CustomerGroupListState copyWith({
    CustomerGroupListStatus? status,
    CustomerGroupListQuery? query,
    CustomerPage<CustomerGroup>? page,
    CustomerFailure? failure,
    bool clearFailure = false,
  }) => CustomerGroupListState(
    status: status ?? this.status,
    query: query ?? this.query,
    page: page ?? this.page,
    failure: clearFailure ? null : failure ?? this.failure,
  );

  @override
  List<Object?> get props => <Object?>[status, query, page, failure];
}

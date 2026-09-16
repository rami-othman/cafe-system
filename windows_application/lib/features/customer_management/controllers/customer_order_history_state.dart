import 'package:equatable/equatable.dart';
import '../models/customer_failure.dart';
import '../models/customer_models.dart';
import '../models/customer_queries.dart';

enum CustomerOrderHistoryStatus { initial, loading, success, failure }

class CustomerOrderHistoryState extends Equatable {
  const CustomerOrderHistoryState({
    this.status = CustomerOrderHistoryStatus.initial,
    this.customer,
    this.page,
    this.branches = const <CustomerOrderBranch>[],
    this.query = const CustomerOrderQuery(),
    this.failure,
  });

  final CustomerOrderHistoryStatus status;
  final Customer? customer;
  final CustomerPage<CustomerOrder>? page;
  final List<CustomerOrderBranch> branches;
  final CustomerOrderQuery query;
  final CustomerFailure? failure;

  @override
  List<Object?> get props => <Object?>[
    status,
    customer,
    page,
    branches,
    query,
    failure,
  ];
}

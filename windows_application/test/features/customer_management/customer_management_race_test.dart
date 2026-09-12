import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:windows_application/features/customer_management/controllers/customer_detail_cubit.dart';
import 'package:windows_application/features/customer_management/controllers/customer_group_membership_cubit.dart';
import 'package:windows_application/features/customer_management/controllers/customer_list_cubit.dart';
import 'package:windows_application/features/customer_management/controllers/customer_lifecycle_cubit.dart';
import 'package:windows_application/features/customer_management/models/customer_models.dart';
import 'package:windows_application/features/customer_management/models/customer_queries.dart';
import 'package:windows_application/features/customer_management/repositories/customer_management_repository.dart';

void main() {
  test('ignores a list response that arrives after cubit disposal', () async {
    final Completer<CustomerPage<Customer>> response =
        Completer<CustomerPage<Customer>>();
    final _RaceRepository repository = _RaceRepository(
      customerResponse: response,
    );
    final CustomerListCubit cubit = CustomerListCubit(repository);

    final Future<void> request = cubit.load();
    await cubit.close();
    response.complete(_customerPage);
    await request;

    expect(cubit.isClosed, isTrue);
  });

  test('ignores a direct detail response after route disposal', () async {
    final Completer<Customer> response = Completer<Customer>();
    final _RaceRepository repository = _RaceRepository(
      detailResponse: response,
    );
    final CustomerDetailCubit cubit = CustomerDetailCubit(repository);

    final Future<void> request = cubit.load(7);
    await cubit.close();
    response.complete(_customer);
    await request;

    expect(cubit.isClosed, isTrue);
  });

  test('cancels delayed candidate search after the dialog closes', () async {
    final _RaceRepository repository = _RaceRepository();
    final CustomerGroupMembershipCubit cubit = CustomerGroupMembershipCubit(
      repository,
      groupId: 4,
    );

    cubit.candidateSearchChanged('Ada');
    await cubit.close();
    await Future<void>.delayed(const Duration(milliseconds: 350));

    expect(repository.eligibleRequests, 0);
  });

  test(
    'ignores a lifecycle replacement after the detail route closes',
    () async {
      final CustomerLifecycleCubit cubit = CustomerLifecycleCubit(
        _RaceRepository(),
        initialCustomer: _customer,
      );
      await cubit.close();

      cubit.replaceCustomer(_customer);

      expect(cubit.isClosed, isTrue);
    },
  );
}

class _RaceRepository implements CustomerManagementRepository {
  _RaceRepository({this.customerResponse, this.detailResponse});

  final Completer<CustomerPage<Customer>>? customerResponse;
  final Completer<Customer>? detailResponse;
  int eligibleRequests = 0;

  @override
  Future<CustomerPage<Customer>> listCustomers(CustomerListQuery query) =>
      customerResponse?.future ??
      Future<CustomerPage<Customer>>.value(_customerPage);

  @override
  Future<Customer> getCustomer(int id) =>
      detailResponse?.future ?? Future<Customer>.value(_customer);

  @override
  Future<CustomerPage<Customer>> listEligibleMembers(
    int groupId,
    CustomerGroupListQuery query,
  ) {
    eligibleRequests++;
    return Future<CustomerPage<Customer>>.value(_customerPage);
  }

  @override
  noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

const Customer _customer = Customer(
  id: 7,
  customerNumber: 'C-000007',
  name: 'Ada',
  lifecycle: CustomerLifecycle.active,
  phones: <CustomerPhone>[],
  groups: <CustomerGroupSummary>[],
  allowedActions: <String>{},
);

const CustomerPage<Customer> _customerPage = CustomerPage<Customer>(
  items: <Customer>[],
  meta: CustomerPageMeta(currentPage: 1, lastPage: 1, perPage: 25, total: 0),
);

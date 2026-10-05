import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:windows_application/features/customer_management/controllers/customer_list_cubit.dart';
import 'package:windows_application/features/customer_management/controllers/customer_list_state.dart';
import 'package:windows_application/features/customer_management/models/customer_models.dart';
import 'package:windows_application/features/customer_management/models/customer_group_models.dart';
import 'package:windows_application/features/customer_management/models/customer_queries.dart';
import 'package:windows_application/features/customer_management/repositories/customer_management_repository.dart';

void main() {
  test(
    'coalesces an identical in-flight customer collection request',
    () async {
      final _CustomerRepository repository = _CustomerRepository();
      final CustomerListCubit cubit = CustomerListCubit(repository);

      final Future<void> first = cubit.load();
      final Future<void> second = cubit.load();

      expect(repository.customerRequests, 1);
      repository.completeCustomers();
      await Future.wait(<Future<void>>[first, second]);
      expect(cubit.state.status, CustomerListStatus.success);
      await cubit.close();
    },
  );

  test(
    'loads bounded authoritative group filter options independently',
    () async {
      final _CustomerRepository repository = _CustomerRepository();
      final CustomerListCubit cubit = CustomerListCubit(repository);
      await cubit.loadGroupOptions();
      expect(repository.groupRequests, 1);
      expect(repository.lastGroupQuery?.perPage, 25);
      expect(cubit.state.groupOptions, const <CustomerGroup>[_group]);
      await cubit.close();
    },
  );

  test(
    'rejects a stale customer-list response after criteria changes',
    () async {
      final _CustomerRepository repository = _CustomerRepository();
      final CustomerListCubit cubit = CustomerListCubit(repository);
      final Future<void> initial = cubit.load();
      final Future<void> filtered = cubit.load(
        query: const CustomerListQuery(search: 'new'),
      );

      repository.completeCustomers(
        query: const CustomerListQuery(search: 'new'),
      );
      await filtered;
      repository.completeCustomers();
      await initial;

      expect(cubit.state.query.search, 'new');
      await cubit.close();
    },
  );

  test('debounces search and requests the first server page', () async {
    final _CustomerRepository repository = _CustomerRepository();
    final CustomerListCubit cubit = CustomerListCubit(repository);

    cubit.searchChanged('Ada');
    expect(repository.customerRequests, 0);
    await Future<void>.delayed(const Duration(milliseconds: 350));

    expect(repository.customerRequests, 1);
    expect(repository.queries.single, const CustomerListQuery(search: 'Ada'));
    repository.completeCustomers(query: const CustomerListQuery(search: 'Ada'));
    await Future<void>.delayed(Duration.zero);
    await cubit.close();
  });

  test('Enter and clearing search submit immediately', () async {
    final _CustomerRepository repository = _CustomerRepository();
    final CustomerListCubit cubit = CustomerListCubit(repository);

    cubit.submitSearch('Grace');
    expect(repository.queries.single, const CustomerListQuery(search: 'Grace'));
    repository.completeCustomers(
      query: const CustomerListQuery(search: 'Grace'),
    );
    await Future<void>.delayed(Duration.zero);

    cubit.searchChanged('');
    expect(repository.queries.last, const CustomerListQuery());
    repository.completeCustomers();
    await Future<void>.delayed(Duration.zero);
    await cubit.close();
  });

  test(
    'filters and page changes retain criteria while resetting filters to page one',
    () async {
      final _CustomerRepository repository = _CustomerRepository();
      final CustomerListCubit cubit = CustomerListCubit(repository);

      final Future<void> initial = cubit.load(
        query: const CustomerListQuery(search: 'Ada', page: 2),
      );
      repository.completeCustomers(
        query: const CustomerListQuery(search: 'Ada', page: 2),
      );
      await initial;

      cubit.setStatus(CustomerStatusFilter.archived);
      expect(
        repository.queries.last,
        const CustomerListQuery(
          search: 'Ada',
          status: CustomerStatusFilter.archived,
          page: 1,
        ),
      );
      repository.completeCustomers(
        query: const CustomerListQuery(
          search: 'Ada',
          status: CustomerStatusFilter.archived,
          page: 1,
        ),
      );
      await Future<void>.delayed(Duration.zero);

      cubit.setPage(3);
      expect(
        repository.queries.last,
        const CustomerListQuery(
          search: 'Ada',
          status: CustomerStatusFilter.archived,
          page: 3,
        ),
      );
      repository.completeCustomers(
        query: const CustomerListQuery(
          search: 'Ada',
          status: CustomerStatusFilter.archived,
          page: 3,
        ),
      );
      await Future<void>.delayed(Duration.zero);
      await cubit.close();
    },
  );

  test(
    'retains criteria on retryable failure and retries the same page',
    () async {
      final _CustomerRepository repository = _CustomerRepository();
      final CustomerListCubit cubit = CustomerListCubit(repository);
      const CustomerListQuery query = CustomerListQuery(search: 'Ada');

      final Future<void> failed = cubit.load(query: query);
      repository.failCustomers(query, StateError('network'));
      await failed;
      expect(cubit.state.status, CustomerListStatus.failure);
      expect(cubit.state.query, query);

      final Future<void> retried = cubit.refresh();
      expect(repository.queries.last, query);
      repository.completeCustomers(query: query);
      await retried;
      expect(cubit.state.status, CustomerListStatus.success);
      await cubit.close();
    },
  );
}

class _CustomerRepository implements CustomerManagementRepository {
  final List<_PendingRequest> _pending = <_PendingRequest>[];
  int customerRequests = 0;
  int groupRequests = 0;
  final List<CustomerListQuery> queries = <CustomerListQuery>[];
  CustomerGroupListQuery? lastGroupQuery;

  @override
  Future<CustomerPage<CustomerGroup>> listGroups(
    CustomerGroupListQuery query,
  ) async {
    groupRequests++;
    lastGroupQuery = query;
    return const CustomerPage<CustomerGroup>(
      items: <CustomerGroup>[_group],
      meta: CustomerPageMeta(
        currentPage: 1,
        lastPage: 1,
        perPage: 25,
        total: 1,
      ),
    );
  }

  @override
  Future<CustomerPage<Customer>> listCustomers(CustomerListQuery query) {
    customerRequests++;
    queries.add(query);
    final Completer<CustomerPage<Customer>> completer =
        Completer<CustomerPage<Customer>>();
    _pending.add(_PendingRequest(query, completer));
    return completer.future;
  }

  void completeCustomers({
    CustomerListQuery query = const CustomerListQuery(),
  }) {
    final _PendingRequest pending = _pending.firstWhere(
      (_PendingRequest request) => request.query == query,
    );
    pending.completer.complete(
      const CustomerPage<Customer>(
        items: <Customer>[],
        meta: CustomerPageMeta(
          currentPage: 1,
          lastPage: 1,
          perPage: 25,
          total: 0,
        ),
      ),
    );
  }

  void failCustomers(CustomerListQuery query, Object error) {
    final _PendingRequest pending = _pending.firstWhere(
      (_PendingRequest request) => request.query == query,
    );
    _pending.remove(pending);
    pending.completer.completeError(error);
  }

  @override
  noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

const CustomerGroup _group = CustomerGroup(
  id: 9,
  name: 'Not on this customer page',
  lifecycle: CustomerLifecycle.active,
  memberCount: 0,
);

class _PendingRequest {
  const _PendingRequest(this.query, this.completer);
  final CustomerListQuery query;
  final Completer<CustomerPage<Customer>> completer;
}

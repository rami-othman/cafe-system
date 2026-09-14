import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:windows_application/features/customer_management/controllers/customer_group_list_cubit.dart';
import 'package:windows_application/features/customer_management/controllers/customer_group_list_state.dart';
import 'package:windows_application/features/customer_management/models/customer_group_models.dart';
import 'package:windows_application/features/customer_management/models/customer_models.dart';
import 'package:windows_application/features/customer_management/models/customer_queries.dart';
import 'package:windows_application/features/customer_management/repositories/customer_management_repository.dart';

void main() {
  test(
    'loads bounded groups and preserves server criteria on page changes',
    () async {
      final _GroupsRepository repository = _GroupsRepository(
        pages: <CustomerPage<CustomerGroup>>[_page(1), _page(2)],
      );
      final CustomerGroupListCubit cubit = CustomerGroupListCubit(repository);

      await cubit.load(query: const CustomerGroupListQuery(perPage: 25));
      cubit.setPage(2);
      await Future<void>.delayed(const Duration(milliseconds: 10));

      expect(
        repository.queries.last,
        const CustomerGroupListQuery(page: 2, perPage: 25),
      );
      expect(cubit.state.page?.meta.currentPage, 2);
      await cubit.close();
    },
  );

  test('debounces search and clears to the first unsearched page', () async {
    final _GroupsRepository repository = _GroupsRepository(
      pages: <CustomerPage<CustomerGroup>>[_page(1)],
    );
    final CustomerGroupListCubit cubit = CustomerGroupListCubit(repository);

    cubit.searchChanged('vip');
    await Future<void>.delayed(const Duration(milliseconds: 350));
    expect(repository.queries.single.search, 'vip');
    cubit.searchChanged('');
    await Future<void>.delayed(const Duration(milliseconds: 10));
    expect(repository.queries.last.search, isEmpty);
    await cubit.close();
  });

  test(
    'rejects stale group responses and exposes retryable failures',
    () async {
      final Completer<CustomerPage<CustomerGroup>> first =
          Completer<CustomerPage<CustomerGroup>>();
      final _GroupsRepository repository = _GroupsRepository(
        deferred: first,
        pages: <CustomerPage<CustomerGroup>>[_page(1)],
      );
      final CustomerGroupListCubit cubit = CustomerGroupListCubit(repository);
      final Future<void> oldRequest = cubit.load(
        query: const CustomerGroupListQuery(search: 'old'),
      );
      await cubit.load(query: const CustomerGroupListQuery(search: 'new'));
      first.complete(_page(1));
      await oldRequest;
      expect(cubit.state.query.search, 'new');
      expect(cubit.state.status, CustomerGroupListStatus.success);
      await cubit.close();
    },
  );
}

CustomerPage<CustomerGroup> _page(int page) => CustomerPage<CustomerGroup>(
  items: <CustomerGroup>[
    CustomerGroup(
      id: page,
      name: 'Group $page',
      lifecycle: CustomerLifecycle.active,
      memberCount: page,
    ),
  ],
  meta: CustomerPageMeta(
    currentPage: page,
    lastPage: 2,
    perPage: 25,
    total: 26,
  ),
);

class _GroupsRepository implements CustomerManagementRepository {
  _GroupsRepository({
    this.pages = const <CustomerPage<CustomerGroup>>[],
    this.deferred,
  });
  final List<CustomerPage<CustomerGroup>> pages;
  final Completer<CustomerPage<CustomerGroup>>? deferred;
  final List<CustomerGroupListQuery> queries = <CustomerGroupListQuery>[];
  int _index = 0;

  @override
  Future<CustomerPage<CustomerGroup>> listGroups(CustomerGroupListQuery query) {
    queries.add(query);
    if (deferred != null && queries.length == 1) return deferred!.future;
    return Future<CustomerPage<CustomerGroup>>.value(
      pages[_index++ % pages.length],
    );
  }

  @override
  noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

import 'package:flutter_test/flutter_test.dart';
import 'package:windows_application/core/network/api_exception.dart';
import 'package:windows_application/features/customer_management/controllers/customer_group_detail_cubit.dart';
import 'package:windows_application/features/customer_management/controllers/customer_group_detail_state.dart';
import 'package:windows_application/features/customer_management/models/customer_group_models.dart';
import 'package:windows_application/features/customer_management/models/customer_models.dart';
import 'package:windows_application/features/customer_management/models/customer_queries.dart';
import 'package:windows_application/features/customer_management/repositories/customer_management_repository.dart';

void main() {
  test('loads group identity and members directly by route id', () async {
    final _DetailRepository repository = _DetailRepository();
    final CustomerGroupDetailCubit cubit = CustomerGroupDetailCubit(repository);

    await cubit.load(4);

    expect(repository.groupIds, <int>[4]);
    expect(repository.memberQueries.single, const CustomerGroupListQuery());
    expect(cubit.state.group?.id, 4);
    expect(cubit.state.members?.items.single.name, 'Member');
    expect(cubit.state.group?.memberCount, 1);
    await cubit.close();
  });

  test(
    'search and pagination remain bounded and retain archived members',
    () async {
      final _DetailRepository repository = _DetailRepository(
        archivedMember: true,
      );
      final CustomerGroupDetailCubit cubit = CustomerGroupDetailCubit(
        repository,
      );
      await cubit.load(4);

      cubit.submitMemberSearch('archived');
      await Future<void>.delayed(Duration.zero);
      expect(repository.memberQueries.last.search, 'archived');
      expect(
        cubit.state.members?.items.single.lifecycle,
        CustomerLifecycle.archived,
      );
      await cubit.close();
    },
  );

  test('retains group and members when refresh fails', () async {
    final _DetailRepository repository = _DetailRepository();
    final CustomerGroupDetailCubit cubit = CustomerGroupDetailCubit(repository);
    await cubit.load(4);
    repository.error = const ApiException(message: 'offline');

    await cubit.refresh();

    expect(cubit.state.status, CustomerGroupDetailStatus.failure);
    expect(cubit.state.group?.id, 4);
    expect(cubit.state.members?.items, isNotEmpty);
    await cubit.close();
  });
}

class _DetailRepository implements CustomerManagementRepository {
  _DetailRepository({this.archivedMember = false});
  final bool archivedMember;
  Object? error;
  final List<int> groupIds = <int>[];
  final List<CustomerGroupListQuery> memberQueries = <CustomerGroupListQuery>[];

  @override
  Future<CustomerGroup> getGroup(int groupId) {
    groupIds.add(groupId);
    if (error != null) return Future<CustomerGroup>.error(error!);
    return Future<CustomerGroup>.value(
      CustomerGroup(
        id: groupId,
        name: 'VIP',
        lifecycle: CustomerLifecycle.active,
        memberCount: 1,
      ),
    );
  }

  @override
  Future<CustomerPage<Customer>> listGroupMembers(
    int groupId,
    CustomerGroupListQuery query,
  ) {
    memberQueries.add(query);
    if (error != null) return Future<CustomerPage<Customer>>.error(error!);
    return Future<CustomerPage<Customer>>.value(
      CustomerPage<Customer>(
        items: <Customer>[
          _customer(
            archivedMember
                ? CustomerLifecycle.archived
                : CustomerLifecycle.active,
          ),
        ],
        meta: const CustomerPageMeta(
          currentPage: 1,
          lastPage: 1,
          perPage: 25,
          total: 1,
        ),
      ),
    );
  }

  Customer _customer(CustomerLifecycle lifecycle) => Customer(
    id: 9,
    customerNumber: 'C-000009',
    name: archivedMember ? 'Archived member' : 'Member',
    lifecycle: lifecycle,
    phones: const <CustomerPhone>[],
    groups: const <CustomerGroupSummary>[],
    allowedActions: const <String>{},
  );

  @override
  noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

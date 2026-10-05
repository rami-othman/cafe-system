import 'package:flutter_test/flutter_test.dart';
import 'package:windows_application/features/customer_management/controllers/customer_group_membership_cubit.dart';
import 'package:windows_application/features/customer_management/controllers/customer_group_membership_state.dart';
import 'package:windows_application/features/customer_management/models/customer_group_models.dart';
import 'package:windows_application/features/customer_management/models/customer_models.dart';
import 'package:windows_application/features/customer_management/models/customer_queries.dart';
import 'package:windows_application/features/customer_management/repositories/customer_management_repository.dart';

void main() {
  test(
    'loads bounded candidates, retains selections across pages, and adds atomically',
    () async {
      final _MembershipRepository repository = _MembershipRepository();
      final CustomerGroupMembershipCubit cubit = CustomerGroupMembershipCubit(
        repository,
        groupId: 4,
      );

      await cubit.loadCandidates();
      cubit.toggleSelected(2);
      cubit.setCandidatePage(2);
      await Future<void>.delayed(Duration.zero);
      expect(cubit.state.selectedCustomerIds, <int>{2});
      await cubit.addSelected();

      expect(repository.added, <int>[2]);
      expect(cubit.state.selectedCustomerIds, isEmpty);
    },
  );

  test(
    'remove calls only the selected membership and preserves failures',
    () async {
      final _MembershipRepository repository = _MembershipRepository(
        error: StateError('offline'),
      );
      final CustomerGroupMembershipCubit cubit = CustomerGroupMembershipCubit(
        repository,
        groupId: 4,
      );

      await cubit.remove(9);

      expect(repository.removed, <int>[9]);
      expect(cubit.state.status, CustomerGroupMembershipStatus.failure);
      await cubit.close();
    },
  );
}

class _MembershipRepository implements CustomerManagementRepository {
  _MembershipRepository({this.error});
  final Object? error;
  final List<int> added = <int>[];
  final List<int> removed = <int>[];

  @override
  Future<CustomerPage<Customer>> listEligibleMembers(
    int groupId,
    CustomerGroupListQuery query,
  ) async => CustomerPage<Customer>(
    items: <Customer>[_customer(2)],
    meta: CustomerPageMeta(
      currentPage: query.page,
      lastPage: 2,
      perPage: query.perPage,
      total: 26,
    ),
  );

  @override
  Future<CustomerGroup> addGroupMembers(int groupId, Set<int> customerIds) {
    added.addAll(customerIds);
    if (error != null) return Future<CustomerGroup>.error(error!);
    return Future<CustomerGroup>.value(
      const CustomerGroup(
        id: 4,
        name: 'VIP',
        lifecycle: CustomerLifecycle.active,
        memberCount: 2,
      ),
    );
  }

  @override
  Future<CustomerGroup> removeGroupMember(int groupId, int customerId) {
    removed.add(customerId);
    if (error != null) return Future<CustomerGroup>.error(error!);
    return Future<CustomerGroup>.value(
      const CustomerGroup(
        id: 4,
        name: 'VIP',
        lifecycle: CustomerLifecycle.active,
        memberCount: 0,
      ),
    );
  }

  Customer _customer(int id) => Customer(
    id: id,
    customerNumber: 'C-00000$id',
    name: 'Candidate $id',
    lifecycle: CustomerLifecycle.active,
    phones: const <CustomerPhone>[],
    groups: const <CustomerGroupSummary>[],
    allowedActions: const <String>{},
  );

  @override
  noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

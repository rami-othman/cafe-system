import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:windows_application/features/customer_management/controllers/customer_detail_cubit.dart';
import 'package:windows_application/features/customer_management/controllers/customer_form_cubit.dart';
import 'package:windows_application/features/customer_management/controllers/customer_group_detail_cubit.dart';
import 'package:windows_application/features/customer_management/controllers/customer_group_form_cubit.dart';
import 'package:windows_application/features/customer_management/controllers/customer_group_list_cubit.dart';
import 'package:windows_application/features/customer_management/controllers/customer_group_membership_cubit.dart';
import 'package:windows_application/features/customer_management/controllers/customer_list_cubit.dart';
import 'package:windows_application/features/customer_management/models/customer_drafts.dart';
import 'package:windows_application/features/customer_management/models/customer_group_models.dart';
import 'package:windows_application/features/customer_management/models/customer_models.dart';
import 'package:windows_application/features/customer_management/models/customer_queries.dart';
import 'package:windows_application/features/customer_management/repositories/customer_management_repository.dart';
import 'package:windows_application/features/customer_management/views/customer_detail_screen.dart';
import 'package:windows_application/features/customer_management/views/customer_form_screen.dart';
import 'package:windows_application/features/customer_management/views/customer_group_detail_screen.dart';
import 'package:windows_application/features/customer_management/views/customer_group_form_screen.dart';
import 'package:windows_application/features/customer_management/views/customer_group_list_screen.dart';
import 'package:windows_application/features/customer_management/views/customer_list_screen.dart';
import 'package:windows_application/features/customer_management/widgets/customer_confirmation_dialog.dart';
import 'package:windows_application/features/customer_management/widgets/customer_group_components.dart';
import 'package:windows_application/features/customer_management/widgets/customer_collection.dart';

class CustomerManagementGoldenFixtures {
  CustomerManagementGoldenFixtures() : _repository = _GoldenRepository();

  final _GoldenRepository _repository;

  Widget customerList() => BlocProvider<CustomerListCubit>(
    create: (_) => CustomerListCubit(_repository),
    child: const CustomerListScreen(),
  );

  Widget customerDetail() => BlocProvider<CustomerDetailCubit>(
    create: (_) => CustomerDetailCubit(_repository),
    child: const CustomerDetailScreen(customerId: 7),
  );

  Widget customerCreate() => BlocProvider<CustomerFormCubit>(
    create: (_) => CustomerFormCubit(_repository),
    child: const CustomerFormScreen(),
  );

  Widget customerEdit() => BlocProvider<CustomerFormCubit>(
    create: (_) => CustomerFormCubit(_repository),
    child: const CustomerFormScreen(customerId: 7),
  );

  Widget groupList() => BlocProvider<CustomerGroupListCubit>(
    create: (_) => CustomerGroupListCubit(_repository),
    child: CustomerGroupListScreen(repository: _repository),
  );

  Widget groupDetail() => BlocProvider<CustomerGroupDetailCubit>(
    create: (_) => CustomerGroupDetailCubit(_repository),
    child: CustomerGroupDetailScreen(groupId: 4, repository: _repository),
  );

  Widget groupCreate() => BlocProvider<CustomerGroupFormCubit>(
    create: (_) => CustomerGroupFormCubit(_repository),
    child: const CustomerGroupFormScreen(),
  );

  Widget groupEdit() => BlocProvider<CustomerGroupFormCubit>(
    create: (_) => CustomerGroupFormCubit(_repository),
    child: const CustomerGroupFormScreen(groupId: 4),
  );

  Future<CustomerGroupMembershipCubit> membershipCubit() async {
    final CustomerGroupMembershipCubit cubit = CustomerGroupMembershipCubit(
      _repository,
      groupId: 4,
    );
    await cubit.loadCandidates();
    return cubit;
  }

  Widget confirmation() => const Scaffold(
    body: CustomerConfirmationDialog(
      title: 'Archive VIP?',
      message: 'The group remains available in historical records.',
      confirmLabel: 'Archive',
    ),
  );

  Widget customerCollection() => Scaffold(
    body: CustomerCollection(
      customers: const <Customer>[_customer, _secondCustomer],
      onSelected: (_) {},
      onEdit: (_) {},
    ),
  );

  Widget groupCollection() => Scaffold(
    body: CustomerGroupTable(
      groups: <CustomerGroup>[_group],
      onView: (_) {},
      onEdit: (_) {},
    ),
  );
}

class _GoldenRepository implements CustomerManagementRepository {
  @override
  Future<CustomerPage<Customer>> listCustomers(CustomerListQuery query) async =>
      const CustomerPage<Customer>(
        items: <Customer>[_customer, _secondCustomer],
        meta: CustomerPageMeta(
          currentPage: 1,
          lastPage: 1,
          perPage: 25,
          total: 2,
        ),
      );

  @override
  Future<Customer> getCustomer(int customerId) async => _customer;

  @override
  Future<Customer> createCustomer(CustomerDraft draft) async => _customer;

  @override
  Future<Customer> updateCustomer(int customerId, CustomerDraft draft) async =>
      _customer;

  @override
  Future<Customer> changeCustomerLifecycle(
    int customerId,
    String action,
  ) async => _customer;

  @override
  Future<CustomerPage<CustomerGroup>> listGroups(
    CustomerGroupListQuery query,
  ) async => CustomerPage<CustomerGroup>(
    items: <CustomerGroup>[_group],
    meta: CustomerPageMeta(currentPage: 1, lastPage: 1, perPage: 25, total: 1),
  );

  @override
  Future<CustomerGroup> getGroup(int groupId) async => _group;

  @override
  Future<CustomerGroup> createGroup(GroupDraft draft) async => _group;

  @override
  Future<CustomerGroup> updateGroup(int groupId, GroupDraft draft) async =>
      _group;

  @override
  Future<CustomerGroup> changeGroupLifecycle(
    int groupId,
    String action,
  ) async => _group;

  @override
  Future<CustomerPage<Customer>> listGroupMembers(
    int groupId,
    CustomerGroupListQuery query,
  ) async => CustomerPage<Customer>(
    items: <Customer>[_customer],
    meta: CustomerPageMeta(currentPage: 1, lastPage: 1, perPage: 25, total: 1),
  );

  @override
  Future<CustomerPage<Customer>> listEligibleMembers(
    int groupId,
    CustomerGroupListQuery query,
  ) async => CustomerPage<Customer>(
    items: <Customer>[_secondCustomer],
    meta: CustomerPageMeta(currentPage: 1, lastPage: 1, perPage: 25, total: 1),
  );

  @override
  Future<CustomerGroup> addGroupMembers(
    int groupId,
    Set<int> customerIds,
  ) async => _group;

  @override
  Future<CustomerGroup> removeGroupMember(int groupId, int customerId) async =>
      _group;

  @override
  Future<bool> fetchCustomerManagementCapability() async => true;
}

final CustomerGroup _group = CustomerGroup(
  id: 4,
  name: 'VIP Guests',
  lifecycle: CustomerLifecycle.active,
  memberCount: 1,
  createdAt: DateTime.utc(2026, 9, 10),
);

const Customer _customer = Customer(
  id: 7,
  customerNumber: 'C-000007',
  name: 'Ada Lovelace',
  lifecycle: CustomerLifecycle.active,
  email: 'ada@example.test',
  notes: 'Preferred contact',
  phones: <CustomerPhone>[
    CustomerPhone(
      id: 1,
      rawNumber: '+963 9 123',
      type: 'mobile',
      isPrimary: true,
    ),
  ],
  groups: <CustomerGroupSummary>[
    CustomerGroupSummary(
      id: 4,
      name: 'VIP Guests',
      lifecycle: CustomerLifecycle.active,
    ),
  ],
  allowedActions: <String>{'update'},
);

const Customer _secondCustomer = Customer(
  id: 8,
  customerNumber: 'C-000008',
  name: 'Samir Haddad',
  lifecycle: CustomerLifecycle.inactive,
  phones: <CustomerPhone>[],
  groups: <CustomerGroupSummary>[],
  allowedActions: <String>{'update'},
);

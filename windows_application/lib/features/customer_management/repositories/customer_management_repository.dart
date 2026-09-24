import 'dart:typed_data';

import 'package:dio/dio.dart';

import '../../../core/network/dio_api_client.dart';
import '../../../core/network/api_exception.dart';
import '../models/customer_drafts.dart';
import '../models/customer_group_models.dart';
import '../models/customer_import_models.dart';
import '../models/customer_models.dart';
import '../models/customer_queries.dart';
import 'customer_import_repository.dart';

abstract interface class CustomerManagementRepository {
  static const Set<String> contractPaths = <String>{
    'customer-management/capabilities',
    'branches',
    'admin/customer-management/customers',
    'admin/customer-management/customers/{customer}/overview',
    'admin/customer-management/customers/{customer}/orders',
    'admin/customer-management/customer-groups',
  };

  Future<bool> fetchCustomerManagementCapability();
  Future<CustomerPage<Customer>> listCustomers(CustomerListQuery query);
  Future<Customer> getCustomer(int customerId);
  Future<CustomerOverview> getCustomerOverview(int customerId);
  Future<List<CustomerOrderBranch>> listPermittedOrderBranches();
  Future<CustomerPage<CustomerOrder>> listCustomerOrders(
    int customerId,
    CustomerOrderQuery query,
  );
  Future<Customer> createCustomer(CustomerDraft draft);
  Future<Customer> updateCustomer(int customerId, CustomerDraft draft);
  Future<Customer> changeCustomerLifecycle(int customerId, String action);
  Future<CustomerPage<CustomerGroup>> listGroups(CustomerGroupListQuery query);
  Future<CustomerGroup> getGroup(int groupId);
  Future<CustomerGroup> createGroup(GroupDraft draft);
  Future<CustomerGroup> updateGroup(int groupId, GroupDraft draft);
  Future<CustomerGroup> changeGroupLifecycle(int groupId, String action);
  Future<CustomerPage<Customer>> listGroupMembers(
    int groupId,
    CustomerGroupListQuery query,
  );
  Future<CustomerPage<Customer>> listEligibleMembers(
    int groupId,
    CustomerGroupListQuery query,
  );
  Future<CustomerGroup> addGroupMembers(int groupId, Set<int> customerIds);
  Future<CustomerGroup> removeGroupMember(int groupId, int customerId);
}

class ApiCustomerManagementRepository
    implements CustomerManagementRepository, CustomerImportRepository {
  ApiCustomerManagementRepository(this._apiClient);

  final DioApiClient _apiClient;

  @override
  Future<bool> fetchCustomerManagementCapability() async {
    final Map<String, dynamic> data = _map(
      await _apiClient.get('customer-management/capabilities'),
    );
    return _map(data['customer'])['manage'] == true;
  }

  @override
  Future<CustomerPage<Customer>> listCustomers(CustomerListQuery query) =>
      _customerPage(
        'admin/customer-management/customers',
        query.toQueryParameters(),
      );

  @override
  Future<Customer> getCustomer(int customerId) => _customer(
    _apiClient.get('admin/customer-management/customers/${_id(customerId)}'),
  );

  @override
  Future<CustomerOverview> getCustomerOverview(int customerId) async {
    try {
      return CustomerOverview.fromJson(
        _map(
          await _apiClient.get(
            'admin/customer-management/customers/${_id(customerId)}/overview',
          ),
        ),
      );
    } on ApiException catch (error) {
      // A running backend may still have the pre-overview route set. Keep the
      // established detail route usable in that narrow compatibility case;
      // a truly missing customer still throws from getCustomer below.
      if (error.statusCode != 404) rethrow;
      final Customer customer = await getCustomer(customerId);
      final CustomerPage<CustomerOrder> recent = await listCustomerOrders(
        customerId,
        const CustomerOrderQuery(perPage: 5),
      );
      return CustomerOverview(
        customer: customer,
        summary: CustomerOrderSummary(
          totalOrders: recent.meta.total,
          lastOrderAt: recent.items.isEmpty
              ? null
              : recent.items.first.createdAt,
        ),
        recentOrders: recent.items,
      );
    }
  }

  @override
  Future<List<CustomerOrderBranch>> listPermittedOrderBranches() async {
    final dynamic data = await _apiClient.get('branches');
    if (data is! List) {
      throw const FormatException('Expected permitted branch list.');
    }
    return data
        .map((dynamic value) => CustomerOrderBranch.fromJson(_map(value)))
        .toList(growable: false);
  }

  @override
  Future<CustomerPage<CustomerOrder>> listCustomerOrders(
    int customerId,
    CustomerOrderQuery query,
  ) async => CustomerPage<CustomerOrder>.fromEnvelope(
    _map(
      await _apiClient.getEnvelope(
        'admin/customer-management/customers/${_id(customerId)}/orders',
        queryParameters: query.toQueryParameters(),
      ),
    ),
    CustomerOrder.fromJson,
  );

  @override
  Future<Customer> createCustomer(CustomerDraft draft) => _customer(
    _apiClient.post(
      'admin/customer-management/customers',
      data: draft.toJson(),
    ),
  );

  @override
  Future<Customer> updateCustomer(int customerId, CustomerDraft draft) =>
      _customer(
        _apiClient.put(
          'admin/customer-management/customers/${_id(customerId)}',
          data: draft.toJson(),
        ),
      );

  @override
  Future<Customer> changeCustomerLifecycle(
    int customerId,
    String action,
  ) => _customer(
    _apiClient.post(
      'admin/customer-management/customers/${_id(customerId)}/${_lifecycleAction(action)}',
    ),
  );

  @override
  Future<CustomerPage<CustomerGroup>> listGroups(
    CustomerGroupListQuery query,
  ) => _groupPage(
    'admin/customer-management/customer-groups',
    query.toQueryParameters(),
  );

  @override
  Future<CustomerGroup> getGroup(int groupId) => _group(
    _apiClient.get('admin/customer-management/customer-groups/${_id(groupId)}'),
  );

  @override
  Future<CustomerGroup> createGroup(GroupDraft draft) => _group(
    _apiClient.post(
      'admin/customer-management/customer-groups',
      data: draft.toJson(),
    ),
  );

  @override
  Future<CustomerGroup> updateGroup(int groupId, GroupDraft draft) => _group(
    _apiClient.put(
      'admin/customer-management/customer-groups/${_id(groupId)}',
      data: draft.toJson(),
    ),
  );

  @override
  Future<CustomerGroup> changeGroupLifecycle(
    int groupId,
    String action,
  ) => _group(
    _apiClient.post(
      'admin/customer-management/customer-groups/${_id(groupId)}/${_lifecycleAction(action)}',
    ),
  );

  @override
  Future<CustomerPage<Customer>> listGroupMembers(
    int groupId,
    CustomerGroupListQuery query,
  ) => _customerPage(
    'admin/customer-management/customer-groups/${_id(groupId)}/members',
    query.toQueryParameters(),
  );

  @override
  Future<CustomerPage<Customer>> listEligibleMembers(
    int groupId,
    CustomerGroupListQuery query,
  ) => _customerPage(
    'admin/customer-management/customer-groups/${_id(groupId)}/eligible-members',
    query.toQueryParameters(),
  );

  @override
  Future<CustomerGroup> addGroupMembers(int groupId, Set<int> customerIds) {
    final List<int> ids = customerIds.toList()..sort();
    if (ids.isEmpty || ids.any((int id) => id <= 0)) {
      throw ArgumentError.value(customerIds, 'customerIds');
    }
    return _group(
      _apiClient.post(
        'admin/customer-management/customer-groups/${_id(groupId)}/members',
        data: <String, dynamic>{'customerIds': ids},
      ),
    );
  }

  @override
  Future<CustomerGroup> removeGroupMember(
    int groupId,
    int customerId,
  ) => _group(
    _apiClient.delete(
      'admin/customer-management/customer-groups/${_id(groupId)}/members/${_id(customerId)}',
    ),
  );

  @override
  Future<CustomerImportStatus> previewCustomerImport({
    required Uint8List bytes,
    required String filename,
  }) async {
    final dynamic response = await _apiClient.postMultipart(
      'admin/customer-management/customer-imports/preview',
      data: FormData.fromMap(<String, dynamic>{
        'file': MultipartFile.fromBytes(bytes, filename: filename),
      }),
    );
    return CustomerImportStatus.fromJson(_map(response));
  }

  @override
  Future<CustomerImportStatus> commitCustomerImport({
    required int importId,
    required bool createMissingGroups,
  }) async {
    final dynamic response = await _apiClient.post(
      'admin/customer-management/customer-imports/${_id(importId)}/commit',
      data: <String, dynamic>{'createMissingGroups': createMissingGroups},
    );
    return CustomerImportStatus.fromJson(_map(response));
  }

  @override
  Future<CustomerImportStatus> getCustomerImport(int importId) async {
    final dynamic response = await _apiClient.get(
      'admin/customer-management/customer-imports/${_id(importId)}',
    );
    return CustomerImportStatus.fromJson(_map(response));
  }

  @override
  Future<Uint8List> downloadCustomerImportErrors(int importId) =>
      _apiClient.getBytes(
        'admin/customer-management/customer-imports/${_id(importId)}/errors',
      );

  Future<Customer> _customer(Future<dynamic> data) async =>
      Customer.fromJson(_map(await data));

  Future<CustomerGroup> _group(Future<dynamic> data) async =>
      CustomerGroup.fromJson(_map(await data));

  Future<CustomerPage<Customer>> _customerPage(
    String path,
    Map<String, dynamic> query,
  ) async => CustomerPage<Customer>.fromEnvelope(
    _map(await _apiClient.getEnvelope(path, queryParameters: query)),
    Customer.fromJson,
  );

  Future<CustomerPage<CustomerGroup>> _groupPage(
    String path,
    Map<String, dynamic> query,
  ) async => CustomerPage<CustomerGroup>.fromEnvelope(
    _map(await _apiClient.getEnvelope(path, queryParameters: query)),
    CustomerGroup.fromJson,
  );
}

Map<String, dynamic> _map(dynamic value) => value is Map<String, dynamic>
    ? value
    : value is Map
    ? value.cast<String, dynamic>()
    : throw FormatException(
        'Customer Management API response must be an object.',
      );

int _id(int value) {
  if (value <= 0) throw ArgumentError.value(value, 'id');
  return value;
}

String _lifecycleAction(String value) {
  if (!const <String>{
    'activate',
    'deactivate',
    'archive',
    'restore',
  }.contains(value)) {
    throw ArgumentError.value(value, 'action');
  }
  return value;
}

import '../../../core/network/dio_api_client.dart';
import '../models/customer_drafts.dart';
import '../models/customer_group_models.dart';
import '../models/customer_models.dart';
import '../models/customer_queries.dart';

abstract interface class CustomerManagementRepository {
  static const Set<String> contractPaths = <String>{
    'customer-management/capabilities',
    'admin/customer-management/customers',
    'admin/customer-management/customer-groups',
  };

  Future<bool> fetchCustomerManagementCapability();
  Future<CustomerPage<Customer>> listCustomers(CustomerListQuery query);
  Future<Customer> getCustomer(int customerId);
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

class ApiCustomerManagementRepository implements CustomerManagementRepository {
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

abstract final class CustomerManagementRouteLocations {
  static const String customers = '/customers';
  static const String customerCreate = '/customers/new';
  static const String customerDetail = '/customers/:customerId';
  static const String customerEdit = '/customers/:customerId/edit';
  static const String groups = '/customers/groups';
  static const String groupCreate = '/customers/groups/new';
  static const String groupDetail = '/customers/groups/:groupId';
  static const String groupEdit = '/customers/groups/:groupId/edit';

  static String customer(int customerId) => '$customers/${_id(customerId)}';
  static String editCustomer(int customerId) => '${customer(customerId)}/edit';
  static String group(int groupId) => '$groups/${_id(groupId)}';
  static String editGroup(int groupId) => '${group(groupId)}/edit';

  static int? parseId(String? value) {
    final int? id = int.tryParse(value ?? '');
    return id != null && id > 0 ? id : null;
  }

  static int _id(int value) {
    if (value <= 0) throw ArgumentError.value(value, 'id');
    return value;
  }
}

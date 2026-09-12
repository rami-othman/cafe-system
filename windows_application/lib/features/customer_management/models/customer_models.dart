import 'package:equatable/equatable.dart';

enum CustomerLifecycle { active, inactive, archived }

CustomerLifecycle _lifecycle(Map<String, dynamic> json) {
  return switch (json['status']) {
    'active' => CustomerLifecycle.active,
    'inactive' => CustomerLifecycle.inactive,
    'archived' => CustomerLifecycle.archived,
    _ => throw FormatException('Customer response has an invalid status.'),
  };
}

Map<String, dynamic> _map(dynamic value, String label) {
  if (value is Map) return Map<String, dynamic>.from(value);
  throw FormatException('$label must be an object.');
}

List<dynamic> _requiredList(Map<String, dynamic> json, String key) {
  final dynamic value = json[key];
  if (value is! List) {
    throw FormatException('Customer response is missing $key.');
  }
  return value;
}

Set<String> _requiredStringSet(Map<String, dynamic> json, String key) {
  final List<dynamic> values = _requiredList(json, key);
  if (values.any((dynamic value) => value is! String || value.trim().isEmpty)) {
    throw FormatException('Customer response has invalid $key.');
  }
  return values.cast<String>().toSet();
}

int _requiredInt(Map<String, dynamic> json, String key) {
  final int? value = (json[key] as num?)?.toInt();
  if (value == null || value <= 0) {
    throw FormatException('Customer response is missing $key.');
  }
  return value;
}

String _requiredString(Map<String, dynamic> json, String key) {
  final String? value = json[key] as String?;
  if (value == null || value.trim().isEmpty) {
    throw FormatException('Customer response is missing $key.');
  }
  return value;
}

DateTime? _calendarDate(dynamic value) {
  if (value == null) return null;
  final DateTime? parsed = DateTime.tryParse(value as String? ?? '');
  if (parsed == null) return null;
  return DateTime.utc(parsed.year, parsed.month, parsed.day);
}

class CustomerPhone extends Equatable {
  const CustomerPhone({
    required this.id,
    required this.rawNumber,
    required this.type,
    required this.isPrimary,
  });

  factory CustomerPhone.fromJson(Map<String, dynamic> json) => CustomerPhone(
    id: _requiredInt(json, 'id'),
    rawNumber: _requiredString(json, 'rawNumber'),
    type: _requiredString(json, 'type'),
    isPrimary: json['isPrimary'] == true,
  );

  final int id;
  final String rawNumber;
  final String type;
  final bool isPrimary;

  @override
  List<Object> get props => <Object>[id, rawNumber, type, isPrimary];
}

class CustomerGroupSummary extends Equatable {
  const CustomerGroupSummary({
    required this.id,
    required this.name,
    required this.lifecycle,
  });

  factory CustomerGroupSummary.fromJson(Map<String, dynamic> json) =>
      CustomerGroupSummary(
        id: _requiredInt(json, 'id'),
        name: _requiredString(json, 'name'),
        lifecycle: _lifecycle(json),
      );

  final int id;
  final String name;
  final CustomerLifecycle lifecycle;

  @override
  List<Object> get props => <Object>[id, name, lifecycle];
}

class Customer extends Equatable {
  const Customer({
    required this.id,
    required this.customerNumber,
    required this.name,
    required this.lifecycle,
    required this.phones,
    required this.groups,
    required this.allowedActions,
    this.email,
    this.birthDate,
    this.notes,
  });

  factory Customer.fromJson(Map<String, dynamic> json) => Customer(
    id: _requiredInt(json, 'id'),
    customerNumber: _requiredString(json, 'customerNumber'),
    name: _requiredString(json, 'name'),
    lifecycle: _lifecycle(json),
    email: json['email'] as String?,
    birthDate: _calendarDate(json['birthDate']),
    notes: json['notes'] as String?,
    phones: _requiredList(json, 'phones')
        .map((dynamic value) => CustomerPhone.fromJson(_map(value, 'phone')))
        .toList(growable: false),
    groups: _requiredList(json, 'groups')
        .map(
          (dynamic value) =>
              CustomerGroupSummary.fromJson(_map(value, 'group')),
        )
        .toList(growable: false),
    allowedActions: _requiredStringSet(json, 'allowedActions'),
  );

  final int id;
  final String customerNumber;
  final String name;
  final CustomerLifecycle lifecycle;
  final String? email;
  final DateTime? birthDate;
  final String? notes;
  final List<CustomerPhone> phones;
  final List<CustomerGroupSummary> groups;
  final Set<String> allowedActions;

  @override
  List<Object?> get props => <Object?>[
    id,
    customerNumber,
    name,
    lifecycle,
    email,
    birthDate,
    notes,
    phones,
    groups,
    allowedActions,
  ];
}

class CustomerPageMeta extends Equatable {
  const CustomerPageMeta({
    required this.currentPage,
    required this.lastPage,
    required this.perPage,
    required this.total,
  });

  factory CustomerPageMeta.fromJson(Map<String, dynamic> json) =>
      CustomerPageMeta(
        currentPage: _requiredInt(json, 'currentPage'),
        lastPage: _requiredInt(json, 'lastPage'),
        perPage: _requiredInt(json, 'perPage'),
        total:
            (json['total'] as num?)?.toInt() ??
            (throw FormatException('Customer page is missing total.')),
      );

  final int currentPage;
  final int lastPage;
  final int perPage;
  final int total;

  @override
  List<Object> get props => <Object>[currentPage, lastPage, perPage, total];
}

class CustomerPage<T> extends Equatable {
  const CustomerPage({required this.items, required this.meta});

  factory CustomerPage.fromEnvelope(
    Map<String, dynamic> envelope,
    T Function(Map<String, dynamic>) fromJson,
  ) {
    final dynamic rawItems = envelope['data'];
    if (rawItems is! List) {
      throw FormatException('Customer page is missing data.');
    }
    return CustomerPage<T>(
      items: rawItems
          .map((dynamic item) => fromJson(_map(item, 'page item')))
          .toList(growable: false),
      meta: CustomerPageMeta.fromJson(_map(envelope['meta'], 'page metadata')),
    );
  }

  final List<T> items;
  final CustomerPageMeta meta;

  @override
  List<Object> get props => <Object>[items, meta];
}

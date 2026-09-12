import 'package:equatable/equatable.dart';

enum CustomerStatusFilter { active, inactive, archived, all }

extension CustomerStatusFilterValue on CustomerStatusFilter {
  String get value => name;
}

class CustomerListQuery extends Equatable {
  const CustomerListQuery({
    this.search = '',
    this.status,
    this.groupId,
    this.page = 1,
    this.perPage = 25,
  });

  final String search;
  final CustomerStatusFilter? status;
  final int? groupId;
  final int page;
  final int perPage;

  CustomerListQuery copyWith({
    String? search,
    CustomerStatusFilter? status,
    int? groupId,
    int? page,
    int? perPage,
    bool clearStatus = false,
    bool clearGroup = false,
  }) => CustomerListQuery(
    search: search ?? this.search,
    status: clearStatus ? null : status ?? this.status,
    groupId: clearGroup ? null : groupId ?? this.groupId,
    page: page ?? this.page,
    perPage: perPage ?? this.perPage,
  );

  Map<String, dynamic> toQueryParameters() => <String, dynamic>{
    if (search.isNotEmpty) 'search': search,
    if (status != null) 'status': status!.value,
    if (groupId != null) 'groupId': groupId,
    'page': page,
    'perPage': perPage,
  };

  @override
  List<Object?> get props => <Object?>[search, status, groupId, page, perPage];
}

class CustomerGroupListQuery extends Equatable {
  const CustomerGroupListQuery({
    this.search = '',
    this.status,
    this.page = 1,
    this.perPage = 25,
  }) : assert(status != CustomerStatusFilter.inactive);

  final String search;
  final CustomerStatusFilter? status;
  final int page;
  final int perPage;

  CustomerGroupListQuery copyWith({
    String? search,
    CustomerStatusFilter? status,
    int? page,
    int? perPage,
    bool clearStatus = false,
  }) => CustomerGroupListQuery(
    search: search ?? this.search,
    status: clearStatus ? null : status ?? this.status,
    page: page ?? this.page,
    perPage: perPage ?? this.perPage,
  );

  Map<String, dynamic> toQueryParameters() => <String, dynamic>{
    if (search.isNotEmpty) 'search': search,
    if (status != null) 'status': status!.value,
    'page': page,
    'perPage': perPage,
  };

  @override
  List<Object?> get props => <Object?>[search, status, page, perPage];
}

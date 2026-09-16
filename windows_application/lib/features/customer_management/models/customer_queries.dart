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

enum CustomerOrderStatusFilter { draft, held, paid, cancelled }
enum CustomerPaymentStatusFilter { unpaid, paid, partiallyRefunded, refunded }

extension CustomerPaymentStatusFilterValue on CustomerPaymentStatusFilter {
  String get value => switch (this) {
    CustomerPaymentStatusFilter.partiallyRefunded => 'partially_refunded',
    _ => name,
  };
}

class CustomerOrderQuery extends Equatable {
  const CustomerOrderQuery({this.from, this.to, this.branchId, this.status, this.paymentStatus, this.page = 1, this.perPage = 25});
  final DateTime? from; final DateTime? to; final int? branchId; final CustomerOrderStatusFilter? status; final CustomerPaymentStatusFilter? paymentStatus; final int page; final int perPage;
  CustomerOrderQuery copyWith({DateTime? from, DateTime? to, int? branchId, CustomerOrderStatusFilter? status, CustomerPaymentStatusFilter? paymentStatus, int? page, bool clearFrom = false, bool clearTo = false, bool clearBranch = false, bool clearStatus = false, bool clearPaymentStatus = false}) => CustomerOrderQuery(from: clearFrom ? null : from ?? this.from, to: clearTo ? null : to ?? this.to, branchId: clearBranch ? null : branchId ?? this.branchId, status: clearStatus ? null : status ?? this.status, paymentStatus: clearPaymentStatus ? null : paymentStatus ?? this.paymentStatus, page: page ?? this.page, perPage: perPage);
  Map<String, dynamic> toQueryParameters() => <String, dynamic>{if (from != null) 'from': _date(from!), if (to != null) 'to': _date(to!), if (branchId != null) 'branchId': branchId, if (status != null) 'status': status!.name, if (paymentStatus != null) 'paymentStatus': paymentStatus!.value, 'page': page, 'perPage': perPage};
  static String _date(DateTime value) => '${value.year.toString().padLeft(4, '0')}-${value.month.toString().padLeft(2, '0')}-${value.day.toString().padLeft(2, '0')}';
  @override List<Object?> get props => <Object?>[from, to, branchId, status, paymentStatus, page, perPage];
}

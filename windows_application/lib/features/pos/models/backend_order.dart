import 'package:equatable/equatable.dart';

import 'backend_order_item.dart';
import 'backend_order_totals.dart';
import 'json_helpers.dart';

class BackendOrder extends Equatable {
  const BackendOrder({
    required this.id,
    required this.orderNumber,
    required this.branchId,
    required this.orderType,
    required this.status,
    required this.paymentStatus,
    required this.items,
    required this.totals,
    this.shiftId,
    this.discountName,
    this.discountType,
    this.discountValue,
    this.discountAmount,
    this.customerId,
    this.customerName,
    this.customerPhone,
    this.tableId,
    this.tableName,
    this.tableCode,
  });

  factory BackendOrder.fromJson(Map<String, dynamic> json) {
    return BackendOrder(
      id: readInt(json['id']) ?? 0,
      orderNumber: readString(json['orderNumber']),
      branchId: readInt(json['branchId']) ?? 0,
      shiftId: readInt(json['shiftId']),
      orderType: readString(json['orderType']),
      status: readString(json['status']),
      paymentStatus: readString(json['paymentStatus']),
      items: readMapList(
        json['items'],
      ).map(BackendOrderItem.fromJson).toList(growable: false),
      totals: BackendOrderTotals.fromJson(
        Map<String, dynamic>.from(
          json['totals'] as Map? ?? <String, dynamic>{},
        ),
      ),
      discountName:
          readString((json['discount'] as Map?)?['reason']).trim().isEmpty
          ? null
          : readString((json['discount'] as Map?)?['reason']).trim(),
      discountType:
          readString((json['discount'] as Map?)?['type']).trim().isEmpty
          ? null
          : readString((json['discount'] as Map?)?['type']).trim(),
      discountValue: (json['discount'] as Map?) == null
          ? null
          : readDouble((json['discount'] as Map?)?['value']),
      discountAmount: (json['discount'] as Map?) == null
          ? null
          : readDouble((json['discount'] as Map?)?['amount']),
      customerId: readInt((json['customer'] as Map?)?['id']),
      customerName: readString((json['customer'] as Map?)?['name']).isEmpty
          ? null
          : readString((json['customer'] as Map?)?['name']),
      customerPhone: readString((json['customer'] as Map?)?['phone']).isEmpty
          ? null
          : readString((json['customer'] as Map?)?['phone']),
      tableId: readInt((json['table'] as Map?)?['id']),
      tableName: readString((json['table'] as Map?)?['name']).isEmpty
          ? null
          : readString((json['table'] as Map?)?['name']),
      tableCode: readString((json['table'] as Map?)?['code']).isEmpty
          ? null
          : readString((json['table'] as Map?)?['code']),
    );
  }

  final int id;
  final String orderNumber;
  final int branchId;
  final int? shiftId;
  final String orderType;
  final String status;
  final String paymentStatus;
  final List<BackendOrderItem> items;
  final BackendOrderTotals totals;
  final String? discountName;
  final String? discountType;
  final double? discountValue;
  final double? discountAmount;
  final int? customerId;
  final String? customerName;
  final String? customerPhone;
  final int? tableId;
  final String? tableName;
  final String? tableCode;

  @override
  List<Object?> get props => <Object?>[
    id,
    orderNumber,
    branchId,
    shiftId,
    orderType,
    status,
    paymentStatus,
    items,
    totals,
    discountName,
    discountType,
    discountValue,
    discountAmount,
    customerId,
    customerName,
    customerPhone,
    tableId,
    tableName,
    tableCode,
  ];
}

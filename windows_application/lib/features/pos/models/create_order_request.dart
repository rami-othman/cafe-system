import 'order_type.dart';
import 'selected_modifier.dart';

class CreateOrderRequest {
  const CreateOrderRequest({
    required this.branchId,
    required this.orderType,
    required this.items,
    this.shiftId,
    this.tableId,
    this.customerId,
    this.note,
  });

  final int branchId;
  final int? shiftId;
  final OrderType orderType;
  final int? tableId;
  final int? customerId;
  final List<AddOrderItemRequest> items;
  final String? note;

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'branchId': branchId,
      'shiftId': shiftId,
      'orderType': orderType.apiValue,
      'tableId': tableId,
      'customerId': customerId,
      'items': items
          .map((AddOrderItemRequest item) => item.toJson())
          .toList(growable: false),
      if (note != null) 'note': note,
    };
  }
}

class AddOrderItemRequest {
  const AddOrderItemRequest({
    required this.productId,
    required this.quantity,
    this.modifiers = const <SelectedModifier>[],
    this.note,
  });

  final int productId;
  final int quantity;
  final List<SelectedModifier> modifiers;
  final String? note;

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'productId': productId,
      'quantity': quantity,
      'modifiers': modifiers
          .map((SelectedModifier modifier) => modifier.toJson())
          .toList(growable: false),
      if (note != null && note!.trim().isNotEmpty) 'note': note!.trim(),
    };
  }
}

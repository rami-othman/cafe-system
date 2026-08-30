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
    this.publishedMenuVersionId,
  });

  final int branchId;
  final int? shiftId;
  final OrderType orderType;
  final int? tableId;
  final int? customerId;
  final List<AddOrderItemRequest> items;
  final String? note;
  final int? publishedMenuVersionId;

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'branchId': branchId,
      'shiftId': shiftId,
      'orderType': orderType.apiValue,
      'tableId': tableId,
      'customerId': customerId,
      if (publishedMenuVersionId != null)
        'publishedMenuVersionId': publishedMenuVersionId,
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
    this.placementId,
    this.variantId,
    this.modifierOptionIds,
    this.note,
  });

  final int productId;
  final int quantity;
  final List<SelectedModifier> modifiers;
  final int? placementId;
  final int? variantId;
  final List<int>? modifierOptionIds;
  final String? note;

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'productId': productId,
      'quantity': quantity,
      'modifiers': modifiers
          .map((SelectedModifier modifier) => modifier.toJson())
          .toList(growable: false),
      if (placementId != null) 'placementId': placementId,
      if (variantId != null) 'variantId': variantId,
      if (modifierOptionIds != null) 'modifierOptionIds': modifierOptionIds,
      if (note != null && note!.trim().isNotEmpty) 'note': note!.trim(),
    };
  }
}

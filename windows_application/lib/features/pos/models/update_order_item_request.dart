import 'selected_modifier.dart';

class UpdateOrderItemRequest {
  const UpdateOrderItemRequest({this.quantity, this.modifiers, this.note});

  final int? quantity;
  final List<SelectedModifier>? modifiers;
  final String? note;

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      if (quantity != null) 'quantity': quantity,
      if (modifiers != null)
        'modifiers': modifiers!
            .map((SelectedModifier modifier) => modifier.toJson())
            .toList(growable: false),
      if (note != null) 'note': note,
    };
  }
}

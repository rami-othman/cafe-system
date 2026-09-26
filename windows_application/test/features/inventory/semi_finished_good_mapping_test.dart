import 'package:flutter_test/flutter_test.dart';
import 'package:windows_application/features/inventory/views/widgets/inventory_item_widgets.dart';

/// Regression coverage for the audited integration gap: `semi_finished_good`
/// is a real `inventory_items.item_type` value the Manufacturing recipe
/// backend accepts as both an output product and an ingredient, but it was
/// missing from the item-type dropdown in `item_form_screen.dart` and from
/// this label switch (both would otherwise silently fall back to a generic
/// "أخرى"/no-selection). Both were fixed as part of the Manufacturing
/// rollout; this test guards the label mapping half of that fix.
void main() {
  test('inventoryItemTypeLabel maps semi_finished_good to its Arabic label', () {
    expect(inventoryItemTypeLabel('semi_finished_good'), 'نصف مصنع');
  });

  test('inventoryItemTypeLabel still falls back to "أخرى" for a truly unknown type', () {
    expect(inventoryItemTypeLabel('made_up_type'), 'أخرى');
  });
}

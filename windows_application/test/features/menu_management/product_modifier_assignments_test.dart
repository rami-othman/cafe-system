import 'package:flutter_test/flutter_test.dart';
import 'package:windows_application/features/menu_management/products/models/product_modifier_assignment.dart';

void main() {
  final json = <String, dynamic>{
    'id': 7,
    'name': 'Milk',
    'nameAr': 'حليب',
    'nameEn': 'Milk',
    'groupType': 'choice',
    'selectionType': 'multiple',
    'isActive': true,
    'isRequired': false,
    'minSelections': 0,
    'maxSelections': 3,
    'allowQuantity': false,
    'sortOrder': 2,
    'activeOptionCount': 3,
    'isRequiredOverride': true,
    'minSelectionsOverride': 1,
    'maxSelectionsOverride': null,
    'allowQuantityOverride': true,
  };

  test(
    'assignment resolves library defaults and serializes only sync fields',
    () {
      final assignment = ProductModifierAssignment.fromJson(json);
      expect(assignment.effectiveIsRequired, isTrue);
      expect(assignment.effectiveMinSelections, 1);
      expect(assignment.effectiveMaxSelections, 3);
      expect(assignment.effectiveAllowQuantity, isTrue);
      expect(assignment.toSyncJson(), <String, dynamic>{
        'modifierGroupId': 7,
        'sortOrder': 2,
        'isRequiredOverride': true,
        'minSelectionsOverride': 1,
        'maxSelectionsOverride': null,
        'allowQuantityOverride': true,
      });
    },
  );

  test('clearing overrides inherits all library defaults', () {
    final assignment = ProductModifierAssignment.fromJson(json).copyWith(
      clearRequired: true,
      clearMinimum: true,
      clearMaximum: true,
      clearAllowQuantity: true,
    );
    expect(assignment.effectiveIsRequired, isFalse);
    expect(assignment.effectiveMinSelections, 0);
    expect(assignment.effectiveMaxSelections, 3);
    expect(assignment.effectiveAllowQuantity, isFalse);
  });
}

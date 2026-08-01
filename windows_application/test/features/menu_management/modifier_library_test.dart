import 'package:flutter_test/flutter_test.dart';
import 'package:windows_application/features/menu_management/modifiers/models/modifier_editor_drafts.dart';
import 'package:windows_application/features/menu_management/modifiers/models/modifier_models.dart';

void main() {
  test('modifier group and archived option parse backend fields', () {
    final ModifierGroupRecord group = ModifierGroupRecord.fromJson(
      <String, dynamic>{
        'id': 3,
        'name': 'Milk',
        'nameAr': null,
        'nameEn': 'Milk',
        'groupType': 'choice',
        'selectionType': 'single',
        'isRequired': false,
        'minSelections': 0,
        'maxSelections': 1,
        'allowQuantity': false,
        'isActive': false,
        'sortOrder': 2,
        'optionCount': 1,
        'activeOptionCount': 0,
        'archivedAt': '2026-07-31T12:00:00Z',
        'options': <Map<String, dynamic>>[
          <String, dynamic>{
            'id': 8,
            'modifierGroupId': 3,
            'name': 'Oat',
            'priceDelta': '0.50',
            'isDefault': false,
            'isActive': false,
            'isAvailable': true,
            'sortOrder': 0,
            'archivedAt': '2026-07-31T12:00:00Z',
          },
        ],
      },
    );
    expect(group.isArchived, isTrue);
    expect(group.activeOptionCount, 0);
    expect(group.options.single.isArchived, isTrue);
    expect(group.options.single.priceDelta, 0.5);
  });
  test(
    'group create payload includes required initial option and trimmed fields',
    () {
      final Map<String, dynamic> json = const ModifierGroupDraft(
        name: ' Milk ',
        initialOptionName: ' Oat ',
        initialOptionPriceDelta: '0.50',
      ).toCreateJson();
      expect(json['name'], 'Milk');
      expect((json['options'] as List).single['name'], 'Oat');
      expect((json['options'] as List).single['priceDelta'], '0.50');
    },
  );
  test('option update payload never includes modifier group ownership', () {
    final Map<String, dynamic> json = const ModifierOptionDraft(
      name: ' Soy ',
      priceDelta: '0',
    ).toJson();
    expect(json['name'], 'Soy');
    expect(json['modifierGroupId'], isNull);
    expect(json['priceDelta'], '0');
  });
}

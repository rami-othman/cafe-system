import 'package:flutter_test/flutter_test.dart';
import 'package:windows_application/features/pos/models/cart_configuration.dart';
import 'package:windows_application/features/pos/models/selected_modifier.dart';

void main() {
  const List<SelectedModifier> standard = <SelectedModifier>[
    SelectedModifier(groupId: 1, optionId: 2),
    SelectedModifier(groupId: 3, optionId: 7),
  ];

  String key({
    int productId = 4,
    List<SelectedModifier> modifiers = standard,
    String note = 'Extra hot',
  }) {
    return CartConfiguration.build(
      productId: productId,
      modifiers: modifiers,
      specialInstructions: note,
    );
  }

  group('CartConfiguration', () {
    test('same IDs produce the same canonical key regardless of order', () {
      expect(key(), '4|1:2,3:7|Extra hot');
      expect(
        key(
          modifiers: const <SelectedModifier>[
            SelectedModifier(groupId: 3, optionId: 7),
            SelectedModifier(groupId: 1, optionId: 2),
            SelectedModifier(groupId: 1, optionId: 2),
          ],
        ),
        key(),
      );
    });

    test('different product, group, option, and note stay distinct', () {
      expect(key(productId: 5), isNot(key()));
      expect(
        key(
          modifiers: const <SelectedModifier>[
            SelectedModifier(groupId: 2, optionId: 2),
            SelectedModifier(groupId: 3, optionId: 7),
          ],
        ),
        isNot(key()),
      );
      expect(
        key(
          modifiers: const <SelectedModifier>[
            SelectedModifier(groupId: 1, optionId: 9),
            SelectedModifier(groupId: 3, optionId: 7),
          ],
        ),
        isNot(key()),
      );
      expect(key(note: 'No foam'), isNot(key()));
    });

    test('trims notes and has no display label or quantity input', () {
      expect(key(note: '  Extra hot  '), key());
      expect(key(note: '   '), '4|1:2,3:7|');
    });
  });
}

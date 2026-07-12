import 'selected_modifier.dart';

/// Stable configuration identity for backend-backed POS cart lines.
abstract final class CartConfiguration {
  static String build({
    required int productId,
    required Iterable<SelectedModifier> modifiers,
    required String specialInstructions,
  }) {
    final List<SelectedModifier> normalized =
        modifiers
            .where((SelectedModifier modifier) {
              return modifier.groupId > 0 && modifier.optionId > 0;
            })
            .toSet()
            .toList(growable: false)
          ..sort((SelectedModifier left, SelectedModifier right) {
            final int groupComparison = left.groupId.compareTo(right.groupId);
            return groupComparison != 0
                ? groupComparison
                : left.optionId.compareTo(right.optionId);
          });

    final String modifierPart = normalized
        .map(
          (SelectedModifier modifier) =>
              '${modifier.groupId}:${modifier.optionId}',
        )
        .join(',');
    return '$productId|$modifierPart|${specialInstructions.trim()}';
  }

  static bool hasCompleteModifierIdentity(
    Iterable<SelectedModifier> modifiers,
  ) {
    return modifiers.every(
      (SelectedModifier modifier) =>
          modifier.groupId > 0 && modifier.optionId > 0,
    );
  }
}

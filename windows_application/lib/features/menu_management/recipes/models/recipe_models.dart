import '../../../pos/models/json_helpers.dart';

class RecipeMaterial {
  const RecipeMaterial({
    required this.id,
    required this.name,
    this.sku,
    this.unitCode,
    required this.configurationAvailable,
    this.unavailabilityReason,
  });
  factory RecipeMaterial.fromJson(Map<String, dynamic> json) => RecipeMaterial(
    id: readInt(json['id']) ?? 0,
    name: readString(json['name']),
    sku: readString(json['sku']).isEmpty ? null : readString(json['sku']),
    unitCode: readString(json['unitCode']).isEmpty
        ? null
        : readString(json['unitCode']),
    configurationAvailable: readBool(json['configurationAvailable']),
    unavailabilityReason: readString(json['unavailabilityReason']).isEmpty
        ? null
        : readString(json['unavailabilityReason']),
  );
  final int id;
  final String name;
  final String? sku;
  final String? unitCode;
  final bool configurationAvailable;
  final String? unavailabilityReason;
}

class RecipeComponent {
  const RecipeComponent({
    required this.materialId,
    required this.quantity,
    required this.unitCode,
    this.operation,
    this.materialName,
    this.materialSku,
    this.sortOrder = 0,
  });
  factory RecipeComponent.fromJson(Map<String, dynamic> json) =>
      RecipeComponent(
        materialId: readInt(json['materialId']) ?? 0,
        quantity: readString(json['quantity']),
        unitCode: readString(json['unitCode']),
        operation: readString(json['operation']).isEmpty
            ? null
            : readString(json['operation']),
        materialName: readString(json['name']).isEmpty
            ? null
            : readString(json['name']),
        materialSku: readString(json['sku']).isEmpty
            ? null
            : readString(json['sku']),
        sortOrder: readInt(json['sortOrder']) ?? 0,
      );
  final int materialId;
  final String quantity;
  final String unitCode;
  final String? operation;

  /// Present on backend-resolved rows. Configuration rows intentionally only
  /// contain stable material IDs and are labelled from the material catalog.
  final String? materialName;
  final String? materialSku;
  final int sortOrder;
  Map<String, dynamic> toJson({bool includeOperation = false}) =>
      <String, dynamic>{
        'materialId': materialId,
        'quantity': quantity,
        'unitCode': unitCode,
        'sortOrder': sortOrder,
        if (includeOperation) 'operation': operation,
      };
}

const Map<String, List<String>> recipeCompatibleUnits = <String, List<String>>{
  'g': <String>['g', 'kg'],
  'kg': <String>['g', 'kg'],
  'ml': <String>['ml', 'l'],
  'l': <String>['ml', 'l'],
  'pc': <String>['pc'],
};

List<String> compatibleRecipeUnits(String? materialUnit) =>
    recipeCompatibleUnits[materialUnit] ?? const <String>[];

class VariantRecipe {
  const VariantRecipe({required this.variantId, required this.components});
  factory VariantRecipe.fromJson(Map<String, dynamic> json) => VariantRecipe(
    variantId: readInt(json['variantId']) ?? 0,
    components: readMapList(
      json['components'],
    ).map(RecipeComponent.fromJson).toList(growable: false),
  );
  final int variantId;
  final List<RecipeComponent> components;
}

class ResolvedRecipe {
  const ResolvedRecipe({required this.variantId, required this.components});
  factory ResolvedRecipe.fromJson(Map<String, dynamic> json) => ResolvedRecipe(
    variantId: readInt(json['variantId']) ?? 0,
    components: readMapList(
      json['components'],
    ).map(RecipeComponent.fromJson).toList(growable: false),
  );
  final int variantId;
  final List<RecipeComponent> components;
}

/// Groups resolver rows by material before they are presented to a manager.
/// The backend already resolves recipe arithmetic; this only keeps the UI from
/// rendering the same material as multiple final rows.
List<RecipeComponent> aggregateRecipeComponents(
  Iterable<RecipeComponent> components,
) {
  final Map<String, RecipeComponent> grouped = <String, RecipeComponent>{};
  for (final component in components) {
    final String key = '${component.materialId}:${component.unitCode}';
    final RecipeComponent? previous = grouped[key];
    grouped[key] = previous == null
        ? component
        : RecipeComponent(
            materialId: component.materialId,
            materialName: component.materialName ?? previous.materialName,
            materialSku: component.materialSku ?? previous.materialSku,
            quantity: _addRecipeQuantities(
              previous.quantity,
              component.quantity,
            ),
            unitCode: component.unitCode,
            sortOrder: previous.sortOrder,
          );
  }
  return grouped.values.toList(growable: false)
    ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
}

String _addRecipeQuantities(String left, String right) {
  final List<String> leftParts = left.split('.');
  final List<String> rightParts = right.split('.');
  final int scale = <int>[
    leftParts.length == 2 ? leftParts[1].length : 0,
    rightParts.length == 2 ? rightParts[1].length : 0,
  ].reduce((a, b) => a > b ? a : b);
  BigInt scaled(String value) {
    final List<String> parts = value.split('.');
    final String decimals = parts.length == 2
        ? parts[1].padRight(scale, '0')
        : '';
    return BigInt.parse(
      '${parts[0]}${decimals.isEmpty ? List<String>.filled(scale, '0').join() : decimals}',
    );
  }

  final BigInt sum = scaled(left) + scaled(right);
  if (scale == 0) return sum.toString();
  final String digits = sum.toString().padLeft(scale + 1, '0');
  final String whole = digits.substring(0, digits.length - scale);
  final String fraction = digits
      .substring(digits.length - scale)
      .replaceFirst(RegExp(r'0+$'), '');
  return fraction.isEmpty ? whole : '$whole.$fraction';
}

class ModifierRecipeProfile {
  const ModifierRecipeProfile({
    required this.optionId,
    required this.scope,
    required this.hasOverride,
    this.inheritedFrom,
    required this.components,
  });
  factory ModifierRecipeProfile.fromJson(Map<String, dynamic> json) =>
      ModifierRecipeProfile(
        optionId: readInt(json['optionId']) ?? 0,
        scope: readString(json['scope']),
        hasOverride: readBool(json['hasOverride']),
        inheritedFrom: readString(json['inheritedFrom']).isEmpty
            ? null
            : readString(json['inheritedFrom']),
        components: readMapList(
          json['components'],
        ).map(RecipeComponent.fromJson).toList(growable: false),
      );
  final int optionId;
  final String scope;
  final bool hasOverride;
  final String? inheritedFrom;
  final List<RecipeComponent> components;
  String get effectiveSource => hasOverride
      ? (scope == 'global'
            ? 'Global'
            : scope[0].toUpperCase() + scope.substring(1))
      : (inheritedFrom == null
            ? 'None'
            : inheritedFrom![0].toUpperCase() + inheritedFrom!.substring(1));
}

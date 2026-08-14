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

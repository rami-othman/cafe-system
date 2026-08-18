import 'dart:ui';

import 'package:windows_application/core/utils/localized_entity_text.dart';

import '../../pos/models/json_helpers.dart';

typedef JsonMap = Map<String, dynamic>;

enum LifecycleStatus { active, inactive, archived }

LifecycleStatus lifecycleStatus({
  required bool isActive,
  required DateTime? archivedAt,
}) => archivedAt != null
    ? LifecycleStatus.archived
    : isActive
    ? LifecycleStatus.active
    : LifecycleStatus.inactive;

int _requiredInt(JsonMap json, String key) {
  final int? value = readInt(json[key]);
  if (value == null) throw FormatException('Catalog response is missing $key.');
  return value;
}

String _requiredString(JsonMap json, String key) {
  final String value = readString(json[key]).trim();
  if (value.isEmpty) throw FormatException('Catalog response is missing $key.');
  return value;
}

JsonMap? _map(dynamic value) =>
    value is Map ? Map<String, dynamic>.from(value) : null;

List<JsonMap> _maps(dynamic value) => readMapList(value);

DateTime? _date(dynamic value) =>
    DateTime.tryParse(readString(value))?.toLocal();

class CatalogPage<T> {
  const CatalogPage({required this.items, required this.meta});

  final List<T> items;
  final CatalogPagination meta;
}

class CatalogPagination {
  const CatalogPagination({
    required this.currentPage,
    required this.lastPage,
    required this.perPage,
    required this.total,
  });

  factory CatalogPagination.fromJson(JsonMap json) => CatalogPagination(
    currentPage: readInt(json['currentPage']) ?? 1,
    lastPage: readInt(json['lastPage']) ?? 1,
    perPage: readInt(json['perPage']) ?? 20,
    total: readInt(json['total']) ?? 0,
  );

  final int currentPage;
  final int lastPage;
  final int perPage;
  final int total;

  bool get hasNextPage => currentPage < lastPage;
}

class CatalogCategory {
  const CatalogCategory({
    required this.id,
    required this.name,
    this.nameAr,
    this.nameEn,
    required this.isActive,
    required this.sortOrder,
  });

  factory CatalogCategory.fromJson(JsonMap json) => CatalogCategory(
    id: _requiredInt(json, 'id'),
    name: _requiredString(json, 'name'),
    nameAr: _optional(json['nameAr']),
    nameEn: _optional(json['nameEn']),
    isActive: readBool(json['isActive'], fallback: true),
    sortOrder: readInt(json['sortOrder']) ?? 0,
  );

  final int id;
  final String name;
  final String? nameAr;
  final String? nameEn;
  final bool isActive;
  final int sortOrder;
  String displayName(Locale locale) => LocalizedEntityText.resolve(
    locale: locale,
    defaultValue: name,
    arabicValue: nameAr,
    englishValue: nameEn,
  );
}

class ReportingCategory {
  const ReportingCategory({
    required this.id,
    required this.name,
    this.nameAr,
    this.nameEn,
    required this.code,
    required this.isActive,
    required this.sortOrder,
  });

  factory ReportingCategory.fromJson(JsonMap json) => ReportingCategory(
    id: _requiredInt(json, 'id'),
    name: _requiredString(json, 'name'),
    nameAr: _optional(json['nameAr']),
    nameEn: _optional(json['nameEn']),
    code: readString(json['code']),
    isActive: readBool(json['isActive'], fallback: true),
    sortOrder: readInt(json['sortOrder']) ?? 0,
  );

  final int id;
  final String name;
  final String? nameAr;
  final String? nameEn;
  final String code;
  final bool isActive;
  final int sortOrder;
  String displayName(Locale locale) => LocalizedEntityText.resolve(
    locale: locale,
    defaultValue: name,
    arabicValue: nameAr,
    englishValue: nameEn,
  );
}

class KitchenStation {
  const KitchenStation({
    required this.id,
    required this.name,
    this.nameAr,
    this.nameEn,
    required this.code,
    required this.branchId,
    required this.branchName,
    required this.isActive,
    required this.sortOrder,
  });

  factory KitchenStation.fromJson(JsonMap json) {
    final JsonMap? branch = _map(json['branch']);
    return KitchenStation(
      id: _requiredInt(json, 'id'),
      name: _requiredString(json, 'name'),
      nameAr: _optional(json['nameAr']),
      nameEn: _optional(json['nameEn']),
      code: readString(json['code']),
      branchId: readInt(json['branchId']),
      branchName: readString(
        json['branchName'],
        fallback: readString(branch?['name']),
      ),
      isActive: readBool(json['isActive'], fallback: true),
      sortOrder: readInt(json['sortOrder']) ?? 0,
    );
  }

  final int id;
  final String name;
  final String? nameAr;
  final String? nameEn;
  final String code;
  final int? branchId;
  final String branchName;
  final bool isActive;
  final int sortOrder;
  String displayName(Locale locale) => LocalizedEntityText.resolve(
    locale: locale,
    defaultValue: name,
    arabicValue: nameAr,
    englishValue: nameEn,
  );
}

class ProductVariant {
  const ProductVariant({
    required this.id,
    this.productId,
    required this.name,
    required this.nameAr,
    required this.nameEn,
    required this.sku,
    required this.barcode,
    required this.basePrice,
    required this.costPrice,
    required this.isDefault,
    required this.isActive,
    required this.sortOrder,
    this.archivedAt,
    this.recipeConfigured,
    this.recipeComponentCount = 0,
  });

  factory ProductVariant.fromJson(JsonMap json) => ProductVariant(
    id: _requiredInt(json, 'id'),
    productId: readInt(json['productId']),
    name: _requiredString(json, 'name'),
    nameAr: _optional(json['nameAr']),
    nameEn: _optional(json['nameEn']),
    sku: _optional(json['sku']),
    barcode: _optional(json['barcode']),
    basePrice: readDouble(json['basePrice']),
    costPrice: json['costPrice'] == null ? null : readDouble(json['costPrice']),
    isDefault: readBool(json['isDefault']),
    isActive: readBool(json['isActive'], fallback: true),
    sortOrder: readInt(json['sortOrder']) ?? 0,
    archivedAt: _date(json['archivedAt']),
    recipeConfigured: json.containsKey('recipeConfigured')
        ? readBool(json['recipeConfigured'])
        : null,
    recipeComponentCount: readInt(json['recipeComponentCount']) ?? 0,
  );

  final int id;
  final int? productId;
  final String name;
  final String? nameAr;
  final String? nameEn;
  final String? sku;
  final String? barcode;
  final double basePrice;
  final double? costPrice;
  final bool isDefault;
  final bool isActive;
  final int sortOrder;
  final DateTime? archivedAt;
  final bool? recipeConfigured;
  final int recipeComponentCount;

  LifecycleStatus get lifecycle =>
      lifecycleStatus(isActive: isActive, archivedAt: archivedAt);
  bool get isArchived => lifecycle == LifecycleStatus.archived;
  bool get isInactive => lifecycle == LifecycleStatus.inactive;
  bool get isActiveLifecycle => lifecycle == LifecycleStatus.active;

  String displayName(Locale locale) => LocalizedEntityText.resolve(
    locale: locale,
    defaultValue: name,
    arabicValue: nameAr,
    englishValue: nameEn,
  );
}

class ModifierOption {
  const ModifierOption({
    required this.id,
    required this.name,
    required this.priceDelta,
    required this.isActive,
    required this.isAvailable,
    this.archivedAt,
  });

  factory ModifierOption.fromJson(JsonMap json) => ModifierOption(
    id: _requiredInt(json, 'id'),
    name: _requiredString(json, 'name'),
    priceDelta: readDouble(json['priceDelta']),
    isActive: readBool(json['isActive'], fallback: true),
    isAvailable: readBool(json['isAvailable'], fallback: true),
    archivedAt: _date(json['archivedAt']),
  );

  final int id;
  final String name;
  final double priceDelta;
  final bool isActive;
  final bool isAvailable;
  final DateTime? archivedAt;
  bool get isArchived => archivedAt != null;
}

class ModifierGroup {
  const ModifierGroup({
    required this.id,
    required this.name,
    required this.groupType,
    required this.selectionType,
    required this.isRequired,
    required this.minSelections,
    required this.maxSelections,
    required this.allowQuantity,
    required this.isRequiredOverride,
    required this.minSelectionsOverride,
    required this.maxSelectionsOverride,
    required this.allowQuantityOverride,
    required this.options,
    this.isActive = true,
    this.archivedAt,
  });

  factory ModifierGroup.fromJson(JsonMap json) => ModifierGroup(
    id: _requiredInt(json, 'id'),
    name: _requiredString(json, 'name'),
    groupType: readString(json['groupType'], fallback: 'choice'),
    selectionType: readString(json['selectionType'], fallback: 'single'),
    isRequired: readBool(json['isRequired']),
    minSelections: readInt(json['minSelections']) ?? 0,
    maxSelections: readInt(json['maxSelections']) ?? 0,
    allowQuantity: readBool(json['allowQuantity']),
    isRequiredOverride: json['isRequiredOverride'] as bool?,
    minSelectionsOverride: readInt(json['minSelectionsOverride']),
    maxSelectionsOverride: readInt(json['maxSelectionsOverride']),
    allowQuantityOverride: json['allowQuantityOverride'] as bool?,
    options: _maps(
      json['options'],
    ).map(ModifierOption.fromJson).toList(growable: false),
    isActive: readBool(json['isActive'], fallback: true),
    archivedAt: _date(json['archivedAt']),
  );

  final int id;
  final String name;
  final String groupType;
  final String selectionType;
  final bool isRequired;
  final int minSelections;
  final int maxSelections;
  final bool allowQuantity;
  final bool? isRequiredOverride;
  final int? minSelectionsOverride;
  final int? maxSelectionsOverride;
  final bool? allowQuantityOverride;
  final List<ModifierOption> options;
  final bool isActive;
  final DateTime? archivedAt;

  bool get effectiveRequired => isRequiredOverride ?? isRequired;
  int get effectiveMinimum => minSelectionsOverride ?? minSelections;
  int get effectiveMaximum => maxSelectionsOverride ?? maxSelections;
  bool get effectiveAllowQuantity => allowQuantityOverride ?? allowQuantity;
  bool get isArchived => archivedAt != null;
}

class ProductSummary {
  const ProductSummary({
    required this.id,
    required this.name,
    required this.nameAr,
    required this.nameEn,
    required this.description,
    required this.imageUrl,
    required this.productType,
    required this.isActive,
    required this.category,
    required this.reportingCategory,
    required this.kitchenStation,
    required this.defaultVariant,
    required this.variantCount,
    required this.modifierGroupCount,
    required this.createdAt,
    required this.updatedAt,
    this.archivedAt,
  });

  factory ProductSummary.fromJson(JsonMap json) => ProductSummary(
    id: _requiredInt(json, 'id'),
    name: _requiredString(json, 'name'),
    nameAr: _optional(json['nameAr']),
    nameEn: _optional(json['nameEn']),
    description: _optional(json['description']),
    imageUrl: _optional(json['imageUrl']),
    productType: readString(json['productType'], fallback: 'standard'),
    isActive: readBool(json['isActive'], fallback: true),
    category: _map(json['category']) == null
        ? null
        : CatalogCategory.fromJson(_map(json['category'])!),
    reportingCategory: _map(json['reportingCategory']) == null
        ? null
        : ReportingCategory.fromJson(_map(json['reportingCategory'])!),
    kitchenStation: _map(json['kitchenStation']) == null
        ? null
        : KitchenStation.fromJson(_map(json['kitchenStation'])!),
    defaultVariant: _map(json['defaultVariant']) == null
        ? null
        : ProductVariant.fromJson(_map(json['defaultVariant'])!),
    variantCount: readInt(json['variantCount']) ?? 0,
    modifierGroupCount: readInt(json['modifierGroupCount']) ?? 0,
    createdAt: _date(json['createdAt']),
    updatedAt: _date(json['updatedAt']),
    archivedAt: _date(json['archivedAt']),
  );

  final int id;
  final String name;
  final String? nameAr;
  final String? nameEn;
  final String? description;
  final String? imageUrl;
  final String productType;
  final bool isActive;
  final CatalogCategory? category;
  final ReportingCategory? reportingCategory;
  final KitchenStation? kitchenStation;
  final ProductVariant? defaultVariant;
  final int variantCount;
  final int modifierGroupCount;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final DateTime? archivedAt;

  bool get isArchived => archivedAt != null;
  bool get isInactive => archivedAt == null && !isActive;
  bool get isActiveLifecycle => archivedAt == null && isActive;

  String displayName(Locale locale) => LocalizedEntityText.resolve(
    locale: locale,
    defaultValue: name,
    arabicValue: nameAr,
    englishValue: nameEn,
  );
}

class ProductDetail extends ProductSummary {
  const ProductDetail({
    required super.id,
    required super.name,
    required super.nameAr,
    required super.nameEn,
    required super.description,
    required super.imageUrl,
    required super.productType,
    required super.isActive,
    required super.category,
    required super.reportingCategory,
    required super.kitchenStation,
    required super.defaultVariant,
    required super.variantCount,
    required super.modifierGroupCount,
    required super.createdAt,
    required super.updatedAt,
    super.archivedAt,
    required this.descriptionAr,
    required this.descriptionEn,
    required this.preparationTimeMinutes,
    required this.isStockTracked,
    required this.sortOrder,
    required this.variants,
    required this.modifierGroups,
  });

  factory ProductDetail.fromJson(JsonMap json) {
    final ProductSummary summary = ProductSummary.fromJson(json);
    final List<ProductVariant> variants = _maps(
      json['variants'],
    ).map(ProductVariant.fromJson).toList(growable: false);
    final List<ModifierGroup> modifierGroups = _maps(
      json['modifierGroups'],
    ).map(ModifierGroup.fromJson).toList(growable: false);
    return ProductDetail(
      id: summary.id,
      name: summary.name,
      nameAr: summary.nameAr,
      nameEn: summary.nameEn,
      description: summary.description,
      imageUrl: summary.imageUrl,
      productType: summary.productType,
      isActive: summary.isActive,
      category: summary.category,
      reportingCategory: summary.reportingCategory,
      kitchenStation: summary.kitchenStation,
      defaultVariant: summary.defaultVariant,
      // Detail responses load the actual collections but do not always include
      // Laravel's `withCount` fields. Respect a supplied count (including 0),
      // otherwise derive the presentation count from that already-loaded data.
      variantCount: json.containsKey('variantCount')
          ? summary.variantCount
          : variants.length,
      modifierGroupCount: json.containsKey('modifierGroupCount')
          ? summary.modifierGroupCount
          : modifierGroups.length,
      createdAt: summary.createdAt,
      updatedAt: summary.updatedAt,
      archivedAt: summary.archivedAt,
      descriptionAr: _optional(json['descriptionAr']),
      descriptionEn: _optional(json['descriptionEn']),
      preparationTimeMinutes: readInt(json['preparationTimeMinutes']),
      isStockTracked: readBool(json['isStockTracked']),
      sortOrder: readInt(json['sortOrder']) ?? 0,
      variants: variants,
      modifierGroups: modifierGroups,
    );
  }

  final String? descriptionAr;
  final String? descriptionEn;
  final int? preparationTimeMinutes;
  final bool isStockTracked;
  final int sortOrder;
  final List<ProductVariant> variants;
  final List<ModifierGroup> modifierGroups;
}

class ProductMenuUsage {
  const ProductMenuUsage({
    required this.productId,
    required this.activePlacementCount,
    required this.menuNames,
  });

  factory ProductMenuUsage.fromJson(JsonMap json) {
    final List<String> names = _maps(json['menus'])
        .map((JsonMap menu) => readString(menu['menuName']).trim())
        .where((String name) => name.isNotEmpty)
        .toSet()
        .take(3)
        .toList(growable: false);
    return ProductMenuUsage(
      productId: _requiredInt(json, 'productId'),
      activePlacementCount: readInt(json['activePlacementCount']) ?? 0,
      menuNames: names,
    );
  }

  final int productId;
  final int activePlacementCount;
  final List<String> menuNames;
}

String? _optional(dynamic value) {
  final String text = readString(value).trim();
  return text.isEmpty ? null : text;
}

import '../../models/catalog_models.dart';
import '../../../pos/models/json_helpers.dart';

typedef PlacementJson = Map<String, dynamic>;

class ProductPlacement {
  const ProductPlacement({
    required this.id,
    required this.sectionId,
    required this.productId,
    required this.sortOrder,
    required this.isFeatured,
    required this.isVisible,
    required this.displayNameOverride,
    required this.displayDescriptionOverride,
    required this.displayImageOverride,
    required this.archivedAt,
    required this.createdAt,
    required this.updatedAt,
    this.product,
  });

  factory ProductPlacement.fromJson(PlacementJson json) => ProductPlacement(
    id:
        readInt(json['id']) ??
        (throw const FormatException('Placement id missing.')),
    sectionId:
        readInt(json['sectionId']) ??
        (throw const FormatException('Placement section missing.')),
    productId:
        readInt(json['productId']) ??
        (throw const FormatException('Placement product missing.')),
    sortOrder: readInt(json['sortOrder']) ?? 0,
    isFeatured: readBool(json['isFeatured']),
    isVisible: readBool(json['isVisible'], fallback: true),
    displayNameOverride: readString(json['displayNameOverride']),
    displayDescriptionOverride: readString(json['displayDescriptionOverride']),
    displayImageOverride: readString(json['displayImageOverride']),
    archivedAt: _date(json['archivedAt']),
    createdAt: _date(json['createdAt']),
    updatedAt: _date(json['updatedAt']),
    product: json['product'] is Map
        ? ProductSummary.fromJson(
            Map<String, dynamic>.from(json['product'] as Map),
          )
        : null,
  );
  final int id, sectionId, productId, sortOrder;
  final bool isFeatured, isVisible;
  final String displayNameOverride,
      displayDescriptionOverride,
      displayImageOverride;
  final DateTime? archivedAt, createdAt, updatedAt;
  final ProductSummary? product;
  bool get isArchived => archivedAt != null;
  String get displayName => displayNameOverride.isNotEmpty
      ? displayNameOverride
      : product?.nameEn?.isNotEmpty == true
      ? product!.nameEn!
      : product?.name ?? 'Product #$productId';
}

class ProductPlacementDraft {
  const ProductPlacementDraft({
    this.productId,
    this.displayNameOverride = '',
    this.displayDescriptionOverride = '',
    this.displayImageOverride = '',
    this.sortOrder,
    this.isFeatured = false,
    this.isVisible = true,
  });
  final int? productId;
  final String displayNameOverride,
      displayDescriptionOverride,
      displayImageOverride;
  final int? sortOrder;
  final bool isFeatured, isVisible;
  Map<String, dynamic> toCreateJson() => <String, dynamic>{
    'productId': productId,
    'displayNameOverride': displayNameOverride.isEmpty
        ? null
        : displayNameOverride,
    'displayDescriptionOverride': displayDescriptionOverride.isEmpty
        ? null
        : displayDescriptionOverride,
    'displayImageOverride': displayImageOverride.isEmpty
        ? null
        : displayImageOverride,
    if (sortOrder != null) 'sortOrder': sortOrder,
    'isFeatured': isFeatured,
    'isVisible': isVisible,
  }..removeWhere((_, value) => value == null);
  Map<String, dynamic> toUpdateJson() => <String, dynamic>{
    'displayNameOverride': displayNameOverride.isEmpty
        ? null
        : displayNameOverride,
    'displayDescriptionOverride': displayDescriptionOverride.isEmpty
        ? null
        : displayDescriptionOverride,
    'displayImageOverride': displayImageOverride.isEmpty
        ? null
        : displayImageOverride,
    if (sortOrder != null) 'sortOrder': sortOrder,
    'isFeatured': isFeatured,
    'isVisible': isVisible,
  };
  factory ProductPlacementDraft.fromPlacement(ProductPlacement p) =>
      ProductPlacementDraft(
        displayNameOverride: p.displayNameOverride,
        displayDescriptionOverride: p.displayDescriptionOverride,
        displayImageOverride: p.displayImageOverride,
        sortOrder: p.sortOrder,
        isFeatured: p.isFeatured,
        isVisible: p.isVisible,
      );
}

class PlacementReorderItem {
  const PlacementReorderItem({required this.id, required this.sortOrder});
  final int id, sortOrder;
  Map<String, dynamic> toJson() => {'id': id, 'sortOrder': sortOrder};
}

DateTime? _date(dynamic value) =>
    DateTime.tryParse(readString(value))?.toLocal();

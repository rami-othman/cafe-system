import 'discount_form_references.dart';

class DiscountProductSelection {
  const DiscountProductSelection({
    required this.productId,
    this.variantMode = 'all',
    this.variantIds = const [],
    this.product,
    this.variants = const [],
  });
  final int productId;
  final String variantMode;
  final List<int> variantIds;
  final DiscountFormReference? product;
  final List<DiscountFormReference> variants;
  bool get isValid =>
      productId > 0 &&
      (variantMode == 'all'
          ? variantIds.isEmpty
          : variantMode == 'selected' &&
                variantIds.isNotEmpty &&
                variantIds.every((id) => id > 0) &&
                variantIds.toSet().length == variantIds.length);
  bool get hasUnavailable =>
      product?.isAvailable == false ||
      variants.any((v) => variantIds.contains(v.id) && !v.isAvailable);
  Map<String, dynamic> toJson() => {
    'productId': productId,
    'variantMode': variantMode,
    'variantIds': variantIds,
  };
  factory DiscountProductSelection.fromJson(Map<String, dynamic> json) =>
      DiscountProductSelection(
        productId: (json['productId'] as num).toInt(),
        variantMode: json['variantMode'] as String,
        variantIds: (json['variantIds'] as List)
            .map((id) => (id as num).toInt())
            .toList(),
        product: json['product'] is Map
            ? DiscountFormReference.fromJson(
                Map<String, dynamic>.from(json['product']),
              )
            : null,
        variants: (json['variants'] as List? ?? [])
            .map(
              (v) =>
                  DiscountFormReference.fromJson(Map<String, dynamic>.from(v)),
            )
            .toList(),
      );
}

class DiscountReferencePage {
  const DiscountReferencePage({
    this.items = const [],
    this.currentPage = 1,
    this.lastPage = 1,
    this.total = 0,
  });
  final List<DiscountFormReference> items;
  final int currentPage;
  final int lastPage;
  final int total;
  factory DiscountReferencePage.fromJson(Map<String, dynamic> json) {
    final meta = Map<String, dynamic>.from(json['meta'] as Map? ?? {});
    return DiscountReferencePage(
      items: (json['data'] as List)
          .map(
            (v) => DiscountFormReference.fromJson(Map<String, dynamic>.from(v)),
          )
          .toList(),
      currentPage: (meta['currentPage'] as num?)?.toInt() ?? 1,
      lastPage: (meta['lastPage'] as num?)?.toInt() ?? 1,
      total: (meta['total'] as num?)?.toInt() ?? 0,
    );
  }
}

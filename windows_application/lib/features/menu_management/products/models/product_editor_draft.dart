class ProductEditorDraft {
  const ProductEditorDraft({
    this.name = '',
    this.nameAr = '',
    this.nameEn = '',
    this.description = '',
    this.descriptionAr = '',
    this.descriptionEn = '',
    this.imageUrl = '',
    this.categoryId,
    this.reportingCategoryId,
    this.kitchenStationId,
    this.productType = 'standard',
    this.preparationTimeMinutes = '',
    this.isStockTracked = false,
    this.sortOrder = '0',
    this.variantName = 'Regular',
    this.variantNameAr = '',
    this.variantNameEn = '',
    this.variantSku = '',
    this.variantBarcode = '',
    this.variantBasePrice = '',
    this.variantCostPrice = '',
  });
  final String name;
  final String nameAr;
  final String nameEn;
  final String description;
  final String descriptionAr;
  final String descriptionEn;
  final String imageUrl;
  final int? categoryId;
  final int? reportingCategoryId;
  final int? kitchenStationId;
  final String productType;
  final String preparationTimeMinutes;
  final bool isStockTracked;
  final String sortOrder;
  final String variantName;
  final String variantNameAr;
  final String variantNameEn;
  final String variantSku;
  final String variantBarcode;
  final String variantBasePrice;
  final String variantCostPrice;
  ProductEditorDraft copyWith({
    String? name,
    String? nameAr,
    String? nameEn,
    String? description,
    String? descriptionAr,
    String? descriptionEn,
    String? imageUrl,
    int? categoryId,
    int? reportingCategoryId,
    int? kitchenStationId,
    String? productType,
    String? preparationTimeMinutes,
    bool? isStockTracked,
    String? sortOrder,
    String? variantName,
    String? variantNameAr,
    String? variantNameEn,
    String? variantSku,
    String? variantBarcode,
    String? variantBasePrice,
    String? variantCostPrice,
    bool clearCategory = false,
    bool clearReportingCategory = false,
    bool clearKitchenStation = false,
  }) => ProductEditorDraft(
    name: name ?? this.name,
    nameAr: nameAr ?? this.nameAr,
    nameEn: nameEn ?? this.nameEn,
    description: description ?? this.description,
    descriptionAr: descriptionAr ?? this.descriptionAr,
    descriptionEn: descriptionEn ?? this.descriptionEn,
    imageUrl: imageUrl ?? this.imageUrl,
    categoryId: clearCategory ? null : categoryId ?? this.categoryId,
    reportingCategoryId: clearReportingCategory
        ? null
        : reportingCategoryId ?? this.reportingCategoryId,
    kitchenStationId: clearKitchenStation
        ? null
        : kitchenStationId ?? this.kitchenStationId,
    productType: productType ?? this.productType,
    preparationTimeMinutes:
        preparationTimeMinutes ?? this.preparationTimeMinutes,
    isStockTracked: isStockTracked ?? this.isStockTracked,
    sortOrder: sortOrder ?? this.sortOrder,
    variantName: variantName ?? this.variantName,
    variantNameAr: variantNameAr ?? this.variantNameAr,
    variantNameEn: variantNameEn ?? this.variantNameEn,
    variantSku: variantSku ?? this.variantSku,
    variantBarcode: variantBarcode ?? this.variantBarcode,
    variantBasePrice: variantBasePrice ?? this.variantBasePrice,
    variantCostPrice: variantCostPrice ?? this.variantCostPrice,
  );
  Map<String, dynamic> toCreateJson() =>
      _generalJson()
        ..['variants'] = <Map<String, dynamic>>[
          <String, dynamic>{
            'name': variantName.trim(),
            'nameAr': _nullable(variantNameAr),
            'nameEn': _nullable(variantNameEn),
            'sku': _nullable(variantSku),
            'barcode': _nullable(variantBarcode),
            'basePrice': double.parse(
              variantBasePrice.trim().isEmpty ? '0' : variantBasePrice,
            ),
            'costPrice': _nullableDouble(variantCostPrice),
            'isDefault': true,
            'isActive': true,
            'sortOrder': 0,
          },
        ];
  Map<String, dynamic> toUpdateJson() => _generalJson();
  Map<String, dynamic> _generalJson() => <String, dynamic>{
    'name': name.trim(),
    'nameAr': _nullable(nameAr),
    'nameEn': _nullable(nameEn),
    'description': _nullable(description),
    'descriptionAr': _nullable(descriptionAr),
    'descriptionEn': _nullable(descriptionEn),
    'imageUrl': _nullable(imageUrl),
    'categoryId': categoryId,
    'reportingCategoryId': reportingCategoryId,
    'kitchenStationId': kitchenStationId,
    'productType': productType,
    'preparationTimeMinutes': _nullableInt(preparationTimeMinutes),
    'isStockTracked': isStockTracked,
    'sortOrder': _nullableInt(sortOrder) ?? 0,
  };
  static String? _nullable(String value) {
    final String text = value.trim();
    return text.isEmpty ? null : text;
  }

  static int? _nullableInt(String value) => int.tryParse(value.trim());
  static double? _nullableDouble(String value) =>
      value.trim().isEmpty ? null : double.tryParse(value.trim());
}

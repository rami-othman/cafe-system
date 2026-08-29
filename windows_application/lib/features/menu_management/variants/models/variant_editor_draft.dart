class VariantEditorDraft {
  const VariantEditorDraft({
    this.name = '',
    this.nameAr = '',
    this.nameEn = '',
    this.sku = '',
    this.barcode = '',
    this.basePrice = '',
    this.costPrice = '',
    this.isActive = true,
    this.sortOrder = '0',
  });

  final String name;
  final String nameAr;
  final String nameEn;
  final String sku;
  final String barcode;
  final String basePrice;
  final String costPrice;
  final bool isActive;
  final String sortOrder;

  VariantEditorDraft copyWith({
    String? name,
    String? nameAr,
    String? nameEn,
    String? sku,
    String? barcode,
    String? basePrice,
    String? costPrice,
    bool? isActive,
    String? sortOrder,
  }) => VariantEditorDraft(
    name: name ?? this.name,
    nameAr: nameAr ?? this.nameAr,
    nameEn: nameEn ?? this.nameEn,
    sku: sku ?? this.sku,
    barcode: barcode ?? this.barcode,
    basePrice: basePrice ?? this.basePrice,
    costPrice: costPrice ?? this.costPrice,
    isActive: isActive ?? this.isActive,
    sortOrder: sortOrder ?? this.sortOrder,
  );

  Map<String, dynamic> toCreateJson({required bool makeDefault}) =>
      <String, dynamic>{..._body(), if (makeDefault) 'isDefault': true};
  Map<String, dynamic> toUpdateJson() => _body();
  Map<String, dynamic> _body() => <String, dynamic>{
    'name': name.trim(),
    'nameAr': _nullable(nameAr),
    'nameEn': _nullable(nameEn),
    'sku': _nullable(sku),
    'barcode': _nullable(barcode),
    'basePrice': double.parse(basePrice.trim()),
    'costPrice': costPrice.trim().isEmpty
        ? null
        : double.parse(costPrice.trim()),
    'isActive': isActive,
    'sortOrder': int.parse(sortOrder.trim()),
  };
  String? _nullable(String value) => value.trim().isEmpty ? null : value.trim();
}

class VariantReorderItem {
  const VariantReorderItem({required this.id, required this.sortOrder});
  final int id;
  final int sortOrder;
  Map<String, dynamic> toJson() => <String, dynamic>{
    'id': id,
    'sortOrder': sortOrder,
  };
}

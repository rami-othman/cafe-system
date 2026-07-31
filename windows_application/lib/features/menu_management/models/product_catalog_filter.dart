class ProductCatalogFilter {
  const ProductCatalogFilter({
    this.search = '',
    this.categoryId,
    this.reportingCategoryId,
    this.kitchenStationId,
    this.productType,
    this.status = 'active',
    this.hasVariants,
    this.hasModifierGroups,
    this.sort = 'sort_order',
    this.direction = 'asc',
  });

  final String search;
  final int? categoryId;
  final int? reportingCategoryId;
  final int? kitchenStationId;
  final String? productType;
  final String status;
  final bool? hasVariants;
  final bool? hasModifierGroups;
  final String sort;
  final String direction;

  bool get hasActiveFilters =>
      search.isNotEmpty ||
      categoryId != null ||
      reportingCategoryId != null ||
      kitchenStationId != null ||
      productType != null ||
      status != 'active' ||
      hasVariants != null ||
      hasModifierGroups != null ||
      sort != 'sort_order' ||
      direction != 'asc';

  ProductCatalogFilter copyWith({
    String? search,
    int? categoryId,
    int? reportingCategoryId,
    int? kitchenStationId,
    String? productType,
    String? status,
    bool? hasVariants,
    bool? hasModifierGroups,
    String? sort,
    String? direction,
    bool clearCategory = false,
    bool clearReportingCategory = false,
    bool clearKitchenStation = false,
    bool clearProductType = false,
    bool clearHasVariants = false,
    bool clearHasModifierGroups = false,
  }) => ProductCatalogFilter(
    search: search ?? this.search,
    categoryId: clearCategory ? null : categoryId ?? this.categoryId,
    reportingCategoryId: clearReportingCategory
        ? null
        : reportingCategoryId ?? this.reportingCategoryId,
    kitchenStationId: clearKitchenStation
        ? null
        : kitchenStationId ?? this.kitchenStationId,
    productType: clearProductType ? null : productType ?? this.productType,
    status: status ?? this.status,
    hasVariants: clearHasVariants ? null : hasVariants ?? this.hasVariants,
    hasModifierGroups: clearHasModifierGroups
        ? null
        : hasModifierGroups ?? this.hasModifierGroups,
    sort: sort ?? this.sort,
    direction: direction ?? this.direction,
  );
}

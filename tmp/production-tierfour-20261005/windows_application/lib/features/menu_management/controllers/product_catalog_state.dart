import 'package:equatable/equatable.dart';

import '../models/catalog_models.dart';
import '../models/product_catalog_filter.dart';

enum ProductCatalogLoadStatus {
  initial,
  loading,
  loaded,
  refreshing,
  loadingNextPage,
  failure,
}

class ProductCatalogState extends Equatable {
  const ProductCatalogState({
    this.status = ProductCatalogLoadStatus.initial,
    this.products = const <ProductSummary>[],
    this.pagination = const CatalogPagination(
      currentPage: 1,
      lastPage: 1,
      perPage: 20,
      total: 0,
    ),
    this.filter = const ProductCatalogFilter(),
    this.categories = const <CatalogCategory>[],
    this.reportingCategories = const <ReportingCategory>[],
    this.kitchenStations = const <KitchenStation>[],
    this.errorMessage,
    this.referenceErrors = const <String, String>{},
  });

  final ProductCatalogLoadStatus status;
  final List<ProductSummary> products;
  final CatalogPagination pagination;
  final ProductCatalogFilter filter;
  final List<CatalogCategory> categories;
  final List<ReportingCategory> reportingCategories;
  final List<KitchenStation> kitchenStations;
  final String? errorMessage;
  final Map<String, String> referenceErrors;

  bool get hasMorePages => pagination.hasNextPage;
  bool get isLoading => status == ProductCatalogLoadStatus.loading;
  bool get isRefreshing => status == ProductCatalogLoadStatus.refreshing;
  bool get isLoadingNextPage =>
      status == ProductCatalogLoadStatus.loadingNextPage;

  ProductCatalogState copyWith({
    ProductCatalogLoadStatus? status,
    List<ProductSummary>? products,
    CatalogPagination? pagination,
    ProductCatalogFilter? filter,
    List<CatalogCategory>? categories,
    List<ReportingCategory>? reportingCategories,
    List<KitchenStation>? kitchenStations,
    String? errorMessage,
    bool clearError = false,
    Map<String, String>? referenceErrors,
  }) => ProductCatalogState(
    status: status ?? this.status,
    products: products ?? this.products,
    pagination: pagination ?? this.pagination,
    filter: filter ?? this.filter,
    categories: categories ?? this.categories,
    reportingCategories: reportingCategories ?? this.reportingCategories,
    kitchenStations: kitchenStations ?? this.kitchenStations,
    errorMessage: clearError ? null : errorMessage ?? this.errorMessage,
    referenceErrors: referenceErrors ?? this.referenceErrors,
  );

  @override
  List<Object?> get props => <Object?>[
    status,
    products,
    pagination,
    filter,
    categories,
    reportingCategories,
    kitchenStations,
    errorMessage,
    referenceErrors,
  ];
}

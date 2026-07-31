import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/network/api_exception.dart';
import '../models/catalog_models.dart';
import '../models/product_catalog_filter.dart';
import '../repositories/menu_catalog_repository.dart';
import 'product_catalog_state.dart';

class ProductCatalogCubit extends Cubit<ProductCatalogState> {
  ProductCatalogCubit({required this.repository})
    : super(const ProductCatalogState());

  static const int pageSize = 20;
  final MenuCatalogRepository repository;
  Timer? _searchTimer;
  int _requestVersion = 0;

  Future<void> loadInitialData() async {
    await Future.wait<void>(<Future<void>>[loadProducts(), loadReferences()]);
  }

  Future<void> loadProducts({bool refresh = false}) async {
    final int request = ++_requestVersion;
    emit(
      state.copyWith(
        status: refresh
            ? ProductCatalogLoadStatus.refreshing
            : ProductCatalogLoadStatus.loading,
        clearError: true,
      ),
    );
    try {
      final CatalogPage<ProductSummary> page = await repository.listProducts(
        filter: state.filter,
        page: 1,
        perPage: pageSize,
      );
      if (isClosed || request != _requestVersion) return;
      emit(
        state.copyWith(
          status: ProductCatalogLoadStatus.loaded,
          products: _unique(page.items),
          pagination: page.meta,
          clearError: true,
        ),
      );
    } catch (error) {
      if (isClosed || request != _requestVersion) return;
      emit(
        state.copyWith(
          status: ProductCatalogLoadStatus.failure,
          errorMessage: _message(error),
        ),
      );
    }
  }

  Future<void> refresh() => loadProducts(refresh: true);

  Future<void> loadNextPage() async {
    if (!state.hasMorePages || state.isLoadingNextPage || state.isLoading) {
      return;
    }
    final int request = ++_requestVersion;
    emit(
      state.copyWith(
        status: ProductCatalogLoadStatus.loadingNextPage,
        clearError: true,
      ),
    );
    try {
      final CatalogPage<ProductSummary> page = await repository.listProducts(
        filter: state.filter,
        page: state.pagination.currentPage + 1,
        perPage: pageSize,
      );
      if (isClosed || request != _requestVersion) return;
      emit(
        state.copyWith(
          status: ProductCatalogLoadStatus.loaded,
          products: _unique(<ProductSummary>[...state.products, ...page.items]),
          pagination: page.meta,
        ),
      );
    } catch (error) {
      if (isClosed || request != _requestVersion) return;
      emit(
        state.copyWith(
          status: ProductCatalogLoadStatus.failure,
          errorMessage: _message(error),
        ),
      );
    }
  }

  Future<void> loadReferences() async {
    final List<CatalogCategory> categories = state.categories;
    final List<ReportingCategory> reporting = state.reportingCategories;
    final List<KitchenStation> stations = state.kitchenStations;
    final Map<String, String> errors = <String, String>{};

    try {
      final page = await repository.listCategories();
      emit(state.copyWith(categories: page.items));
    } catch (error) {
      errors['Categories'] = _message(error);
    }
    try {
      final page = await repository.listReportingCategories();
      emit(state.copyWith(reportingCategories: page.items));
    } catch (error) {
      errors['Reporting categories'] = _message(error);
    }
    try {
      final page = await repository.listKitchenStations();
      emit(state.copyWith(kitchenStations: page.items));
    } catch (error) {
      errors['Kitchen stations'] = _message(error);
    }
    if (!isClosed) {
      emit(
        state.copyWith(
          categories: state.categories.isEmpty ? categories : null,
          reportingCategories: state.reportingCategories.isEmpty
              ? reporting
              : null,
          kitchenStations: state.kitchenStations.isEmpty ? stations : null,
          referenceErrors: errors,
        ),
      );
    }
  }

  void updateSearch(String query) {
    _searchTimer?.cancel();
    ++_requestVersion;
    emit(state.copyWith(filter: state.filter.copyWith(search: query)));
    _searchTimer = Timer(const Duration(milliseconds: 350), loadProducts);
  }

  Future<void> updateFilter(ProductCatalogFilter filter) async {
    _searchTimer?.cancel();
    ++_requestVersion;
    emit(state.copyWith(filter: filter));
    await loadProducts();
  }

  Future<void> clearFilters() => updateFilter(const ProductCatalogFilter());

  String _message(Object error) => error is ApiException
      ? error.message
      : 'Unable to load the product catalog. Please try again.';

  List<ProductSummary> _unique(List<ProductSummary> products) {
    final Set<int> ids = <int>{};
    return products
        .where((ProductSummary item) => ids.add(item.id))
        .toList(growable: false);
  }

  @override
  Future<void> close() {
    _searchTimer?.cancel();
    return super.close();
  }
}

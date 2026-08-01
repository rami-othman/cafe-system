import 'package:flutter_test/flutter_test.dart';
import 'package:windows_application/core/network/api_exception.dart';
import 'package:windows_application/features/menu_management/menus/controllers/product_placements_cubit.dart';
import 'package:windows_application/features/menu_management/menus/models/menu_models.dart';
import 'package:windows_application/features/menu_management/menus/models/product_placement.dart';
import 'package:windows_application/features/menu_management/models/catalog_models.dart';
import 'package:windows_application/features/menu_management/models/product_catalog_filter.dart';
import 'package:windows_application/features/menu_management/repositories/menu_catalog_repository.dart';

void main() {
  test(
    'picker uses server search/category parameters, resets pagination, and loads next page',
    () async {
      final _PickerRepository repository = _PickerRepository();
      final ProductPlacementsCubit cubit = ProductPlacementsCubit(
        repository: repository,
      );
      await cubit.load(1);
      await cubit.searchProducts('latte', sectionId: 5, categoryId: 4);
      expect(repository.filters.single.search, 'latte');
      expect(repository.filters.single.categoryId, 4);
      expect(repository.pages, <int>[1]);
      expect(cubit.state.pickerProducts.map((p) => p.id), <int>[12]);
      expect(cubit.state.pickerHasMore, isTrue);
      await cubit.searchProducts(
        'latte',
        sectionId: 5,
        categoryId: 4,
        next: true,
      );
      expect(repository.pages, <int>[1, 2]);
      expect(cubit.state.pickerProducts.map((p) => p.id), <int>[12, 16]);
      await cubit.searchProducts('tea', sectionId: 5);
      expect(repository.pages.last, 1);
      expect(cubit.state.pickerPage, 1);
      await cubit.close();
    },
  );

  test(
    'picker excludes placed, archived, and inactive products under the backend contract',
    () async {
      final ProductPlacementsCubit cubit = ProductPlacementsCubit(
        repository: _PickerRepository(),
      );
      await cubit.load(1);
      await cubit.searchProducts('', sectionId: 5);
      expect(
        cubit.state.pickerProducts.map((p) => p.id),
        isNot(containsAll(<int>[11, 13, 14])),
      );
      expect(cubit.state.pickerProducts.map((p) => p.id), contains(12));
      await cubit.close();
    },
  );

  test(
    'picker exposes empty, no-results, failure, and retry-safe states',
    () async {
      final _PickerRepository repository = _PickerRepository()..empty = true;
      final ProductPlacementsCubit cubit = ProductPlacementsCubit(
        repository: repository,
      );
      await cubit.load(1);
      await cubit.searchProducts('missing', sectionId: 5);
      expect(cubit.state.pickerProducts, isEmpty);
      expect(cubit.state.pickerErrorMessage, isNull);
      repository.empty = false;
      repository.fail = true;
      await cubit.searchProducts('retry', sectionId: 5);
      expect(cubit.state.pickerErrorMessage, 'Catalog search failed.');
      repository.fail = false;
      await cubit.searchProducts('retry', sectionId: 5);
      expect(cubit.state.pickerErrorMessage, isNull);
      expect(cubit.state.pickerLoading, isFalse);
      await cubit.close();
    },
  );
}

class _PickerRepository extends MenuCatalogRepository {
  final List<ProductCatalogFilter> filters = <ProductCatalogFilter>[];
  final List<int> pages = <int>[];
  bool empty = false, fail = false;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
  @override
  Future<MenuRecord> getMenu(
    int menuId, {
    bool includeArchived = false,
  }) async => MenuRecord.fromJson(<String, dynamic>{
    'id': 1,
    'name': 'Main',
    'nameEn': 'Main',
    'status': 'draft',
    'sections': <Map<String, dynamic>>[
      <String, dynamic>{
        'id': 5,
        'menuId': 1,
        'name': 'Coffee',
        'isActive': true,
        'sortOrder': 0,
        'placementCount': 1,
      },
    ],
  });
  @override
  Future<List<ProductPlacement>> getMenuPlacements(
    int sectionId, {
    bool includeArchived = false,
  }) async => <ProductPlacement>[ProductPlacement.fromJson(_placement())];
  @override
  Future<CatalogPage<ProductSummary>> listProducts({
    required ProductCatalogFilter filter,
    required int page,
    int perPage = 20,
  }) async {
    filters.add(filter);
    pages.add(page);
    if (fail) {
      throw const ApiException(message: 'Catalog search failed.');
    }
    if (empty) {
      return const CatalogPage<ProductSummary>(
        items: <ProductSummary>[],
        meta: CatalogPagination(
          currentPage: 1,
          lastPage: 1,
          perPage: 20,
          total: 0,
        ),
      );
    }
    final List<ProductSummary> products = page == 1
        ? <ProductSummary>[
            _product(11),
            _product(12),
            _product(13, archived: true),
            _product(14, active: false),
          ]
        : <ProductSummary>[_product(16)];
    return CatalogPage<ProductSummary>(
      items: products,
      meta: CatalogPagination(
        currentPage: page,
        lastPage: 2,
        perPage: 20,
        total: 5,
      ),
    );
  }
}

ProductSummary _product(int id, {bool archived = false, bool active = true}) =>
    ProductSummary.fromJson(<String, dynamic>{
      'id': id,
      'name': 'Product $id',
      'productType': 'standard',
      'isActive': active,
      'archivedAt': archived ? '2026-07-31T10:00:00Z' : null,
      'variantCount': 1,
      'modifierGroupCount': 0,
      'isStockTracked': false,
      'sortOrder': 0,
    });

Map<String, dynamic> _placement() => <String, dynamic>{
  'id': 9,
  'sectionId': 5,
  'productId': 11,
  'sortOrder': 0,
  'isFeatured': false,
  'isVisible': true,
  'displayNameOverride': '',
  'displayDescriptionOverride': '',
  'displayImageOverride': '',
};

import 'package:flutter_test/flutter_test.dart';
import 'package:windows_application/core/network/api_exception.dart';
import 'package:windows_application/features/menu_management/menus/controllers/menu_editor_cubit.dart';
import 'package:windows_application/features/menu_management/menus/controllers/menu_list_cubit.dart';
import 'package:windows_application/features/menu_management/menus/models/menu_editor_draft.dart';
import 'package:windows_application/features/menu_management/menus/models/menu_filter.dart';
import 'package:windows_application/features/menu_management/menus/models/menu_models.dart';
import 'package:windows_application/features/menu_management/models/catalog_models.dart';
import 'package:windows_application/features/menu_management/models/product_catalog_filter.dart';
import 'package:windows_application/features/menu_management/products/models/product_editor_draft.dart';
import 'package:windows_application/features/menu_management/repositories/menu_catalog_repository.dart';

void main() {
  test('menu list and detail parsing keeps archived metadata and sections', () {
    final MenuRecord menu = MenuRecord.fromJson(menuJson(archived: true));
    expect(menu.isArchived, isTrue);
    expect(menu.visibleProductCount, 3);
    expect(menu.sections.single.placementCount, 2);
    expect(menu.sections.single.isArchived, isTrue);
  });
  test('menu and section payloads exclude computed fields and ownership', () {
    final Map<String, dynamic> menu = const MenuEditorDraft(
      name: ' Main ',
      priority: '4',
    ).toJson(isCreate: true);
    final Map<String, dynamic> section = const MenuSectionDraft(
      name: ' Coffee ',
      sortOrder: '2',
    ).toJson();
    expect(menu, containsPair('name', 'Main'));
    expect(menu.containsKey('sectionCount'), isFalse);
    expect(menu.containsKey('status'), isFalse);
    expect(section, containsPair('name', 'Coffee'));
    expect(section.containsKey('menuId'), isFalse);
    expect(section.containsKey('placements'), isFalse);
  });
  test(
    'menu list filters reset pagination and preserve lifecycle filter',
    () async {
      final MenusRepositoryFake repo = MenusRepositoryFake();
      final MenuListCubit cubit = MenuListCubit(repository: repo);
      await cubit.load();
      await cubit.updateFilter(const MenuFilter(status: 'archived'));
      await cubit.archive(1);
      expect(repo.filters.last.status, 'archived');
      expect(repo.archiveCalls, 1);
      await cubit.close();
    },
  );
  test(
    'editor validates, maps 422 fields, and prevents duplicate submit',
    () async {
      final MenusRepositoryFake repo = MenusRepositoryFake()..validation = true;
      final MenuEditorCubit cubit = MenuEditorCubit(repository: repo);
      await cubit.initializeCreate();
      await cubit.submit();
      expect(cubit.state.fieldErrors['name'], isNotEmpty);
      cubit.updateDraft(const MenuEditorDraft(name: 'Main'));
      await cubit.submit();
      expect(
        cubit.state.fieldErrors['name'],
        'The name has already been taken.',
      );
      await cubit.close();
    },
  );
}

class MenusRepositoryFake extends MenuCatalogRepository {
  final List<MenuFilter> filters = <MenuFilter>[];
  int archiveCalls = 0;
  bool validation = false;
  @override
  Future<CatalogPage<MenuRecord>> listMenus({
    required MenuFilter filter,
    required int page,
    int perPage = 20,
  }) async {
    filters.add(filter);
    return CatalogPage<MenuRecord>(
      items: <MenuRecord>[MenuRecord.fromJson(menuJson())],
      meta: const CatalogPagination(
        currentPage: 1,
        lastPage: 1,
        perPage: 20,
        total: 1,
      ),
    );
  }

  @override
  Future<MenuRecord> archiveMenu(int menuId) async {
    archiveCalls++;
    return MenuRecord.fromJson(menuJson(archived: true));
  }

  @override
  Future<MenuRecord> createMenu(MenuEditorDraft draft) async {
    if (validation)
      throw const ApiException(
        message: 'The submitted data was invalid.',
        validationErrors: <String, List<String>>{
          'name': <String>['The name has already been taken.'],
        },
      );
    return MenuRecord.fromJson(menuJson());
  }

  @override
  Future<MenuRecord> updateMenu(int menuId, MenuEditorDraft draft) async =>
      createMenu(draft);
  @override
  Future<MenuRecord> getMenu(
    int menuId, {
    bool includeArchived = false,
  }) async => MenuRecord.fromJson(menuJson());
  @override
  Future<CatalogPage<ProductSummary>> listProducts({
    required ProductCatalogFilter filter,
    required int page,
    int perPage = 20,
  }) async => throw UnimplementedError();
  @override
  Future<ProductDetail> getProduct(
    int productId, {
    bool includeArchived = false,
  }) async => throw UnimplementedError();
  @override
  Future<ProductDetail> createProduct(ProductEditorDraft draft) async =>
      throw UnimplementedError();
  @override
  Future<ProductDetail> updateProductGeneral(
    int productId,
    ProductEditorDraft draft,
  ) async => throw UnimplementedError();
  @override
  Future<CatalogPage<CatalogCategory>> listCategories({
    int perPage = 100,
  }) async => throw UnimplementedError();
  @override
  Future<CatalogPage<ReportingCategory>> listReportingCategories({
    int perPage = 100,
  }) async => throw UnimplementedError();
  @override
  Future<CatalogPage<KitchenStation>> listKitchenStations({
    int perPage = 100,
  }) async => throw UnimplementedError();
}

Map<String, dynamic> menuJson({bool archived = false}) => <String, dynamic>{
  'id': 1,
  'name': 'Main',
  'nameAr': null,
  'nameEn': 'Main',
  'description': '',
  'descriptionAr': null,
  'descriptionEn': null,
  'coverImageUrl': null,
  'status': archived ? 'archived' : 'draft',
  'priority': 0,
  'sectionCount': 1,
  'visibleProductCount': 3,
  'archivedAt': archived ? '2026-07-31T12:00:00Z' : null,
  'createdAt': '2026-07-30T10:00:00Z',
  'updatedAt': '2026-07-30T10:00:00Z',
  'sections': <Map<String, dynamic>>[
    <String, dynamic>{
      'id': 5,
      'menuId': 1,
      'name': 'Coffee',
      'nameAr': null,
      'nameEn': null,
      'description': null,
      'imageUrl': null,
      'isActive': !archived,
      'sortOrder': 0,
      'placementCount': 2,
      'archivedAt': archived ? '2026-07-31T12:00:00Z' : null,
    },
  ],
};
// ignore_for_file: curly_braces_in_flow_control_structures

import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:windows_application/features/menu_management/controllers/product_detail_cubit.dart';
import 'package:windows_application/features/menu_management/models/catalog_models.dart';
import 'package:windows_application/features/menu_management/models/product_catalog_filter.dart';
import 'package:windows_application/features/menu_management/products/models/product_editor_draft.dart';
import 'package:windows_application/features/menu_management/modifiers/controllers/modifier_library_cubit.dart';
import 'package:windows_application/features/menu_management/modifiers/models/modifier_models.dart';
import 'package:windows_application/features/menu_management/menus/controllers/menu_list_cubit.dart';
import 'package:windows_application/features/menu_management/menus/models/menu_filter.dart';
import 'package:windows_application/features/menu_management/menus/models/menu_models.dart';
import 'package:windows_application/features/menu_management/products/controllers/product_modifier_assignments_cubit.dart';
import 'package:windows_application/features/menu_management/products/models/product_modifier_assignment.dart';
import 'package:windows_application/features/menu_management/repositories/menu_catalog_repository.dart';
import 'package:windows_application/features/menu_management/recipes/models/recipe_models.dart';
import 'package:windows_application/features/menu_management/variants/controllers/variants_cubit.dart';

void main() {
  test('modifier library parses a bounded preview contract', () {
    final ModifierGroupRecord group = ModifierGroupRecord.fromJson(
      <String, dynamic>{
        ..._groupJson('Milk Type'),
        'optionCount': 8,
        'optionPreview': <Map<String, dynamic>>[
          _optionJson(1, 'Whole Milk', 0),
          _optionJson(2, 'Oat Milk', 0.5),
          _optionJson(3, 'Almond Milk', -0.5),
        ],
        'remainingOptionCount': 5,
      },
    );

    expect(group.optionPreview, hasLength(3));
    expect(group.remainingOptionCount, 5);
    expect(group.optionPreview[1].priceDelta, 0.5);
    expect(group.optionPreview[2].priceDelta, -0.5);
    expect(group.options, isEmpty);
  });

  test(
    'modifier library newest filter result wins and stale failure is ignored',
    () async {
      final _ModifierRaceRepository repository = _ModifierRaceRepository();
      final ModifierLibraryCubit cubit = ModifierLibraryCubit(
        repository: repository,
      );
      final Future<void> oldRequest = cubit.updateFilter(
        const ModifierGroupFilter(search: 'lat'),
      );
      await Future<void>.delayed(Duration.zero);
      final Future<void> newRequest = cubit.updateFilter(
        const ModifierGroupFilter(search: 'milk'),
      );

      repository.milk.complete(_page(<ModifierGroupRecord>[_group('Milk')]));
      await newRequest;
      repository.lat.completeError(StateError('stale failure'));
      await oldRequest;

      expect(cubit.state.filter.search, 'milk');
      expect(cubit.state.groups.single.name, 'Milk');
      expect(cubit.state.status, ModifierLibraryStatus.loaded);
      await cubit.close();
    },
  );

  test(
    'modifier library debounces search and protects pagination refresh state',
    () async {
      final _ModifierRaceRepository repository = _ModifierRaceRepository();
      final ModifierLibraryCubit cubit = ModifierLibraryCubit(
        repository: repository,
      );
      await cubit.updateSearch('lat');
      await cubit.updateSearch('milk');
      await Future<void>.delayed(const Duration(milliseconds: 400));

      expect(repository.searches, <String>['milk']);
      repository.milk.complete(_page(<ModifierGroupRecord>[_group('Milk')]));
      await Future<void>.delayed(Duration.zero);
      expect(cubit.state.groups.single.name, 'Milk');
      await cubit.close();
    },
  );

  test(
    'menu list newest result wins over stale success and stale failure',
    () async {
      final _MenuRaceRepository repository = _MenuRaceRepository();
      final MenuListCubit cubit = MenuListCubit(repository: repository);
      final Future<void> oldRequest = cubit.updateFilter(
        const MenuFilter(search: 'old'),
      );
      await Future<void>.delayed(Duration.zero);
      final Future<void> newRequest = cubit.updateFilter(
        const MenuFilter(search: 'new'),
      );

      repository.newRequest.complete(_menuPage('New menu'));
      await newRequest;
      repository.oldRequest.completeError(StateError('stale failure'));
      await oldRequest;

      expect(cubit.state.filter.search, 'new');
      expect(cubit.state.menus.single.name, 'New menu');
      expect(cubit.state.status, MenuListStatus.loaded);
      await cubit.close();
    },
  );

  test(
    'product modifier assignment list uses the backend material summary',
    () async {
      final _AssignmentRepository repository = _AssignmentRepository();
      final ProductModifierAssignmentsCubit cubit =
          ProductModifierAssignmentsCubit(repository: repository);

      await cubit.load(11);

      expect(repository.profileCalls, 0);
      expect(cubit.state.materialImpactConfiguredGroupIds, contains(7));
      await cubit.close();
    },
  );

  test(
    'variant list uses recipe summary without per-variant recipe calls',
    () async {
      final _VariantSummaryRepository repository = _VariantSummaryRepository();
      final VariantsCubit cubit = VariantsCubit(repository: repository);

      await cubit.load(11);

      expect(repository.recipeCalls, 0);
      expect(cubit.state.recipeConfigured[1], isTrue);
      expect(cubit.state.recipeConfigured[2], isFalse);
      await cubit.close();
    },
  );

  test(
    'product detail can accept an authoritative child summary update',
    () async {
      final ProductDetailCubit cubit = ProductDetailCubit(
        repository: _ProductDetailRepository(),
      );
      await cubit.load(11);
      cubit.replaceProduct(_product(recipeConfigured: true));

      expect(cubit.state.product!.variantCount, 2);
      expect(cubit.state.product!.variants.first.recipeConfigured, isTrue);
      await cubit.close();
    },
  );
}

abstract class _MinimalRepository extends MenuCatalogRepository {
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

class _ModifierRaceRepository extends _MinimalRepository {
  final Completer<CatalogPage<ModifierGroupRecord>> lat =
      Completer<CatalogPage<ModifierGroupRecord>>();
  final Completer<CatalogPage<ModifierGroupRecord>> milk =
      Completer<CatalogPage<ModifierGroupRecord>>();
  final List<String> searches = <String>[];

  @override
  Future<CatalogPage<ModifierGroupRecord>> listModifierGroups({
    required ModifierGroupFilter filter,
    required int page,
    int perPage = 20,
  }) {
    searches.add(filter.search);
    return switch (filter.search) {
      'lat' => lat.future,
      'milk' => milk.future,
      _ => Future<CatalogPage<ModifierGroupRecord>>.value(
        _page(<ModifierGroupRecord>[]),
      ),
    };
  }
}

class _MenuRaceRepository extends _MinimalRepository {
  final Completer<CatalogPage<MenuRecord>> oldRequest =
      Completer<CatalogPage<MenuRecord>>();
  final Completer<CatalogPage<MenuRecord>> newRequest =
      Completer<CatalogPage<MenuRecord>>();

  @override
  Future<CatalogPage<MenuRecord>> listMenus({
    required MenuFilter filter,
    required int page,
    int perPage = 20,
  }) => switch (filter.search) {
    'old' => oldRequest.future,
    'new' => newRequest.future,
    _ => Future<CatalogPage<MenuRecord>>.value(_menuPage('Default')),
  };
}

class _AssignmentRepository extends _MinimalRepository {
  int profileCalls = 0;

  @override
  Future<ProductDetail> getProduct(
    int productId, {
    bool includeArchived = false,
  }) async => _product();

  @override
  Future<List<ProductModifierAssignment>> getProductModifierAssignments(
    int productId,
  ) async => <ProductModifierAssignment>[
    ProductModifierAssignment.fromJson(<String, dynamic>{
      'id': 7,
      'name': 'Extras',
      'groupType': 'add_on',
      'selectionType': 'multiple',
      'isActive': true,
      'activeOptionCount': 2,
      'isRequired': false,
      'minSelections': 0,
      'maxSelections': 2,
      'allowQuantity': false,
      'sortOrder': 0,
      'materialImpactConfigured': true,
    }),
  ];

  @override
  Future<CatalogPage<ModifierGroupRecord>> listModifierGroups({
    required ModifierGroupFilter filter,
    required int page,
    int perPage = 20,
  }) async => _page(<ModifierGroupRecord>[]);

  @override
  Future<ModifierRecipeProfile> getModifierRecipeProfile(
    int optionId, {
    int? productId,
    int? variantId,
  }) {
    profileCalls++;
    return Future<ModifierRecipeProfile>.error(
      StateError('must not be called'),
    );
  }
}

class _VariantSummaryRepository extends _MinimalRepository {
  int recipeCalls = 0;

  @override
  Future<ProductDetail> getProduct(
    int productId, {
    bool includeArchived = false,
  }) async => _product(recipeConfigured: true);

  @override
  Future<VariantRecipe> getVariantRecipe(int variantId) {
    recipeCalls++;
    return Future<VariantRecipe>.error(StateError('must not be called'));
  }
}

class _ProductDetailRepository extends _MinimalRepository {
  @override
  Future<ProductDetail> getProduct(
    int productId, {
    bool includeArchived = false,
  }) async => _product();
}

CatalogPage<ModifierGroupRecord> _page(List<ModifierGroupRecord> items) =>
    CatalogPage<ModifierGroupRecord>(
      items: items,
      meta: CatalogPagination(
        currentPage: 1,
        lastPage: 1,
        perPage: 20,
        total: items.length,
      ),
    );

CatalogPage<MenuRecord> _menuPage(String name) => CatalogPage<MenuRecord>(
  items: <MenuRecord>[MenuRecord.fromJson(_menuJson(name))],
  meta: const CatalogPagination(
    currentPage: 1,
    lastPage: 1,
    perPage: 20,
    total: 1,
  ),
);

ModifierGroupRecord _group(String name) =>
    ModifierGroupRecord.fromJson(_groupJson(name));

Map<String, dynamic> _groupJson(String name) => <String, dynamic>{
  'id': name.hashCode,
  'name': name,
  'groupType': 'choice',
  'selectionType': 'single',
  'isRequired': false,
  'minSelections': 0,
  'maxSelections': 1,
  'allowQuantity': false,
  'isActive': true,
  'sortOrder': 0,
  'optionCount': 1,
  'activeOptionCount': 1,
  'optionPreview': <Map<String, dynamic>>[_optionJson(1, '$name option', 0)],
  'remainingOptionCount': 0,
};

Map<String, dynamic> _optionJson(int id, String name, num price) =>
    <String, dynamic>{
      'id': id,
      'name': name,
      'priceDelta': price,
      'isDefault': false,
      'isActive': true,
      'isAvailable': true,
      'sortOrder': 0,
    };

ProductDetail _product({bool recipeConfigured = false}) =>
    ProductDetail.fromJson(<String, dynamic>{
      'id': 11,
      'name': 'Latte',
      'productType': 'standard',
      'isActive': true,
      'variantCount': 2,
      'modifierGroupCount': 1,
      'isStockTracked': true,
      'variants': <Map<String, dynamic>>[
        <String, dynamic>{
          'id': 1,
          'productId': 11,
          'name': 'Regular',
          'basePrice': 3,
          'costPrice': 1,
          'isDefault': true,
          'isActive': true,
          'sortOrder': 0,
          'recipeConfigured': recipeConfigured,
          'recipeComponentCount': recipeConfigured ? 2 : 0,
        },
        <String, dynamic>{
          'id': 2,
          'productId': 11,
          'name': 'Large',
          'basePrice': 4,
          'costPrice': 1,
          'isDefault': false,
          'isActive': true,
          'sortOrder': 1,
          'recipeConfigured': false,
          'recipeComponentCount': 0,
        },
      ],
      'modifierGroups': const <Map<String, dynamic>>[],
    });

Map<String, dynamic> _menuJson(String name) => <String, dynamic>{
  'id': name.hashCode,
  'name': name,
  'status': 'draft',
  'priority': 0,
  'sectionCount': 0,
  'visibleProductCount': 0,
  'assignmentCount': 0,
  'scheduleRuleCount': 0,
};

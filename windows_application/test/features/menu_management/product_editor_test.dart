import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:windows_application/core/network/api_exception.dart';
import 'package:windows_application/features/menu_management/controllers/product_catalog_cubit.dart';
import 'package:windows_application/features/menu_management/catalog_setup/models/catalog_setup_models.dart';
import 'package:windows_application/features/menu_management/models/catalog_models.dart';
import 'package:windows_application/features/menu_management/models/product_catalog_filter.dart';
import 'package:windows_application/features/menu_management/products/controllers/product_editor_cubit.dart';
import 'package:windows_application/features/menu_management/products/controllers/product_editor_state.dart';
import 'package:windows_application/features/menu_management/products/models/product_editor_draft.dart';
import 'package:windows_application/features/menu_management/products/views/product_editor_screen.dart';
import 'package:windows_application/features/menu_management/repositories/menu_catalog_repository.dart';
import 'package:windows_application/features/menu_management/variants/models/variant_editor_draft.dart';

void main() {
  test('create and update payloads keep the variant contract separate', () {
    const ProductEditorDraft draft = ProductEditorDraft(
      name: 'Latte',
      categoryId: 4,
      variantName: 'Regular',
      variantBasePrice: '3.50',
      variantSku: ' LATTE-R ',
    );
    final Map<String, dynamic> create = draft.toCreateJson();
    final Map<String, dynamic> update = draft.toUpdateJson();
    final List<dynamic> variants = create['variants'] as List<dynamic>;
    expect(variants, hasLength(1));
    expect((variants.single as Map<String, dynamic>)['isDefault'], isTrue);
    expect((variants.single as Map<String, dynamic>)['isActive'], isTrue);
    expect((variants.single as Map<String, dynamic>)['sortOrder'], 0);
    expect((variants.single as Map<String, dynamic>)['sku'], 'LATTE-R');
    expect(update.containsKey('variants'), isFalse);
  });

  test(
    'editor initializes references, tracks dirty state, validates, and saves',
    () async {
      final _EditorRepository repository = _EditorRepository();
      final ProductEditorCubit cubit = ProductEditorCubit(
        repository: repository,
      );
      await cubit.initializeCreate();
      expect(cubit.state.status, ProductEditorStatus.ready);
      expect(cubit.state.categories.single.name, 'Coffee');
      await cubit.updateDraft(
        cubit.state.draft.copyWith(
          name: 'Latte',
          categoryId: 4,
          variantBasePrice: '3.5',
        ),
      );
      expect(cubit.state.isDirty, isTrue);
      await cubit.submit();
      expect(repository.createCalls, 1);
      expect(cubit.state.status, ProductEditorStatus.success);
      await cubit.close();
    },
  );

  test(
    'editor loads only product general fields in edit mode and maps nested validation errors',
    () async {
      final _EditorRepository repository = _EditorRepository()
        ..validationOnUpdate = true;
      final ProductEditorCubit cubit = ProductEditorCubit(
        repository: repository,
      );
      await cubit.loadForEdit(11);
      expect(cubit.state.draft.name, 'Iced Latte');
      expect(cubit.state.currentDefaultVariant?.sku, 'LATTE-R');
      await cubit.updateDraft(cubit.state.draft.copyWith(name: 'Updated'));
      await cubit.submit();
      expect(repository.updateCalls, 1);
      expect(cubit.state.fieldErrors['variants.0.sku'], 'SKU already exists.');
      expect(cubit.state.draft.variantSku, isEmpty);
      await cubit.close();
    },
  );

  test('duplicate submit is ignored while saving', () async {
    final _EditorRepository repository = _EditorRepository()
      ..createCompleter = Completer<ProductDetail>();
    final ProductEditorCubit cubit = ProductEditorCubit(repository: repository);
    await cubit.initializeCreate();
    await cubit.updateDraft(
      cubit.state.draft.copyWith(
        name: 'Latte',
        categoryId: 4,
        variantBasePrice: '3',
      ),
    );
    final Future<void> first = cubit.submit();
    await cubit.submit();
    expect(repository.createCalls, 1);
    repository.createCompleter!.complete(_detail());
    await first;
    await cubit.close();
  });

  test(
    'refresh keeps an archived assigned reference selected in edit mode',
    () async {
      final _EditorRepository repository = _EditorRepository();
      final ProductEditorCubit cubit = ProductEditorCubit(
        repository: repository,
      );
      await cubit.loadForEdit(11);
      repository.omitCategories = true;
      await cubit.refreshReferences();

      expect(cubit.state.draft.categoryId, 4);
      expect(cubit.state.categories, hasLength(1));
      expect(cubit.state.categories.single.isActive, isFalse);
      expect(cubit.state.isDirty, isFalse);
      await cubit.close();
    },
  );

  testWidgets(
    'create editor has initial variant and protects unsaved changes',
    (tester) async {
      final _EditorRepository repository = _EditorRepository();
      await tester.pumpWidget(_editorApp(repository));
      await tester.pumpAndSettle();
      expect(find.text('Initial Default Variant'), findsOneWidget);
      expect(find.text('Current Default Variant'), findsNothing);
      expect(find.text('Modifier Groups'), findsNothing);
      await tester.enterText(find.byType(TextFormField).first, 'Latte');
      await tester.pump();
      await tester.tap(find.text('Back').first);
      await tester.pumpAndSettle();
      expect(
        find.text('You have unsaved changes. Leave without saving?'),
        findsOneWidget,
      );
      await tester.tap(find.text('Stay'));
    },
  );

  testWidgets(
    'edit editor shows current default variant without variant fields',
    (tester) async {
      final _EditorRepository repository = _EditorRepository();
      await tester.pumpWidget(_editorApp(repository, productId: 11));
      await tester.pumpAndSettle();
      expect(find.text('Current Default Variant'), findsOneWidget);
      expect(
        find.text(
          'Advanced Variant editing is managed separately from Product General information.',
        ),
        findsOneWidget,
      );
      expect(find.text('Initial Default Variant'), findsNothing);
    },
  );
}

Widget _editorApp(_EditorRepository repository, {int? productId}) =>
    MaterialApp(
      home: Scaffold(
        body: MultiBlocProvider(
          providers: <BlocProvider<dynamic>>[
            BlocProvider<ProductCatalogCubit>(
              create: (_) => ProductCatalogCubit(repository: repository),
            ),
            BlocProvider<ProductEditorCubit>(
              create: (_) => ProductEditorCubit(repository: repository),
            ),
          ],
          child: ProductEditorScreen(productId: productId),
        ),
      ),
    );

class _EditorRepository extends MenuCatalogRepository {
  int createCalls = 0;
  int updateCalls = 0;
  bool validationOnUpdate = false;
  Completer<ProductDetail>? createCompleter;
  bool omitCategories = false;
  @override
  Future<ProductDetail> createProduct(ProductEditorDraft draft) {
    createCalls++;
    return createCompleter?.future ?? Future<ProductDetail>.value(_detail());
  }

  @override
  Future<ProductDetail> updateProductGeneral(
    int productId,
    ProductEditorDraft draft,
  ) async {
    updateCalls++;
    if (validationOnUpdate) {
      throw const ApiException(
        message: 'The submitted data was invalid.',
        validationErrors: <String, List<String>>{
          'variants.0.sku': <String>['SKU already exists.'],
        },
      );
    }
    return _detail();
  }

  @override
  Future<ProductDetail> getProduct(
    int productId, {
    bool includeArchived = false,
  }) async => _detail();
  @override
  Future<ProductVariant> createVariant(
    int productId,
    VariantEditorDraft draft, {
    bool makeDefault = false,
  }) async => _detail().variants.single;
  @override
  Future<ProductVariant> updateVariant(
    int variantId,
    VariantEditorDraft draft,
  ) async => _detail().variants.single;
  @override
  Future<ProductVariant> setDefaultVariant(int variantId) async =>
      _detail().variants.single;
  @override
  Future<ProductVariant> archiveVariant(
    int variantId, {
    int? replacementDefaultVariantId,
  }) async => _detail().variants.single;
  @override
  Future<ProductVariant> restoreVariant(
    int variantId, {
    bool makeDefault = false,
  }) async => _detail().variants.single;
  @override
  Future<void> reorderVariants(
    int productId,
    List<VariantReorderItem> items,
  ) async {}
  @override
  Future<CatalogPage<CatalogCategory>> listCategories({
    int perPage = 100,
  }) async => CatalogPage<CatalogCategory>(
    items: omitCategories
        ? const <CatalogCategory>[]
        : <CatalogCategory>[
            CatalogCategory.fromJson(<String, dynamic>{
              'id': 4,
              'name': 'Coffee',
              'isActive': true,
              'sortOrder': 0,
            }),
          ],
    meta: _meta(),
  );
  @override
  Future<CatalogSetupRecord> getCatalogSetupRecord(
    CatalogSetupKind kind,
    int id, {
    bool includeArchived = false,
  }) async => const CatalogSetupRecord(
    id: 4,
    name: 'Coffee',
    nameAr: '',
    nameEn: '',
    description: '',
    code: '',
    printerName: '',
    branchId: null,
    isActive: false,
    sortOrder: 0,
    productCount: 1,
  );
  @override
  Future<CatalogPage<ReportingCategory>> listReportingCategories({
    int perPage = 100,
  }) async => CatalogPage<ReportingCategory>(
    items: const <ReportingCategory>[],
    meta: _meta(),
  );
  @override
  Future<CatalogPage<KitchenStation>> listKitchenStations({
    int perPage = 100,
  }) async => CatalogPage<KitchenStation>(
    items: const <KitchenStation>[],
    meta: _meta(),
  );
  @override
  Future<CatalogPage<ProductSummary>> listProducts({
    required ProductCatalogFilter filter,
    required int page,
    int perPage = 20,
  }) async => CatalogPage<ProductSummary>(
    items: <ProductSummary>[ProductSummary.fromJson(_summary())],
    meta: _meta(),
  );
}

CatalogPagination _meta() =>
    const CatalogPagination(currentPage: 1, lastPage: 1, perPage: 20, total: 1);
ProductDetail _detail() => ProductDetail.fromJson(<String, dynamic>{
  ..._summary(),
  'descriptionAr': null,
  'descriptionEn': null,
  'preparationTimeMinutes': 3,
  'isStockTracked': false,
  'sortOrder': 0,
  'variants': <Map<String, dynamic>>[
    <String, dynamic>{
      'id': 20,
      'name': 'Regular',
      'sku': 'LATTE-R',
      'barcode': null,
      'basePrice': 3.5,
      'costPrice': 1,
      'isDefault': true,
      'isActive': true,
      'sortOrder': 0,
    },
  ],
  'modifierGroups': const <Map<String, dynamic>>[],
});
Map<String, dynamic> _summary() => <String, dynamic>{
  'id': 11,
  'name': 'Iced Latte',
  'nameAr': null,
  'nameEn': null,
  'description': null,
  'imageUrl': null,
  'productType': 'standard',
  'isActive': true,
  'category': <String, dynamic>{
    'id': 4,
    'name': 'Coffee',
    'isActive': true,
    'sortOrder': 0,
  },
  'reportingCategory': null,
  'kitchenStation': null,
  'defaultVariant': <String, dynamic>{
    'id': 20,
    'name': 'Regular',
    'sku': 'LATTE-R',
    'barcode': null,
    'basePrice': 3.5,
    'costPrice': 1,
    'isDefault': true,
    'isActive': true,
    'sortOrder': 0,
  },
  'variantCount': 1,
  'modifierGroupCount': 0,
  'createdAt': '2026-07-30T10:00:00Z',
  'updatedAt': '2026-07-30T10:00:00Z',
};

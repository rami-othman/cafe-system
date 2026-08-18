import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:windows_application/core/network/api_exception.dart';
import 'package:windows_application/features/menu_management/models/catalog_models.dart';
import 'package:windows_application/features/menu_management/models/product_catalog_filter.dart';
import 'package:windows_application/features/menu_management/products/models/product_editor_draft.dart';
import 'package:windows_application/features/menu_management/repositories/menu_catalog_repository.dart';
import 'package:windows_application/features/menu_management/variants/controllers/variants_cubit.dart';
import 'package:windows_application/features/menu_management/variants/controllers/variants_state.dart';
import 'package:windows_application/features/menu_management/variants/models/variant_editor_draft.dart';
import 'package:windows_application/features/menu_management/pricing/configured_price_validation.dart';

void main() {
  test('variant drafts use dedicated create and update contracts', () {
    const VariantEditorDraft draft = VariantEditorDraft(
      name: ' Large ',
      sku: ' L ',
      barcode: ' B ',
      basePrice: '4.50',
      costPrice: '1.25',
      sortOrder: '2',
    );
    final Map<String, dynamic> create = draft.toCreateJson(makeDefault: true);
    final Map<String, dynamic> update = draft.toUpdateJson();
    expect(create['name'], 'Large');
    expect(create['sku'], 'L');
    expect(create['isDefault'], isTrue);
    expect(update.containsKey('isDefault'), isFalse);
    expect(update.containsKey('productId'), isFalse);
  });

  test(
    'loads active and archived variants and maps Laravel field errors',
    () async {
      final _VariantsRepository repository = _VariantsRepository()
        ..createError = true;
      final VariantsCubit cubit = VariantsCubit(repository: repository);
      await cubit.load(11);
      expect(cubit.state.status, VariantsStatus.loaded);
      expect(cubit.state.activeVariants, hasLength(2));
      expect(cubit.state.archivedVariants.single.name, 'Old');
      await cubit.create(
        const VariantEditorDraft(name: 'New', basePrice: '2', sortOrder: '2'),
        makeDefault: false,
      );
      expect(cubit.state.fieldErrors['sku'], 'The sku has already been taken.');
      await cubit.close();
    },
  );

  test(
    'set default, archive, restore, and reorder use dedicated mutations',
    () async {
      final _VariantsRepository repository = _VariantsRepository();
      final VariantsCubit cubit = VariantsCubit(repository: repository);
      await cubit.load(11);
      await cubit.setDefault(2);
      await cubit.archive(1, replacementDefaultVariantId: 2);
      await cubit.restore(3);
      await cubit.reorder(<ProductVariant>[
        cubit.state.activeVariants[1],
        cubit.state.activeVariants[0],
      ]);
      expect(repository.setDefaultCalls, 1);
      expect(repository.archiveReplacement, 2);
      expect(repository.restoreCalls, 1);
      expect(repository.reorderItems, hasLength(2));
      await cubit.close();
    },
  );

  test(
    'failed reorder restores visible active order and concurrent action is ignored',
    () async {
      final _VariantsRepository repository = _VariantsRepository()
        ..reorderError = true;
      final VariantsCubit cubit = VariantsCubit(repository: repository);
      await cubit.load(11);
      final List<int> before = cubit.state.activeVariants
          .map((item) => item.id)
          .toList();
      await cubit.reorder(<ProductVariant>[
        cubit.state.activeVariants[1],
        cubit.state.activeVariants[0],
      ]);
      expect(cubit.state.activeVariants.map((item) => item.id), before);
      repository.createCompleter = Completer<ProductVariant>();
      final Future<bool> create = cubit.create(
        const VariantEditorDraft(name: 'New', basePrice: '2', sortOrder: '2'),
        makeDefault: false,
      );
      expect(await cubit.setDefault(2), isFalse);
      repository.createCompleter!.complete(cubit.state.activeVariants.first);
      await create;
      await cubit.close();
    },
  );

  test(
    'variant create and update require a strictly positive configured base price',
    () async {
      final _VariantsRepository repository = _VariantsRepository();
      final VariantsCubit cubit = VariantsCubit(repository: repository);
      await cubit.load(11);
      for (final String price in <String>[
        '0',
        '0.00',
        '-0.01',
        '-5',
        'invalid',
      ]) {
        expect(
          await cubit.create(
            VariantEditorDraft(name: 'New', basePrice: price, sortOrder: '0'),
            makeDefault: false,
          ),
          isFalse,
        );
        expect(
          cubit.state.fieldErrors['basePrice'],
          configuredSellPriceMustBePositive,
        );
      }
      expect(
        await cubit.create(
          const VariantEditorDraft(
            name: 'New',
            basePrice: '5.50',
            sortOrder: '0',
          ),
          makeDefault: false,
        ),
        isTrue,
      );
      expect(
        await cubit.update(
          1,
          const VariantEditorDraft(
            name: 'Regular',
            basePrice: '0.01',
            sortOrder: '0',
          ),
        ),
        isTrue,
      );
      await cubit.close();
    },
  );
}

class _VariantsRepository extends MenuCatalogRepository {
  bool createError = false;
  bool reorderError = false;
  int setDefaultCalls = 0;
  int restoreCalls = 0;
  int? archiveReplacement;
  List<VariantReorderItem> reorderItems = const <VariantReorderItem>[];
  Completer<ProductVariant>? createCompleter;
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
  }) {
    if (createError) {
      return Future<ProductVariant>.error(
        const ApiException(
          message: 'Validation failed.',
          validationErrors: <String, List<String>>{
            'sku': <String>['The sku has already been taken.'],
          },
        ),
      );
    }
    return createCompleter?.future ??
        Future<ProductVariant>.value(_detail().variants.first);
  }

  @override
  Future<ProductVariant> updateVariant(
    int variantId,
    VariantEditorDraft draft,
  ) async => _detail().variants.first;
  @override
  Future<ProductVariant> setDefaultVariant(int variantId) async {
    setDefaultCalls++;
    return _detail().variants[1];
  }

  @override
  Future<ProductVariant> archiveVariant(
    int variantId, {
    int? replacementDefaultVariantId,
  }) async {
    archiveReplacement = replacementDefaultVariantId;
    return _detail().variants.first;
  }

  @override
  Future<ProductVariant> restoreVariant(
    int variantId, {
    bool makeDefault = false,
  }) async {
    restoreCalls++;
    return _detail().variants[2];
  }

  @override
  Future<void> reorderVariants(
    int productId,
    List<VariantReorderItem> items,
  ) async {
    reorderItems = items;
    if (reorderError) throw const ApiException(message: 'Could not reorder.');
  }

  @override
  Future<CatalogPage<ProductSummary>> listProducts({
    required ProductCatalogFilter filter,
    required int page,
    int perPage = 20,
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

ProductDetail _detail() => ProductDetail.fromJson(<String, dynamic>{
  'id': 11,
  'name': 'Latte',
  'productType': 'standard',
  'isActive': true,
  'category': null,
  'reportingCategory': null,
  'kitchenStation': null,
  'defaultVariant': _variant(1, 'Regular', true),
  'variantCount': 2,
  'modifierGroupCount': 0,
  'descriptionAr': null,
  'descriptionEn': null,
  'isStockTracked': false,
  'sortOrder': 0,
  'variants': <Map<String, dynamic>>[
    _variant(1, 'Regular', true),
    _variant(2, 'Large', false),
    _variant(3, 'Old', false, archived: true),
  ],
  'modifierGroups': const <Map<String, dynamic>>[],
});
Map<String, dynamic> _variant(
  int id,
  String name,
  bool isDefault, {
  bool archived = false,
}) => <String, dynamic>{
  'id': id,
  'productId': 11,
  'name': name,
  'basePrice': 3.5,
  'costPrice': 1,
  'isDefault': isDefault,
  'isActive': !archived,
  'sortOrder': id - 1,
  if (archived) 'archivedAt': '2026-07-31T10:00:00Z',
};

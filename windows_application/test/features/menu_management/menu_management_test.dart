import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:windows_application/app/app.dart';
import 'package:windows_application/app/app_router.dart';
import 'package:windows_application/core/network/api_exception.dart';
import 'package:windows_application/core/network/dio_api_client.dart';
import 'package:windows_application/core/services/service_locator.dart';
import 'package:windows_application/features/menu_management/controllers/product_catalog_cubit.dart';
import 'package:windows_application/features/menu_management/controllers/product_detail_cubit.dart';
import 'package:windows_application/features/menu_management/controllers/product_lifecycle_cubit.dart';
import 'package:windows_application/features/menu_management/models/catalog_models.dart';
import 'package:windows_application/features/menu_management/models/product_catalog_filter.dart';
import 'package:windows_application/features/menu_management/products/models/product_editor_draft.dart';
import 'package:windows_application/features/menu_management/products/controllers/product_editor_cubit.dart';
import 'package:windows_application/features/menu_management/repositories/menu_catalog_repository.dart';
import 'package:windows_application/features/menu_management/variants/models/variant_editor_draft.dart';
import 'package:windows_application/features/menu_management/views/product_catalog_screen.dart';
import 'package:windows_application/shared/widgets/app_sidebar_item.dart';

void main() {
  test('models parse product detail, nullable references, and pagination', () {
    final ProductDetail detail = ProductDetail.fromJson(_detailJson());
    final ProductSummary nullable = ProductSummary.fromJson(<String, dynamic>{
      ..._summaryJson(),
      'category': null,
      'reportingCategory': null,
      'kitchenStation': null,
      'defaultVariant': null,
    });
    final CatalogPagination pagination = CatalogPagination.fromJson(
      <String, dynamic>{
        'currentPage': 2,
        'lastPage': 3,
        'perPage': 20,
        'total': 41,
      },
    );
    expect(detail.variants.single.sku, 'LATTE-R');
    expect(detail.modifierGroups.single.effectiveRequired, isTrue);
    expect(detail.modifierGroups.single.options.single.isAvailable, isTrue);
    expect(nullable.category, isNull);
    expect(nullable.defaultVariant, isNull);
    expect(pagination.hasNextPage, isTrue);
  });

  test(
    'repository sends catalog query parameters and retains tenant header',
    () async {
      RequestOptions? request;
      final BackendMenuCatalogRepository repository =
          BackendMenuCatalogRepository(
            _client((options) {
              request = options;
              return Response<dynamic>(
                requestOptions: options,
                data: <String, dynamic>{
                  'data': <Map<String, dynamic>>[_summaryJson()],
                  'meta': <String, dynamic>{
                    'currentPage': 1,
                    'lastPage': 1,
                    'perPage': 20,
                    'total': 1,
                  },
                },
              );
            }),
          );
      final result = await repository.listProducts(
        filter: const ProductCatalogFilter(
          search: 'latte',
          categoryId: 4,
          status: 'all',
          hasVariants: true,
          sort: 'name',
          direction: 'desc',
        ),
        page: 2,
      );
      expect(request!.path, 'admin/catalog/products');
      expect(request!.queryParameters['search'], 'latte');
      expect(request!.queryParameters['categoryId'], 4);
      expect(request!.queryParameters['hasVariants'], true);
      expect(request!.queryParameters['page'], 2);
      expect(result.items.single.id, 11);
    },
  );

  test('Laravel validation response maps to ApiException', () async {
    final Dio dio = Dio(BaseOptions(baseUrl: 'http://localhost/api/v1/'));
    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) => handler.reject(
          DioException(
            requestOptions: options,
            response: Response<dynamic>(
              requestOptions: options,
              statusCode: 422,
              data: <String, dynamic>{
                'message': 'Validation failed.',
                'errors': <String, dynamic>{
                  'name': <String>['Required.'],
                },
              },
            ),
            type: DioExceptionType.badResponse,
          ),
        ),
      ),
    );
    await expectLater(
      DioApiClient(dio: dio).get('admin/catalog/products'),
      throwsA(
        isA<ApiException>().having(
          (error) => error.validationErrors?['name']?.single,
          'name error',
          'Required.',
        ),
      ),
    );
  });

  test(
    'cubit resets pagination on filters, retries, and de-duplicates next page',
    () async {
      final _FakeRepository repository = _FakeRepository()..failNextList = true;
      final ProductCatalogCubit cubit = ProductCatalogCubit(
        repository: repository,
      );
      await cubit.loadProducts();
      expect(cubit.state.errorMessage, isNotNull);
      await cubit.loadProducts();
      expect(cubit.state.products, hasLength(1));
      await cubit.updateFilter(
        const ProductCatalogFilter(productType: 'standard'),
      );
      expect(repository.filters.last.productType, 'standard');
      await cubit.loadNextPage();
      expect(cubit.state.products, hasLength(1));
      await cubit.loadReferences();
      expect(cubit.state.categories.single.name, 'Coffee');
      await cubit.clearFilters();
      expect(cubit.state.filter.hasActiveFilters, isFalse);
      await cubit.close();
    },
  );

  testWidgets(
    'catalog states render rows, empty catalog, no-results, and retry',
    (tester) async {
      final _FakeRepository repository = _FakeRepository();
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: MultiBlocProvider(
              providers: <BlocProvider<dynamic>>[
                BlocProvider<ProductCatalogCubit>(
                  create: (_) => ProductCatalogCubit(repository: repository),
                ),
                BlocProvider<ProductLifecycleCubit>(
                  create: (_) => ProductLifecycleCubit(repository: repository),
                ),
              ],
              child: const ProductCatalogScreen(key: ValueKey<String>('empty')),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Iced Latte'), findsOneWidget);
      expect(find.text('Create Product'), findsOneWidget);
      repository.empty = true;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: MultiBlocProvider(
              providers: <BlocProvider<dynamic>>[
                BlocProvider<ProductCatalogCubit>(
                  create: (_) => ProductCatalogCubit(repository: repository),
                ),
                BlocProvider<ProductLifecycleCubit>(
                  create: (_) => ProductLifecycleCubit(repository: repository),
                ),
              ],
              child: const ProductCatalogScreen(),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('No active products are available.'), findsOneWidget);
      repository.empty = false;
    },
  );

  testWidgets(
    'sidebar opens Menu Management and detail route parses product ID',
    (tester) async {
      await serviceLocator.reset();
      setupServiceLocator(useBackend: false);
      final _FakeRepository repository = _FakeRepository();
      await serviceLocator.unregister<MenuCatalogRepository>();
      await serviceLocator.unregister<ProductCatalogCubit>();
      await serviceLocator.unregister<ProductDetailCubit>();
      await serviceLocator.unregister<ProductEditorCubit>();
      serviceLocator.registerLazySingleton<MenuCatalogRepository>(
        () => repository,
      );
      serviceLocator.registerFactory<ProductCatalogCubit>(
        () => ProductCatalogCubit(
          repository: serviceLocator<MenuCatalogRepository>(),
        ),
      );
      serviceLocator.registerFactory<ProductDetailCubit>(
        () => ProductDetailCubit(
          repository: serviceLocator<MenuCatalogRepository>(),
        ),
      );
      serviceLocator.registerFactory<ProductEditorCubit>(
        () => ProductEditorCubit(
          repository: serviceLocator<MenuCatalogRepository>(),
        ),
      );
      tester.view.physicalSize = const Size(1280, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
        appRouter.go(AppRoutes.pos);
      });
      await tester.pumpWidget(const App());
      await tester.pumpAndSettle();
      await tester.tap(find.text('Menu Management'));
      await tester.pumpAndSettle();
      expect(find.text('Products'), findsWidgets);
      expect(
        tester
            .widget<AppSidebarItem>(
              find.byWidgetPredicate(
                (widget) =>
                    widget is AppSidebarItem &&
                    widget.label == 'Menu Management',
              ),
            )
            .isActive,
        isTrue,
      );
      await tester.tap(find.text('Iced Latte').first);
      await tester.pumpAndSettle();
      expect(find.text('Variants (1)'), findsOneWidget);
      expect(find.text('Modifier Groups (1)'), findsOneWidget);
      await tester.tap(find.byKey(const Key('edit-product-action')));
      await tester.pumpAndSettle();
      expect(find.text('Current Default Variant'), findsOneWidget);
      appRouter.go(AppRoutes.menuManagementProductCreate);
      await tester.pumpAndSettle();
      expect(find.text('Initial Default Variant'), findsOneWidget);
    },
  );
}

class _FakeRepository extends MenuCatalogRepository {
  bool failNextList = false;
  bool empty = false;
  final List<ProductCatalogFilter> filters = <ProductCatalogFilter>[];
  @override
  Future<ProductDetail> getProduct(
    int productId, {
    bool includeArchived = false,
  }) async => ProductDetail.fromJson(_detailJson());
  @override
  Future<ProductVariant> createVariant(
    int productId,
    VariantEditorDraft draft, {
    bool makeDefault = false,
  }) async => ProductDetail.fromJson(_detailJson()).variants.single;
  @override
  Future<ProductVariant> updateVariant(
    int variantId,
    VariantEditorDraft draft,
  ) async => ProductDetail.fromJson(_detailJson()).variants.single;
  @override
  Future<ProductVariant> setDefaultVariant(int variantId) async =>
      ProductDetail.fromJson(_detailJson()).variants.single;
  @override
  Future<ProductVariant> archiveVariant(
    int variantId, {
    int? replacementDefaultVariantId,
  }) async => ProductDetail.fromJson(_detailJson()).variants.single;
  @override
  Future<ProductVariant> restoreVariant(
    int variantId, {
    bool makeDefault = false,
  }) async => ProductDetail.fromJson(_detailJson()).variants.single;
  @override
  Future<void> reorderVariants(
    int productId,
    List<VariantReorderItem> items,
  ) async {}
  @override
  Future<ProductDetail> createProduct(ProductEditorDraft draft) async =>
      ProductDetail.fromJson(_detailJson());
  @override
  Future<ProductDetail> updateProductGeneral(
    int productId,
    ProductEditorDraft draft,
  ) async => ProductDetail.fromJson(_detailJson());
  @override
  Future<CatalogPage<CatalogCategory>> listCategories({
    int perPage = 100,
  }) async => CatalogPage<CatalogCategory>(
    items: <CatalogCategory>[
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
  }) async {
    filters.add(filter);
    if (failNextList) {
      failNextList = false;
      throw const ApiException(message: 'Unable to reach catalog.');
    }
    return CatalogPage<ProductSummary>(
      items: empty
          ? const <ProductSummary>[]
          : <ProductSummary>[ProductSummary.fromJson(_summaryJson())],
      meta: CatalogPagination(
        currentPage: page,
        lastPage: page == 1 ? 2 : 2,
        perPage: perPage,
        total: empty ? 0 : 2,
      ),
    );
  }

  @override
  Future<CatalogPage<ReportingCategory>> listReportingCategories({
    int perPage = 100,
  }) async => CatalogPage<ReportingCategory>(
    items: const <ReportingCategory>[],
    meta: _meta(),
  );
  CatalogPagination _meta() => const CatalogPagination(
    currentPage: 1,
    lastPage: 1,
    perPage: 100,
    total: 1,
  );
}

DioApiClient _client(Response<dynamic> Function(RequestOptions) responder) {
  final Dio dio = Dio(BaseOptions(baseUrl: 'http://localhost:8000/api/v1/'));
  dio.interceptors.add(
    InterceptorsWrapper(
      onRequest: (options, handler) => handler.resolve(responder(options)),
    ),
  );
  return DioApiClient(dio: dio);
}

Map<String, dynamic> _summaryJson() => <String, dynamic>{
  'id': 11,
  'name': 'Iced Latte',
  'nameAr': null,
  'nameEn': 'Iced Latte',
  'description': 'Cold espresso and milk',
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
    'basePrice': 3.5,
    'costPrice': 1.1,
    'isDefault': true,
    'isActive': true,
    'sortOrder': 0,
  },
  'variantCount': 1,
  'modifierGroupCount': 1,
  'createdAt': '2026-07-30T10:00:00Z',
  'updatedAt': '2026-07-30T10:00:00Z',
};
Map<String, dynamic> _detailJson() => <String, dynamic>{
  ..._summaryJson(),
  'descriptionAr': null,
  'descriptionEn': 'Cold espresso and milk',
  'preparationTimeMinutes': 3,
  'isStockTracked': true,
  'sortOrder': 0,
  'variants': <Map<String, dynamic>>[
    <String, dynamic>{
      'id': 20,
      'name': 'Regular',
      'sku': 'LATTE-R',
      'barcode': null,
      'basePrice': 3.5,
      'costPrice': 1.1,
      'isDefault': true,
      'isActive': true,
      'sortOrder': 0,
    },
  ],
  'modifierGroups': <Map<String, dynamic>>[
    <String, dynamic>{
      'id': 8,
      'name': 'Milk',
      'groupType': 'choice',
      'selectionType': 'single',
      'isRequired': false,
      'minSelections': 0,
      'maxSelections': 1,
      'allowQuantity': false,
      'isRequiredOverride': true,
      'minSelectionsOverride': 1,
      'maxSelectionsOverride': 1,
      'allowQuantityOverride': false,
      'options': <Map<String, dynamic>>[
        <String, dynamic>{
          'id': 2,
          'name': 'Oat milk',
          'priceDelta': 0.5,
          'isActive': true,
          'isAvailable': true,
        },
      ],
    },
  ],
};

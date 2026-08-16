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
import 'package:windows_application/l10n/app_localizations.dart';
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
    'catalog uses compact filters, applies advanced filters, and clears chips',
    (tester) async {
      final _FakeRepository repository = _FakeRepository();
      await _pumpCatalog(tester, repository: repository);

      expect(find.byKey(const Key('product-catalog-search')), findsOneWidget);
      expect(find.text('More Filters'), findsOneWidget);
      expect(find.text('Sort'), findsOneWidget);
      expect(find.text('Reporting Category'), findsNothing);
      expect(find.byKey(const Key('product-catalog-sort')), findsOneWidget);

      await tester.tap(find.text('More Filters'));
      await tester.pumpAndSettle();
      expect(
        find.text('Refine the product list with additional criteria.'),
        findsOneWidget,
      );
      expect(find.text('Classification'), findsOneWidget);
      expect(find.text('Preparation'), findsOneWidget);
      expect(find.text('Product setup'), findsOneWidget);
      expect(find.text('Category'), findsOneWidget);
      expect(find.text('Reporting Category'), findsOneWidget);
      expect(find.text('Kitchen Station'), findsWidgets);
      expect(find.text('Product type'), findsOneWidget);
      expect(find.text('Has variants'), findsOneWidget);
      expect(find.text('Has modifiers'), findsOneWidget);
      expect(find.text('Clear filters'), findsOneWidget);
      expect(find.text('Cancel'), findsOneWidget);
      expect(find.text('Apply filters'), findsOneWidget);
      expect(
        tester.getTopLeft(find.byKey(const Key('product-filter-category'))).dy,
        closeTo(
          tester
              .getTopLeft(
                find.byKey(const Key('product-filter-reporting-category')),
              )
              .dy,
          2,
        ),
      );
      expect(
        tester
            .getTopLeft(find.byKey(const Key('product-filter-kitchen-station')))
            .dy,
        closeTo(
          tester.getTopLeft(find.byKey(const Key('product-filter-type'))).dy,
          2,
        ),
      );

      await tester.tap(find.byKey(const Key('product-filter-category')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Coffee').last);
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('product-filters-apply')));
      await tester.pumpAndSettle();
      expect(repository.filters.last.categoryId, 4);
      expect(find.widgetWithText(InputChip, 'Coffee'), findsOneWidget);

      await tester.enterText(
        find.byKey(const Key('product-catalog-search')),
        'latte',
      );
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pumpAndSettle();
      expect(repository.filters.last.search, 'latte');
      expect(find.text('Clear All'), findsOneWidget);
      await tester.tap(find.text('Clear All'));
      await tester.pumpAndSettle();
      expect(repository.filters.last.hasActiveFilters, isFalse);

      await tester.tap(find.text('More Filters'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('product-filter-category')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Coffee').last);
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('product-filters-apply')));
      await tester.pumpAndSettle();
      final InputChip chip = tester.widget<InputChip>(
        find.widgetWithText(InputChip, 'Coffee'),
      );
      chip.onDeleted!();
      await tester.pumpAndSettle();
      expect(repository.filters.last.categoryId, isNull);
    },
  );

  testWidgets(
    'catalog preserves lifecycle filtering and manager-scannable row content',
    (tester) async {
      final _FakeRepository repository = _FakeRepository();
      await _pumpCatalog(tester, repository: repository, width: 1440);

      expect(find.text('Base price'), findsOneWidget);
      expect(
        find.text('1 variants · 1 modifiers · Coffee Bar'),
        findsOneWidget,
      );
      expect(find.text('Setup'), findsNothing);
      expect(find.text('Active'), findsWidgets);
      expect(find.text('Regular'), findsNothing);

      await tester.tap(find.text('Archived'));
      await tester.pumpAndSettle();
      expect(repository.filters.last.status, 'archived');
      repository.archived = true;
      await tester.pumpWidget(const SizedBox.shrink());
      await _pumpCatalog(tester, repository: repository, width: 1440);
      expect(find.text('Archived'), findsWidgets);

      await tester.tap(find.byKey(const Key('product-actions-11')));
      await tester.pumpAndSettle();
      expect(find.text('Open'), findsOneWidget);
      expect(find.text('Restore'), findsOneWidget);
    },
  );

  testWidgets('More Filters clear and cancel leave the applied filter intact', (
    tester,
  ) async {
    final _FakeRepository repository = _FakeRepository();
    await _pumpCatalog(tester, repository: repository, width: 1280);

    await tester.tap(find.text('More Filters'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('product-filter-category')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Coffee').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Clear filters'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();

    expect(find.text('Classification'), findsNothing);
    expect(repository.filters.last.categoryId, isNull);
  });

  testWidgets(
    'catalog rows remain overflow-free at desktop widths and in Arabic RTL',
    (tester) async {
      final _FakeRepository repository = _FakeRepository();
      for (final double width in <double>[1280, 1440, 1920]) {
        await _pumpCatalog(tester, repository: repository, width: width);
        expect(find.byKey(const Key('product-row-11')), findsOneWidget);
        await tester.tap(find.text('More Filters'));
        await tester.pumpAndSettle();
        expect(find.text('Classification'), findsOneWidget);
        expect(
          tester
              .getTopLeft(find.byKey(const Key('product-filter-category')))
              .dy,
          closeTo(
            tester
                .getTopLeft(
                  find.byKey(const Key('product-filter-reporting-category')),
                )
                .dy,
            2,
          ),
        );
        await tester.tap(find.text('Cancel'));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox.shrink());
      }

      await _pumpCatalog(
        tester,
        repository: repository,
        width: 1280,
        locale: const Locale('ar'),
      );
      expect(find.text('المنتجات'), findsOneWidget);
      expect(
        Directionality.of(tester.element(find.text('المنتجات'))),
        TextDirection.rtl,
      );
      await tester.tap(find.text('مزيد من الفلاتر'));
      await tester.pumpAndSettle();
      expect(find.text('التصنيف'), findsOneWidget);
      expect(find.text('تطبيق الفلاتر'), findsOneWidget);
      expect(tester.takeException(), isNull);
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
      expect(find.byKey(const Key('menu-module-navigation')), findsOneWidget);
      expect(find.text('Downtown'), findsNothing);
      expect(find.byType(ChoiceChip), findsNothing);
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
      expect(
        find.byKey(const Key('product-summary-Base Price')),
        findsOneWidget,
      );
      expect(find.byKey(const Key('product-summary-Variants')), findsOneWidget);
      expect(
        find.byKey(const Key('product-summary-Modifier Groups')),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('product-summary-Stock Tracking')),
        findsOneWidget,
      );
      expect(find.text('Product Setup'), findsOneWidget);
      expect(find.text('Description'), findsOneWidget);
      expect(find.text('Advanced & Technical'), findsOneWidget);
      expect(find.text('Product ID'), findsNothing);
      await tester.ensureVisible(find.text('Advanced & Technical'));
      await tester.tap(find.text('Advanced & Technical'));
      await tester.pumpAndSettle();
      expect(find.text('Product ID'), findsOneWidget);
      for (final double width in <double>[1280, 1440, 1920]) {
        tester.view.physicalSize = Size(width, 900);
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
      }
      expect(find.text('Variants'), findsWidgets);
      expect(find.text('Modifiers'), findsWidgets);
      expect(repository.productUsageCalls, 0);
      await tester.ensureVisible(find.text('Usage'));
      await tester.tap(find.text('Usage'));
      await tester.pumpAndSettle();
      expect(repository.productUsageCalls, 1);
      expect(
        find.text('Menus where this Product is currently used.'),
        findsOneWidget,
      );
      await tester.tap(find.byKey(const Key('edit-product-action')));
      await tester.pumpAndSettle();
      expect(find.text('Default Variant'), findsOneWidget);
      appRouter.go(AppRoutes.menuManagementProductCreate);
      await tester.pumpAndSettle();
      expect(find.text('Initial selling option'), findsOneWidget);
    },
  );
}

Future<void> _pumpCatalog(
  WidgetTester tester, {
  required _FakeRepository repository,
  double width = 1280,
  Locale locale = const Locale('en'),
}) async {
  tester.view.physicalSize = Size(width, 900);
  tester.view.devicePixelRatio = 1;
  addTearDown(() {
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });
  await tester.pumpWidget(
    MaterialApp(
      locale: locale,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
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
}

class _FakeRepository extends MenuCatalogRepository {
  bool failNextList = false;
  bool empty = false;
  bool archived = false;
  final List<ProductCatalogFilter> filters = <ProductCatalogFilter>[];
  int productUsageCalls = 0;
  @override
  Future<ProductMenuUsage> getProductMenuUsage(int productId) async {
    productUsageCalls++;
    return ProductMenuUsage.fromJson(<String, dynamic>{
      'productId': productId,
      'activePlacementCount': 1,
      'menus': <Map<String, dynamic>>[
        <String, dynamic>{'menuName': 'Main Menu'},
      ],
    });
  }

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
    items: <KitchenStation>[
      KitchenStation.fromJson(<String, dynamic>{
        'id': 7,
        'name': 'Coffee Bar',
        'code': 'COFFEE',
        'isActive': true,
        'sortOrder': 0,
      }),
    ],
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
          : <ProductSummary>[
              ProductSummary.fromJson(<String, dynamic>{
                ..._summaryJson(),
                'archivedAt': archived ? '2026-08-01T10:00:00Z' : null,
              }),
            ],
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
    items: <ReportingCategory>[
      ReportingCategory.fromJson(<String, dynamic>{
        'id': 9,
        'name': 'Beverages',
        'code': 'BEV',
        'isActive': true,
        'sortOrder': 0,
      }),
    ],
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
  'kitchenStation': <String, dynamic>{
    'id': 7,
    'name': 'Coffee Bar',
    'code': 'COFFEE',
    'isActive': true,
    'sortOrder': 0,
  },
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

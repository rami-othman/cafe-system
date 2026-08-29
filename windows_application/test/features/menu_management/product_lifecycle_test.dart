import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:windows_application/core/network/api_exception.dart';
import 'package:windows_application/core/network/dio_api_client.dart';
import 'package:windows_application/features/menu_management/controllers/product_lifecycle_cubit.dart';
import 'package:windows_application/features/menu_management/models/catalog_models.dart';
import 'package:windows_application/features/menu_management/models/product_catalog_filter.dart';
import 'package:windows_application/features/menu_management/products/models/product_editor_draft.dart';
import 'package:windows_application/features/menu_management/repositories/menu_catalog_repository.dart';

void main() {
  group('Product lifecycle repository', () {
    test(
      'archive and restore use the dedicated empty-body endpoints',
      () async {
        final List<RequestOptions> requests = <RequestOptions>[];
        final BackendMenuCatalogRepository repository =
            BackendMenuCatalogRepository(
              _client((RequestOptions options) {
                requests.add(options);
                return Response<dynamic>(
                  requestOptions: options,
                  data: <String, dynamic>{
                    'data': _product(
                      archived: options.path.endsWith('/archive'),
                    ),
                  },
                );
              }),
            );

        await repository.archiveProduct(11);
        await repository.restoreProduct(11);

        expect(requests.map((RequestOptions item) => item.path), <String>[
          'admin/catalog/products/11/archive',
          'admin/catalog/products/11/restore',
        ]);
        expect(
          requests.every((RequestOptions item) => item.data == null),
          isTrue,
        );
      },
    );

    test('Laravel lifecycle errors retain their safe API message', () async {
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
                  'message': 'Product cannot be archived.',
                },
              ),
              type: DioExceptionType.badResponse,
            ),
          ),
        ),
      );
      await expectLater(
        BackendMenuCatalogRepository(DioApiClient(dio: dio)).archiveProduct(11),
        throwsA(
          isA<ApiException>().having(
            (ApiException error) => error.message,
            'message',
            'Product cannot be archived.',
          ),
        ),
      );
    });
  });

  group('ProductLifecycleCubit', () {
    test(
      'archive and restore succeed, refreshable state remains filter-neutral',
      () async {
        final _LifecycleRepository repository = _LifecycleRepository();
        final ProductLifecycleCubit cubit = ProductLifecycleCubit(
          repository: repository,
        );

        expect(await cubit.archive(11), isTrue);
        expect(cubit.state.action, ProductLifecycleAction.archive);
        expect(cubit.state.product!.isArchived, isTrue);
        expect(await cubit.restore(11), isTrue);
        expect(cubit.state.action, ProductLifecycleAction.restore);
        expect(cubit.state.product!.isArchived, isFalse);
        await cubit.close();
      },
    );

    test(
      'failure is safe and duplicate or concurrent lifecycle requests are ignored',
      () async {
        final _LifecycleRepository repository = _LifecycleRepository()
          ..archiveCompleter = Completer<ProductDetail>();
        final ProductLifecycleCubit cubit = ProductLifecycleCubit(
          repository: repository,
        );

        final Future<bool> archive = cubit.archive(11);
        expect(await cubit.archive(11), isFalse);
        expect(await cubit.restore(11), isFalse);
        repository.archiveCompleter!.complete(
          ProductDetail.fromJson(_product(archived: true)),
        );
        expect(await archive, isTrue);

        repository.archiveError = true;
        expect(await cubit.archive(11), isFalse);
        expect(cubit.state.errorMessage, 'Product cannot be archived.');
        await cubit.close();
      },
    );
  });
}

class _LifecycleRepository extends MenuCatalogRepository {
  Completer<ProductDetail>? archiveCompleter;
  bool archiveError = false;

  @override
  Future<ProductDetail> archiveProduct(int productId) {
    if (archiveError) {
      return Future<ProductDetail>.error(
        const ApiException(message: 'Product cannot be archived.'),
      );
    }
    return archiveCompleter?.future ??
        Future<ProductDetail>.value(
          ProductDetail.fromJson(_product(archived: true)),
        );
  }

  @override
  Future<ProductDetail> restoreProduct(int productId) async =>
      ProductDetail.fromJson(_product());

  @override
  Future<CatalogPage<ProductSummary>> listProducts({
    required ProductCatalogFilter filter,
    required int page,
    int perPage = 20,
  }) => throw UnimplementedError();

  @override
  Future<ProductDetail> getProduct(
    int productId, {
    bool includeArchived = false,
  }) => throw UnimplementedError();

  @override
  Future<ProductDetail> createProduct(ProductEditorDraft draft) =>
      throw UnimplementedError();

  @override
  Future<ProductDetail> updateProductGeneral(
    int productId,
    ProductEditorDraft draft,
  ) => throw UnimplementedError();

  @override
  Future<CatalogPage<CatalogCategory>> listCategories({int perPage = 100}) =>
      throw UnimplementedError();

  @override
  Future<CatalogPage<ReportingCategory>> listReportingCategories({
    int perPage = 100,
  }) => throw UnimplementedError();

  @override
  Future<CatalogPage<KitchenStation>> listKitchenStations({
    int perPage = 100,
  }) => throw UnimplementedError();
}

DioApiClient _client(Response<dynamic> Function(RequestOptions) responder) {
  final Dio dio = Dio(BaseOptions(baseUrl: 'http://localhost/api/v1/'));
  dio.interceptors.add(
    InterceptorsWrapper(
      onRequest: (options, handler) => handler.resolve(responder(options)),
    ),
  );
  return DioApiClient(dio: dio);
}

Map<String, dynamic> _product({bool archived = false}) => <String, dynamic>{
  'id': 11,
  'name': 'Iced Latte',
  'productType': 'standard',
  'isActive': !archived,
  'archivedAt': archived ? '2026-07-31T10:00:00Z' : null,
  'category': null,
  'reportingCategory': null,
  'kitchenStation': null,
  'defaultVariant': null,
  'variantCount': 1,
  'modifierGroupCount': 0,
  'descriptionAr': null,
  'descriptionEn': null,
  'isStockTracked': false,
  'sortOrder': 0,
  'variants': const <Map<String, dynamic>>[],
  'modifierGroups': const <Map<String, dynamic>>[],
};

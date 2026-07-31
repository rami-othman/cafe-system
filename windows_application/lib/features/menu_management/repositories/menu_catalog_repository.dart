import '../../../core/network/dio_api_client.dart';
import '../models/catalog_models.dart';
import '../models/product_catalog_filter.dart';
import '../products/models/product_editor_draft.dart';
import '../variants/models/variant_editor_draft.dart';

abstract class MenuCatalogRepository {
  Future<CatalogPage<ProductSummary>> listProducts({
    required ProductCatalogFilter filter,
    required int page,
    int perPage = 20,
  });
  Future<ProductDetail> getProduct(
    int productId, {
    bool includeArchived = false,
  });
  Future<ProductDetail> createProduct(ProductEditorDraft draft);
  Future<ProductDetail> updateProductGeneral(
    int productId,
    ProductEditorDraft draft,
  );
  Future<CatalogPage<CatalogCategory>> listCategories({int perPage = 100});
  Future<CatalogPage<ReportingCategory>> listReportingCategories({
    int perPage = 100,
  });
  Future<CatalogPage<KitchenStation>> listKitchenStations({int perPage = 100});
  Future<ProductVariant> createVariant(
    int productId,
    VariantEditorDraft draft, {
    bool makeDefault = false,
  }) => throw UnsupportedError('Variant management is not configured.');
  Future<ProductVariant> updateVariant(
    int variantId,
    VariantEditorDraft draft,
  ) => throw UnsupportedError('Variant management is not configured.');
  Future<ProductVariant> setDefaultVariant(int variantId) =>
      throw UnsupportedError('Variant management is not configured.');
  Future<ProductVariant> archiveVariant(
    int variantId, {
    int? replacementDefaultVariantId,
  }) => throw UnsupportedError('Variant management is not configured.');
  Future<ProductVariant> restoreVariant(
    int variantId, {
    bool makeDefault = false,
  }) => throw UnsupportedError('Variant management is not configured.');
  Future<void> reorderVariants(int productId, List<VariantReorderItem> items) =>
      throw UnsupportedError('Variant management is not configured.');
}

class BackendMenuCatalogRepository implements MenuCatalogRepository {
  const BackendMenuCatalogRepository(this._apiClient);

  final DioApiClient _apiClient;

  @override
  Future<CatalogPage<ProductSummary>> listProducts({
    required ProductCatalogFilter filter,
    required int page,
    int perPage = 20,
  }) async {
    final Map<String, dynamic> query = <String, dynamic>{
      'page': page,
      'perPage': perPage,
      'status': filter.status,
      'sort': filter.sort,
      'direction': filter.direction,
    };
    _add(query, 'search', filter.search.trim());
    _add(query, 'categoryId', filter.categoryId);
    _add(query, 'reportingCategoryId', filter.reportingCategoryId);
    _add(query, 'kitchenStationId', filter.kitchenStationId);
    _add(query, 'productType', filter.productType);
    _add(query, 'hasVariants', filter.hasVariants);
    _add(query, 'hasModifierGroups', filter.hasModifierGroups);
    return _page(
      await _apiClient.getEnvelope(
        'admin/catalog/products',
        queryParameters: query,
      ),
      ProductSummary.fromJson,
    );
  }

  @override
  Future<ProductDetail> getProduct(
    int productId, {
    bool includeArchived = false,
  }) async {
    final dynamic response = await _apiClient.get(
      'admin/catalog/products/$productId',
      queryParameters: includeArchived
          ? const <String, dynamic>{'includeArchived': true}
          : null,
    );
    if (response is! Map) {
      throw const FormatException('Invalid product response.');
    }
    return ProductDetail.fromJson(Map<String, dynamic>.from(response));
  }

  @override
  Future<ProductVariant> createVariant(
    int productId,
    VariantEditorDraft draft, {
    bool makeDefault = false,
  }) async {
    final dynamic response = await _apiClient.post(
      'admin/catalog/products/$productId/variants',
      data: draft.toCreateJson(makeDefault: makeDefault),
    );
    return _variant(response);
  }

  @override
  Future<ProductVariant> updateVariant(
    int variantId,
    VariantEditorDraft draft,
  ) async => _variant(
    await _apiClient.patch(
      'admin/catalog/product-variants/$variantId',
      data: draft.toUpdateJson(),
    ),
  );

  @override
  Future<ProductVariant> setDefaultVariant(int variantId) async => _variant(
    await _apiClient.post(
      'admin/catalog/product-variants/$variantId/set-default',
    ),
  );

  @override
  Future<ProductVariant> archiveVariant(
    int variantId, {
    int? replacementDefaultVariantId,
  }) async => _variant(
    await _apiClient.post(
      'admin/catalog/product-variants/$variantId/archive',
      data: replacementDefaultVariantId == null
          ? null
          : <String, dynamic>{
              'replacementDefaultVariantId': replacementDefaultVariantId,
            },
    ),
  );

  @override
  Future<ProductVariant> restoreVariant(
    int variantId, {
    bool makeDefault = false,
  }) async => _variant(
    await _apiClient.post(
      'admin/catalog/product-variants/$variantId/restore',
      data: makeDefault ? const <String, dynamic>{'makeDefault': true} : null,
    ),
  );

  @override
  Future<void> reorderVariants(
    int productId,
    List<VariantReorderItem> items,
  ) async {
    await _apiClient.post(
      'admin/catalog/products/$productId/variants/reorder',
      data: <String, dynamic>{
        'items': items.map((item) => item.toJson()).toList(growable: false),
      },
    );
  }

  @override
  Future<ProductDetail> createProduct(ProductEditorDraft draft) async {
    final dynamic response = await _apiClient.post(
      'admin/catalog/products',
      data: draft.toCreateJson(),
    );
    return _detail(response);
  }

  @override
  Future<ProductDetail> updateProductGeneral(
    int productId,
    ProductEditorDraft draft,
  ) async {
    final dynamic response = await _apiClient.patch(
      'admin/catalog/products/$productId',
      data: draft.toUpdateJson(),
    );
    return _detail(response);
  }

  ProductDetail _detail(dynamic response) {
    if (response is! Map) {
      throw const FormatException('Invalid product response.');
    }
    return ProductDetail.fromJson(Map<String, dynamic>.from(response));
  }

  ProductVariant _variant(dynamic response) {
    if (response is! Map) {
      throw const FormatException('Invalid variant response.');
    }
    return ProductVariant.fromJson(Map<String, dynamic>.from(response));
  }

  @override
  Future<CatalogPage<CatalogCategory>> listCategories({int perPage = 100}) =>
      _references('categories', perPage, CatalogCategory.fromJson);

  @override
  Future<CatalogPage<ReportingCategory>> listReportingCategories({
    int perPage = 100,
  }) =>
      _references('reporting-categories', perPage, ReportingCategory.fromJson);

  @override
  Future<CatalogPage<KitchenStation>> listKitchenStations({
    int perPage = 100,
  }) => _references('kitchen-stations', perPage, KitchenStation.fromJson);

  Future<CatalogPage<T>> _references<T>(
    String path,
    int perPage,
    T Function(JsonMap json) converter,
  ) async => _page(
    await _apiClient.getEnvelope(
      'admin/catalog/$path',
      queryParameters: <String, dynamic>{
        'perPage': perPage,
        'status': 'active',
      },
    ),
    converter,
  );

  CatalogPage<T> _page<T>(dynamic body, T Function(JsonMap json) converter) {
    if (body is! Map) {
      throw const FormatException('Invalid paginated catalog response.');
    }
    final JsonMap envelope = Map<String, dynamic>.from(body);
    final dynamic data = envelope['data'];
    final dynamic meta = envelope['meta'];
    if (data is! List || meta is! Map) {
      throw const FormatException(
        'Catalog response is missing pagination data.',
      );
    }
    return CatalogPage<T>(
      items: data
          .whereType<Map>()
          .map((Map item) => converter(Map<String, dynamic>.from(item)))
          .toList(growable: false),
      meta: CatalogPagination.fromJson(Map<String, dynamic>.from(meta)),
    );
  }

  void _add(Map<String, dynamic> query, String key, Object? value) {
    if (value is String && value.isEmpty) {
      return;
    }
    if (value != null) query[key] = value;
  }
}

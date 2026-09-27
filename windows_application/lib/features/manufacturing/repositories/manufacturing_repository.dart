import '../../../core/network/dio_api_client.dart';
import '../../pos/models/json_helpers.dart';
import '../models/manufacturing_conversion_models.dart';
import '../models/manufacturing_models.dart';
import '../models/manufacturing_production_models.dart';
import '../models/manufacturing_recipe_models.dart';
import '../models/manufacturing_report_models.dart';

/// Data access for the Manufacturing module: Overview (Phase 1), Recipes,
/// Production, Conversion, and Reports (Phase 2+). Materials and stock
/// receipts deliberately have no methods here - they go through
/// `InventoryRepository` directly, per the app's "single inventory data
/// layer" rule.
class ManufacturingRepository {
  const ManufacturingRepository(this._api);
  final DioApiClient _api;
  Future<Map<String, dynamic>> ingredients({String search = '', int page = 1}) async =>
      Map<String, dynamic>.from(await _api.getEnvelope('manufacturing/ingredients', queryParameters: {'search': search, 'page': page, 'branchId': _api.scopeBranchId}) as Map);

  /// `GET /manufacturing/overview`. The backend returns a flat
  /// `{"data": {...}}` envelope with no pagination `meta`, so this uses
  /// [DioApiClient.get] (which unwraps `data`) rather than `getEnvelope`.
  Future<ManufacturingOverview> getOverview({int? warehouseId}) async =>
      ManufacturingOverview.fromJson(
        Map<String, dynamic>.from(
          await _api.get(
                'manufacturing/overview',
                queryParameters: <String, dynamic>{
                  if (warehouseId case final int value) 'warehouseId': value,
                },
              )
              as Map,
        ),
      );

  // ---- Recipes ----

  Future<List<ManufacturingRecipeSummary>> recipes({
    String? search,
    String? type,
    String? status,
  }) async => readMapList(
    await _api.get(
      'manufacturing/recipes',
      queryParameters: <String, dynamic>{
        if (search != null && search.isNotEmpty) 'search': search,
        if (type != null && type.isNotEmpty) 'type': type,
        if (status != null && status.isNotEmpty) 'status': status,
      },
    ),
  ).map(ManufacturingRecipeSummary.fromJson).toList(growable: false);

  Future<ManufacturingRecipeDetail> recipe(int id) async =>
      ManufacturingRecipeDetail.fromJson(
        Map<String, dynamic>.from(
          await _api.get('manufacturing/recipes/$id') as Map,
        ),
      );

  Future<ManufacturingRecipeDetail> createRecipe(
    Map<String, dynamic> payload,
  ) async => ManufacturingRecipeDetail.fromJson(
    Map<String, dynamic>.from(
      await _api.post('manufacturing/recipes', data: payload) as Map,
    ),
  );

  Future<ManufacturingRecipeDetail> updateRecipe(
    int id,
    Map<String, dynamic> payload,
  ) async => ManufacturingRecipeDetail.fromJson(
    Map<String, dynamic>.from(
      await _api.put('manufacturing/recipes/$id', data: payload) as Map,
    ),
  );

  Future<ManufacturingRecipeDetail> setRecipeStatus(
    int id,
    String status,
  ) async => ManufacturingRecipeDetail.fromJson(
    Map<String, dynamic>.from(
      await _api.patch(
            'manufacturing/recipes/$id/status',
            data: <String, dynamic>{'status': status},
          )
          as Map,
    ),
  );

  Future<ManufacturingRecipeDetail> duplicateRecipe(
    int id,
    int targetProductItemId,
  ) async => ManufacturingRecipeDetail.fromJson(
    Map<String, dynamic>.from(
      await _api.post(
            'manufacturing/recipes/$id/duplicate',
            data: <String, dynamic>{'targetProductItemId': targetProductItemId},
          )
          as Map,
    ),
  );

  // ---- Production ----

  Future<ManufacturingProductionPreview> productionPreview({
    required int recipeId,
    required String qty,
    int? warehouseId,
    int? branchId,
  }) async => ManufacturingProductionPreview.fromJson(
    Map<String, dynamic>.from(
      await _api.get(
            'manufacturing/production/preview',
            queryParameters: <String, dynamic>{
              'recipeId': recipeId,
              'qty': qty,
              if (warehouseId case final int value) 'warehouseId': value,
              if (branchId case final int value) 'branchId': value,
            },
          )
          as Map,
    ),
  );

  Future<ManufacturingProductionDraft> createProductionDraft(
    Map<String, dynamic> payload,
  ) async => ManufacturingProductionDraft.fromJson(
    Map<String, dynamic>.from(
      await _api.post('manufacturing/production/drafts', data: payload) as Map,
    ),
  );

  Future<ManufacturingProductionDraft> productionDraft(int id) async =>
      ManufacturingProductionDraft.fromJson(
        Map<String, dynamic>.from(
          await _api.get('manufacturing/production/drafts/$id') as Map,
        ),
      );

  Future<ManufacturingProductionOrder> completeProductionDraft(
    int draftId,
    Map<String, dynamic> payload,
  ) async => ManufacturingProductionOrder.fromJson(
    Map<String, dynamic>.from(
      await _api.post(
            'manufacturing/production/drafts/$draftId/complete',
            data: payload,
          )
          as Map,
    ),
  );

  Future<List<ManufacturingProductionListItem>> productionList({
    String? search,
    int? warehouseId,
    int? branchId,
    String? status,
    String? type,
  }) async => readMapList(
    await _api.get(
      'manufacturing/production',
      queryParameters: <String, dynamic>{
        if (branchId case final int value) 'branchId': value,
        if (search != null && search.isNotEmpty) 'search': search,
        if (warehouseId case final int value) 'warehouseId': value,
        if (status != null && status.isNotEmpty) 'status': status,
        if (type != null && type.isNotEmpty) 'type': type,
      },
    ),
  ).map(ManufacturingProductionListItem.fromJson).toList(growable: false);

  Future<ManufacturingProductionOrder> production(String idOrReference) async =>
      ManufacturingProductionOrder.fromJson(
        Map<String, dynamic>.from(
          await _api.get('manufacturing/production/$idOrReference') as Map,
        ),
      );

  Future<ManufacturingProductionOrder> reverseProduction(
    String idOrReference,
    String reason,
    String idempotencyKey,
  ) async => ManufacturingProductionOrder.fromJson(
    Map<String, dynamic>.from(
      await _api.post(
            'manufacturing/production/$idOrReference/reverse',
            data: <String, dynamic>{
              'reason': reason,
              'idempotencyKey': idempotencyKey,
            },
          )
          as Map,
    ),
  );

  // ---- Conversion ----

  Future<ManufacturingConversionResult> createConversion(
    Map<String, dynamic> payload,
  ) async => ManufacturingConversionResult.fromJson(
    Map<String, dynamic>.from(
      await _api.post('manufacturing/conversions', data: payload) as Map,
    ),
  );

  Future<ManufacturingConversionResult> conversion(
    String idOrReference,
  ) async => ManufacturingConversionResult.fromJson(
    Map<String, dynamic>.from(
      await _api.get('manufacturing/conversions/$idOrReference') as Map,
    ),
  );

  // ---- Reports ----

  Future<ManufacturingReportsData> reports({
    int? warehouseId,
    String? type,
    String? dateFrom,
    String? dateTo,
  }) async => ManufacturingReportsData.fromJson(
    Map<String, dynamic>.from(
      await _api.get(
            'manufacturing/reports',
            queryParameters: <String, dynamic>{
              if (warehouseId case final int value) 'warehouseId': value,
              if (type != null && type.isNotEmpty) 'type': type,
              if (dateFrom != null && dateFrom.isNotEmpty) 'dateFrom': dateFrom,
              if (dateTo != null && dateTo.isNotEmpty) 'dateTo': dateTo,
            },
          )
          as Map,
    ),
  );
}

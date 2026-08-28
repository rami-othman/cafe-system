// ignore_for_file: curly_braces_in_flow_control_structures, use_null_aware_elements

import 'package:dio/dio.dart';

import 'dart:io';

import '../../../core/network/dio_api_client.dart';
import '../../../core/debug/schedule_check_debug.dart';
import '../../pos/models/json_helpers.dart';
import '../models/catalog_models.dart';
import '../models/product_catalog_filter.dart';
import '../products/models/product_editor_draft.dart';
import '../variants/models/variant_editor_draft.dart';
import '../modifiers/models/modifier_editor_drafts.dart';
import '../modifiers/models/modifier_models.dart';
import '../products/models/product_modifier_assignment.dart';
import '../menus/models/menu_editor_draft.dart';
import '../menus/models/menu_filter.dart';
import '../menus/models/menu_models.dart';
import '../menus/models/product_placement.dart';
import '../assignments/models/menu_assignment_models.dart';
import '../../pos/models/branch.dart';
import '../pricing/models/variant_price_models.dart';
import '../availability/models/availability_models.dart';
import '../operational_availability/models/operational_availability_models.dart';
import '../review/models/review_models.dart';
import '../versions/models/published_version_models.dart';
import '../catalog_setup/models/catalog_setup_models.dart';
import '../recipes/models/recipe_models.dart';

abstract class MenuCatalogRepository {
  Future<List<RecipeMaterial>> listRecipeMaterials({String search = ''}) =>
      throw UnsupportedError('Recipes are not configured.');
  Future<VariantRecipe> getVariantRecipe(int variantId) =>
      throw UnsupportedError('Recipes are not configured.');
  Future<VariantRecipe> saveVariantRecipe(
    int variantId,
    List<RecipeComponent> components,
  ) => throw UnsupportedError('Recipes are not configured.');
  Future<ResolvedRecipe> resolveVariantRecipe(
    int variantId,
    List<Map<String, dynamic>> selectedOptions,
  ) => throw UnsupportedError('Recipes are not configured.');
  Future<ModifierRecipeProfile> getModifierRecipeProfile(
    int optionId, {
    int? productId,
    int? variantId,
  }) => throw UnsupportedError('Modifier recipe profiles are not configured.');
  Future<List<ModifierRecipeProfile>> getVariantRecipeMaterialEffects(
    int variantId,
  ) => throw UnsupportedError('Modifier recipe profiles are not configured.');
  Future<List<ModifierRecipeProfile>> getModifierGroupMaterialEffects(
    int groupId,
  ) async => const <ModifierRecipeProfile>[];
  Future<ModifierRecipeProfile> saveModifierRecipeProfile(
    int optionId,
    List<RecipeComponent> components, {
    int? productId,
    int? variantId,
  }) => throw UnsupportedError('Modifier recipe profiles are not configured.');
  Future<void> deleteModifierRecipeProfile(
    int optionId, {
    required int productId,
    int? variantId,
  }) => throw UnsupportedError('Modifier recipe profiles are not configured.');
  Future<MenuValidationResult> validateMenu(
    int menuId,
    ReviewContext context,
  ) => throw UnsupportedError('Menu review is not configured.');
  Future<MenuValidationResult> validateMenuCollection(ReviewContext context) =>
      throw UnsupportedError('Menu review is not configured.');
  Future<ResolvedPreview> previewMenu(int menuId, ReviewContext context) =>
      throw UnsupportedError('Menu review is not configured.');
  Future<MenuScheduleCheck> previewMenuSchedule(
    int menuId,
    ReviewContext context,
  ) => throw UnsupportedError('Menu review is not configured.');
  Future<ResolvedPreview> previewMenuCollection(ReviewContext context) =>
      throw UnsupportedError('Menu review is not configured.');
  Future<MenuPublicationResult> publishMenuScope(ReviewContext context) =>
      throw UnsupportedError('Menu publishing is not configured.');
  Future<PublishedMenuVersion?> getCurrentPublishedVersion(
    ReviewContext context,
  ) => throw UnsupportedError('Current menu version is not configured.');
  Future<PublishedVersionPage> listPublishedVersions({
    required int branchId,
    required String channel,
    required int page,
    int perPage = 20,
  }) => throw UnsupportedError('Published version history is not configured.');
  Future<PublishedVersionDetail> getPublishedVersion(
    int versionId, {
    bool includePayload = false,
  }) => throw UnsupportedError('Published version detail is not configured.');
  Future<VersionComparison> comparePublishedVersions(
    int versionId,
    int againstVersionId,
  ) =>
      throw UnsupportedError('Published version comparison is not configured.');
  Future<RollbackResult> rollbackPublishedVersion(
    int versionId, {
    String? reason,
  }) => throw UnsupportedError('Published version rollback is not configured.');
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
  Future<String> uploadProductImage(String filePath) =>
      throw UnsupportedError('Product image uploads are not configured.');
  Future<ProductDetail> setProductActive(int productId, bool isActive) =>
      throw UnsupportedError('Product activation is not configured.');
  Future<ProductDetail> archiveProduct(int productId) =>
      throw UnsupportedError('Product lifecycle is not configured.');
  Future<ProductDetail> restoreProduct(int productId) =>
      throw UnsupportedError('Product lifecycle is not configured.');
  Future<CatalogPage<CatalogCategory>> listCategories({int perPage = 100});
  Future<CatalogPage<ReportingCategory>> listReportingCategories({
    int perPage = 100,
  });
  Future<CatalogPage<KitchenStation>> listKitchenStations({int perPage = 100});
  Future<CatalogSetupPage> listCatalogSetup({
    required CatalogSetupKind kind,
    required CatalogSetupStatus status,
    required String search,
    required int page,
    int perPage = catalogSetupPageSize,
  }) => throw UnsupportedError('Catalog Setup is not configured.');
  Future<CatalogSetupRecord> getCatalogSetupRecord(
    CatalogSetupKind kind,
    int id, {
    bool includeArchived = false,
  }) => throw UnsupportedError('Catalog Setup is not configured.');
  Future<CatalogSetupRecord> createCatalogSetup(
    CatalogSetupKind kind,
    CatalogSetupDraft draft,
  ) => throw UnsupportedError('Catalog Setup is not configured.');
  Future<CatalogSetupRecord> updateCatalogSetup(
    CatalogSetupKind kind,
    int id,
    CatalogSetupDraft draft,
  ) => throw UnsupportedError('Catalog Setup is not configured.');
  Future<CatalogSetupRecord> archiveCatalogSetup(
    CatalogSetupKind kind,
    int id,
  ) => throw UnsupportedError('Catalog Setup is not configured.');
  Future<CatalogSetupRecord> restoreCatalogSetup(
    CatalogSetupKind kind,
    int id,
  ) => throw UnsupportedError('Catalog Setup is not configured.');
  Future<void> reorderCatalogSetup(
    CatalogSetupKind kind,
    List<CatalogSetupRecord> items,
  ) => throw UnsupportedError('Catalog Setup is not configured.');
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
  Future<VariantPriceOverridesSnapshot> listVariantPriceOverrides(
    int variantId,
  ) => throw UnsupportedError('Variant price overrides are not configured.');
  Future<VariantPriceOverridesSnapshot> syncVariantPriceOverrides(
    int variantId,
    List<VariantPriceOverrideDraft> overrides,
  ) => throw UnsupportedError('Variant price overrides are not configured.');
  Future<EffectiveVariantPrice> getEffectiveVariantPrice(
    int variantId, {
    int? branchId,
    String? channel,
  }) => throw UnsupportedError('Variant price overrides are not configured.');
  Future<ProductAvailabilityRulesSnapshot> listProductAvailabilityRules(
    int productId,
  ) => throw UnsupportedError('Scheduled availability is not configured.');
  Future<ProductAvailabilityRulesSnapshot> syncProductAvailabilityRules(
    int productId,
    List<AvailabilityRuleDraft> rules,
  ) => throw UnsupportedError('Scheduled availability is not configured.');
  Future<AvailabilityPreview> previewProductAvailability(
    int productId, {
    int? variantId,
    int? branchId,
    String? channel,
    required String dateTime,
  }) => throw UnsupportedError('Scheduled availability is not configured.');
  Future<List<OperationalAvailabilityOverride>> listProductOperationalOverrides(
    int productId,
  ) => throw UnsupportedError('Operational availability is not configured.');
  Future<OperationalAvailabilityOverride> upsertProductOperationalOverride(
    int productId,
    OperationalAvailabilityDraft draft,
  ) => throw UnsupportedError('Operational availability is not configured.');
  Future<void> clearProductOperationalOverride(
    int productId,
    int branchId,
    String channel,
  ) => throw UnsupportedError('Operational availability is not configured.');
  Future<List<OperationalAvailabilityOverride>> listVariantOperationalOverrides(
    int variantId,
  ) => throw UnsupportedError('Operational availability is not configured.');
  Future<OperationalAvailabilityOverride> upsertVariantOperationalOverride(
    int variantId,
    OperationalAvailabilityDraft draft,
  ) => throw UnsupportedError('Operational availability is not configured.');
  Future<void> clearVariantOperationalOverride(
    int variantId,
    int branchId,
    String channel,
  ) => throw UnsupportedError('Operational availability is not configured.');
  Future<OperationalAvailabilityPreview> previewProductOperationalAvailability(
    int productId, {
    required int branchId,
    required String channel,
  }) => throw UnsupportedError('Operational availability is not configured.');
  Future<OperationalAvailabilityPreview> previewVariantOperationalAvailability(
    int productId,
    int variantId, {
    required int branchId,
    required String channel,
  }) => throw UnsupportedError('Operational availability is not configured.');
  Future<CatalogPage<ModifierGroupRecord>> listModifierGroups({
    required ModifierGroupFilter filter,
    required int page,
    int perPage = 20,
  }) => throw UnsupportedError('Modifier management is not configured.');
  Future<ModifierGroupRecord> getModifierGroup(
    int groupId, {
    bool includeArchived = false,
  }) => throw UnsupportedError('Modifier management is not configured.');
  Future<ModifierGroupRecord> createModifierGroup(ModifierGroupDraft draft) =>
      throw UnsupportedError('Modifier management is not configured.');
  Future<ModifierGroupRecord> updateModifierGroup(
    int groupId,
    ModifierGroupDraft draft,
  ) => throw UnsupportedError('Modifier management is not configured.');
  Future<ModifierGroupRecord> archiveModifierGroup(int groupId) =>
      throw UnsupportedError('Modifier management is not configured.');
  Future<ModifierGroupRecord> restoreModifierGroup(int groupId) =>
      throw UnsupportedError('Modifier management is not configured.');
  Future<void> reorderModifierGroups(List<ModifierReorderItem> items) =>
      throw UnsupportedError('Modifier management is not configured.');
  Future<ModifierOptionRecord> createModifierOption(
    int groupId,
    ModifierOptionDraft draft,
  ) => throw UnsupportedError('Modifier management is not configured.');
  Future<ModifierOptionRecord> updateModifierOption(
    int optionId,
    ModifierOptionDraft draft,
  ) => throw UnsupportedError('Modifier management is not configured.');
  Future<ModifierOptionRecord> archiveModifierOption(int optionId) =>
      throw UnsupportedError('Modifier management is not configured.');
  Future<ModifierOptionRecord> restoreModifierOption(int optionId) =>
      throw UnsupportedError('Modifier management is not configured.');
  Future<void> reorderModifierOptions(
    int groupId,
    List<ModifierReorderItem> items,
  ) => throw UnsupportedError('Modifier management is not configured.');
  Future<List<ProductModifierAssignment>> getProductModifierAssignments(
    int productId,
  ) => throw UnsupportedError(
    'Product modifier assignments are not configured.',
  );
  Future<List<ProductModifierAssignment>> syncProductModifierAssignments(
    int productId,
    List<ProductModifierAssignment> assignments,
  ) => throw UnsupportedError(
    'Product modifier assignments are not configured.',
  );
  Future<ProductMenuUsage> getProductMenuUsage(int productId) =>
      throw UnsupportedError('Product menu usage is not configured.');
  Future<CatalogPage<MenuRecord>> listMenus({
    required MenuFilter filter,
    required int page,
    int perPage = 20,
  }) => throw UnsupportedError('Menu management is not configured.');
  Future<MenuRecord> getMenu(int menuId, {bool includeArchived = false}) =>
      throw UnsupportedError('Menu management is not configured.');
  Future<MenuRecord> createMenu(MenuEditorDraft draft) =>
      throw UnsupportedError('Menu management is not configured.');
  Future<MenuRecord> updateMenu(int menuId, MenuEditorDraft draft) =>
      throw UnsupportedError('Menu management is not configured.');
  Future<MenuRecord> archiveMenu(int menuId) =>
      throw UnsupportedError('Menu management is not configured.');
  Future<MenuRecord> restoreMenu(int menuId) =>
      throw UnsupportedError('Menu management is not configured.');
  Future<MenuSectionRecord> createMenuSection(
    int menuId,
    MenuSectionDraft draft,
  ) => throw UnsupportedError('Menu section management is not configured.');
  Future<MenuSectionRecord> updateMenuSection(
    int sectionId,
    MenuSectionDraft draft,
  ) => throw UnsupportedError('Menu section management is not configured.');
  Future<MenuSectionRecord> archiveMenuSection(int sectionId) =>
      throw UnsupportedError('Menu section management is not configured.');
  Future<MenuSectionRecord> restoreMenuSection(int sectionId) =>
      throw UnsupportedError('Menu section management is not configured.');
  Future<void> reorderMenuSections(
    int menuId,
    List<MenuSectionReorderItem> items,
  ) => throw UnsupportedError('Menu section management is not configured.');
  Future<List<Branch>> listAssignmentBranches() =>
      throw UnsupportedError('Menu assignment management is not configured.');
  Future<List<MenuAssignment>> listMenuAssignments({
    required int branchId,
    required String channel,
  }) => throw UnsupportedError('Menu assignment management is not configured.');
  Future<List<MenuAssignment>> syncMenuAssignments({
    required int branchId,
    required String channel,
    required List<MenuAssignmentDraft> assignments,
  }) => throw UnsupportedError('Menu assignment management is not configured.');
  Future<List<MenuScheduleRule>> listMenuAvailabilityRules(int menuId) =>
      throw UnsupportedError('Menu schedule management is not configured.');
  Future<List<MenuScheduleRule>> syncMenuAvailabilityRules(
    int menuId,
    List<Map<String, dynamic>> rules,
  ) => throw UnsupportedError('Menu schedule management is not configured.');
  Future<List<ProductPlacement>> getMenuPlacements(
    int sectionId, {
    bool includeArchived = false,
  }) =>
      throw UnsupportedError('Product placement management is not configured.');
  Future<ProductPlacement> createProductPlacement(
    int sectionId,
    ProductPlacementDraft draft,
  ) =>
      throw UnsupportedError('Product placement management is not configured.');
  Future<ProductPlacement> updateProductPlacement(
    int placementId,
    ProductPlacementDraft draft,
  ) =>
      throw UnsupportedError('Product placement management is not configured.');
  Future<ProductPlacement> moveProductPlacement(
    int placementId,
    int targetSectionId, {
    int? sortOrder,
  }) =>
      throw UnsupportedError('Product placement management is not configured.');
  Future<void> reorderSectionPlacements(
    int sectionId,
    List<PlacementReorderItem> items,
  ) =>
      throw UnsupportedError('Product placement management is not configured.');
  Future<ProductPlacement> archiveProductPlacement(int placementId) =>
      throw UnsupportedError('Product placement management is not configured.');
  Future<ProductPlacement> restoreProductPlacement(int placementId) =>
      throw UnsupportedError('Product placement management is not configured.');
}

class BackendMenuCatalogRepository implements MenuCatalogRepository {
  const BackendMenuCatalogRepository(this._apiClient);

  final DioApiClient _apiClient;
  @override
  Future<List<RecipeMaterial>> listRecipeMaterials({String search = ''}) async {
    final dynamic body = await _apiClient.get(
      'admin/catalog/materials',
      queryParameters: search.trim().isEmpty
          ? null
          : <String, dynamic>{'search': search.trim()},
    );
    if (body is! List)
      throw const FormatException('Invalid materials response.');
    return body
        .whereType<Map>()
        .map((item) => RecipeMaterial.fromJson(Map<String, dynamic>.from(item)))
        .toList(growable: false);
  }

  @override
  Future<VariantRecipe> getVariantRecipe(int variantId) async {
    final dynamic body = await _apiClient.get(
      'admin/catalog/product-variants/$variantId/recipe',
    );
    if (body is! Map) throw const FormatException('Invalid recipe response.');
    return VariantRecipe.fromJson(Map<String, dynamic>.from(body));
  }

  @override
  Future<VariantRecipe> saveVariantRecipe(
    int variantId,
    List<RecipeComponent> components,
  ) async {
    final dynamic body = await _apiClient.put(
      'admin/catalog/product-variants/$variantId/recipe',
      data: <String, dynamic>{
        'components': components.map((c) => c.toJson()).toList(),
      },
    );
    if (body is! Map) throw const FormatException('Invalid recipe response.');
    return VariantRecipe.fromJson(Map<String, dynamic>.from(body));
  }

  @override
  Future<ResolvedRecipe> resolveVariantRecipe(
    int variantId,
    List<Map<String, dynamic>> selectedOptions,
  ) async {
    final dynamic body = await _apiClient.post(
      'admin/catalog/product-variants/$variantId/recipe/resolve',
      data: <String, dynamic>{'selectedOptions': selectedOptions},
    );
    if (body is! Map)
      throw const FormatException('Invalid resolved recipe response.');
    return ResolvedRecipe.fromJson(Map<String, dynamic>.from(body));
  }

  String _profilePath(int optionId, int? productId, int? variantId) =>
      variantId != null
      ? 'admin/catalog/product-variants/$variantId/modifier-options/$optionId/recipe-adjustments'
      : productId != null
      ? 'admin/catalog/products/$productId/modifier-options/$optionId/recipe-adjustments'
      : 'admin/catalog/modifier-options/$optionId/recipe-adjustments';
  @override
  Future<ModifierRecipeProfile> getModifierRecipeProfile(
    int optionId, {
    int? productId,
    int? variantId,
  }) async {
    final dynamic body = await _apiClient.get(
      _profilePath(optionId, productId, variantId),
    );
    if (body is! Map)
      throw const FormatException('Invalid modifier recipe profile response.');
    return ModifierRecipeProfile.fromJson(Map<String, dynamic>.from(body));
  }

  @override
  Future<List<ModifierRecipeProfile>> getVariantRecipeMaterialEffects(
    int variantId,
  ) async {
    final dynamic body = await _apiClient.get(
      'admin/catalog/product-variants/$variantId/recipe-material-effects',
    );
    if (body is! List) {
      throw const FormatException('Invalid modifier recipe effects response.');
    }
    return body
        .whereType<Map>()
        .map(
          (item) =>
              ModifierRecipeProfile.fromJson(Map<String, dynamic>.from(item)),
        )
        .toList(growable: false);
  }

  @override
  Future<List<ModifierRecipeProfile>> getModifierGroupMaterialEffects(
    int groupId,
  ) async {
    final dynamic body = await _apiClient.get(
      'admin/catalog/modifier-groups/$groupId/recipe-material-effects',
    );
    if (body is! List) {
      throw const FormatException('Invalid modifier group effects response.');
    }
    return body
        .whereType<Map>()
        .map(
          (item) =>
              ModifierRecipeProfile.fromJson(Map<String, dynamic>.from(item)),
        )
        .toList(growable: false);
  }

  @override
  Future<ModifierRecipeProfile> saveModifierRecipeProfile(
    int optionId,
    List<RecipeComponent> components, {
    int? productId,
    int? variantId,
  }) async {
    final dynamic body = await _apiClient.put(
      _profilePath(optionId, productId, variantId),
      data: <String, dynamic>{
        'components': components
            .map((c) => c.toJson(includeOperation: true))
            .toList(),
      },
    );
    if (body is! Map)
      throw const FormatException('Invalid modifier recipe profile response.');
    return ModifierRecipeProfile.fromJson(Map<String, dynamic>.from(body));
  }

  @override
  Future<void> deleteModifierRecipeProfile(
    int optionId, {
    required int productId,
    int? variantId,
  }) => _apiClient.delete(_profilePath(optionId, productId, variantId));
  @override
  Future<MenuValidationResult> validateMenu(int id, ReviewContext c) async =>
      MenuValidationResult.fromJson(
        Map<String, dynamic>.from(
          await _apiClient.post(
            'admin/menus/$id/validate',
            data: c.validationJson(),
          ),
        ),
      );
  @override
  Future<MenuValidationResult> validateMenuCollection(ReviewContext c) async =>
      MenuValidationResult.fromJson(
        Map<String, dynamic>.from(
          await _apiClient.post(
            'admin/menu-management/validate',
            data: c.validationJson(),
          ),
        ),
      );
  @override
  Future<ResolvedPreview> previewMenu(int id, ReviewContext c) async =>
      ResolvedPreview.fromJson(
        Map<String, dynamic>.from(
          await _apiClient.post(
            'admin/menus/$id/preview',
            data: c.previewJson(),
          ),
        ),
      );
  @override
  Future<MenuScheduleCheck> previewMenuSchedule(int id, ReviewContext c) async {
    try {
      ScheduleCheckDebug.log(
        'parser entered: BackendMenuCatalogRepository.previewMenuSchedule',
      );
      final Map<String, dynamic> response = Map<String, dynamic>.from(
        await _apiClient.post(
          'admin/menus/$id/preview',
          data: c.previewJson(),
          debugContext: 'menu schedule preview',
        ),
      );
      final dynamic menus = response['menus'];
      if (menus is! List) {
        throw const FormatException('Invalid Menu schedule preview response.');
      }
      Map<String, dynamic>? menu;
      // Keep this schedule-only projection deliberately shallow. In particular,
      // do not cast the heterogeneous preview payload through Iterable.cast:
      // malformed optional diagnostics must never turn a valid Menu schedule
      // result into a RangeError in the manager drawer.
      for (final item in menus) {
        if (item is! Map) continue;
        final candidate = Map<String, dynamic>.from(item);
        if (readInt(candidate['id']) == id) {
          menu = candidate;
          break;
        }
      }
      if (menu == null) {
        throw const FormatException('Menu was not returned by preview.');
      }
      final result = MenuScheduleCheck(
        isScheduledAvailable: readBool(menu['isScheduledAvailable']),
        scheduleReason: readString(menu['scheduleReason']),
      );
      ScheduleCheckDebug.log(
        'parsed menuId=$id isScheduledAvailable=${result.isScheduledAvailable} '
        'scheduleReason=${result.scheduleReason}',
      );
      return result;
    } catch (error, stackTrace) {
      ScheduleCheckDebug.failure(
        'BackendMenuCatalogRepository.previewMenuSchedule',
        error,
        stackTrace,
      );
      rethrow;
    }
  }

  @override
  Future<ResolvedPreview> previewMenuCollection(ReviewContext c) async =>
      ResolvedPreview.fromJson(
        Map<String, dynamic>.from(
          await _apiClient.post(
            'admin/menu-management/preview',
            data: c.previewJson(),
          ),
        ),
      );

  @override
  Future<MenuPublicationResult> publishMenuScope(ReviewContext c) async {
    final dynamic response = await _apiClient.post(
      'admin/menu-management/publish',
      data: <String, dynamic>{
        'branchId': c.branchId,
        'channel': c.channel,
        // Omission means the backend publishes its active assigned collection.
        // Menu IDs are intentionally never part of the manager publish flow.
      },
    );
    if (response is! Map) {
      throw const FormatException('Invalid menu publication response.');
    }
    return MenuPublicationResult.fromJson(Map<String, dynamic>.from(response));
  }

  @override
  Future<CatalogSetupRecord> getCatalogSetupRecord(
    CatalogSetupKind kind,
    int id, {
    bool includeArchived = false,
  }) => _catalogSetupRecord(
    _apiClient.get(
      'admin/catalog/${kind.path}/$id',
      queryParameters: <String, dynamic>{
        if (includeArchived) 'includeArchived': true,
      },
    ),
  );

  @override
  Future<PublishedMenuVersion?> getCurrentPublishedVersion(
    ReviewContext c,
  ) async {
    final dynamic response = await _apiClient.get(
      'admin/menu-management/current-version',
      queryParameters: <String, dynamic>{
        'branchId': c.branchId,
        'channel': c.channel,
      },
    );
    if (response == null) return null;
    if (response is! Map) {
      throw const FormatException('Invalid current menu version response.');
    }
    return PublishedMenuVersion.fromJson(Map<String, dynamic>.from(response));
  }

  @override
  Future<PublishedVersionPage> listPublishedVersions({
    required int branchId,
    required String channel,
    required int page,
    int perPage = 20,
  }) async {
    final dynamic response = await _apiClient.getEnvelope(
      'admin/menu-management/versions',
      queryParameters: <String, dynamic>{
        'branchId': branchId,
        'channel': channel,
        'page': page,
        'perPage': perPage,
      },
    );
    if (response is! Map) {
      throw const FormatException(
        'Invalid published version history response.',
      );
    }
    return PublishedVersionPage.fromEnvelope(
      Map<String, dynamic>.from(response),
    );
  }

  @override
  Future<PublishedVersionDetail> getPublishedVersion(
    int versionId, {
    bool includePayload = false,
  }) async {
    final dynamic response = await _apiClient.get(
      'admin/menu-management/versions/$versionId',
      queryParameters: includePayload
          ? const <String, dynamic>{'includePayload': true}
          : null,
    );
    if (response is! Map) {
      throw const FormatException('Invalid published version detail response.');
    }
    return PublishedVersionDetail.fromJson(Map<String, dynamic>.from(response));
  }

  @override
  Future<VersionComparison> comparePublishedVersions(
    int versionId,
    int againstVersionId,
  ) async {
    final dynamic response = await _apiClient.get(
      'admin/menu-management/versions/$versionId/compare',
      queryParameters: <String, dynamic>{'againstVersionId': againstVersionId},
    );
    if (response is! Map) {
      throw const FormatException(
        'Invalid published version comparison response.',
      );
    }
    return VersionComparison.fromJson(Map<String, dynamic>.from(response));
  }

  @override
  Future<RollbackResult> rollbackPublishedVersion(
    int versionId, {
    String? reason,
  }) async {
    final dynamic response = await _apiClient.post(
      'admin/menu-management/versions/$versionId/rollback',
      data: <String, dynamic>{
        if (reason != null && reason.trim().isNotEmpty) 'reason': reason.trim(),
      },
    );
    if (response is! Map) {
      throw const FormatException(
        'Invalid published version rollback response.',
      );
    }
    return RollbackResult.fromJson(Map<String, dynamic>.from(response));
  }

  @override
  Future<CatalogPage<MenuRecord>> listMenus({
    required MenuFilter filter,
    required int page,
    int perPage = 20,
  }) async => _page(
    await _apiClient.getEnvelope(
      'admin/menus',
      queryParameters: <String, dynamic>{
        'page': page,
        'perPage': perPage,
        'status': filter.status,
        'sort': filter.sort,
        'direction': filter.direction,
        if (filter.search.trim().isNotEmpty) 'search': filter.search.trim(),
      },
    ),
    MenuRecord.fromJson,
  );

  @override
  Future<MenuRecord> getMenu(int menuId, {bool includeArchived = false}) =>
      _menu(
        _apiClient.get(
          'admin/menus/$menuId',
          queryParameters: includeArchived
              ? const <String, dynamic>{'includeArchived': true}
              : null,
        ),
      );
  @override
  Future<MenuRecord> createMenu(MenuEditorDraft draft) =>
      _menu(_apiClient.post('admin/menus', data: draft.toJson(isCreate: true)));
  @override
  Future<MenuRecord> updateMenu(int menuId, MenuEditorDraft draft) => _menu(
    _apiClient.patch(
      'admin/menus/$menuId',
      data: draft.toJson(isCreate: false),
    ),
  );
  @override
  Future<MenuRecord> archiveMenu(int menuId) =>
      _menu(_apiClient.post('admin/menus/$menuId/archive'));
  @override
  Future<MenuRecord> restoreMenu(int menuId) =>
      _menu(_apiClient.post('admin/menus/$menuId/restore'));
  @override
  Future<List<Branch>> listAssignmentBranches() async {
    final dynamic response = await _apiClient.get('branches');
    if (response is! List)
      throw const FormatException('Invalid branch response.');
    return response
        .whereType<Map>()
        .map((item) => Branch.fromJson(Map<String, dynamic>.from(item)))
        .toList(growable: false);
  }

  @override
  Future<List<MenuAssignment>> listMenuAssignments({
    required int branchId,
    required String channel,
  }) => _menuAssignments(
    _apiClient.get(
      'admin/menu-management/assignments',
      queryParameters: <String, dynamic>{
        'branchId': branchId,
        'channel': channel,
      },
    ),
  );

  @override
  Future<List<MenuAssignment>> syncMenuAssignments({
    required int branchId,
    required String channel,
    required List<MenuAssignmentDraft> assignments,
  }) => _menuAssignments(
    _apiClient.put(
      'admin/menu-management/assignments',
      data: <String, dynamic>{
        'branchId': branchId,
        'channel': channel,
        'assignments': assignments.map((item) => item.toJson()).toList(),
      },
    ),
  );

  @override
  Future<List<MenuScheduleRule>> listMenuAvailabilityRules(int menuId) =>
      _menuRules(
        _apiClient.get(
          'admin/menus/$menuId/availability-rules',
          debugMenuScheduleSave: true,
        ),
      );

  @override
  Future<List<MenuScheduleRule>> syncMenuAvailabilityRules(
    int menuId,
    List<Map<String, dynamic>> rules,
  ) => _menuRules(
    _apiClient.put(
      'admin/menus/$menuId/availability-rules',
      data: <String, dynamic>{'rules': rules},
      debugMenuScheduleSave: true,
    ),
  );
  @override
  Future<MenuSectionRecord> createMenuSection(
    int menuId,
    MenuSectionDraft draft,
  ) => _section(
    _apiClient.post('admin/menus/$menuId/sections', data: draft.toJson()),
  );
  @override
  Future<MenuSectionRecord> updateMenuSection(
    int sectionId,
    MenuSectionDraft draft,
  ) => _section(
    _apiClient.patch('admin/menu-sections/$sectionId', data: draft.toJson()),
  );
  @override
  Future<MenuSectionRecord> archiveMenuSection(int sectionId) =>
      _section(_apiClient.post('admin/menu-sections/$sectionId/archive'));
  @override
  Future<MenuSectionRecord> restoreMenuSection(int sectionId) =>
      _section(_apiClient.post('admin/menu-sections/$sectionId/restore'));
  @override
  Future<void> reorderMenuSections(
    int menuId,
    List<MenuSectionReorderItem> items,
  ) => _apiClient.post(
    'admin/menus/$menuId/sections/reorder',
    data: <String, dynamic>{
      'items': items.map((item) => item.toJson()).toList(growable: false),
    },
  );

  @override
  Future<List<ProductPlacement>> getMenuPlacements(
    int sectionId, {
    bool includeArchived = false,
  }) async {
    final dynamic body = await _apiClient.get(
      'admin/menu-sections/$sectionId/placements',
      queryParameters: includeArchived
          ? const <String, dynamic>{'includeArchived': true}
          : null,
    );
    if (body is! List)
      throw const FormatException('Invalid placement response.');
    return body
        .whereType<Map>()
        .map(
          (item) => ProductPlacement.fromJson(Map<String, dynamic>.from(item)),
        )
        .toList(growable: false);
  }

  @override
  Future<ProductPlacement> createProductPlacement(
    int sectionId,
    ProductPlacementDraft draft,
  ) async => _placement(
    await _apiClient.post(
      'admin/menu-sections/$sectionId/placements',
      data: draft.toCreateJson(),
    ),
  );
  @override
  Future<ProductPlacement> updateProductPlacement(
    int placementId,
    ProductPlacementDraft draft,
  ) async => _placement(
    await _apiClient.patch(
      'admin/menu-item-placements/$placementId',
      data: draft.toUpdateJson(),
    ),
  );
  @override
  Future<ProductPlacement> moveProductPlacement(
    int placementId,
    int targetSectionId, {
    int? sortOrder,
  }) async => _placement(
    await _apiClient.post(
      'admin/menu-item-placements/$placementId/move',
      data: <String, dynamic>{
        'targetSectionId': targetSectionId,
        if (sortOrder != null) 'sortOrder': sortOrder,
      },
    ),
  );
  @override
  Future<void> reorderSectionPlacements(
    int sectionId,
    List<PlacementReorderItem> items,
  ) => _apiClient.post(
    'admin/menu-sections/$sectionId/placements/reorder',
    data: <String, dynamic>{
      'items': items.map((item) => item.toJson()).toList(growable: false),
    },
  );
  @override
  Future<ProductPlacement> archiveProductPlacement(int placementId) async =>
      _placement(
        await _apiClient.post(
          'admin/menu-item-placements/$placementId/archive',
        ),
      );
  @override
  Future<ProductPlacement> restoreProductPlacement(int placementId) async =>
      _placement(
        await _apiClient.post(
          'admin/menu-item-placements/$placementId/restore',
        ),
      );

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
  Future<VariantPriceOverridesSnapshot> listVariantPriceOverrides(
    int variantId,
  ) async => _priceOverrides(
    await _apiClient.get(
      'admin/catalog/product-variants/$variantId/price-overrides',
    ),
  );

  @override
  Future<VariantPriceOverridesSnapshot> syncVariantPriceOverrides(
    int variantId,
    List<VariantPriceOverrideDraft> overrides,
  ) async => _priceOverrides(
    await _apiClient.put(
      'admin/catalog/product-variants/$variantId/price-overrides',
      data: <String, dynamic>{
        'overrides': overrides
            .map((item) => item.toJson())
            .toList(growable: false),
      },
    ),
  );

  @override
  Future<EffectiveVariantPrice> getEffectiveVariantPrice(
    int variantId, {
    int? branchId,
    String? channel,
  }) async => _effectivePrice(
    await _apiClient.get(
      'admin/catalog/product-variants/$variantId/effective-price',
      queryParameters: <String, dynamic>{
        if (branchId != null) 'branchId': branchId,
        if (channel != null) 'channel': channel,
      },
    ),
  );

  @override
  Future<ProductAvailabilityRulesSnapshot> listProductAvailabilityRules(
    int productId,
  ) async => _availabilityRules(
    await _apiClient.get(
      'admin/catalog/products/$productId/availability-rules',
    ),
  );

  @override
  Future<ProductAvailabilityRulesSnapshot> syncProductAvailabilityRules(
    int productId,
    List<AvailabilityRuleDraft> rules,
  ) async => _availabilityRules(
    await _apiClient.put(
      'admin/catalog/products/$productId/availability-rules',
      data: <String, dynamic>{
        'rules': rules.map((item) => item.toJson()).toList(growable: false),
      },
    ),
  );

  @override
  Future<AvailabilityPreview> previewProductAvailability(
    int productId, {
    int? variantId,
    int? branchId,
    String? channel,
    required String dateTime,
  }) async => _availabilityPreview(
    await _apiClient.get(
      'admin/catalog/products/$productId/availability-preview',
      queryParameters: <String, dynamic>{
        if (variantId != null) 'productVariantId': variantId,
        if (branchId != null) 'branchId': branchId,
        if (channel != null) 'channel': channel,
        'dateTime': dateTime,
      },
    ),
  );

  @override
  Future<List<OperationalAvailabilityOverride>> listProductOperationalOverrides(
    int productId,
  ) async => (await _listOperationalOverrides(
    level: 'product',
  )).where((item) => item.productId == productId).toList(growable: false);

  @override
  Future<OperationalAvailabilityOverride> upsertProductOperationalOverride(
    int productId,
    OperationalAvailabilityDraft draft,
  ) async => _operationalOverride(
    await _apiClient.put(
      'admin/catalog/products/$productId/operational-availability',
      data: draft.toJson(),
    ),
  );

  @override
  Future<void> clearProductOperationalOverride(
    int productId,
    int branchId,
    String channel,
  ) async {
    await _apiClient.delete(
      'admin/catalog/products/$productId/operational-availability',
      queryParameters: <String, dynamic>{
        'branchId': branchId,
        'channel': channel,
      },
    );
  }

  @override
  Future<List<OperationalAvailabilityOverride>> listVariantOperationalOverrides(
    int variantId,
  ) async => (await _listOperationalOverrides(level: 'variant'))
      .where((item) => item.productVariantId == variantId)
      .toList(growable: false);

  @override
  Future<OperationalAvailabilityOverride> upsertVariantOperationalOverride(
    int variantId,
    OperationalAvailabilityDraft draft,
  ) async => _operationalOverride(
    await _apiClient.put(
      'admin/catalog/product-variants/$variantId/operational-availability',
      data: draft.toJson(),
    ),
  );

  @override
  Future<void> clearVariantOperationalOverride(
    int variantId,
    int branchId,
    String channel,
  ) async {
    await _apiClient.delete(
      'admin/catalog/product-variants/$variantId/operational-availability',
      queryParameters: <String, dynamic>{
        'branchId': branchId,
        'channel': channel,
      },
    );
  }

  @override
  Future<OperationalAvailabilityPreview> previewProductOperationalAvailability(
    int productId, {
    required int branchId,
    required String channel,
  }) => _operationalPreview(
    _apiClient.get(
      'admin/catalog/products/$productId/operational-availability-preview',
      queryParameters: <String, dynamic>{
        'branchId': branchId,
        'channel': channel,
      },
    ),
  );

  @override
  Future<OperationalAvailabilityPreview> previewVariantOperationalAvailability(
    int productId,
    int variantId, {
    required int branchId,
    required String channel,
  }) => _operationalPreview(
    _apiClient.get(
      'admin/catalog/products/$productId/operational-availability-preview',
      queryParameters: <String, dynamic>{
        'productVariantId': variantId,
        'branchId': branchId,
        'channel': channel,
      },
    ),
  );

  @override
  Future<CatalogPage<ModifierGroupRecord>> listModifierGroups({
    required ModifierGroupFilter filter,
    required int page,
    int perPage = 20,
  }) async => _page(
    await _apiClient.getEnvelope(
      'admin/catalog/modifier-groups',
      queryParameters: <String, dynamic>{
        'page': page,
        'perPage': perPage,
        'status': filter.status,
        if (filter.search.trim().isNotEmpty) 'search': filter.search.trim(),
        if (filter.groupType != null) 'groupType': filter.groupType,
        if (filter.selectionType != null) 'selectionType': filter.selectionType,
      },
    ),
    ModifierGroupRecord.fromJson,
  );
  @override
  Future<ModifierGroupRecord> getModifierGroup(
    int groupId, {
    bool includeArchived = false,
  }) => _modifierGroup(
    _apiClient.get(
      'admin/catalog/modifier-groups/$groupId',
      queryParameters: includeArchived
          ? const <String, dynamic>{'includeArchived': true}
          : null,
    ),
  );
  @override
  Future<ModifierGroupRecord> createModifierGroup(ModifierGroupDraft draft) =>
      _modifierGroup(
        _apiClient.post(
          'admin/catalog/modifier-groups',
          data: draft.toCreateJson(),
        ),
      );
  @override
  Future<ModifierGroupRecord> updateModifierGroup(
    int groupId,
    ModifierGroupDraft draft,
  ) => _modifierGroup(
    _apiClient.patch(
      'admin/catalog/modifier-groups/$groupId',
      data: draft.toUpdateJson(),
    ),
  );
  @override
  Future<ModifierGroupRecord> archiveModifierGroup(int groupId) =>
      _modifierGroup(
        _apiClient.post('admin/catalog/modifier-groups/$groupId/archive'),
      );
  @override
  Future<ModifierGroupRecord> restoreModifierGroup(int groupId) =>
      _modifierGroup(
        _apiClient.post('admin/catalog/modifier-groups/$groupId/restore'),
      );
  @override
  Future<void> reorderModifierGroups(List<ModifierReorderItem> items) =>
      _apiClient.post(
        'admin/catalog/modifier-groups/reorder',
        data: <String, dynamic>{
          'items': items.map((item) => item.toJson()).toList(growable: false),
        },
      );
  @override
  Future<ModifierOptionRecord> createModifierOption(
    int groupId,
    ModifierOptionDraft draft,
  ) => _modifierOption(
    _apiClient.post(
      'admin/catalog/modifier-groups/$groupId/options',
      data: draft.toJson(),
    ),
  );
  @override
  Future<ModifierOptionRecord> updateModifierOption(
    int optionId,
    ModifierOptionDraft draft,
  ) => _modifierOption(
    _apiClient.patch(
      'admin/catalog/modifier-options/$optionId',
      data: draft.toJson(),
    ),
  );
  @override
  Future<ModifierOptionRecord> archiveModifierOption(int optionId) =>
      _modifierOption(
        _apiClient.post('admin/catalog/modifier-options/$optionId/archive'),
      );
  @override
  Future<ModifierOptionRecord> restoreModifierOption(int optionId) =>
      _modifierOption(
        _apiClient.post('admin/catalog/modifier-options/$optionId/restore'),
      );
  @override
  Future<void> reorderModifierOptions(
    int groupId,
    List<ModifierReorderItem> items,
  ) => _apiClient.post(
    'admin/catalog/modifier-groups/$groupId/options/reorder',
    data: <String, dynamic>{
      'items': items.map((item) => item.toJson()).toList(growable: false),
    },
  );

  @override
  Future<List<ProductModifierAssignment>> getProductModifierAssignments(
    int productId,
  ) => _assignments(
    _apiClient.get('admin/catalog/products/$productId/modifier-groups'),
  );

  @override
  Future<List<ProductModifierAssignment>> syncProductModifierAssignments(
    int productId,
    List<ProductModifierAssignment> assignments,
  ) => _assignments(
    _apiClient.put(
      'admin/catalog/products/$productId/modifier-groups',
      data: <String, dynamic>{
        'groups': assignments
            .map((item) => item.toSyncJson())
            .toList(growable: false),
      },
    ),
  );

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

  @override
  Future<String> uploadProductImage(String filePath) async {
    final dynamic response = await _apiClient.postMultipart(
      'admin/catalog/product-images',
      data: FormData.fromMap(<String, dynamic>{
        'image': await MultipartFile.fromFile(
          filePath,
          filename: File(filePath).uri.pathSegments.last,
        ),
      }),
    );
    final dynamic url = (response as Map<String, dynamic>)['url'];
    if (url is! String || url.trim().isEmpty) {
      throw const FormatException('The uploaded image URL was missing.');
    }
    return url;
  }

  @override
  Future<ProductDetail> setProductActive(int productId, bool isActive) async =>
      _detail(
        await _apiClient.patch(
          'admin/catalog/products/$productId',
          data: <String, dynamic>{'isActive': isActive},
        ),
      );

  @override
  Future<ProductDetail> archiveProduct(int productId) async => _detail(
    await _apiClient.post('admin/catalog/products/$productId/archive'),
  );

  @override
  Future<ProductDetail> restoreProduct(int productId) async => _detail(
    await _apiClient.post('admin/catalog/products/$productId/restore'),
  );

  @override
  Future<ProductMenuUsage> getProductMenuUsage(int productId) async {
    final dynamic response = await _apiClient.get(
      'admin/catalog/products/$productId/menu-usage',
    );
    if (response is! Map) {
      throw const FormatException('Invalid product menu usage response.');
    }
    return ProductMenuUsage.fromJson(Map<String, dynamic>.from(response));
  }

  ProductDetail _detail(dynamic response) {
    if (response is! Map) {
      throw const FormatException('Invalid product response.');
    }
    return ProductDetail.fromJson(Map<String, dynamic>.from(response));
  }

  ProductPlacement _placement(dynamic response) {
    if (response is! Map)
      throw const FormatException('Invalid placement response.');
    return ProductPlacement.fromJson(Map<String, dynamic>.from(response));
  }

  Future<MenuRecord> _menu(Future<dynamic> response) async {
    final dynamic body = await response;
    if (body is! Map) throw const FormatException('Invalid menu response.');
    return MenuRecord.fromJson(Map<String, dynamic>.from(body));
  }

  Future<MenuSectionRecord> _section(Future<dynamic> response) async {
    final dynamic body = await response;
    if (body is! Map)
      throw const FormatException('Invalid menu section response.');
    return MenuSectionRecord.fromJson(Map<String, dynamic>.from(body));
  }

  ProductVariant _variant(dynamic response) {
    if (response is! Map) {
      throw const FormatException('Invalid variant response.');
    }
    return ProductVariant.fromJson(Map<String, dynamic>.from(response));
  }

  VariantPriceOverridesSnapshot _priceOverrides(dynamic response) {
    if (response is! Map) {
      throw const FormatException('Invalid price override response.');
    }
    return VariantPriceOverridesSnapshot.fromJson(
      Map<String, dynamic>.from(response),
    );
  }

  EffectiveVariantPrice _effectivePrice(dynamic response) {
    if (response is! Map) {
      throw const FormatException('Invalid effective price response.');
    }
    return EffectiveVariantPrice.fromJson(Map<String, dynamic>.from(response));
  }

  ProductAvailabilityRulesSnapshot _availabilityRules(dynamic response) {
    if (response is! Map) {
      throw const FormatException('Invalid availability rule response.');
    }
    return ProductAvailabilityRulesSnapshot.fromJson(
      Map<String, dynamic>.from(response),
    );
  }

  AvailabilityPreview _availabilityPreview(dynamic response) {
    if (response is! Map) {
      throw const FormatException('Invalid availability preview response.');
    }
    return AvailabilityPreview.fromJson(Map<String, dynamic>.from(response));
  }

  Future<List<OperationalAvailabilityOverride>> _listOperationalOverrides({
    required String level,
  }) async {
    final List<OperationalAvailabilityOverride> result =
        <OperationalAvailabilityOverride>[];
    int page = 1;
    int lastPage = 1;
    do {
      final dynamic body = await _apiClient.getEnvelope(
        'admin/catalog/operational-availability',
        queryParameters: <String, dynamic>{
          'level': level,
          'includeArchived': true,
          'perPage': 100,
          'page': page,
        },
      );
      if (body is! Map)
        throw const FormatException(
          'Invalid operational availability response.',
        );
      final dynamic rows = body['data'];
      if (rows is! List)
        throw const FormatException(
          'Invalid operational availability response.',
        );
      for (final Map row in rows.whereType<Map>()) {
        final OperationalAvailabilityOverride item =
            OperationalAvailabilityOverride.fromJson(
              Map<String, dynamic>.from(row),
            );
        if (result.every((existing) => existing.id != item.id)) {
          result.add(item);
        }
      }
      final dynamic meta = body['meta'];
      lastPage = meta is Map ? (meta['last_page'] as num?)?.toInt() ?? 1 : 1;
      page++;
    } while (page <= lastPage);
    return List<OperationalAvailabilityOverride>.unmodifiable(result);
  }

  OperationalAvailabilityOverride _operationalOverride(dynamic response) {
    if (response is! Map)
      throw const FormatException('Invalid operational availability response.');
    return OperationalAvailabilityOverride.fromJson(
      Map<String, dynamic>.from(response),
    );
  }

  Future<OperationalAvailabilityPreview> _operationalPreview(
    Future<dynamic> response,
  ) async {
    final dynamic body = await response;
    if (body is! Map) {
      throw const FormatException('Invalid operational resolution response.');
    }
    return OperationalAvailabilityPreview.fromJson(
      Map<String, dynamic>.from(body),
    );
  }

  Future<ModifierGroupRecord> _modifierGroup(Future<dynamic> response) async {
    final dynamic body = await response;
    if (body is! Map)
      throw const FormatException('Invalid modifier group response.');
    return ModifierGroupRecord.fromJson(Map<String, dynamic>.from(body));
  }

  Future<ModifierOptionRecord> _modifierOption(Future<dynamic> response) async {
    final dynamic body = await response;
    if (body is! Map)
      throw const FormatException('Invalid modifier option response.');
    return ModifierOptionRecord.fromJson(Map<String, dynamic>.from(body));
  }

  Future<List<ProductModifierAssignment>> _assignments(
    Future<dynamic> response,
  ) async {
    final dynamic body = await response;
    if (body is! List) {
      throw const FormatException(
        'Invalid product modifier assignments response.',
      );
    }
    return body
        .whereType<Map>()
        .map(
          (item) => ProductModifierAssignment.fromJson(
            Map<String, dynamic>.from(item),
          ),
        )
        .toList(growable: false);
  }

  Future<List<MenuAssignment>> _menuAssignments(
    Future<dynamic> response,
  ) async {
    final dynamic body = await response;
    if (body is! List) {
      throw const FormatException('Invalid menu assignments response.');
    }
    return body
        .whereType<Map>()
        .map((item) => MenuAssignment.fromJson(Map<String, dynamic>.from(item)))
        .toList(growable: false);
  }

  Future<List<MenuScheduleRule>> _menuRules(Future<dynamic> response) async {
    final dynamic body = await response;
    // Dio normally unwraps Laravel's `data` field. Accept the envelope as
    // well because schedule rules are fetched on demand and must not fail
    // merely because a runtime transport returned the complete JSON body.
    final dynamic rows = body is Map ? body['data'] : body;
    if (rows is! List) {
      throw const FormatException('Invalid menu availability rules response.');
    }
    return rows
        .whereType<Map>()
        .map(
          (item) => MenuScheduleRule.fromJson(Map<String, dynamic>.from(item)),
        )
        .toList(growable: false);
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

  @override
  Future<CatalogSetupPage> listCatalogSetup({
    required CatalogSetupKind kind,
    required CatalogSetupStatus status,
    required String search,
    required int page,
    int perPage = catalogSetupPageSize,
  }) async {
    final dynamic response = await _apiClient.getEnvelope(
      'admin/catalog/${kind.path}',
      queryParameters: <String, dynamic>{
        'status': status.value,
        'page': page,
        'perPage': perPage,
        if (search.trim().isNotEmpty) 'search': search.trim(),
      },
    );
    if (response is! Map)
      throw const FormatException('Invalid Catalog Setup response.');
    final CatalogPage<CatalogSetupRecord> pageResult = _page(
      response,
      CatalogSetupRecord.fromJson,
    );
    return CatalogSetupPage(items: pageResult.items, meta: pageResult.meta);
  }

  @override
  Future<CatalogSetupRecord> createCatalogSetup(
    CatalogSetupKind kind,
    CatalogSetupDraft draft,
  ) => _catalogSetupRecord(
    _apiClient.post('admin/catalog/${kind.path}', data: draft.toJson(kind)),
  );

  @override
  Future<CatalogSetupRecord> updateCatalogSetup(
    CatalogSetupKind kind,
    int id,
    CatalogSetupDraft draft,
  ) => _catalogSetupRecord(
    _apiClient.patch(
      'admin/catalog/${kind.path}/$id',
      data: draft.toJson(kind),
    ),
  );

  @override
  Future<CatalogSetupRecord> archiveCatalogSetup(
    CatalogSetupKind kind,
    int id,
  ) => _catalogSetupRecord(
    _apiClient.post('admin/catalog/${kind.path}/$id/archive'),
  );

  @override
  Future<CatalogSetupRecord> restoreCatalogSetup(
    CatalogSetupKind kind,
    int id,
  ) => _catalogSetupRecord(
    _apiClient.post('admin/catalog/${kind.path}/$id/restore'),
  );

  @override
  Future<void> reorderCatalogSetup(
    CatalogSetupKind kind,
    List<CatalogSetupRecord> items,
  ) async {
    await _apiClient.post(
      'admin/catalog/${kind.path}/reorder',
      data: <String, dynamic>{
        'items': items
            .asMap()
            .entries
            .map(
              (entry) => <String, dynamic>{
                'id': entry.value.id,
                'sortOrder': entry.key,
              },
            )
            .toList(growable: false),
      },
    );
  }

  Future<CatalogSetupRecord> _catalogSetupRecord(
    Future<dynamic> response,
  ) async {
    final dynamic body = await response;
    if (body is! Map)
      throw const FormatException('Invalid Catalog Setup response.');
    return CatalogSetupRecord.fromJson(Map<String, dynamic>.from(body));
  }

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

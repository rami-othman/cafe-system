import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/network/api_exception.dart';
import '../../catalog_setup/models/catalog_setup_models.dart';
import '../../models/catalog_models.dart';
import '../../repositories/menu_catalog_repository.dart';
import '../../pricing/configured_price_validation.dart';
import '../models/product_editor_draft.dart';
import '../models/selected_product_image.dart';
import 'product_editor_state.dart';

class ProductEditorCubit extends Cubit<ProductEditorState> {
  ProductEditorCubit({required this.repository})
    : super(const ProductEditorState());
  final MenuCatalogRepository repository;

  Future<void> initializeCreate() async {
    emit(const ProductEditorState(status: ProductEditorStatus.loading));
    await _loadReferences();
    emit(state.copyWith(status: ProductEditorStatus.ready));
  }

  Future<void> loadForEdit(int productId) async {
    emit(
      ProductEditorState(
        status: ProductEditorStatus.loading,
        productId: productId,
      ),
    );
    try {
      final ProductDetail product = await repository.getProduct(
        productId,
        includeArchived: true,
      );
      if (product.isArchived) {
        emit(
          state.copyWith(
            status: ProductEditorStatus.failure,
            isReadOnly: true,
            formError: 'This product has been archived and is read-only.',
          ),
        );
        return;
      }
      emit(
        state.copyWith(
          draft: _draft(product),
          currentDefaultVariant: product.defaultVariant,
          status: ProductEditorStatus.loading,
          isDirty: false,
          isReadOnly: false,
        ),
      );
      await _loadReferences();
      _retainSelectedReferences(product);
      emit(state.copyWith(status: ProductEditorStatus.ready, isDirty: false));
    } catch (error) {
      emit(
        state.copyWith(
          status: ProductEditorStatus.failure,
          formError: _message(error),
        ),
      );
    }
  }

  Future<void> retry() =>
      state.isCreate ? initializeCreate() : loadForEdit(state.productId!);
  Future<void> updateDraft(ProductEditorDraft draft) async => emit(
    state.copyWith(
      draft: draft,
      isDirty: true,
      clearFieldErrors: true,
      clearFormError: true,
      clearImageUploadError: true,
    ),
  );

  Future<void> uploadImage(SelectedProductImage image) async {
    if (state.isUploadingImage || state.isReadOnly) return;
    emit(
      state.copyWith(
        isUploadingImage: true,
        clearImageUploadError: true,
        clearFormError: true,
      ),
    );
    try {
      final String imageUrl = await repository.uploadProductImage(image);
      emit(
        state.copyWith(
          draft: state.draft.copyWith(imageUrl: imageUrl),
          isDirty: true,
          isUploadingImage: false,
          clearImageUploadError: true,
        ),
      );
    } catch (error) {
      emit(
        state.copyWith(
          isUploadingImage: false,
          imageUploadError: _message(error),
        ),
      );
    }
  }

  Future<void> refreshReferences() async {
    final CatalogCategory? previousCategory = _categoryForId(
      state.categories,
      state.draft.categoryId,
    );
    final ReportingCategory? previousReportingCategory =
        _reportingCategoryForId(
          state.reportingCategories,
          state.draft.reportingCategoryId,
        );
    final KitchenStation? previousKitchenStation = _kitchenStationForId(
      state.kitchenStations,
      state.draft.kitchenStationId,
    );
    await _loadReferences();
    await _restoreArchivedSelections(
      previousCategory: previousCategory,
      previousReportingCategory: previousReportingCategory,
      previousKitchenStation: previousKitchenStation,
    );
  }

  Future<void> submit() async {
    if (state.status == ProductEditorStatus.submitting || state.isReadOnly) {
      return;
    }
    final Map<String, String> errors = _validate(
      state.draft,
      create: state.isCreate,
    );
    if (errors.isNotEmpty) {
      emit(
        state.copyWith(
          status: ProductEditorStatus.failure,
          fieldErrors: errors,
          clearFormError: true,
        ),
      );
      return;
    }
    emit(
      state.copyWith(
        status: ProductEditorStatus.submitting,
        clearFieldErrors: true,
        clearFormError: true,
      ),
    );
    try {
      final ProductDetail saved = state.isCreate
          ? await repository.createProduct(state.draft)
          : await repository.updateProductGeneral(
              state.productId!,
              state.draft,
            );
      emit(
        state.copyWith(
          status: ProductEditorStatus.success,
          savedProduct: saved,
          isDirty: false,
        ),
      );
    } catch (error) {
      if (error is ApiException && error.validationErrors != null) {
        emit(
          state.copyWith(
            status: ProductEditorStatus.failure,
            fieldErrors: _fieldErrors(error.validationErrors!),
            formError: _nonFieldMessage(error.validationErrors!, error.message),
          ),
        );
        return;
      }
      emit(
        state.copyWith(
          status: ProductEditorStatus.failure,
          formError: _message(error),
        ),
      );
    }
  }

  Future<void> _loadReferences() async {
    final Map<String, String> errors = <String, String>{};
    try {
      emit(
        state.copyWith(categories: (await repository.listCategories()).items),
      );
    } catch (error) {
      errors['Categories'] = _message(error);
    }
    try {
      emit(
        state.copyWith(
          reportingCategories:
              (await repository.listReportingCategories()).items,
        ),
      );
    } catch (error) {
      errors['Reporting categories'] = _message(error);
    }
    try {
      emit(
        state.copyWith(
          kitchenStations: (await repository.listKitchenStations()).items,
        ),
      );
    } catch (error) {
      errors['Kitchen stations'] = _message(error);
    }
    emit(state.copyWith(referenceErrors: errors));
  }

  void _retainSelectedReferences(ProductDetail product) {
    final CatalogCategory? category = product.category;
    final ReportingCategory? reporting = product.reportingCategory;
    final KitchenStation? station = product.kitchenStation;
    emit(
      state.copyWith(
        categories:
            category != null &&
                !state.categories.any((item) => item.id == category.id)
            ? <CatalogCategory>[...state.categories, category]
            : state.categories,
        reportingCategories:
            reporting != null &&
                !state.reportingCategories.any(
                  (item) => item.id == reporting.id,
                )
            ? <ReportingCategory>[...state.reportingCategories, reporting]
            : state.reportingCategories,
        kitchenStations:
            station != null &&
                !state.kitchenStations.any((item) => item.id == station.id)
            ? <KitchenStation>[...state.kitchenStations, station]
            : state.kitchenStations,
      ),
    );
  }

  Future<void> _restoreArchivedSelections({
    CatalogCategory? previousCategory,
    ReportingCategory? previousReportingCategory,
    KitchenStation? previousKitchenStation,
  }) async {
    final List<String> errors = <String>[];
    final int? categoryId = state.draft.categoryId;
    final int? reportingCategoryId = state.draft.reportingCategoryId;
    final int? kitchenStationId = state.draft.kitchenStationId;

    if (categoryId != null &&
        !state.categories.any((item) => item.id == categoryId)) {
      try {
        final record = await repository.getCatalogSetupRecord(
          CatalogSetupKind.categories,
          categoryId,
          includeArchived: true,
        );
        emit(
          state.copyWith(
            categories: <CatalogCategory>[
              ...state.categories,
              CatalogCategory(
                id: record.id,
                name: record.name,
                isActive: record.isActive,
                sortOrder: record.sortOrder,
              ),
            ],
          ),
        );
      } catch (_) {
        if (previousCategory != null) {
          emit(
            state.copyWith(
              categories: <CatalogCategory>[
                ...state.categories,
                previousCategory,
              ],
            ),
          );
        }
        errors.add('Categories');
      }
    }
    if (reportingCategoryId != null &&
        !state.reportingCategories.any(
          (item) => item.id == reportingCategoryId,
        )) {
      try {
        final record = await repository.getCatalogSetupRecord(
          CatalogSetupKind.reportingCategories,
          reportingCategoryId,
          includeArchived: true,
        );
        emit(
          state.copyWith(
            reportingCategories: <ReportingCategory>[
              ...state.reportingCategories,
              ReportingCategory(
                id: record.id,
                name: record.name,
                code: record.code,
                isActive: record.isActive,
                sortOrder: record.sortOrder,
              ),
            ],
          ),
        );
      } catch (_) {
        if (previousReportingCategory != null) {
          emit(
            state.copyWith(
              reportingCategories: <ReportingCategory>[
                ...state.reportingCategories,
                previousReportingCategory,
              ],
            ),
          );
        }
        errors.add('Reporting categories');
      }
    }
    if (kitchenStationId != null &&
        !state.kitchenStations.any((item) => item.id == kitchenStationId)) {
      try {
        final record = await repository.getCatalogSetupRecord(
          CatalogSetupKind.kitchenStations,
          kitchenStationId,
          includeArchived: true,
        );
        emit(
          state.copyWith(
            kitchenStations: <KitchenStation>[
              ...state.kitchenStations,
              KitchenStation(
                id: record.id,
                name: record.name,
                code: record.code,
                branchId: record.branchId,
                branchName: '',
                isActive: record.isActive,
                sortOrder: record.sortOrder,
              ),
            ],
          ),
        );
      } catch (_) {
        if (previousKitchenStation != null) {
          emit(
            state.copyWith(
              kitchenStations: <KitchenStation>[
                ...state.kitchenStations,
                previousKitchenStation,
              ],
            ),
          );
        }
        errors.add('Kitchen stations');
      }
    }
    if (errors.isNotEmpty) {
      emit(
        state.copyWith(
          referenceErrors: <String, String>{
            ...state.referenceErrors,
            for (final String key in errors)
              key: 'The selected archived reference could not be refreshed.',
          },
        ),
      );
    }
  }

  CatalogCategory? _categoryForId(List<CatalogCategory> records, int? id) {
    for (final CatalogCategory record in records) {
      if (record.id == id) return record;
    }
    return null;
  }

  ReportingCategory? _reportingCategoryForId(
    List<ReportingCategory> records,
    int? id,
  ) {
    for (final ReportingCategory record in records) {
      if (record.id == id) return record;
    }
    return null;
  }

  KitchenStation? _kitchenStationForId(List<KitchenStation> records, int? id) {
    for (final KitchenStation record in records) {
      if (record.id == id) return record;
    }
    return null;
  }

  ProductEditorDraft _draft(ProductDetail p) => ProductEditorDraft(
    name: p.name,
    nameAr: p.nameAr ?? '',
    nameEn: p.nameEn ?? '',
    description: p.description ?? '',
    descriptionAr: p.descriptionAr ?? '',
    descriptionEn: p.descriptionEn ?? '',
    imageUrl: p.imageUrl ?? '',
    categoryId: p.category?.id,
    reportingCategoryId: p.reportingCategory?.id,
    kitchenStationId: p.kitchenStation?.id,
    productType: p.productType == 'open_price' ? 'open_price' : 'standard',
    preparationTimeMinutes: p.preparationTimeMinutes?.toString() ?? '',
    isStockTracked: p.isStockTracked,
    sortOrder: p.sortOrder.toString(),
  );
  Map<String, String> _validate(
    ProductEditorDraft draft, {
    required bool create,
  }) {
    final Map<String, String> errors = <String, String>{};
    final RegExp decimal = RegExp(r'^\d+(\.\d{1,2})?$');
    if (draft.name.trim().isEmpty) {
      errors['name'] = 'Product name is required.';
    }
    if (draft.categoryId == null) {
      errors['categoryId'] = 'Catalog category is required.';
    }
    if (!<String>['standard', 'open_price'].contains(draft.productType)) {
      errors['productType'] = 'Select a valid product type.';
    }
    if (draft.preparationTimeMinutes.trim().isNotEmpty &&
        (int.tryParse(draft.preparationTimeMinutes) == null ||
            int.parse(draft.preparationTimeMinutes) < 0)) {
      errors['preparationTimeMinutes'] =
          'Enter zero or a positive whole number.';
    }
    if (int.tryParse(draft.sortOrder) == null) {
      errors['sortOrder'] = 'Enter a valid whole number.';
    }
    if (draft.imageUrl.trim().isNotEmpty) {
      final Uri? url = Uri.tryParse(draft.imageUrl.trim());
      if (url == null || !(url.isScheme('http') || url.isScheme('https'))) {
        errors['imageUrl'] = 'Enter a valid HTTP(S) image URL.';
      }
    }
    if (create) {
      if (draft.variantName.trim().isEmpty) {
        errors['variants.0.name'] = 'Variant name is required.';
      }
      if (draft.variantBasePrice.trim().isEmpty &&
          draft.productType == 'standard') {
        errors['variants.0.basePrice'] = 'Base price is required.';
      } else if (draft.variantBasePrice.trim().isNotEmpty &&
          (!decimal.hasMatch(draft.variantBasePrice.trim()) ||
              double.parse(draft.variantBasePrice) <= 0)) {
        errors['variants.0.basePrice'] = configuredSellPriceMustBePositive;
      }
      if (draft.variantCostPrice.trim().isNotEmpty &&
          (!decimal.hasMatch(draft.variantCostPrice.trim()) ||
              double.parse(draft.variantCostPrice) < 0)) {
        errors['variants.0.costPrice'] = 'Enter zero or a positive price.';
      }
    }
    return errors;
  }

  Map<String, String> _fieldErrors(Map<String, List<String>> errors) =>
      errors.map((key, value) => MapEntry(key, value.first));
  String _nonFieldMessage(Map<String, List<String>> errors, String fallback) {
    for (final MapEntry<String, List<String>> entry in errors.entries) {
      if (!_knownFields.contains(entry.key) && entry.value.isNotEmpty) {
        return entry.value.first;
      }
    }
    return fallback;
  }

  static const Set<String> _knownFields = <String>{
    'name',
    'nameAr',
    'nameEn',
    'description',
    'descriptionAr',
    'descriptionEn',
    'imageUrl',
    'categoryId',
    'reportingCategoryId',
    'kitchenStationId',
    'productType',
    'preparationTimeMinutes',
    'isStockTracked',
    'sortOrder',
    'variants.0.name',
    'variants.0.nameAr',
    'variants.0.nameEn',
    'variants.0.sku',
    'variants.0.barcode',
    'variants.0.basePrice',
    'variants.0.costPrice',
  };
  String _message(Object error) => error is ApiException
      ? error.message
      : 'Unable to save this product. Please try again.';
}

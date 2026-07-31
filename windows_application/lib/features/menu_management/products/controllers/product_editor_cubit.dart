import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/network/api_exception.dart';
import '../../models/catalog_models.dart';
import '../../repositories/menu_catalog_repository.dart';
import '../models/product_editor_draft.dart';
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
      final ProductDetail product = await repository.getProduct(productId);
      emit(
        state.copyWith(
          draft: _draft(product),
          currentDefaultVariant: product.defaultVariant,
          status: ProductEditorStatus.loading,
          isDirty: false,
        ),
      );
      await _loadReferences();
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
    ),
  );
  Future<void> submit() async {
    if (state.status == ProductEditorStatus.submitting) return;
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
              double.parse(draft.variantBasePrice) < 0)) {
        errors['variants.0.basePrice'] = 'Enter zero or a positive price.';
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

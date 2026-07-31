import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/network/api_exception.dart';
import '../../models/catalog_models.dart';
import '../../repositories/menu_catalog_repository.dart';
import '../models/variant_editor_draft.dart';
import 'variants_state.dart';

class VariantsCubit extends Cubit<VariantsState> {
  VariantsCubit({required this.repository}) : super(const VariantsState());
  final MenuCatalogRepository repository;

  Future<void> load(int productId, {bool refresh = false}) async {
    if (state.isMutating) return;
    emit(
      state.copyWith(
        status: refresh ? VariantsStatus.refreshing : VariantsStatus.loading,
        clearErrors: true,
        clearSuccess: true,
      ),
    );
    try {
      _setProduct(
        await repository.getProduct(productId, includeArchived: true),
        status: VariantsStatus.loaded,
      );
    } catch (error) {
      emit(
        state.copyWith(
          status: VariantsStatus.failure,
          formError: _message(error),
        ),
      );
    }
  }

  void selectFilter(VariantFilter filter) =>
      emit(state.copyWith(filter: filter, clearErrors: true));
  Future<void> refresh() => load(state.product!.id, refresh: true);

  Future<bool> create(VariantEditorDraft draft, {required bool makeDefault}) =>
      _run(
        VariantAction.create,
        draft,
        () => repository.createVariant(
          state.product!.id,
          draft,
          makeDefault: makeDefault,
        ),
        'Variant created successfully.',
      );
  Future<bool> update(int id, VariantEditorDraft draft) => _run(
    VariantAction.update,
    draft,
    () => repository.updateVariant(id, draft),
    'Variant updated successfully.',
  );
  Future<bool> setDefault(int id) => _run(
    VariantAction.setDefault,
    null,
    () => repository.setDefaultVariant(id),
    'Default Variant updated successfully.',
  );
  Future<bool> archive(int id, {int? replacementDefaultVariantId}) => _run(
    VariantAction.archive,
    null,
    () => repository.archiveVariant(
      id,
      replacementDefaultVariantId: replacementDefaultVariantId,
    ),
    'Variant archived successfully.',
  );
  Future<bool> restore(int id, {bool makeDefault = false}) => _run(
    VariantAction.restore,
    null,
    () => repository.restoreVariant(id, makeDefault: makeDefault),
    'Variant restored successfully.',
  );

  Future<bool> reorder(List<ProductVariant> next) async {
    if (state.isMutating || state.product == null || !_unique(next)) {
      return false;
    }
    final List<ProductVariant> previous = state.activeVariants;
    final List<ProductVariant> ordered = List<ProductVariant>.unmodifiable(
      next,
    );
    emit(
      state.copyWith(
        activeVariants: ordered,
        action: VariantAction.reorder,
        clearErrors: true,
        clearSuccess: true,
      ),
    );
    try {
      await repository.reorderVariants(state.product!.id, <VariantReorderItem>[
        for (int index = 0; index < ordered.length; index++)
          VariantReorderItem(id: ordered[index].id, sortOrder: index),
      ]);
      await _reloadAfterMutation('Variants reordered successfully.');
      return true;
    } catch (error) {
      emit(
        state.copyWith(
          activeVariants: previous,
          clearAction: true,
          formError: _message(error),
        ),
      );
      return false;
    }
  }

  Future<bool> _run(
    VariantAction action,
    VariantEditorDraft? draft,
    Future<ProductVariant> Function() request,
    String message,
  ) async {
    if (state.isMutating || state.product == null) return false;
    final Map<String, String> errors = draft == null
        ? const <String, String>{}
        : _validate(draft);
    if (errors.isNotEmpty) {
      emit(
        state.copyWith(
          fieldErrors: errors,
          formError: null,
          clearSuccess: true,
        ),
      );
      return false;
    }
    emit(state.copyWith(action: action, clearErrors: true, clearSuccess: true));
    try {
      await request();
      await _reloadAfterMutation(message);
      return true;
    } catch (error) {
      if (error is ApiException && error.validationErrors != null) {
        final Map<String, String> mapped = error.validationErrors!.map(
          (key, value) => MapEntry(key, value.first),
        );
        emit(
          state.copyWith(
            clearAction: true,
            fieldErrors: mapped,
            formError: _formError(mapped, error.message),
          ),
        );
      } else {
        emit(state.copyWith(clearAction: true, formError: _message(error)));
      }
      return false;
    }
  }

  Future<void> _reloadAfterMutation(String message) async {
    final ProductDetail product = await repository.getProduct(
      state.product!.id,
      includeArchived: true,
    );
    _setProduct(product, status: VariantsStatus.loaded, message: message);
  }

  void _setProduct(
    ProductDetail product, {
    required VariantsStatus status,
    String? message,
  }) {
    final List<ProductVariant> active = product.variants
        .where((item) => !item.isArchived)
        .toList(growable: false);
    final List<ProductVariant> archived = product.variants
        .where((item) => item.isArchived)
        .toList(growable: false);
    emit(
      state.copyWith(
        status: status,
        product: product,
        activeVariants: active,
        archivedVariants: archived,
        clearAction: true,
        clearErrors: true,
        successMessage: message,
      ),
    );
  }

  Map<String, String> _validate(VariantEditorDraft draft) {
    final Map<String, String> errors = <String, String>{};
    final RegExp decimal = RegExp(r'^\d+(\.\d{1,2})?$');
    if (draft.name.trim().isEmpty) {
      errors['name'] = 'Variant name is required.';
    }
    if (!decimal.hasMatch(draft.basePrice.trim())) {
      errors['basePrice'] = 'Enter zero or a positive price.';
    }
    if (draft.costPrice.trim().isNotEmpty &&
        !decimal.hasMatch(draft.costPrice.trim())) {
      errors['costPrice'] = 'Enter zero or a positive price.';
    }
    if (int.tryParse(draft.sortOrder.trim()) == null ||
        int.parse(draft.sortOrder.trim()) < 0) {
      errors['sortOrder'] = 'Enter zero or a positive whole number.';
    }
    return errors;
  }

  bool _unique(List<ProductVariant> items) =>
      items.map((item) => item.id).toSet().length == items.length;
  String? _formError(Map<String, String> errors, String fallback) {
    for (final MapEntry<String, String> entry in errors.entries) {
      if (!const <String>{
        'name',
        'nameAr',
        'nameEn',
        'sku',
        'barcode',
        'basePrice',
        'costPrice',
        'isActive',
        'sortOrder',
      }.contains(entry.key)) {
        return entry.value;
      }
    }
    return null;
  }

  String _message(Object error) => error is ApiException
      ? error.message
      : 'Unable to update variants. Please try again.';
}

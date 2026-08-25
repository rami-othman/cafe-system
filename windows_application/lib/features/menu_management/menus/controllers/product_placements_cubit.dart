// ignore_for_file: curly_braces_in_flow_control_structures

import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../core/network/api_exception.dart';
import '../../models/catalog_models.dart';
import '../../models/product_catalog_filter.dart';
import '../../repositories/menu_catalog_repository.dart';
import '../models/menu_models.dart';
import '../models/product_placement.dart';

enum PlacementFilter { active, archived, all }

enum PlacementStatus { initial, loading, loaded, refreshing, failure }

class PlacementBatchResult {
  const PlacementBatchResult({
    required this.successfulProductIds,
    required this.failedProductIds,
    required this.conflictedProductIds,
    this.refreshFailed = false,
  });

  final List<int> successfulProductIds;
  final List<int> failedProductIds;
  final List<int> conflictedProductIds;
  final bool refreshFailed;

  bool get fullySucceeded =>
      !refreshFailed &&
      failedProductIds.isEmpty &&
      successfulProductIds.isNotEmpty;
}

class ProductPlacementsState {
  const ProductPlacementsState({
    this.status = PlacementStatus.initial,
    this.menu,
    this.placements = const {},
    this.filter = PlacementFilter.active,
    this.pickerProducts = const [],
    this.pickerLoading = false,
    this.pickerPage = 1,
    this.pickerHasMore = false,
    this.pickerSearch = '',
    this.pickerErrorMessage,
    this.actionId,
    this.errorMessage,
    this.fieldErrors = const {},
    this.successMessage,
  });
  final PlacementStatus status;
  final MenuRecord? menu;
  final Map<int, List<ProductPlacement>> placements;
  final PlacementFilter filter;
  final List<ProductSummary> pickerProducts;
  final bool pickerLoading, pickerHasMore;
  final int pickerPage;
  final String pickerSearch;
  final String? pickerErrorMessage;
  final int? actionId;
  final String? errorMessage, successMessage;
  final Map<String, List<String>> fieldErrors;
  bool get isBusy => actionId != null;
  bool get readOnly => menu?.isArchived ?? false;
  List<ProductPlacement> forSection(int id) {
    final all = placements[id] ?? const <ProductPlacement>[];
    return all
        .where(
          (p) => switch (filter) {
            PlacementFilter.active => !p.isArchived,
            PlacementFilter.archived => p.isArchived,
            PlacementFilter.all => true,
          },
        )
        .toList()
      ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
  }

  ProductPlacementsState copyWith({
    PlacementStatus? status,
    MenuRecord? menu,
    Map<int, List<ProductPlacement>>? placements,
    PlacementFilter? filter,
    List<ProductSummary>? pickerProducts,
    bool? pickerLoading,
    bool? pickerHasMore,
    int? pickerPage,
    String? pickerSearch,
    String? pickerErrorMessage,
    bool clearPickerError = false,
    int? actionId,
    bool clearAction = false,
    String? errorMessage,
    bool clearError = false,
    Map<String, List<String>>? fieldErrors,
    String? successMessage,
    bool clearSuccess = false,
  }) => ProductPlacementsState(
    status: status ?? this.status,
    menu: menu ?? this.menu,
    placements: placements ?? this.placements,
    filter: filter ?? this.filter,
    pickerProducts: pickerProducts ?? this.pickerProducts,
    pickerLoading: pickerLoading ?? this.pickerLoading,
    pickerHasMore: pickerHasMore ?? this.pickerHasMore,
    pickerPage: pickerPage ?? this.pickerPage,
    pickerSearch: pickerSearch ?? this.pickerSearch,
    pickerErrorMessage: clearPickerError
        ? null
        : pickerErrorMessage ?? this.pickerErrorMessage,
    actionId: clearAction ? null : actionId ?? this.actionId,
    errorMessage: clearError ? null : errorMessage ?? this.errorMessage,
    fieldErrors: fieldErrors ?? this.fieldErrors,
    successMessage: clearSuccess ? null : successMessage ?? this.successMessage,
  );
}

class ProductPlacementsCubit extends Cubit<ProductPlacementsState> {
  ProductPlacementsCubit({required this.repository})
    : super(const ProductPlacementsState());
  final MenuCatalogRepository repository;
  int _pickerRequest = 0;

  /// Reuse the canonical Menu Detail snapshot when Products is embedded in
  /// Menu Workspace. Mutations still reconcile via [load].
  void hydrate(MenuRecord value) {
    final entries = <int, List<ProductPlacement>>{};
    for (final placement in value.placements) {
      (entries[placement.sectionId] ??= <ProductPlacement>[]).add(placement);
    }
    for (final section in value.sections) {
      entries.putIfAbsent(section.id, () => <ProductPlacement>[]);
    }
    emit(
      state.copyWith(
        status: PlacementStatus.loaded,
        menu: value,
        placements: entries,
        clearError: true,
        clearSuccess: true,
      ),
    );
  }

  Future<void> load(int menuId, {bool refresh = false}) async {
    emit(
      state.copyWith(
        status: refresh ? PlacementStatus.refreshing : PlacementStatus.loading,
        clearError: true,
        clearSuccess: true,
      ),
    );
    try {
      final menu = await repository.getMenu(menuId, includeArchived: true);
      // GET /admin/menus/:id is the authoritative bounded composition
      // snapshot: sections + placements + embedded products/variants.
      // Do not regress to the former section-by-section request fan-out.
      final entries = <int, List<ProductPlacement>>{};
      for (final placement in menu.placements) {
        (entries[placement.sectionId] ??= <ProductPlacement>[]).add(placement);
      }
      for (final section in menu.sections) {
        entries.putIfAbsent(section.id, () => <ProductPlacement>[]);
      }
      emit(
        state.copyWith(
          status: PlacementStatus.loaded,
          menu: menu,
          placements: entries,
          clearError: true,
        ),
      );
    } catch (e) {
      emit(
        state.copyWith(
          status: PlacementStatus.failure,
          errorMessage: _message(e),
          fieldErrors: _fields(e),
        ),
      );
    }
  }

  void setFilter(PlacementFilter value) => emit(state.copyWith(filter: value));
  Future<void> searchProducts(
    String search, {
    required int sectionId,
    int? categoryId,
    bool next = false,
  }) async {
    final int request = ++_pickerRequest;
    final page = next ? state.pickerPage + 1 : 1;
    emit(
      state.copyWith(
        pickerLoading: true,
        pickerSearch: search,
        clearPickerError: true,
      ),
    );
    try {
      final result = await repository.listProducts(
        filter: ProductCatalogFilter(search: search, categoryId: categoryId),
        page: page,
      );
      if (request != _pickerRequest) return;
      // Inactive (but unarchived) products are valid according to the API.
      // Keep target-section duplicates in the result so the picker can explain
      // why they are unavailable; the sheet owns their disabled state.
      final products = result.items.where((p) => !p.isArchived).toList();
      emit(
        state.copyWith(
          pickerLoading: false,
          pickerProducts: next
              ? [...state.pickerProducts, ...products]
              : products,
          pickerPage: page,
          pickerHasMore: result.meta.hasNextPage,
        ),
      );
    } catch (e) {
      if (request != _pickerRequest) return;
      emit(
        state.copyWith(pickerLoading: false, pickerErrorMessage: _message(e)),
      );
    }
  }

  Future<void> create(int sectionId, ProductPlacementDraft draft) =>
      _mutate(sectionId, () async {
        _assertSectionMutable(sectionId);
        if ((state.placements[sectionId] ?? const []).any(
          (p) => p.productId == draft.productId && !p.isArchived,
        ))
          throw const _PlacementError(
            'This product is already placed in this section.',
          );
        await repository.createProductPlacement(sectionId, draft);
      }, 'Product added to section successfully.');

  Future<PlacementBatchResult> createMany(
    int sectionId,
    List<int> productIds,
  ) async {
    if (state.isBusy || state.readOnly || productIds.isEmpty) {
      return const PlacementBatchResult(
        successfulProductIds: [],
        failedProductIds: [],
        conflictedProductIds: [],
      );
    }
    final menuId = state.menu?.id;
    if (menuId == null) {
      return const PlacementBatchResult(
        successfulProductIds: [],
        failedProductIds: [],
        conflictedProductIds: [],
      );
    }
    final existing = (state.placements[sectionId] ?? const <ProductPlacement>[])
        .where((placement) => !placement.isArchived)
        .map((placement) => placement.productId)
        .toSet();
    final ids = productIds.where(existing.add).toList(growable: false);
    if (ids.isEmpty) {
      emit(
        state.copyWith(
          errorMessage: 'Selected products are already in this section.',
        ),
      );
      return PlacementBatchResult(
        successfulProductIds: const [],
        failedProductIds: productIds,
        conflictedProductIds: productIds,
      );
    }
    emit(
      state.copyWith(actionId: sectionId, clearError: true, clearSuccess: true),
    );
    final successful = <int>[];
    final failed = <int>[];
    final conflicted = <int>[];
    try {
      _assertSectionMutable(sectionId);
      for (final id in ids) {
        try {
          await repository.createProductPlacement(
            sectionId,
            ProductPlacementDraft(productId: id),
          );
          successful.add(id);
        } catch (e) {
          failed.add(id);
          if (_isDuplicateError(e)) conflicted.add(id);
        }
      }
      await load(menuId, refresh: true);
      if (state.status == PlacementStatus.failure) {
        emit(state.copyWith(clearAction: true));
        return PlacementBatchResult(
          successfulProductIds: successful,
          failedProductIds: failed,
          conflictedProductIds: conflicted,
          refreshFailed: true,
        );
      }
      emit(state.copyWith(clearAction: true));
      return PlacementBatchResult(
        successfulProductIds: successful,
        failedProductIds: failed,
        conflictedProductIds: conflicted,
      );
    } catch (e) {
      emit(state.copyWith(clearAction: true, errorMessage: _message(e)));
      return PlacementBatchResult(
        successfulProductIds: successful,
        failedProductIds: ids.where((id) => !successful.contains(id)).toList(),
        conflictedProductIds: conflicted,
      );
    }
  }

  Future<void> update(int placementId, ProductPlacementDraft draft) =>
      _mutate(placementId, () {
        _assertPlacementMutable(placementId);
        return repository.updateProductPlacement(placementId, draft);
      }, 'Placement updated successfully.');
  Future<void> move(ProductPlacement placement, int targetSectionId) =>
      _mutate(placement.id, () async {
        _assertPlacementMutable(placement.id);
        if (placement.sectionId == targetSectionId)
          throw const _PlacementError('Choose a different section.');
        _assertSectionMutable(targetSectionId);
        if ((state.placements[targetSectionId] ?? const []).any(
          (p) => !p.isArchived && p.productId == placement.productId,
        ))
          throw const _PlacementError(
            'This product is already placed in the target section.',
          );
        await repository.moveProductPlacement(
          placement.id,
          targetSectionId,
          sortOrder: (state.placements[targetSectionId] ?? const [])
              .where((p) => !p.isArchived)
              .length,
        );
      }, 'Product moved successfully.');
  Future<void> reorder(int sectionId, int from, int to) => _mutate(
    sectionId,
    () async {
      _assertSectionMutable(sectionId);
      final list =
          [
              ...(state.placements[sectionId] ?? const []),
            ].where((p) => !p.isArchived).toList()
            ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
      if (from < 0 || from >= list.length || to < 0 || to >= list.length)
        throw const _PlacementError('The selected placement order is invalid.');
      final item = list.removeAt(from);
      list.insert(to, item);
      await repository.reorderSectionPlacements(sectionId, [
        for (var i = 0; i < list.length; i++)
          PlacementReorderItem(id: list[i].id, sortOrder: i),
      ]);
    },
    'Product order updated successfully.',
  );
  Future<void> archive(int id) => _mutate(id, () {
    _assertPlacementMutable(id);
    return repository.archiveProductPlacement(id);
  }, 'Placement archived successfully.');
  Future<void> restore(int id) => _mutate(id, () {
    final placement = _placement(id);
    _assertSectionMutable(placement.sectionId);
    return repository.restoreProductPlacement(id);
  }, 'Placement restored successfully.');

  ProductPlacement _placement(int id) {
    for (final entries in state.placements.values) {
      for (final placement in entries) {
        if (placement.id == id) return placement;
      }
    }
    throw const _PlacementError('The selected placement is unavailable.');
  }

  void _assertPlacementMutable(int id) {
    final placement = _placement(id);
    if (placement.isArchived)
      throw const _PlacementError('Archived placements can only be restored.');
    _assertSectionMutable(placement.sectionId);
  }

  void _assertSectionMutable(int id) {
    MenuSectionRecord? section;
    for (final candidate
        in state.menu?.sections ?? const <MenuSectionRecord>[]) {
      if (candidate.id == id) {
        section = candidate;
        break;
      }
    }
    if (section == null || section.menuId != state.menu?.id)
      throw const _PlacementError('The selected section is unavailable.');
    if (section.isArchived || !section.isActive)
      throw const _PlacementError('This section cannot be changed.');
  }

  Future<void> _mutate(
    int actionId,
    Future<dynamic> Function() action,
    String success,
  ) async {
    if (state.isBusy || state.readOnly) return;
    final menuId = state.menu?.id;
    if (menuId == null) return;
    emit(
      state.copyWith(actionId: actionId, clearError: true, clearSuccess: true),
    );
    try {
      await action();
      await load(menuId, refresh: true);
      emit(state.copyWith(successMessage: success, clearAction: true));
    } catch (e) {
      emit(
        state.copyWith(
          clearAction: true,
          errorMessage: _message(e),
          fieldErrors: _fields(e),
        ),
      );
    }
  }

  String _message(Object e) => e is _PlacementError
      ? e.message
      : e is ApiException
      ? e.message
      : 'Unable to update product placements.';
  Map<String, List<String>> _fields(Object e) =>
      e is ApiException ? e.validationErrors ?? const {} : const {};

  bool _isDuplicateError(Object e) =>
      _message(e).toLowerCase().contains('already placed');
}

class _PlacementError implements Exception {
  const _PlacementError(this.message);
  final String message;
}

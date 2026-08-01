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
      final entries = await Future.wait(
        menu.sections.map(
          (s) async => MapEntry(
            s.id,
            await repository.getMenuPlacements(s.id, includeArchived: true),
          ),
        ),
      );
      emit(
        state.copyWith(
          status: PlacementStatus.loaded,
          menu: menu,
          placements: Map<int, List<ProductPlacement>>.fromEntries(entries),
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
    if (state.pickerLoading) return;
    final page = next ? state.pickerPage + 1 : 1;
    emit(state.copyWith(pickerLoading: true, clearPickerError: true));
    try {
      final result = await repository.listProducts(
        filter: ProductCatalogFilter(search: search, categoryId: categoryId),
        page: page,
      );
      final placed = (state.placements[sectionId] ?? const <ProductPlacement>[])
          .where((p) => !p.isArchived)
          .map((p) => p.productId)
          .toSet();
      final products = result.items
          .where((p) => p.isActive && !p.isArchived && !placed.contains(p.id))
          .toList();
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
}

class _PlacementError implements Exception {
  const _PlacementError(this.message);
  final String message;
}

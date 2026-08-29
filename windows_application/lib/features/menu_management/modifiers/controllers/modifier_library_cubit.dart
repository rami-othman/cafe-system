import 'dart:async';

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/network/api_exception.dart';
import '../../models/catalog_models.dart';
import '../../repositories/menu_catalog_repository.dart';
import '../models/modifier_models.dart';
import '../models/modifier_editor_drafts.dart';

enum ModifierLibraryStatus { initial, loading, loaded, refreshing, failure }

class ModifierLibraryState extends Equatable {
  const ModifierLibraryState({
    this.status = ModifierLibraryStatus.initial,
    this.filter = const ModifierGroupFilter(),
    this.groups = const <ModifierGroupRecord>[],
    this.pagination = const CatalogPagination(
      currentPage: 1,
      lastPage: 1,
      perPage: 20,
      total: 0,
    ),
    this.errorMessage,
    this.currentActionId,
  });
  final ModifierLibraryStatus status;
  final ModifierGroupFilter filter;
  final List<ModifierGroupRecord> groups;
  final CatalogPagination pagination;
  final String? errorMessage;
  final int? currentActionId;
  bool get isBusy =>
      status == ModifierLibraryStatus.loading ||
      status == ModifierLibraryStatus.refreshing ||
      currentActionId != null;
  bool get hasMore => pagination.hasNextPage;
  ModifierLibraryState copyWith({
    ModifierLibraryStatus? status,
    ModifierGroupFilter? filter,
    List<ModifierGroupRecord>? groups,
    CatalogPagination? pagination,
    String? errorMessage,
    int? currentActionId,
    bool clearError = false,
    bool clearAction = false,
  }) => ModifierLibraryState(
    status: status ?? this.status,
    filter: filter ?? this.filter,
    groups: groups ?? this.groups,
    pagination: pagination ?? this.pagination,
    errorMessage: clearError ? null : errorMessage ?? this.errorMessage,
    currentActionId: clearAction
        ? null
        : currentActionId ?? this.currentActionId,
  );
  @override
  List<Object?> get props => <Object?>[
    status,
    filter.search,
    filter.status,
    filter.groupType,
    filter.selectionType,
    groups,
    pagination.currentPage,
    pagination.total,
    errorMessage,
    currentActionId,
  ];
}

class ModifierLibraryCubit extends Cubit<ModifierLibraryState> {
  ModifierLibraryCubit({required this.repository})
    : super(const ModifierLibraryState());
  final MenuCatalogRepository repository;
  Timer? _searchTimer;
  int _requestTicket = 0;
  Future<void> load({bool refresh = false, bool next = false}) async {
    if (isClosed ||
        state.currentActionId != null ||
        (next &&
            (!state.hasMore ||
                state.status == ModifierLibraryStatus.loading))) {
      return;
    }
    final int ticket = ++_requestTicket;
    final int page = next ? state.pagination.currentPage + 1 : 1;
    emit(
      state.copyWith(
        status: refresh
            ? ModifierLibraryStatus.refreshing
            : ModifierLibraryStatus.loading,
        clearError: true,
      ),
    );
    try {
      final CatalogPage<ModifierGroupRecord> result = await repository
          .listModifierGroups(filter: state.filter, page: page);
      if (isClosed || ticket != _requestTicket) return;
      emit(
        state.copyWith(
          status: ModifierLibraryStatus.loaded,
          groups: next
              ? <ModifierGroupRecord>[...state.groups, ...result.items]
              : result.items,
          pagination: result.meta,
        ),
      );
    } catch (error) {
      if (isClosed || ticket != _requestTicket) return;
      emit(
        state.copyWith(
          status: ModifierLibraryStatus.failure,
          errorMessage: _message(error),
        ),
      );
    }
  }

  Future<void> updateFilter(ModifierGroupFilter filter) async {
    _searchTimer?.cancel();
    ++_requestTicket;
    emit(state.copyWith(filter: filter));
    await load();
  }

  Future<void> updateSearch(String value) async {
    _searchTimer?.cancel();
    ++_requestTicket;
    emit(state.copyWith(filter: state.filter.copyWith(search: value)));
    _searchTimer = Timer(const Duration(milliseconds: 350), load);
  }

  Future<void> refresh() => load(refresh: true);
  void cancelPendingSearch() => _searchTimer?.cancel();

  Future<bool> prepareReorder() async {
    _searchTimer?.cancel();
    if (isClosed ||
        state.currentActionId != null ||
        state.filter.hasActiveFilters) {
      return false;
    }
    final int ticket = ++_requestTicket;
    emit(
      state.copyWith(
        status: ModifierLibraryStatus.refreshing,
        clearError: true,
      ),
    );
    try {
      final List<ModifierGroupRecord> groups = <ModifierGroupRecord>[];
      int page = 1;
      CatalogPage<ModifierGroupRecord> result;
      do {
        result = await repository.listModifierGroups(
          filter: const ModifierGroupFilter(),
          page: page,
          perPage: 100,
        );
        if (isClosed || ticket != _requestTicket) return false;
        groups.addAll(result.items);
        page++;
      } while (page <= result.meta.lastPage);
      emit(
        state.copyWith(
          status: ModifierLibraryStatus.loaded,
          groups: groups,
          pagination: result.meta,
        ),
      );
      return true;
    } catch (error) {
      if (isClosed || ticket != _requestTicket) return false;
      emit(
        state.copyWith(
          status: ModifierLibraryStatus.failure,
          errorMessage: _message(error),
        ),
      );
      return false;
    }
  }

  Future<void> archive(int id) =>
      _mutate(id, () => repository.archiveModifierGroup(id));
  Future<void> restore(int id) =>
      _mutate(id, () => repository.restoreModifierGroup(id));
  Future<void> activate(ModifierGroupRecord group) => _mutate(
    group.id,
    () => repository.updateModifierGroup(group.id, _draft(group, true)),
  );
  Future<void> deactivate(ModifierGroupRecord group) => _mutate(
    group.id,
    () => repository.updateModifierGroup(group.id, _draft(group, false)),
  );

  ModifierGroupDraft _draft(ModifierGroupRecord group, bool isActive) =>
      ModifierGroupDraft(
        name: group.name,
        nameAr: group.nameAr ?? '',
        nameEn: group.nameEn ?? '',
        code: group.code ?? '',
        groupType: group.groupType,
        selectionType: group.selectionType,
        isRequired: group.isRequired,
        minSelections: group.minSelections.toString(),
        maxSelections: group.maxSelections.toString(),
        allowQuantity: group.allowQuantity,
        isActive: isActive,
        sortOrder: group.sortOrder.toString(),
      );
  Future<void> move(ModifierGroupRecord group, int direction) async {
    if (state.currentActionId != null) return;
    final List<ModifierGroupRecord> active = state.groups
        .where((item) => item.isActive && !item.isArchived)
        .toList();
    final int index = active.indexWhere((item) => item.id == group.id);
    final int target = index + direction;
    if (index < 0 || target < 0 || target >= active.length) return;

    final ModifierGroupRecord swapped = active[target];
    active[index] = swapped;
    active[target] = group;
    final List<ModifierReorderItem> items = active
        .asMap()
        .entries
        .map((entry) => ModifierReorderItem(entry.value.id, entry.key))
        .toList(growable: false);
    emit(state.copyWith(currentActionId: group.id, clearError: true));
    try {
      await repository.reorderModifierGroups(items);
      emit(state.copyWith(clearAction: true));
      await prepareReorder();
    } catch (error) {
      emit(state.copyWith(clearAction: true, errorMessage: _message(error)));
    }
  }

  Future<void> _mutate(
    int id,
    Future<ModifierGroupRecord> Function() action,
  ) async {
    if (state.currentActionId != null) return;
    emit(state.copyWith(currentActionId: id, clearError: true));
    try {
      await action();
      emit(state.copyWith(clearAction: true));
      await load(refresh: true);
    } catch (error) {
      emit(state.copyWith(clearAction: true, errorMessage: _message(error)));
    }
  }

  String _message(Object error) => error is ApiException
      ? error.message
      : 'Unable to update this modifier group.';

  @override
  Future<void> close() {
    _searchTimer?.cancel();
    return super.close();
  }
}

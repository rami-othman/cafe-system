import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/network/api_exception.dart';
import '../../models/catalog_models.dart';
import '../../repositories/menu_catalog_repository.dart';
import '../models/modifier_models.dart';

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
  Future<void> load({bool refresh = false, bool next = false}) async {
    if (state.isBusy || (next && !state.hasMore)) return;
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
      emit(
        state.copyWith(
          status: ModifierLibraryStatus.failure,
          errorMessage: _message(error),
        ),
      );
    }
  }

  Future<void> updateFilter(ModifierGroupFilter filter) async {
    emit(state.copyWith(filter: filter));
    await load();
  }

  Future<void> updateSearch(String value) =>
      updateFilter(state.filter.copyWith(search: value));
  Future<void> refresh() => load(refresh: true);
  Future<void> archive(int id) =>
      _mutate(id, () => repository.archiveModifierGroup(id));
  Future<void> restore(int id) =>
      _mutate(id, () => repository.restoreModifierGroup(id));
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
}

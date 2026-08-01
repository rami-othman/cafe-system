import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/network/api_exception.dart';
import '../../models/catalog_models.dart';
import '../../repositories/menu_catalog_repository.dart';
import '../models/menu_filter.dart';
import '../models/menu_models.dart';

enum MenuListStatus { initial, loading, loaded, refreshing, failure }

class MenuListState extends Equatable {
  const MenuListState({
    this.status = MenuListStatus.initial,
    this.filter = const MenuFilter(),
    this.menus = const <MenuRecord>[],
    this.pagination = const CatalogPagination(
      currentPage: 1,
      lastPage: 1,
      perPage: 20,
      total: 0,
    ),
    this.errorMessage,
    this.currentActionId,
  });
  final MenuListStatus status;
  final MenuFilter filter;
  final List<MenuRecord> menus;
  final CatalogPagination pagination;
  final String? errorMessage;
  final int? currentActionId;
  bool get isBusy =>
      status == MenuListStatus.loading ||
      status == MenuListStatus.refreshing ||
      currentActionId != null;
  bool get hasMore => pagination.hasNextPage;
  MenuListState copyWith({
    MenuListStatus? status,
    MenuFilter? filter,
    List<MenuRecord>? menus,
    CatalogPagination? pagination,
    String? errorMessage,
    int? currentActionId,
    bool clearError = false,
    bool clearAction = false,
  }) => MenuListState(
    status: status ?? this.status,
    filter: filter ?? this.filter,
    menus: menus ?? this.menus,
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
    filter.sort,
    filter.direction,
    menus,
    pagination.currentPage,
    pagination.total,
    errorMessage,
    currentActionId,
  ];
}

class MenuListCubit extends Cubit<MenuListState> {
  MenuListCubit({required this.repository}) : super(const MenuListState());
  final MenuCatalogRepository repository;
  Future<void> load({bool refresh = false, bool next = false}) async {
    if (state.isBusy || (next && !state.hasMore)) return;
    final int page = next ? state.pagination.currentPage + 1 : 1;
    emit(
      state.copyWith(
        status: refresh ? MenuListStatus.refreshing : MenuListStatus.loading,
        clearError: true,
      ),
    );
    try {
      final CatalogPage<MenuRecord> result = await repository.listMenus(
        filter: state.filter,
        page: page,
      );
      emit(
        state.copyWith(
          status: MenuListStatus.loaded,
          menus: next
              ? <MenuRecord>[...state.menus, ...result.items]
              : result.items,
          pagination: result.meta,
        ),
      );
    } catch (error) {
      emit(
        state.copyWith(
          status: MenuListStatus.failure,
          errorMessage: _message(error),
        ),
      );
    }
  }

  Future<void> updateFilter(MenuFilter filter) async {
    emit(state.copyWith(filter: filter));
    await load();
  }

  Future<void> updateSearch(String search) =>
      updateFilter(state.filter.copyWith(search: search));
  Future<void> refresh() => load(refresh: true);
  Future<void> archive(int id) =>
      _lifecycle(id, () => repository.archiveMenu(id));
  Future<void> restore(int id) =>
      _lifecycle(id, () => repository.restoreMenu(id));
  Future<void> _lifecycle(int id, Future<MenuRecord> Function() action) async {
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

  String _message(Object error) =>
      error is ApiException ? error.message : 'Unable to update this menu.';
}

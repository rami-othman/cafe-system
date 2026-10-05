import 'package:flutter_bloc/flutter_bloc.dart';

import '../models/cashier_dashboard.dart';
import '../repositories/cashier_dashboard_repository.dart';

enum CashierInventoryStatus { initial, loading, loaded, error }

class CashierInventoryState {
  const CashierInventoryState({
    this.status = CashierInventoryStatus.initial,
    this.page,
    this.search = '',
    this.stateFilter,
    this.branchId,
  });

  final CashierInventoryStatus status;
  final CashierStockPage? page;
  final String search;

  /// One of `low`, `zero`, `negative`, or null for every item.
  final String? stateFilter;
  final int? branchId;

  bool get showsSkeleton =>
      page == null && status != CashierInventoryStatus.error;

  CashierInventoryState copyWith({
    CashierInventoryStatus? status,
    CashierStockPage? page,
    String? search,
    String? stateFilter,
    bool clearStateFilter = false,
    int? branchId,
  }) => CashierInventoryState(
    status: status ?? this.status,
    page: page ?? this.page,
    search: search ?? this.search,
    stateFilter: clearStateFilter ? null : stateFilter ?? this.stateFilter,
    branchId: branchId ?? this.branchId,
  );
}

class CashierInventoryCubit extends Cubit<CashierInventoryState> {
  CashierInventoryCubit({required this.repository})
    : super(const CashierInventoryState());

  final CashierDashboardRepository repository;

  int _requestVersion = 0;

  Future<void> load({int? branchId, String? initialStateFilter}) {
    return _fetch(
      branchId: branchId ?? state.branchId,
      search: state.search,
      stateFilter: initialStateFilter ?? state.stateFilter,
      clearStateFilter: false,
    );
  }

  Future<void> search(String value) {
    if (state.search == value) return Future<void>.value();
    return _fetch(
      branchId: state.branchId,
      search: value,
      stateFilter: state.stateFilter,
      clearStateFilter: false,
    );
  }

  Future<void> filterByState(String? value) {
    if (state.stateFilter == value) return Future<void>.value();
    return _fetch(
      branchId: state.branchId,
      search: state.search,
      stateFilter: value,
      clearStateFilter: value == null,
    );
  }

  Future<void> _fetch({
    required int? branchId,
    required String search,
    required String? stateFilter,
    required bool clearStateFilter,
  }) async {
    final int request = ++_requestVersion;
    emit(
      state.copyWith(
        status: state.page == null
            ? CashierInventoryStatus.loading
            : state.status,
        search: search,
        stateFilter: stateFilter,
        clearStateFilter: clearStateFilter,
        branchId: branchId,
      ),
    );

    try {
      final CashierStockPage page = await repository.inventory(
        branchId: branchId,
        search: search,
        state: clearStateFilter ? null : stateFilter,
      );
      if (request != _requestVersion || isClosed) return;
      emit(state.copyWith(status: CashierInventoryStatus.loaded, page: page));
    } catch (_) {
      if (request != _requestVersion || isClosed) return;
      emit(state.copyWith(status: CashierInventoryStatus.error));
    }
  }
}

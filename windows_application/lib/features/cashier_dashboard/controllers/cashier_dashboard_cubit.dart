import 'package:flutter_bloc/flutter_bloc.dart';

import '../models/cashier_dashboard.dart';
import '../repositories/cashier_dashboard_repository.dart';
import 'cashier_dashboard_state.dart';

class CashierDashboardCubit extends Cubit<CashierDashboardState> {
  CashierDashboardCubit({required this.repository})
    : super(const CashierDashboardState());

  final CashierDashboardRepository repository;

  /// Latest-request-wins. A branch switch or a rapid refresh must never let an
  /// older in-flight response overwrite a newer one.
  int _requestVersion = 0;
  bool _inFlight = false;

  Future<void> load({int? branchId, bool force = false}) async {
    final int? scope = branchId ?? state.branchId;
    if (_inFlight && !force) return;

    _inFlight = true;
    final int request = ++_requestVersion;
    emit(
      state.copyWith(
        status: state.data == null
            ? CashierDashboardStatus.loading
            : state.status,
        branchId: scope,
        isRefreshing: state.data != null,
      ),
    );

    try {
      final CashierDashboard data = await repository.dashboard(branchId: scope);
      if (request != _requestVersion || isClosed) return;
      _inFlight = false;
      emit(
        state.copyWith(
          status: CashierDashboardStatus.loaded,
          data: data,
          isRefreshing: false,
        ),
      );
    } catch (_) {
      if (request != _requestVersion || isClosed) return;
      _inFlight = false;
      // A failed refresh keeps the last good figures on screen rather than
      // replacing a working till view with an error page.
      emit(
        state.copyWith(
          status: CashierDashboardStatus.error,
          isRefreshing: false,
        ),
      );
    }
  }

  Future<void> refresh() => load(force: true);

  Future<void> selectBranch(int? value) {
    if (state.branchId == value) return Future<void>.value();
    return load(branchId: value, force: true);
  }
}

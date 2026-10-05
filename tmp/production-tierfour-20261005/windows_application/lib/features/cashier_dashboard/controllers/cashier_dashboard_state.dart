import '../models/cashier_dashboard.dart';

enum CashierDashboardStatus { initial, loading, loaded, error }

class CashierDashboardState {
  const CashierDashboardState({
    this.status = CashierDashboardStatus.initial,
    this.data,
    this.branchId,
    this.isRefreshing = false,
  });

  final CashierDashboardStatus status;

  /// Retained across a refresh so the shell never flashes back to skeletons
  /// once real figures have been shown.
  final CashierDashboard? data;
  final int? branchId;
  final bool isRefreshing;

  bool get showsSkeleton =>
      data == null && status != CashierDashboardStatus.error;

  CashierDashboardState copyWith({
    CashierDashboardStatus? status,
    CashierDashboard? data,
    int? branchId,
    bool? isRefreshing,
  }) => CashierDashboardState(
    status: status ?? this.status,
    data: data ?? this.data,
    branchId: branchId ?? this.branchId,
    isRefreshing: isRefreshing ?? this.isRefreshing,
  );
}

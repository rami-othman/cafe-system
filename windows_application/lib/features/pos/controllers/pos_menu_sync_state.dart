import 'package:equatable/equatable.dart';

import '../models/pos_menu_runtime_models.dart';
import '../models/pos_menu_sync_result.dart';

/// A single authoritative menu-runtime state. An active menu is never
/// overwritten merely because a newer menu was downloaded mid-cart.
enum PosMenuSyncStatus {
  idle,
  syncingWithUsableCache,
  onlineFresh,
  offlineUsingCache,
  syncErrorUsingCache,
  noPublishedMenu,
  noCacheOffline,
  pendingVersion,
  applyingVersion,
  fatalSyncError,
}

class PosMenuSyncState extends Equatable {
  const PosMenuSyncState({
    this.branchId,
    this.status = PosMenuSyncStatus.idle,
    this.activeMenu,
    this.pendingMenu,
    this.lastSyncedAt,
    this.failure,
  });

  final int? branchId;
  final PosMenuSyncStatus status;
  final PosPublishedRuntimeMenu? activeMenu;
  final PosPublishedRuntimeMenu? pendingMenu;
  final DateTime? lastSyncedAt;
  final PosMenuSyncFailure? failure;

  int? get activeVersionId => activeMenu?.version.id;
  int? get pendingVersionId => pendingMenu?.version.id;

  bool get isBackendReachable => switch (status) {
    // A saved published menu is being refreshed, not an offline verdict. Keep
    // checkout available while the request is in flight; if the backend is
    // actually unavailable, the payment request fails safely and the sync
    // state changes to offlineUsingCache/noCacheOffline.
    PosMenuSyncStatus.syncingWithUsableCache ||
    PosMenuSyncStatus.onlineFresh ||
    PosMenuSyncStatus.pendingVersion ||
    PosMenuSyncStatus.applyingVersion ||
    PosMenuSyncStatus.noPublishedMenu => true,
    _ => false,
  };

  PosMenuSyncState copyWith({
    int? branchId,
    PosMenuSyncStatus? status,
    PosPublishedRuntimeMenu? activeMenu,
    PosPublishedRuntimeMenu? pendingMenu,
    DateTime? lastSyncedAt,
    PosMenuSyncFailure? failure,
    bool clearActiveMenu = false,
    bool clearPendingMenu = false,
    bool clearFailure = false,
  }) => PosMenuSyncState(
    branchId: branchId ?? this.branchId,
    status: status ?? this.status,
    activeMenu: clearActiveMenu ? null : activeMenu ?? this.activeMenu,
    pendingMenu: clearPendingMenu ? null : pendingMenu ?? this.pendingMenu,
    lastSyncedAt: lastSyncedAt ?? this.lastSyncedAt,
    failure: clearFailure ? null : failure ?? this.failure,
  );

  @override
  List<Object?> get props => <Object?>[
    status,
    branchId,
    activeMenu,
    pendingMenu,
    lastSyncedAt,
    failure,
  ];
}

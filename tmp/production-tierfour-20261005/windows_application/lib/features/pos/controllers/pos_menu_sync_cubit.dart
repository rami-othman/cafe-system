import 'package:flutter_bloc/flutter_bloc.dart';

import '../models/pos_menu_runtime_models.dart';
import '../models/pos_menu_sync_result.dart';
import '../repositories/pos_menu_sync_repository.dart';
import 'pos_menu_sync_state.dart';

class PosMenuSyncCubit extends Cubit<PosMenuSyncState> {
  PosMenuSyncCubit({required this.repository})
    : super(const PosMenuSyncState());

  final PosMenuSyncRepository repository;
  int _requestGeneration = 0;

  /// Cache-first sync. Repeated startup, manual refresh, and reconnect calls
  /// are coalesced by the repository; the generation also prevents stale
  /// branches from changing the active POS context.
  Future<void> sync(int branchId, {required bool hasActiveCart}) async {
    final int request = ++_requestGeneration;
    final bool sameBranch = state.branchId == branchId;
    if (!sameBranch) {
      emit(
        PosMenuSyncState(branchId: branchId, status: PosMenuSyncStatus.idle),
      );
    }

    final PosPublishedRuntimeMenu? cached = await repository.loadCachedMenu(
      branchId: branchId,
    );
    if (isClosed || request != _requestGeneration) return;
    if (cached != null && !sameBranch) {
      emit(
        state.copyWith(
          status: PosMenuSyncStatus.syncingWithUsableCache,
          activeMenu: cached,
          lastSyncedAt: await repository.cachedSyncedAt(branchId: branchId),
          clearFailure: true,
        ),
      );
    } else if (state.activeMenu != null) {
      emit(
        state.copyWith(
          status: PosMenuSyncStatus.syncingWithUsableCache,
          clearFailure: true,
        ),
      );
    }

    final PosMenuSyncResult result = await repository.sync(branchId: branchId);
    if (isClosed || request != _requestGeneration) return;
    _apply(result, hasActiveCart: hasActiveCart);
  }

  void _apply(PosMenuSyncResult result, {required bool hasActiveCart}) {
    switch (result) {
      case PosMenuSyncUpdated(:final menu, :final syncedAt):
        _mergeFreshMenu(menu, syncedAt, hasActiveCart: hasActiveCart);
      case PosMenuSyncUpToDate(:final menu, :final syncedAt):
        _mergeFreshMenu(menu, syncedAt, hasActiveCart: hasActiveCart);
      case PosMenuSyncNoPublication():
        if (hasActiveCart && state.activeMenu != null) {
          emit(
            state.copyWith(
              // The server authoritatively withdrew publication, but the
              // pinned active order may complete before its menu is removed.
              status: PosMenuSyncStatus.noPublishedMenu,
              clearPendingMenu: true,
              clearFailure: true,
            ),
          );
        } else {
          emit(
            state.copyWith(
              status: PosMenuSyncStatus.noPublishedMenu,
              clearActiveMenu: true,
              clearPendingMenu: true,
              clearFailure: true,
            ),
          );
        }
      case PosMenuSyncUsingCachedAfterFailure(:final menu, :final failure):
        emit(
          state.copyWith(
            status: failure.kind == PosMenuSyncFailureKind.network
                ? PosMenuSyncStatus.offlineUsingCache
                : PosMenuSyncStatus.syncErrorUsingCache,
            activeMenu: state.activeMenu ?? menu,
            failure: failure,
          ),
        );
      case PosMenuSyncFatalNoCache(:final failure):
        emit(
          state.copyWith(
            status: failure.kind == PosMenuSyncFailureKind.network
                ? PosMenuSyncStatus.noCacheOffline
                : PosMenuSyncStatus.fatalSyncError,
            clearActiveMenu: true,
            clearPendingMenu: true,
            failure: failure,
          ),
        );
    }
  }

  void _mergeFreshMenu(
    PosPublishedRuntimeMenu menu,
    DateTime syncedAt, {
    required bool hasActiveCart,
  }) {
    final PosPublishedRuntimeMenu? active = state.activeMenu;
    if (active == null ||
        active.version.id == menu.version.id ||
        !hasActiveCart) {
      emit(
        state.copyWith(
          status: PosMenuSyncStatus.onlineFresh,
          activeMenu: menu,
          clearPendingMenu: true,
          lastSyncedAt: syncedAt,
          clearFailure: true,
        ),
      );
      return;
    }
    emit(
      state.copyWith(
        status: PosMenuSyncStatus.pendingVersion,
        pendingMenu: menu,
        lastSyncedAt: syncedAt,
        clearFailure: true,
      ),
    );
  }

  /// Must be called after a cart/order becomes safely empty.
  void activatePendingIfSafe({required bool hasActiveCart}) {
    if (hasActiveCart) return;
    if (state.status == PosMenuSyncStatus.noPublishedMenu &&
        state.pendingMenu == null) {
      emit(state.copyWith(clearActiveMenu: true));
      return;
    }
    if (state.pendingMenu == null) return;
    final PosPublishedRuntimeMenu pending = state.pendingMenu!;
    emit(state.copyWith(status: PosMenuSyncStatus.applyingVersion));
    emit(
      state.copyWith(
        status: PosMenuSyncStatus.onlineFresh,
        activeMenu: pending,
        clearPendingMenu: true,
      ),
    );
  }
}

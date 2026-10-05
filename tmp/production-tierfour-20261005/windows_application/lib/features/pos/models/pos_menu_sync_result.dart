import 'pos_menu_runtime_models.dart';

enum PosMenuSyncFailureKind {
  network,
  invalidBranch,
  unsupportedSourceSchema,
  unsupportedRuntimeContract,
  invalidResponse,
}

class PosMenuSyncFailure {
  const PosMenuSyncFailure({required this.kind});

  final PosMenuSyncFailureKind kind;
}

sealed class PosMenuSyncResult {
  const PosMenuSyncResult();
}

class PosMenuSyncUpdated extends PosMenuSyncResult {
  const PosMenuSyncUpdated({required this.menu, required this.syncedAt});

  final PosPublishedRuntimeMenu menu;
  final DateTime syncedAt;
}

class PosMenuSyncUpToDate extends PosMenuSyncResult {
  const PosMenuSyncUpToDate({required this.menu, required this.syncedAt});

  final PosPublishedRuntimeMenu menu;
  final DateTime syncedAt;
}

class PosMenuSyncNoPublication extends PosMenuSyncResult {
  const PosMenuSyncNoPublication({required this.context});

  final PosMenuContext context;
}

class PosMenuSyncUsingCachedAfterFailure extends PosMenuSyncResult {
  const PosMenuSyncUsingCachedAfterFailure({
    required this.menu,
    required this.failure,
  });

  final PosPublishedRuntimeMenu menu;
  final PosMenuSyncFailure failure;
}

class PosMenuSyncFatalNoCache extends PosMenuSyncResult {
  const PosMenuSyncFatalNoCache({required this.failure});

  final PosMenuSyncFailure failure;
}

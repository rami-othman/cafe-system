import '../../../core/network/api_exception.dart';
import '../../../core/network/dio_api_client.dart';
import '../models/pos_menu_runtime_models.dart';
import '../models/pos_menu_sync_result.dart';
import 'pos_menu_sync_cache.dart';

class PosMenuSyncRepository {
  PosMenuSyncRepository({required this.apiClient, required this.cache});

  final DioApiClient apiClient;
  final PosMenuSyncCache cache;
  final Map<String, Future<PosMenuSyncResult>> _inFlight =
      <String, Future<PosMenuSyncResult>>{};

  /// Exposes only the matching branch-scoped immutable projection so the UI
  /// can render it before the fresh runtime overlay request completes.
  Future<PosPublishedRuntimeMenu?> loadCachedMenu({
    required int branchId,
  }) async {
    final PosCachedMenu? cached = await cache.read(
      PosMenuCacheScope.forBranch(branchId),
    );
    return cached?.withRuntime(null);
  }

  Future<DateTime?> cachedSyncedAt({required int branchId}) async {
    final PosCachedMenu? cached = await cache.read(
      PosMenuCacheScope.forBranch(branchId),
    );
    return cached?.syncedAt;
  }

  Future<PosMenuSyncResult> sync({required int branchId}) {
    final PosMenuCacheScope scope = PosMenuCacheScope.forBranch(branchId);
    return _inFlight.putIfAbsent(scope.fileName, () async {
      try {
        return await _syncScope(scope);
      } finally {
        _inFlight.remove(scope.fileName);
      }
    });
  }

  Future<PosMenuSyncResult> _syncScope(PosMenuCacheScope scope) async {
    final PosCachedMenu? cached = await cache.read(scope);
    try {
      return await _request(scope, cached, allowRecovery: true);
    } catch (error) {
      final PosMenuSyncFailure failure = _failureFor(error);
      if (cached != null) {
        return PosMenuSyncUsingCachedAfterFailure(
          menu: cached.withRuntime(null),
          failure: failure,
        );
      }
      return PosMenuSyncFatalNoCache(failure: failure);
    }
  }

  Future<PosMenuSyncResult> _request(
    PosMenuCacheScope scope,
    PosCachedMenu? cached, {
    required bool allowRecovery,
  }) async {
    final Map<String, dynamic> query = <String, dynamic>{
      'branchId': scope.branchId,
    };
    if (cached != null) query['knownVersionId'] = cached.version.id;
    final dynamic body = await apiClient.get(
      'pos/menu-sync',
      queryParameters: query,
    );
    final PosMenuSyncResponse response = PosMenuSyncResponse.fromJson(body);
    if (response.context.branchId != scope.branchId ||
        response.context.channel != scope.channel) {
      throw const PosMenuContractException(
        'Sync response scope does not match request.',
      );
    }
    if (response.version == null) {
      return PosMenuSyncNoPublication(context: response.context);
    }

    if (response.upToDate) {
      if (cached != null && cached.version.id == response.version!.id) {
        final PosCachedMenu refreshed = PosCachedMenu(
          scope: cached.scope,
          context: cached.context,
          version: cached.version,
          menu: cached.menu,
          syncedAt: DateTime.now(),
          runtime: response.runtime,
        );
        await cache.write(refreshed);
        return PosMenuSyncUpToDate(
          menu: refreshed.withRuntime(response.runtime),
          syncedAt: refreshed.syncedAt,
        );
      }
      if (allowRecovery) {
        return _request(scope, null, allowRecovery: false);
      }
      throw const PosMenuContractException(
        'Server reported current version without static cache.',
      );
    }

    final PosStaticMenuProjection staticMenu = response.menu!;
    final PosCachedMenu next = PosCachedMenu(
      scope: scope,
      context: response.context,
      version: response.version!,
      menu: staticMenu,
      syncedAt: DateTime.now(),
      runtime: response.runtime,
    );
    await cache.write(next);
    return PosMenuSyncUpdated(
      menu: next.withRuntime(response.runtime),
      syncedAt: next.syncedAt,
    );
  }

  PosMenuSyncFailure _failureFor(Object error) {
    if (error is PosMenuContractException) {
      return PosMenuSyncFailure(
        kind: error.message.contains('Unsupported POS runtime contract')
            ? PosMenuSyncFailureKind.unsupportedRuntimeContract
            : PosMenuSyncFailureKind.invalidResponse,
      );
    }
    if (error is ApiException) {
      if (error.statusCode == 409) {
        return const PosMenuSyncFailure(
          kind: PosMenuSyncFailureKind.unsupportedSourceSchema,
        );
      }
      if (error.statusCode == 422) {
        return const PosMenuSyncFailure(
          kind: PosMenuSyncFailureKind.invalidBranch,
        );
      }
    }
    return const PosMenuSyncFailure(kind: PosMenuSyncFailureKind.network);
  }
}

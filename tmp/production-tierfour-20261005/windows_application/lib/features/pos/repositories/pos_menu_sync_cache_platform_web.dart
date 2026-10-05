import 'dart:async';
import 'dart:convert';
import 'dart:js_interop';

import 'package:web/web.dart' as web;

import 'pos_menu_sync_cache_models.dart';

PosMenuSyncCache createPosMenuSyncCache() => IndexedDbPosMenuSyncCache();

/// Browser persistence for substantial published POS menu payloads. IndexedDB
/// avoids the synchronous, quota-constrained localStorage mechanism.
class IndexedDbPosMenuSyncCache implements PosMenuSyncCache {
  static const String _databaseName = 'cafe618-pos-menu-cache-v1';
  static const String _storeName = 'menus';
  Future<web.IDBDatabase>? _database;

  Future<web.IDBDatabase> _open() => _database ??= _openDatabase();

  Future<web.IDBDatabase> _openDatabase() {
    final web.IDBOpenDBRequest request = web.window.indexedDB.open(
      _databaseName,
      1,
    );
    request.onupgradeneeded = ((web.Event _) {
      final web.IDBDatabase database = request.result! as web.IDBDatabase;
      database.createObjectStore(_storeName);
    }).toJS;
    return _request<web.IDBDatabase>(request);
  }

  @override
  Future<PosCachedMenu?> read(PosMenuCacheScope scope) async {
    try {
      final web.IDBDatabase database = await _open();
      final web.IDBTransaction transaction = database.transaction(
        _storeName.toJS,
        'readonly',
      );
      final Object? encoded = await _request<Object?>(
        transaction.objectStore(_storeName).get(scope.fileName.toJS),
      );
      if (encoded is! String) return null;
      return PosCachedMenu.fromJson(jsonDecode(encoded), expectedScope: scope);
    } catch (_) {
      return null;
    }
  }

  @override
  Future<void> write(PosCachedMenu menu) async {
    final web.IDBDatabase database = await _open();
    final web.IDBTransaction transaction = database.transaction(
      _storeName.toJS,
      'readwrite',
    );
    await _request<Object?>(
      transaction
          .objectStore(_storeName)
          .put(encodePosCachedMenu(menu).toJS, menu.scope.fileName.toJS),
    );
  }

  @override
  Future<void> clear(PosMenuCacheScope scope) async {
    try {
      final web.IDBDatabase database = await _open();
      final web.IDBTransaction transaction = database.transaction(
        _storeName.toJS,
        'readwrite',
      );
      await _request<Object?>(
        transaction.objectStore(_storeName).delete(scope.fileName.toJS),
      );
    } catch (_) {
      // Cache cleanup must never block a POS session.
    }
  }

  Future<T> _request<T>(web.IDBRequest request) {
    final Completer<T> completer = Completer<T>();
    request.onsuccess = ((web.Event _) {
      final Object? result = request.result?.dartify();
      completer.complete(result as T);
    }).toJS;
    request.onerror = ((web.Event _) {
      completer.completeError(StateError('IndexedDB request failed.'));
    }).toJS;
    return completer.future;
  }
}

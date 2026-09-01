import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';

import '../models/pos_menu_runtime_models.dart';

class PosMenuCacheScope {
  const PosMenuCacheScope({
    required this.tenantIdentity,
    required this.branchId,
    this.channel = 'pos',
  });

  factory PosMenuCacheScope.forBranch({
    required int? tenantId,
    required int branchId,
  }) => PosMenuCacheScope(
    // An unavailable identity intentionally cannot collide with any real
    // tenant. Production sync becomes tenant-scoped as soon as auth restores.
    tenantIdentity: tenantId != null && tenantId > 0
        ? 'tenant-$tenantId'
        : 'unauthenticated',
    branchId: branchId,
  );

  final String tenantIdentity;
  final int branchId;
  final String channel;

  String get fileName =>
      'runtime-v1-$tenantIdentity-branch-$branchId-channel-$channel.json';
}

class PosCachedMenu {
  const PosCachedMenu({
    required this.scope,
    required this.context,
    required this.version,
    required this.menu,
    required this.syncedAt,
    this.runtime,
  });

  final PosMenuCacheScope scope;
  final PosMenuContext context;
  final PosPublishedMenuVersion version;
  final PosStaticMenuProjection menu;
  final DateTime syncedAt;

  /// The last backend-evaluated overlay is intentionally retained only as a
  /// stale hint while offline.  The client never evaluates schedules itself.
  final PosRuntimeOverlay? runtime;

  PosPublishedRuntimeMenu withRuntime(PosRuntimeOverlay? runtime) {
    return PosPublishedRuntimeMenu(
      context: context,
      version: version,
      menu: menu,
      runtime: runtime ?? this.runtime,
    );
  }

  factory PosCachedMenu.fromJson(
    Object? value, {
    required PosMenuCacheScope expectedScope,
  }) {
    if (value is! Map) {
      throw const PosMenuContractException(
        'Cached POS menu must be an object.',
      );
    }
    final Map<String, dynamic> json = Map<String, dynamic>.from(value);
    final Map<String, dynamic> scopeJson = Map<String, dynamic>.from(
      json['scope'] as Map? ?? <String, dynamic>{},
    );
    final PosMenuCacheScope scope = PosMenuCacheScope(
      tenantIdentity: scopeJson['tenantIdentity']?.toString() ?? '',
      branchId: int.tryParse(scopeJson['branchId']?.toString() ?? '') ?? -1,
      channel: scopeJson['channel']?.toString() ?? '',
    );
    if (scope.tenantIdentity != expectedScope.tenantIdentity ||
        scope.branchId != expectedScope.branchId ||
        scope.channel != expectedScope.channel) {
      throw const PosMenuContractException(
        'Cached POS menu has the wrong scope.',
      );
    }
    final DateTime? syncedAt = DateTime.tryParse(
      json['syncedAt']?.toString() ?? '',
    );
    if (syncedAt == null) {
      throw const PosMenuContractException(
        'Cached POS menu has no sync timestamp.',
      );
    }
    return PosCachedMenu(
      scope: scope,
      context: PosMenuContext.fromJson(json['context']),
      version: PosPublishedMenuVersion.fromJson(json['version']),
      menu: PosStaticMenuProjection.fromJson(json['menu']),
      syncedAt: syncedAt,
      runtime: json['runtime'] == null
          ? null
          : PosRuntimeOverlay.fromJson(json['runtime']),
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
    'scope': <String, dynamic>{
      'tenantIdentity': scope.tenantIdentity,
      'branchId': scope.branchId,
      'channel': scope.channel,
    },
    'context': context.toJson(),
    'version': version.toJson(),
    'menu': menu.toJson(),
    'syncedAt': syncedAt.toIso8601String(),
    if (runtime != null) 'runtime': runtime!.toJson(),
  };
}

abstract class PosMenuSyncCache {
  Future<PosCachedMenu?> read(PosMenuCacheScope scope);
  Future<void> write(PosCachedMenu menu);
  Future<void> clear(PosMenuCacheScope scope);
}

/// Stores only immutable static projection data. Runtime overlays are fetched
/// anew and intentionally cannot become a version identity.
class FilePosMenuSyncCache implements PosMenuSyncCache {
  FilePosMenuSyncCache({Future<Directory> Function()? directoryProvider})
    : _directoryProvider = directoryProvider ?? _defaultDirectory;

  final Future<Directory> Function() _directoryProvider;

  static Future<Directory> _defaultDirectory() async {
    final Directory support = await getApplicationSupportDirectory();
    return Directory('${support.path}${Platform.pathSeparator}pos_menu_sync');
  }

  Future<File> _fileFor(PosMenuCacheScope scope) async {
    final Directory directory = await _directoryProvider();
    if (!await directory.exists()) await directory.create(recursive: true);
    return File('${directory.path}${Platform.pathSeparator}${scope.fileName}');
  }

  @override
  Future<PosCachedMenu?> read(PosMenuCacheScope scope) async {
    try {
      final File file = await _fileFor(scope);
      final File previous = File('${file.path}.previous');
      if (!await file.exists() && await previous.exists()) {
        await previous.rename(file.path);
      }
      if (!await file.exists()) return null;
      return PosCachedMenu.fromJson(
        jsonDecode(await file.readAsString()),
        expectedScope: scope,
      );
    } on FileSystemException {
      return null;
    } on FormatException {
      return null;
    } on PosMenuContractException {
      return null;
    }
  }

  @override
  Future<void> write(PosCachedMenu menu) async {
    final File target = await _fileFor(menu.scope);
    final File temporary = File('${target.path}.next');
    final File previous = File('${target.path}.previous');
    await temporary.writeAsString(jsonEncode(menu.toJson()), flush: true);
    // Dart cannot replace an existing Windows file in one rename. Keep the
    // prior complete file as recovery until the new complete file is renamed.
    if (await previous.exists()) await previous.delete();
    if (await target.exists()) await target.rename(previous.path);
    await temporary.rename(target.path);
    if (await previous.exists()) await previous.delete();
  }

  @override
  Future<void> clear(PosMenuCacheScope scope) async {
    final File target = await _fileFor(scope);
    if (await target.exists()) await target.delete();
    final File previous = File('${target.path}.previous');
    if (await previous.exists()) await previous.delete();
  }
}

class MemoryPosMenuSyncCache implements PosMenuSyncCache {
  final Map<String, PosCachedMenu> _items = <String, PosCachedMenu>{};

  @override
  Future<void> clear(PosMenuCacheScope scope) async {
    _items.remove(scope.fileName);
  }

  @override
  Future<PosCachedMenu?> read(PosMenuCacheScope scope) async =>
      _items[scope.fileName];

  @override
  Future<void> write(PosCachedMenu menu) async {
    _items[menu.scope.fileName] = menu;
  }
}

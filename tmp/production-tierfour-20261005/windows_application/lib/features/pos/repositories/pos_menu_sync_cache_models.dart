import 'dart:convert';

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

String encodePosCachedMenu(PosCachedMenu menu) => jsonEncode(menu.toJson());

import 'package:flutter_test/flutter_test.dart';
import 'package:windows_application/features/pos/repositories/pos_menu_sync_cache.dart';

void main() {
  test('cache keys isolate tenant branch and channel', () {
    const PosMenuCacheScope base = PosMenuCacheScope(
      tenantIdentity: 'tenant-4',
      branchId: 1,
      channel: 'pos',
    );
    const PosMenuCacheScope otherTenant = PosMenuCacheScope(
      tenantIdentity: 'tenant-5',
      branchId: 1,
      channel: 'pos',
    );
    const PosMenuCacheScope otherBranch = PosMenuCacheScope(
      tenantIdentity: 'tenant-4',
      branchId: 2,
      channel: 'pos',
    );
    const PosMenuCacheScope otherChannel = PosMenuCacheScope(
      tenantIdentity: 'tenant-4',
      branchId: 1,
      channel: 'kiosk',
    );

    expect(base.fileName, isNot(otherTenant.fileName));
    expect(base.fileName, isNot(otherBranch.fileName));
    expect(base.fileName, isNot(otherChannel.fileName));
  });

  test('corrupt or wrong-scope cached values are rejected', () {
    const PosMenuCacheScope scope = PosMenuCacheScope(
      tenantIdentity: 'tenant-4',
      branchId: 1,
    );

    expect(
      () => PosCachedMenu.fromJson(<String, Object?>{}, expectedScope: scope),
      throwsA(isA<Exception>()),
    );
    expect(
      () => PosCachedMenu.fromJson('not-json', expectedScope: scope),
      throwsA(isA<Exception>()),
    );
  });
}

import 'package:flutter_test/flutter_test.dart';
import 'package:windows_application/core/branding/app_brand.dart';
import 'package:windows_application/features/auth/models/auth_session.dart';
import 'package:windows_application/features/pos/models/branch.dart';

const AuthUser _cashier = AuthUser(id: 1, name: 'Cashier', role: 'cashier');
const AuthUser _manager = AuthUser(id: 2, name: 'Manager', role: 'manager');
const AuthUser _owner = AuthUser(id: 3, name: 'Owner', role: 'owner');
const List<Branch> _branches = <Branch>[
  Branch(
    id: 10,
    name: 'المزة',
    currency: 'SYP',
    timezone: 'Asia/Damascus',
    isActive: true,
    taxRate: 0,
  ),
  Branch(
    id: 20,
    name: 'فرع المطار',
    currency: 'SYP',
    timezone: 'Asia/Damascus',
    isActive: true,
    taxRate: 0,
  ),
];

BrandIdentity _resolve(AuthUser user, int? branchId) => AppBrand.resolve(
  user: user,
  branches: _branches,
  activeBranchId: branchId,
  localizedSystemName: AppBrand.systemNameAr,
  localizedOperationalHub: 'مركز العمليات',
  localizedPos: 'نقطة البيع',
);

void main() {
  test('cashier identity uses the active branch human-readable name', () {
    expect(_resolve(_cashier, 10).displayName, 'المزة');
    expect(_resolve(_cashier, 20).displayName, 'فرع المطار');
    expect(_resolve(_cashier, 20).subtitle, 'نقطة البيع');
  });

  test('cashier without a resolvable branch gets the safe system fallback', () {
    expect(_resolve(_cashier, 999).displayName, AppBrand.systemNameAr);
  });

  test('manager and owner retain the general product identity', () {
    expect(_resolve(_manager, 10).displayName, AppBrand.systemNameAr);
    expect(_resolve(_owner, 20).displayName, AppBrand.systemNameAr);
  });

  test('resolution is stateless across logout and another cashier login', () {
    expect(_resolve(_cashier, 10).displayName, 'المزة');
    expect(_resolve(_manager, null).displayName, AppBrand.systemNameAr);
    expect(_resolve(_cashier, 20).displayName, 'فرع المطار');
  });
}

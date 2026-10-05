import 'package:flutter_test/flutter_test.dart';
import 'package:windows_application/app/app.dart';
import 'package:windows_application/core/services/service_locator.dart';
import 'package:windows_application/features/auth/models/auth_session.dart';
import 'package:windows_application/features/auth/repositories/auth_session_storage.dart';
import 'package:windows_application/features/auth/repositories/auth_session_storage_contract.dart';
import 'package:windows_application/features/cashier_dashboard/models/cashier_dashboard.dart';
import 'package:windows_application/features/cashier_dashboard/repositories/cashier_dashboard_repository.dart';

/// Boots the application's service locator with a session of the given role.
///
/// The role must be registered before [setupServiceLocator] runs, because the
/// locator only registers an AuthSessionStorage when one is not already there.
Future<void> setupCashierLocator({
  String role = 'cashier',
  CashierDashboardRepository? repository,
}) async {
  await serviceLocator.reset();
  serviceLocator.registerLazySingleton<AuthSessionStorage>(
    () => MemoryAuthSessionStorage(sessionForRole(role)),
  );
  if (repository != null) {
    serviceLocator.registerLazySingleton<CashierDashboardRepository>(
      () => repository,
    );
  }
  setupServiceLocator(useBackend: false);
}

AuthSession sessionForRole(String role) => AuthSession(
  accessToken: 'cashier-test-token',
  user: AuthUser(
    id: 7,
    name: role == 'cashier' ? 'Sara Cashier' : 'Test Operator',
    role: role,
    email: 'operator@example.local',
  ),
  tenant: const AuthTenant(id: 1, name: 'Cafe 618'),
  mustChangePassword: false,
  lastValidatedAt: DateTime.utc(2026, 1, 1),
  offlineSessionMaxAgeSeconds: 43200,
);

Future<void> pumpApp(WidgetTester tester) async {
  await tester.pumpWidget(const App());
  await tester.pumpAndSettle();
}

/// A repository that returns whatever the test hands it, including a pending
/// future (for skeleton assertions) or an error (for retry assertions).
class FakeCashierDashboardRepository extends CashierDashboardRepository {
  /// Futures are produced per call rather than stored, so a failing case never
  /// creates an unawaited error future at construction time.
  FakeCashierDashboardRepository({
    Future<CashierDashboard> Function()? dashboardFuture,
    Future<CashierStockPage> Function()? inventoryFuture,
  }) : _dashboard = dashboardFuture,
       _inventory = inventoryFuture,
       super();

  final Future<CashierDashboard> Function()? _dashboard;
  final Future<CashierStockPage> Function()? _inventory;
  int dashboardCalls = 0;

  @override
  Future<CashierDashboard> dashboard({int? branchId}) {
    dashboardCalls++;
    final Future<CashierDashboard> Function()? build = _dashboard;
    return build == null
        ? Future<CashierDashboard>.value(openShiftDashboard())
        : build();
  }

  @override
  Future<CashierStockPage> inventory({
    int? branchId,
    String? search,
    String? state,
    int page = 1,
    int perPage = 50,
  }) {
    final Future<CashierStockPage> Function()? build = _inventory;
    return build == null
        ? Future<CashierStockPage>.value(stockPage())
        : build();
  }
}

/// A dashboard payload shaped exactly like the endpoint's response, including
/// the deliberate absence of any profit, cost or valuation field.
CashierDashboard openShiftDashboard({
  Map<String, dynamic> overrides = const <String, dynamic>{},
}) => CashierDashboard.fromJson(<String, dynamic>{
  'scope': <String, dynamic>{
    'kind': 'current_shift',
    'branchId': 1,
    'branchName': '618TierFour',
    'cashierId': 7,
    'cashierName': 'Sara Cashier',
    'currency': 'SYP',
  },
  'shift': <String, dynamic>{
    'id': 42,
    'status': 'open',
    'openedAt': '2026-09-16T09:12:00Z',
    'durationSeconds': 16080,
  },
  'cashDrawer': <String, dynamic>{
    'available': true,
    'openingCash': '50000.00',
    'cashSales': '245000.00',
    'cashRefunds': '5000.00',
    'expectedCash': '290000.00',
    'cashSaleCount': 18,
    'cashRefundCount': 1,
  },
  'sales': <String, dynamic>{
    'available': true,
    'netSales': '400000.00',
    'grossSales': '405000.00',
    'discounts': '12000.00',
    'refunds': '5000.00',
    'orderCount': 24,
    'averageOrderValue': '16875.00',
    'byMethod': <Map<String, dynamic>>[
      <String, dynamic>{'method': 'cash', 'count': 18, 'amount': '245000.00'},
      <String, dynamic>{'method': 'card', 'count': 6, 'amount': '160000.00'},
    ],
  },
  'orders': <String, dynamic>{
    'active': 2,
    'held': 1,
    'completed': 24,
    'blockingCount': 3,
  },
  'inventory': <String, dynamic>{
    'warehouseId': 5,
    'warehouseName': '618TierFour — Main Store',
    'configured': true,
    'ambiguous': false,
    'totalItems': 120,
    'lowStockCount': 7,
    'zeroStockCount': 2,
    'negativeStockCount': 3,
    'shiftCount': <String, dynamic>{
      'required': true,
      'completed': false,
      'pendingTemplates': 1,
    },
  },
  'finance': <String, dynamic>{
    'capabilities': <String, dynamic>{
      'vouchers': true,
      'purchases': true,
      'sales': true,
      'receipts': true,
      'payments': true,
    },
    'receiptVouchers': <String, dynamic>{'count': 3, 'cashTotal': '75000.00'},
    'paymentVouchers': <String, dynamic>{'count': 1, 'cashTotal': '20000.00'},
    'purchaseDocumentCount': 2,
    'salesInvoiceCount': 4,
  },
  'alerts': <Map<String, dynamic>>[
    <String, dynamic>{
      'severity': 'warning',
      'code': 'NEGATIVE_STOCK_ITEMS',
      'count': 3,
    },
  ],
  ...overrides,
});

CashierDashboard noShiftDashboard() => openShiftDashboard(
  overrides: <String, dynamic>{
    'scope': <String, dynamic>{
      'kind': 'branch_only',
      'branchId': 1,
      'branchName': '618TierFour',
      'cashierId': 7,
      'cashierName': 'Sara Cashier',
      'currency': 'SYP',
    },
    'shift': null,
    'cashDrawer': <String, dynamic>{'available': false},
    'sales': <String, dynamic>{'available': false},
    'finance': <String, dynamic>{
      'capabilities': <String, dynamic>{'vouchers': true},
    },
    'alerts': <Map<String, dynamic>>[
      <String, dynamic>{'severity': 'info', 'code': 'NO_OPEN_SHIFT'},
    ],
  },
);

CashierStockPage stockPage() => CashierStockPage.fromJson(<String, dynamic>{
  'warehouseName': '618TierFour — Main Store',
  'configured': true,
  'items': <Map<String, dynamic>>[
    <String, dynamic>{
      'itemId': 1,
      'nameAr': 'حليب',
      'nameEn': 'Milk',
      'sku': 'MLK-1',
      'unit': 'L',
      'quantity': '-5.000',
      'state': 'negative',
      'lastMovementAt': '2026-09-16T10:00:00Z',
    },
    <String, dynamic>{
      'itemId': 2,
      'nameAr': 'بن',
      'nameEn': 'Coffee beans',
      'sku': 'CFE-1',
      'unit': 'kg',
      'quantity': '1.500',
      'state': 'low',
      'lastMovementAt': '2026-09-16T09:00:00Z',
    },
  ],
  'meta': <String, dynamic>{
    'currentPage': 1,
    'perPage': 50,
    'total': 2,
    'lastPage': 1,
  },
});

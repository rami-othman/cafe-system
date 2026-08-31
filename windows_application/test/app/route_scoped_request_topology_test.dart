import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:windows_application/app/app.dart';
import 'package:windows_application/app/app_router.dart';
import 'package:windows_application/core/services/service_locator.dart';
import 'package:windows_application/features/discounts/models/discount_list_item.dart';
import 'package:windows_application/features/discounts/models/discount_upsert_request.dart';
import 'package:windows_application/features/discounts/repositories/discounts_repository.dart';
import 'package:windows_application/features/menu_management/repositories/menu_catalog_repository.dart';
import 'package:windows_application/features/orders/controllers/orders_state.dart';
import 'package:windows_application/features/orders/models/order_summary.dart';
import 'package:windows_application/features/orders/repositories/orders_repository.dart';
import 'package:windows_application/features/pos/models/branch.dart';
import 'package:windows_application/features/reports/models/daily_report_data.dart';
import 'package:windows_application/features/reports/repositories/reports_repository.dart';

void main() {
  setUp(() async {
    await serviceLocator.reset();
    setupServiceLocator(useBackend: false);
  });

  tearDown(() => appRouter.go(AppRoutes.pos));

  testWidgets('POS does not request unvisited feature repositories', (
    WidgetTester tester,
  ) async {
    final _TopologySpies spies = _installSpies();
    appRouter.go(AppRoutes.pos);

    await _pumpApp(tester);

    expect(spies.orders.requests, 0);
    expect(spies.discounts.requests, 0);
    expect(spies.reports.requests, 0);
    expect(spies.menu.requests, 0);
  });

  testWidgets('Orders initializes only Orders data', (
    WidgetTester tester,
  ) async {
    final _TopologySpies spies = _installSpies();
    appRouter.go(AppRoutes.orders);

    await _pumpApp(tester);

    expect(spies.orders.requests, greaterThan(0));
    expect(spies.discounts.requests, 0);
    expect(spies.reports.requests, 0);
    expect(spies.menu.requests, 0);
  });

  testWidgets('Reports initializes only report data', (
    WidgetTester tester,
  ) async {
    final _TopologySpies spies = _installSpies();
    appRouter.go(AppRoutes.reports);

    await _pumpApp(tester);

    expect(spies.orders.requests, 0);
    expect(spies.discounts.requests, 0);
    expect(spies.reports.requests, 1);
    expect(spies.menu.requests, 0);
  });

  testWidgets('Discounts initializes only discount-management data', (
    WidgetTester tester,
  ) async {
    final _TopologySpies spies = _installSpies();
    appRouter.go(AppRoutes.discounts);

    await _pumpApp(tester);

    expect(spies.orders.requests, 0);
    expect(spies.discounts.requests, 1);
    expect(spies.reports.requests, 0);
    expect(spies.menu.requests, 0);
  });
}

Future<void> _pumpApp(WidgetTester tester) async {
  tester.view.physicalSize = const Size(1280, 800);
  tester.view.devicePixelRatio = 1;
  addTearDown(() {
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });
  await tester.pumpWidget(const App());
  await tester.pumpAndSettle();
}

_TopologySpies _installSpies() {
  final _TopologySpies spies = _TopologySpies();
  serviceLocator.unregister<OrdersRepository>();
  serviceLocator.registerLazySingleton<OrdersRepository>(() => spies.orders);
  serviceLocator.unregister<DiscountsRepository>();
  serviceLocator.registerLazySingleton<DiscountsRepository>(
    () => spies.discounts,
  );
  serviceLocator.unregister<ReportsRepository>();
  serviceLocator.registerLazySingleton<ReportsRepository>(() => spies.reports);
  serviceLocator.unregister<MenuCatalogRepository>();
  serviceLocator.registerLazySingleton<MenuCatalogRepository>(() => spies.menu);
  return spies;
}

class _TopologySpies {
  final _SpyOrdersRepository orders = _SpyOrdersRepository();
  final _SpyDiscountsRepository discounts = _SpyDiscountsRepository();
  final _SpyReportsRepository reports = _SpyReportsRepository();
  final _SpyMenuCatalogRepository menu = _SpyMenuCatalogRepository();
}

class _SpyOrdersRepository extends OrdersRepository {
  int requests = 0;

  @override
  Future<List<Branch>> getBranches() async {
    requests++;
    return const <Branch>[
      Branch(
        id: 1,
        name: 'Downtown',
        currency: 'SYP',
        timezone: 'Asia/Damascus',
        isActive: true,
      ),
    ];
  }

  @override
  Future<List<OrderSummary>> getOrders({
    required int branchId,
    OrdersFilter? filter,
  }) async {
    requests++;
    return const <OrderSummary>[];
  }
}

class _SpyDiscountsRepository implements DiscountsRepository {
  int requests = 0;

  @override
  Future<List<DiscountListItem>> getDiscounts() async {
    requests++;
    return const <DiscountListItem>[];
  }

  @override
  Future<List<Branch>> getBranches() async => const <Branch>[];

  @override
  Future<DiscountListItem> createDiscount(DiscountUpsertRequest request) =>
      throw UnimplementedError();

  @override
  Future<void> deleteDiscount(String discountId) => throw UnimplementedError();

  @override
  Future<DiscountListItem> setStatus(String discountId, bool isActive) =>
      throw UnimplementedError();

  @override
  Future<DiscountListItem> updateDiscount(
    String discountId,
    DiscountUpsertRequest request,
  ) => throw UnimplementedError();
}

class _SpyReportsRepository extends ReportsRepository {
  int requests = 0;

  @override
  Future<DailyReportData> getDailyReport({
    DateTime? date,
    int? branchId,
  }) async {
    requests++;
    return DailyReportData.mock();
  }
}

class _SpyMenuCatalogRepository implements MenuCatalogRepository {
  int requests = 0;

  @override
  dynamic noSuchMethod(Invocation invocation) {
    requests++;
    throw UnimplementedError('Menu Management must not initialize here.');
  }
}

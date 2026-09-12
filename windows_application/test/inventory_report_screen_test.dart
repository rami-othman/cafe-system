import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:windows_application/app/app.dart';
import 'package:windows_application/app/app_router.dart';
import 'package:windows_application/core/services/service_locator.dart';
import 'package:windows_application/features/reports/models/inventory_report.dart';
import 'package:windows_application/features/reports/repositories/inventory_report_repository.dart';
import 'package:windows_application/features/reports/views/inventory_report_screen.dart';
import 'package:windows_application/features/reports/widgets/reports_overview_components.dart';

void main() {
  setUp(() async {
    await serviceLocator.reset();
    setupServiceLocator(useBackend: false);
  });
  tearDown(() => appRouter.go(AppRoutes.pos));

  testWidgets('Inventory route renders its read-only report sections', (
    tester,
  ) async {
    appRouter.go(AppRoutes.reportsInventory);
    await _pump(tester);
    expect(find.byType(InventoryReportScreen), findsOneWidget);
    for (final text in <String>[
      'Inventory',
      'Current inventory value',
      'Inventory value by location',
      'Inventory movement',
      'Stock health',
      'Low and out-of-stock items',
      'Consumption analysis',
      'Waste analysis',
      'Stock-count variances',
      'Location comparison',
      'Inventory exceptions',
    ]) {
      expect(find.text(text), findsWidgets);
    }
    expect(tester.takeException(), isNull);
  });

  testWidgets('shows skeleton then safe retryable error', (tester) async {
    final completer = Completer<InventoryReport>();
    serviceLocator.unregister<InventoryReportRepository>();
    serviceLocator.registerLazySingleton<InventoryReportRepository>(
      () => _DeferredRepository(completer.future),
    );
    appRouter.go(AppRoutes.reportsInventory);
    await tester.pumpWidget(const App());
    await tester.pump();
    expect(find.byType(ReportsOverviewSkeletonCard), findsWidgets);
    completer.completeError(Exception('database details must remain hidden'));
    await tester.pumpAndSettle();
    expect(find.text('Unable to load the Inventory report.'), findsOneWidget);
    expect(find.textContaining('database details'), findsNothing);
  });

  testWidgets('is overflow-free at desktop widths', (tester) async {
    for (final width in <double>[1280, 1366, 1440, 1600, 1920]) {
      tester.view.physicalSize = Size(width, 900);
      tester.view.devicePixelRatio = 1;
      appRouter.go(AppRoutes.reportsInventory);
      await _pump(tester);
      expect(tester.takeException(), isNull);
    }
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });
}

Future<void> _pump(WidgetTester tester) async {
  await tester.pumpWidget(const App());
  await tester.pumpAndSettle();
}

class _DeferredRepository extends InventoryReportRepository {
  const _DeferredRepository(this.future);
  final Future<InventoryReport> future;
  @override
  Future<InventoryReport> getReport({
    required DateTime from,
    required DateTime to,
    required int? branchId,
    required int? locationId,
    required int? categoryId,
    required bool comparePrevious,
  }) => future;
}

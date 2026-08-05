import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:windows_application/core/network/dio_api_client.dart';
import 'package:windows_application/features/menu_management/catalog_setup/controllers/catalog_setup_cubit.dart';
import 'package:windows_application/features/menu_management/catalog_setup/models/catalog_setup_models.dart';
import 'package:windows_application/features/menu_management/catalog_setup/views/catalog_setup_screen.dart';
import 'package:windows_application/features/menu_management/models/catalog_models.dart';
import 'package:windows_application/features/menu_management/repositories/menu_catalog_repository.dart';
import 'package:windows_application/l10n/app_localizations.dart';

void main() {
  testWidgets(
    'Catalog Setup renders controls, dialogs, pagination, and usage',
    (tester) async {
      await _pump(tester, const Locale('en'));

      expect(find.text('Catalog Setup'), findsWidgets);
      expect(find.text('Catalog Categories'), findsNWidgets(2));
      expect(find.text('3'), findsOneWidget);
      expect(find.text('Page 1'), findsOneWidget);
      final Finder moveUp = find.ancestor(
        of: find.byTooltip('Move up').first,
        matching: find.byType(IconButton),
      );
      final Finder moveDown = find.ancestor(
        of: find.byTooltip('Move down').last,
        matching: find.byType(IconButton),
      );
      expect(moveUp, findsOneWidget);
      expect(tester.widget<IconButton>(moveUp).onPressed, isNull);
      expect(moveDown, findsOneWidget);
      expect(tester.widget<IconButton>(moveDown).onPressed, isNull);

      await tester.tap(find.text('Create Category'));
      await tester.pump();
      expect(find.byType(AlertDialog), findsOneWidget);
      expect(find.text('Name'), findsWidgets);
      await tester.tap(find.text('Cancel').last);
      await tester.pump();

      await tester.tap(find.byTooltip('Archive Category').first);
      await tester.pump();
      expect(find.text('Archive Category'), findsNWidgets(2));
      expect(
        find.textContaining('Existing Product assignments'),
        findsOneWidget,
      );
    },
  );

  testWidgets('Kitchen Station technical values remain LTR in Arabic', (
    tester,
  ) async {
    await _pump(
      tester,
      const Locale('ar'),
      kind: CatalogSetupKind.kitchenStations,
    );

    final AppLocalizations l10n = AppLocalizations.of(
      tester.element(find.byType(CatalogSetupScreen)),
    );
    expect(find.text(l10n.catalogSetupTitle), findsOneWidget);
    expect(find.text(l10n.catalogSetupKitchenStationsTitle), findsNWidgets(2));
    final Finder value = find.text('BAR · bar-printer');
    expect(value, findsOneWidget);
    expect(
      tester
          .widget<Directionality>(
            find
                .ancestor(of: value, matching: find.byType(Directionality))
                .first,
          )
          .textDirection,
      TextDirection.ltr,
    );
    expect(tester.takeException(), isNull);
  });
}

Future<void> _pump(
  WidgetTester tester,
  Locale locale, {
  CatalogSetupKind kind = CatalogSetupKind.categories,
}) async {
  tester.view.physicalSize = const Size(1440, 1200);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(
    MaterialApp(
      locale: locale,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: BlocProvider<CatalogSetupCubit>(
        create: (_) =>
            CatalogSetupCubit(repository: _CatalogSetupUiRepository()),
        child: Scaffold(body: CatalogSetupScreen(initialKind: kind)),
      ),
    ),
  );
  await tester.pump();
  await tester.pump();
}

class _CatalogSetupUiRepository extends BackendMenuCatalogRepository {
  _CatalogSetupUiRepository()
    : super(DioApiClient(dio: Dio(BaseOptions(baseUrl: 'http://localhost/'))));

  @override
  Future<CatalogSetupPage> listCatalogSetup({
    required CatalogSetupKind kind,
    required CatalogSetupStatus status,
    required String search,
    required int page,
    int perPage = 20,
  }) async => CatalogSetupPage(
    items: <CatalogSetupRecord>[
      CatalogSetupRecord(
        id: 1,
        name: kind == CatalogSetupKind.kitchenStations ? 'Bar' : 'Coffee',
        nameAr: '',
        nameEn: '',
        description: '',
        code: kind == CatalogSetupKind.kitchenStations ? 'BAR' : '',
        printerName: kind == CatalogSetupKind.kitchenStations
            ? 'bar-printer'
            : '',
        branchId: null,
        isActive: true,
        sortOrder: 0,
        productCount: 3,
      ),
      const CatalogSetupRecord(
        id: 2,
        name: 'Tea',
        nameAr: '',
        nameEn: '',
        description: '',
        code: '',
        printerName: '',
        branchId: null,
        isActive: false,
        sortOrder: 1,
        productCount: 0,
      ),
    ],
    meta: const CatalogPagination(
      currentPage: 1,
      lastPage: 2,
      perPage: 20,
      total: 21,
    ),
  );
}

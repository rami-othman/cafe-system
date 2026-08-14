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
    expect(find.text(l10n.catalogSetupTitle), findsWidgets);
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

  testWidgets(
    'route-style tab changes sync the active tab and its saved search query',
    (tester) async {
      final CatalogSetupCubit cubit = CatalogSetupCubit(
        repository: _CatalogSetupUiRepository(),
      );
      addTearDown(cubit.close);
      tester.view.physicalSize = const Size(1440, 1200);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(_CatalogSetupHarness(cubit: cubit));
      await tester.pump();
      await tester.pump();

      await tester.enterText(find.byType(TextField), 'coffee');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pump();
      expect(cubit.state.search, 'coffee');

      await tester.tap(find.text('Open kitchen stations'));
      await tester.pump();
      await tester.pump();
      expect(cubit.state.kind, CatalogSetupKind.kitchenStations);
      expect(
        tester.widget<TextField>(find.byType(TextField)).controller!.text,
        isEmpty,
      );

      await tester.enterText(find.byType(TextField), 'bar');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pump();
      await tester.tap(find.text('Open categories'));
      await tester.pump();
      await tester.pump();

      expect(cubit.state.kind, CatalogSetupKind.categories);
      expect(cubit.state.search, 'coffee');
      expect(
        tester.widget<TextField>(find.byType(TextField)).controller!.text,
        'coffee',
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('Catalog Setup renders error retry and empty states safely', (
    tester,
  ) async {
    final _CatalogSetupUiRepository repository = _CatalogSetupUiRepository()
      ..failLists = true;
    await _pump(tester, const Locale('en'), repository: repository);
    expect(find.text('Retry'), findsOneWidget);
    expect(find.textContaining('SQL'), findsNothing);
    expect(find.textContaining('stack trace'), findsNothing);

    repository.failLists = false;
    await tester.tap(find.text('Retry'));
    await tester.pump();
    await tester.pump();
    expect(find.text('Coffee'), findsOneWidget);

    repository.emptyLists = true;
    await tester.tap(find.text('Refresh'));
    await tester.pump();
    await tester.pump();
    expect(find.text('No matching records.'), findsOneWidget);
  });

  testWidgets(
    'Catalog Setup controls submit mutations and backend pagination',
    (tester) async {
      final _CatalogSetupUiRepository repository = _CatalogSetupUiRepository();
      await _pump(tester, const Locale('en'), repository: repository);

      await tester.enterText(find.byType(TextField), 'coffee');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pump();
      expect(repository.listCalls.last.search, 'coffee');

      await tester.tap(find.text('Next'));
      await tester.pump();
      expect(repository.listCalls.last.page, 2);

      await tester.tap(find.text('Create Category'));
      await tester.pump();
      await tester.enterText(find.byType(TextField).at(1), 'Cold drinks');
      await tester.tap(find.text('Save'));
      await tester.pump();
      await tester.pump();
      expect(repository.mutations, contains('create'));

      await tester.tap(find.byTooltip('Edit').first);
      await tester.pump();
      await tester.enterText(find.byType(TextField).at(1), 'Updated coffee');
      await tester.tap(find.text('Save'));
      await tester.pump();
      await tester.pump();
      expect(repository.mutations, contains('update'));

      await tester.tap(find.byTooltip('Archive Category').first);
      await tester.pump();
      expect(
        find.textContaining('Existing Product assignments'),
        findsOneWidget,
      );
      await tester.tap(find.text('Archive Category').last);
      await tester.pump();
      await tester.pump();
      expect(repository.mutations, contains('archive'));

      await tester.tap(find.byTooltip('Restore').first);
      await tester.pump();
      await tester.pump();
      expect(repository.mutations, contains('restore'));
      await tester.tap(find.byTooltip('Move down').first);
      await tester.pump();
      expect(repository.mutations, contains('reorder'));
    },
  );

  testWidgets('Arabic dialogs and long localized names remain stable', (
    tester,
  ) async {
    final _CatalogSetupUiRepository repository = _CatalogSetupUiRepository()
      ..itemName = 'تصنيف مشروبات ساخنة وطويل للغاية للاختبار';
    await _pump(tester, const Locale('ar'), repository: repository);
    final AppLocalizations l10n = AppLocalizations.of(
      tester.element(find.byType(CatalogSetupScreen)),
    );
    expect(find.text(repository.itemName!), findsOneWidget);
    await tester.tap(
      find.text(l10n.catalogSetupCreate(l10n.catalogSetupCategory)),
    );
    await tester.pump();
    expect(
      Directionality.of(tester.element(find.byType(AlertDialog))),
      TextDirection.rtl,
    );
    await tester.tap(find.text(l10n.commonCancel).last);
    await tester.pump();
    await tester.tap(
      find.byTooltip(l10n.catalogSetupArchive(l10n.catalogSetupCategory)),
    );
    await tester.pump();
    expect(
      Directionality.of(tester.element(find.byType(AlertDialog))),
      TextDirection.rtl,
    );
    expect(tester.takeException(), isNull);
  });
}

class _CatalogSetupHarness extends StatefulWidget {
  const _CatalogSetupHarness({required this.cubit});
  final CatalogSetupCubit cubit;

  @override
  State<_CatalogSetupHarness> createState() => _CatalogSetupHarnessState();
}

class _CatalogSetupHarnessState extends State<_CatalogSetupHarness> {
  CatalogSetupKind kind = CatalogSetupKind.categories;

  @override
  Widget build(BuildContext context) => MaterialApp(
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: Scaffold(
      body: BlocProvider.value(
        value: widget.cubit,
        child: Column(
          children: <Widget>[
            TextButton(
              onPressed: () =>
                  setState(() => kind = CatalogSetupKind.kitchenStations),
              child: const Text('Open kitchen stations'),
            ),
            TextButton(
              onPressed: () =>
                  setState(() => kind = CatalogSetupKind.categories),
              child: const Text('Open categories'),
            ),
            Expanded(child: CatalogSetupScreen(initialKind: kind)),
          ],
        ),
      ),
    ),
  );
}

Future<void> _pump(
  WidgetTester tester,
  Locale locale, {
  CatalogSetupKind kind = CatalogSetupKind.categories,
  _CatalogSetupUiRepository? repository,
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
        create: (_) => CatalogSetupCubit(
          repository: repository ?? _CatalogSetupUiRepository(),
        ),
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

  final List<_UiListCall> listCalls = <_UiListCall>[];
  final List<String> mutations = <String>[];
  bool failLists = false;
  bool emptyLists = false;
  String? itemName;

  @override
  Future<CatalogSetupPage> listCatalogSetup({
    required CatalogSetupKind kind,
    required CatalogSetupStatus status,
    required String search,
    required int page,
    int perPage = 20,
  }) async {
    listCalls.add(_UiListCall(status: status, search: search, page: page));
    if (failLists) throw StateError('offline');
    return CatalogSetupPage(
      items: emptyLists
          ? const <CatalogSetupRecord>[]
          : <CatalogSetupRecord>[
              CatalogSetupRecord(
                id: 1,
                name: kind == CatalogSetupKind.kitchenStations
                    ? 'Bar'
                    : itemName ?? 'Coffee',
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
      meta: CatalogPagination(
        currentPage: page,
        lastPage: 2,
        perPage: 20,
        total: emptyLists ? 0 : 21,
      ),
    );
  }

  @override
  Future<CatalogSetupRecord> createCatalogSetup(
    CatalogSetupKind kind,
    CatalogSetupDraft draft,
  ) async => _mutate('create', draft.name);

  @override
  Future<CatalogSetupRecord> updateCatalogSetup(
    CatalogSetupKind kind,
    int id,
    CatalogSetupDraft draft,
  ) async => _mutate('update', draft.name, id: id);

  @override
  Future<CatalogSetupRecord> archiveCatalogSetup(
    CatalogSetupKind kind,
    int id,
  ) async => _mutate('archive', 'Coffee', id: id, active: false);

  @override
  Future<CatalogSetupRecord> restoreCatalogSetup(
    CatalogSetupKind kind,
    int id,
  ) async => _mutate('restore', 'Tea', id: id);

  @override
  Future<void> reorderCatalogSetup(
    CatalogSetupKind kind,
    List<CatalogSetupRecord> items,
  ) async {
    mutations.add('reorder');
  }

  CatalogSetupRecord _mutate(
    String mutation,
    String name, {
    int id = 1,
    bool active = true,
  }) {
    mutations.add(mutation);
    return CatalogSetupRecord(
      id: id,
      name: name,
      nameAr: '',
      nameEn: '',
      description: '',
      code: '',
      printerName: '',
      branchId: null,
      isActive: active,
      sortOrder: 0,
      productCount: 0,
    );
  }
}

class _UiListCall {
  const _UiListCall({
    required this.status,
    required this.search,
    required this.page,
  });
  final CatalogSetupStatus status;
  final String search;
  final int page;
}

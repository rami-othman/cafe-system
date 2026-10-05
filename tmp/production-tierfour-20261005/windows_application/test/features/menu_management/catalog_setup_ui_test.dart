import 'dart:async';

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
  testWidgets('desktop toolbar is one compact row with the All filter', (
    tester,
  ) async {
    await _pump(tester, width: 1280);

    final toolbar = find.byKey(const Key('catalog-setup-toolbar-row'));
    final status = find.byKey(const Key('catalog-setup-status-filter'));
    expect(toolbar, findsOneWidget);
    expect(find.text('Status: All'), findsOneWidget);
    expect(tester.getSize(status).width, lessThanOrEqualTo(154));

    final top = tester.getTopLeft(find.byType(TextField).first).dy;
    for (final finder in <Finder>[
      status,
      find.widgetWithText(OutlinedButton, 'Refresh'),
      find.widgetWithText(FilledButton, 'Add Category'),
    ]) {
      expect(
        (tester.getTopLeft(finder.first).dy - top).abs(),
        lessThanOrEqualTo(6),
      );
    }
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'short desktop windows scroll instead of vertically overflowing',
    (tester) async {
      await _pump(tester, height: 501);

      expect(find.text('Catalog Setup'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('Catalog Setup shares tabs and changes the primary action', (
    tester,
  ) async {
    final repository = _CatalogSetupUiRepository();
    await _pump(tester, repository: repository);
    expect(find.text('Catalog Setup'), findsOneWidget);
    expect(find.text('Add Category'), findsOneWidget);
    expect(find.text('Products'), findsOneWidget);

    await tester.tap(find.text('Reporting Categories').first);
    await tester.pump();
    await tester.pump();
    expect(find.text('Add Reporting Category'), findsOneWidget);
    expect(
      find.text(
        'Reporting Categories do not control where Products appear in the menu.',
      ),
      findsOneWidget,
    );

    await tester.tap(find.text('Kitchen Stations').first);
    await tester.pump();
    await tester.pump();
    expect(find.text('Add Kitchen Station'), findsOneWidget);
  });

  testWidgets('first load uses skeleton rows and refresh preserves the list', (
    tester,
  ) async {
    final pending = Completer<CatalogSetupPage>();
    final repository = _CatalogSetupUiRepository()
      ..loader = (_, _, _, _) => pending.future;
    await _pump(tester, repository: repository, settle: false);
    await tester.pump();
    expect(find.byKey(const Key('catalog-setup-skeleton')), findsOneWidget);
    pending.complete(_page());
    await tester.pump();
    await tester.pump();
    expect(find.text('Coffee'), findsOneWidget);

    repository.loader = (_, _, _, _) async {
      await Future<void>.delayed(const Duration(milliseconds: 10));
      return _page();
    };
    await tester.tap(find.text('Refresh'));
    await tester.pump();
    expect(find.text('Coffee'), findsOneWidget);
    expect(find.byKey(const Key('catalog-setup-skeleton')), findsNothing);
    await tester.pump(const Duration(milliseconds: 20));
  });

  testWidgets('pagination follows the visible rows without blank table space', (
    tester,
  ) async {
    await _pump(tester);

    final list = find.byKey(const Key('catalog-setup-record-list'));
    final pagination = find.byKey(const Key('catalog-setup-pagination'));
    expect(list, findsOneWidget);
    expect(pagination, findsOneWidget);
    expect(
      tester.getTopLeft(pagination).dy - tester.getBottomLeft(list).dy,
      lessThanOrEqualTo(1),
    );
  });

  testWidgets('empty and error states keep the add and retry actions useful', (
    tester,
  ) async {
    final repository = _CatalogSetupUiRepository()..failLists = true;
    await _pump(tester, repository: repository);
    expect(find.text('Couldn’t load data'), findsOneWidget);
    expect(find.textContaining('offline'), findsNothing);
    repository.failLists = false;
    await tester.tap(find.text('Retry'));
    await tester.pump();
    await tester.pump();
    expect(find.text('Coffee'), findsOneWidget);

    repository.emptyLists = true;
    await tester.tap(find.text('Refresh'));
    await tester.pump();
    await tester.pump();
    expect(find.text('No categories yet'), findsOneWidget);
    expect(find.text('Add Category'), findsNWidgets(2));
  });

  testWidgets('add opens a side sheet, validates, and saves', (tester) async {
    final repository = _CatalogSetupUiRepository();
    await _pump(tester, repository: repository);
    await tester.tap(find.text('Add Category'));
    await tester.pump();
    expect(
      find.text('Use the names that staff and customers should recognize.'),
      findsOneWidget,
    );
    await tester.tap(find.text('Save Category'));
    await tester.pump();
    expect(find.text('Enter a name to continue.'), findsOneWidget);
    expect(find.text('English name'), findsOneWidget);
    expect(find.text('Arabic name'), findsOneWidget);
    await tester.enterText(find.byType(TextField).at(1), 'Cold drinks');
    await tester.tap(find.text('Save Category'));
    await tester.pump();
    await tester.pump();
    expect(repository.mutations, contains('create'));
  });

  testWidgets('localized editors expose only English and Arabic name fields', (
    tester,
  ) async {
    await _pump(tester);

    await tester.tap(find.text('Reporting Categories').first);
    await tester.pump();
    await tester.pump();
    await tester.tap(find.text('Add Reporting Category'));
    await tester.pump();
    expect(find.byType(TextField), findsNWidgets(3));
    expect(find.text('English name'), findsOneWidget);
    expect(find.text('Arabic name'), findsOneWidget);
    final reportingSave = tester.widget<Text>(
      find.text('Save Reporting Category'),
    );
    expect(reportingSave.maxLines, 1);
    expect(reportingSave.softWrap, isFalse);
    await tester.tap(find.text('Cancel'));
    await tester.pump();

    await tester.tap(find.byTooltip('Edit').first);
    await tester.pump();
    expect(find.text('Edit Reporting Category'), findsOneWidget);
    expect(find.byType(TextField), findsNWidgets(3));
    await tester.tap(find.text('Cancel'));
    await tester.pump();

    await tester.tap(find.text('Kitchen Stations').first);
    await tester.pump();
    await tester.pump();
    await tester.tap(find.text('Add Kitchen Station'));
    await tester.pump();
    expect(find.byType(TextField), findsNWidgets(3));
    expect(find.text('English name'), findsOneWidget);
    expect(find.text('Arabic name'), findsOneWidget);
    final kitchenSave = tester.widget<Text>(find.text('Save Kitchen Station'));
    expect(kitchenSave.maxLines, 1);
    expect(kitchenSave.softWrap, isFalse);
    expect(tester.takeException(), isNull);
  });

  testWidgets('catalog actions archive, restore, and reorder supported rows', (
    tester,
  ) async {
    final repository = _CatalogSetupUiRepository();
    await _pump(tester, repository: repository);

    await tester.tap(find.byTooltip('Archive Category').first);
    await tester.pump();
    await tester.tap(find.text('Archive Category').last);
    await tester.pump();
    await tester.pump();
    expect(repository.mutations, contains('archive'));

    final cubit = tester
        .element(find.byType(CatalogSetupScreen))
        .read<CatalogSetupCubit>();
    await cubit.setStatus(CatalogSetupStatus.archived);
    await tester.pump();
    await tester.tap(find.byTooltip('Restore'));
    await tester.pump();
    await tester.pump();
    expect(repository.mutations, contains('restore'));

    await cubit.setStatus(CatalogSetupStatus.all);
    await tester.pump();
    await tester.tap(find.byTooltip('Move down').first);
    await tester.pump();
    await tester.pump();
    expect(repository.mutations, contains('reorder'));
  });

  testWidgets('Arabic RTL layout has no row overflow and labels actions', (
    tester,
  ) async {
    await _pump(tester, locale: const Locale('ar'));
    final l10n = AppLocalizations.of(
      tester.element(find.byType(CatalogSetupScreen)),
    );
    expect(find.text(l10n.catalogSetupTitle), findsOneWidget);
    expect(find.byTooltip(l10n.catalogSetupMoveUp), findsWidgets);
    expect(
      Directionality.of(
        tester.element(find.byKey(const Key('catalog-setup-toolbar-row'))),
      ),
      TextDirection.rtl,
    );
    expect(
      find.text('${l10n.menuPublishStatus}: ${l10n.catalogSetupAll}'),
      findsOneWidget,
    );
    await tester.tap(find.text(l10n.catalogSetupReportingCategoriesTitle));
    await tester.pump();
    await tester.pump();
    await tester.tap(
      find.text(l10n.catalogSetupAdd(l10n.catalogSetupReportingCategory)),
    );
    await tester.pump();
    expect(find.text(l10n.catalogSetupNameEnglish), findsOneWidget);
    expect(find.text(l10n.catalogSetupNameArabic), findsOneWidget);
    expect(
      find.byWidgetPredicate(
        (widget) =>
            widget is Align &&
            widget.alignment == AlignmentDirectional.centerEnd,
      ),
      findsWidgets,
    );
    expect(tester.takeException(), isNull);
  });
}

Future<void> _pump(
  WidgetTester tester, {
  _CatalogSetupUiRepository? repository,
  Locale locale = const Locale('en'),
  bool settle = true,
  double width = 1440,
  double height = 1200,
}) async {
  tester.view.physicalSize = Size(width, height);
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
        child: const Scaffold(
          body: CatalogSetupScreen(initialKind: CatalogSetupKind.categories),
        ),
      ),
    ),
  );
  await tester.pump();
  if (settle) await tester.pump();
}

class _CatalogSetupUiRepository extends BackendMenuCatalogRepository {
  _CatalogSetupUiRepository()
    : super(DioApiClient(dio: Dio(BaseOptions(baseUrl: 'http://localhost/'))));

  final List<String> mutations = <String>[];
  bool failLists = false;
  bool emptyLists = false;
  Future<CatalogSetupPage> Function(
    CatalogSetupKind,
    CatalogSetupStatus,
    String,
    int,
  )?
  loader;

  @override
  Future<CatalogSetupPage> listCatalogSetup({
    required CatalogSetupKind kind,
    required CatalogSetupStatus status,
    required String search,
    required int page,
    int perPage = 20,
  }) {
    if (failLists) return Future<CatalogSetupPage>.error(StateError('offline'));
    if (loader != null) return loader!(kind, status, search, page);
    return Future<CatalogSetupPage>.value(
      emptyLists
          ? _page(items: const <CatalogSetupRecord>[])
          : status == CatalogSetupStatus.archived
          ? _page(items: <CatalogSetupRecord>[_record(archived: true)])
          : _page(),
    );
  }

  @override
  Future<CatalogSetupRecord> createCatalogSetup(
    CatalogSetupKind kind,
    CatalogSetupDraft draft,
  ) async {
    mutations.add('create');
    return _record(name: draft.name, id: 3);
  }

  @override
  Future<CatalogSetupRecord> archiveCatalogSetup(
    CatalogSetupKind kind,
    int id,
  ) async {
    mutations.add('archive');
    return _record(id: id, archived: true);
  }

  @override
  Future<CatalogSetupRecord> restoreCatalogSetup(
    CatalogSetupKind kind,
    int id,
  ) async {
    mutations.add('restore');
    return _record(id: id);
  }

  @override
  Future<void> reorderCatalogSetup(
    CatalogSetupKind kind,
    List<CatalogSetupRecord> items,
  ) async {
    mutations.add('reorder');
  }
}

CatalogSetupPage _page({List<CatalogSetupRecord>? items}) => CatalogSetupPage(
  items: items ?? <CatalogSetupRecord>[_record(), _record(name: 'Tea', id: 2)],
  meta: const CatalogPagination(
    currentPage: 1,
    lastPage: 1,
    perPage: 20,
    total: 2,
  ),
);

CatalogSetupRecord _record({
  String name = 'Coffee',
  int id = 1,
  bool archived = false,
}) => CatalogSetupRecord(
  id: id,
  name: name,
  nameAr: id == 1 ? 'قهوة' : '',
  nameEn: '',
  description: '',
  code: '',
  printerName: '',
  branchId: null,
  isActive: !archived,
  isArchived: archived,
  sortOrder: id - 1,
  productCount: 3,
);

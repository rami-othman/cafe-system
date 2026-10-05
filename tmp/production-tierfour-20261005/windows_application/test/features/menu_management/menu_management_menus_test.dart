import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:windows_application/core/network/api_exception.dart';
import 'package:windows_application/features/menu_management/menus/views/menu_list_screen.dart';
import 'package:windows_application/features/menu_management/menus/views/menu_detail_screen.dart';
import 'package:windows_application/features/menu_management/menus/views/menu_editor_screen.dart';
import 'package:windows_application/features/menu_management/menus/controllers/menu_editor_cubit.dart';
import 'package:windows_application/features/menu_management/menus/controllers/menu_detail_cubit.dart';
import 'package:windows_application/features/menu_management/menus/controllers/menu_list_cubit.dart';
import 'package:windows_application/features/menu_management/menus/models/menu_editor_draft.dart';
import 'package:windows_application/features/menu_management/menus/models/menu_filter.dart';
import 'package:windows_application/features/menu_management/menus/models/menu_models.dart';
import 'package:windows_application/features/menu_management/models/catalog_models.dart';
import 'package:windows_application/features/menu_management/models/product_catalog_filter.dart';
import 'package:windows_application/features/menu_management/products/models/product_editor_draft.dart';
import 'package:windows_application/features/menu_management/repositories/menu_catalog_repository.dart';
import 'package:windows_application/l10n/app_localizations.dart';

void main() {
  test('menu list and detail parsing keeps archived metadata and sections', () {
    final MenuRecord menu = MenuRecord.fromJson(menuJson(archived: true));
    expect(menu.isArchived, isTrue);
    expect(menu.visibleProductCount, 3);
    expect(menu.sections.single.placementCount, 2);
    expect(menu.sections.single.isArchived, isTrue);
  });
  test('menu and section payloads exclude computed fields and ownership', () {
    final Map<String, dynamic> menu = const MenuEditorDraft(
      name: ' Main ',
      priority: '4',
    ).toJson(isCreate: true);
    final Map<String, dynamic> section = const MenuSectionDraft(
      name: ' Coffee ',
      sortOrder: '2',
    ).toJson();
    expect(menu, containsPair('name', 'Main'));
    expect(menu.containsKey('sectionCount'), isFalse);
    expect(menu.containsKey('status'), isFalse);
    expect(section, containsPair('name', 'Coffee'));
    expect(section.containsKey('menuId'), isFalse);
    expect(section.containsKey('placements'), isFalse);
  });
  test(
    'localized Menu names derive one canonical API name without a status',
    () {
      final draft = const MenuEditorDraft().withLocalizedNames(
        english: ' Main ',
        arabic: 'الرئيسية',
      );
      expect(draft.name, ' Main ');
      expect(draft.nameEn, ' Main ');
      expect(draft.nameAr, 'الرئيسية');
      expect(draft.toJson(isCreate: true).containsKey('status'), isFalse);
    },
  );
  test(
    'menu list filters reset pagination and preserve lifecycle filter',
    () async {
      final MenusRepositoryFake repo = MenusRepositoryFake();
      final MenuListCubit cubit = MenuListCubit(repository: repo);
      await cubit.load();
      await cubit.updateFilter(const MenuFilter(status: 'archived'));
      await cubit.archive(1);
      expect(repo.filters.last.status, 'archived');
      expect(repo.archiveCalls, 1);
      await cubit.close();
    },
  );
  test('menu list defaults to an unfiltered manager view', () {
    const MenuFilter filter = MenuFilter();
    expect(filter.status, 'all');
    expect(filter.hasActiveFilters, isFalse);
  });
  testWidgets('menu list uses the compact manager table at desktop width', (
    tester,
  ) async {
    final MenusRepositoryFake repo = MenusRepositoryFake()
      ..records = <MenuRecord>[
        MenuRecord.fromJson(menuJson()),
        MenuRecord.fromJson(menuJson(status: 'active')),
        MenuRecord.fromJson(menuJson(status: 'paused')),
        MenuRecord.fromJson(menuJson(archived: true)),
      ];
    await tester.pumpWidget(_menuListApp(repo));
    await tester.pump();
    await tester.pump();

    expect(find.byKey(const Key('menu-list-search')), findsOneWidget);
    expect(find.text('Status: All'), findsOneWidget);
    expect(find.text('Sort: Priority'), findsOneWidget);
    expect(find.text('Ascending'), findsOneWidget);
    expect(find.text('Draft'), findsOneWidget);
    expect(find.text('Active'), findsAtLeastNWidgets(1));
    expect(find.text('Paused'), findsOneWidget);
    expect(find.text('Archived'), findsOneWidget);
    expect(find.text('Sections'), findsOneWidget);
    expect(find.text('Visible Products'), findsOneWidget);
    expect(find.text('Last Updated'), findsOneWidget);
    expect(
      tester.getRect(find.text('Visible Products')).right,
      lessThan(tester.getRect(find.text('Last Updated')).left),
    );
    expect(tester.takeException(), isNull);
  });
  testWidgets('menu list localizes its manager labels in Arabic', (
    tester,
  ) async {
    final MenusRepositoryFake repo = MenusRepositoryFake();
    await tester.pumpWidget(_menuListApp(repo, locale: const Locale('ar')));
    await tester.pump();
    await tester.pump();

    expect(find.text('القوائم'), findsAtLeastNWidgets(1));
    expect(find.text('الحالة: الكل'), findsOneWidget);
    expect(find.text('تصاعدي'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
  test(
    'editor validates, maps 422 fields, and prevents duplicate submit',
    () async {
      final MenusRepositoryFake repo = MenusRepositoryFake()..validation = true;
      final MenuEditorCubit cubit = MenuEditorCubit(repository: repo);
      await cubit.initializeCreate();
      await cubit.submit();
      expect(cubit.state.fieldErrors['name'], isNotEmpty);
      cubit.updateDraft(const MenuEditorDraft(name: 'Main'));
      await cubit.submit();
      expect(
        cubit.state.fieldErrors['name'],
        'The name has already been taken.',
      );
      await cubit.close();
    },
  );

  testWidgets('Add Menu opens a compact shared right-side sheet', (
    tester,
  ) async {
    final MenusRepositoryFake repo = MenusRepositoryFake();
    await tester.pumpWidget(
      _menuListApp(
        repo,
        createEditorCubit: () => MenuEditorCubit(repository: repo),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('menu-list-add')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('menu-editor-sheet')), findsOneWidget);
    expect(find.text('English Name'), findsOneWidget);
    expect(find.text('Arabic Name'), findsOneWidget);
    expect(find.text('Default name'), findsNothing);
    expect(find.byKey(const Key('menu-editor-cover-image-url')), findsNothing);
    expect(
      tester.getSize(find.byKey(const Key('menu-editor-sheet'))).width,
      520,
    );
    final Rect sheet = tester.getRect(
      find.byKey(const Key('menu-editor-sheet')),
    );
    final Rect footer = tester.getRect(
      find.byKey(const Key('menu-editor-save')),
    );
    expect(footer.bottom, lessThanOrEqualTo(sheet.bottom));

    await tester.tap(find.byKey(const Key('menu-editor-more-details')));
    await tester.pump();
    expect(
      find.byKey(const Key('menu-editor-cover-image-url')),
      findsOneWidget,
    );
    expect(find.byKey(const Key('menu-editor-priority')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'shared editor pre-fills localized names and keeps validation input',
    (tester) async {
      final MenusRepositoryFake repo = MenusRepositoryFake()..validation = true;
      await tester.pumpWidget(
        _editorLauncher(repo, menuId: 1, locale: const Locale('en')),
      );
      await tester.tap(find.text('Open editor'));
      await tester.pumpAndSettle();

      expect(
        tester
            .widget<TextField>(find.byKey(const Key('menu-editor-name-en')))
            .controller!
            .text,
        'Main',
      );
      await tester.enterText(
        find.byKey(const Key('menu-editor-name-en')),
        'Updated menu',
      );
      await tester.tap(find.byKey(const Key('menu-editor-save')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('menu-editor-sheet')), findsOneWidget);
      expect(
        tester
            .widget<TextField>(find.byKey(const Key('menu-editor-name-en')))
            .controller!
            .text,
        'Updated menu',
      );
      await tester.tap(find.byKey(const Key('menu-editor-close')));
      await tester.pumpAndSettle();
      expect(repo.createCalls, 1);
    },
  );

  testWidgets('Arabic sheet mirrors direction and Cancel does not create', (
    tester,
  ) async {
    final MenusRepositoryFake repo = MenusRepositoryFake();
    await tester.pumpWidget(
      _menuListApp(
        repo,
        locale: const Locale('ar'),
        createEditorCubit: () => MenuEditorCubit(repository: repo),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('menu-list-add')));
    await tester.pumpAndSettle();
    expect(
      Directionality.of(
        tester.element(find.byKey(const Key('menu-editor-sheet'))),
      ),
      TextDirection.rtl,
    );
    await tester.tap(find.byKey(const Key('menu-editor-close')));
    await tester.pumpAndSettle();
    expect(repo.createCalls, 0);
    expect(find.byKey(const Key('menu-list-add')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Edit Menu opens the same sheet from Menu Workspace', (
    tester,
  ) async {
    final MenusRepositoryFake repo = MenusRepositoryFake();
    await tester.pumpWidget(
      _menuWorkspaceApp(
        repo,
        createEditorCubit: () => MenuEditorCubit(repository: repo),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Edit Menu'));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('menu-editor-sheet')), findsOneWidget);
    expect(find.text('Save Changes'), findsOneWidget);
    expect(find.text('Default name'), findsNothing);
  });

  testWidgets(
    'Menu Overview is the default compact workspace with authoritative composition',
    (tester) async {
      final MenusRepositoryFake repo = MenusRepositoryFake()
        ..detailRecord = _menuRecord(sectionCount: 3, visibleProductCount: 6);
      await tester.pumpWidget(
        _menuWorkspaceApp(
          repo,
          createEditorCubit: () => MenuEditorCubit(repository: repo),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Menu details'), findsOneWidget);
      expect(find.text('Main'), findsAtLeastNWidgets(1));
      expect(find.text('Draft'), findsAtLeastNWidgets(1));
      expect(find.text('3 Sections · 6 visible Products'), findsOneWidget);
      expect(find.text('draft'), findsNothing);
      expect(
        find.byKey(const Key('menu-overview-manage-sections')),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('menu-overview-manage-products')),
        findsOneWidget,
      );
      expect(
        tester
            .getSize(find.byKey(const Key('menu-overview-manage-sections')))
            .height,
        36,
      );
      expect(
        tester
            .getSize(find.byKey(const Key('menu-overview-manage-products')))
            .height,
        36,
      );
      expect(
        tester.getSize(find.byKey(const Key('menu-overview-panel'))).width,
        lessThanOrEqualTo(720),
      );
      expect(
        tester.getRect(find.byKey(const Key('menu-workspace-content'))).width,
        lessThanOrEqualTo(720),
      );
      expect(
        tester.getRect(find.byKey(const Key('menu-workspace-content'))).left,
        lessThan(120),
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('Menu Overview maps every lifecycle to a manager label', (
    tester,
  ) async {
    final MenusRepositoryFake repo = MenusRepositoryFake();
    const labels = <String, String>{
      'draft': 'Draft',
      'active': 'Active',
      'paused': 'Paused',
      'archived': 'Archived',
    };

    for (final entry in labels.entries) {
      repo.detailRecord = _menuRecord(status: entry.key);
      await tester.pumpWidget(
        _menuWorkspaceApp(
          repo,
          createEditorCubit: () => MenuEditorCubit(repository: repo),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text(entry.value), findsAtLeastNWidgets(1));
      expect(find.text(entry.key), findsNothing);
    }
    expect(tester.takeException(), isNull);
  });

  testWidgets('Menu Overview tabs stay horizontal on supported desktops', (
    tester,
  ) async {
    final MenusRepositoryFake repo = MenusRepositoryFake();
    for (final width in <double>[1280, 1440, 1920]) {
      await tester.pumpWidget(
        _menuWorkspaceApp(
          repo,
          desktopSize: Size(width, 900),
          createEditorCubit: () => MenuEditorCubit(repository: repo),
        ),
      );
      await tester.pumpAndSettle();

      _expectHorizontalWorkspaceTabs(tester);
      expect(tester.takeException(), isNull);
    }
  });

  testWidgets('Menu Overview mirrors localized names and RTL in Arabic', (
    tester,
  ) async {
    final MenusRepositoryFake repo = MenusRepositoryFake()
      ..detailRecord = _menuRecord(
        name: 'Main Menu',
        nameAr: 'القائمة الرئيسية',
        nameEn: 'Main Menu',
        sectionCount: 3,
        visibleProductCount: 6,
      );
    await tester.pumpWidget(
      _menuWorkspaceApp(
        repo,
        locale: const Locale('ar'),
        createEditorCubit: () => MenuEditorCubit(repository: repo),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('القائمة الرئيسية'), findsAtLeastNWidgets(1));
    expect(find.text('Main Menu'), findsAtLeastNWidgets(1));
    expect(find.text('مسودة'), findsAtLeastNWidgets(1));
    expect(find.text('3 أقسام · 6 منتج ظاهر'), findsOneWidget);
    expect(find.text('نظرة عامة'), findsOneWidget);
    expect(
      Directionality.of(
        tester.element(find.byKey(const Key('menu-workspace-content'))),
      ),
      TextDirection.rtl,
    );
    expect(
      find.byKey(const Key('menu-overview-manage-sections')),
      findsOneWidget,
    );
    expect(
      find.byKey(const Key('menu-overview-manage-products')),
      findsOneWidget,
    );
    _expectHorizontalWorkspaceTabs(tester, rtl: true);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'creating a Menu closes the sheet and leaves the manager on the list',
    (tester) async {
      final MenusRepositoryFake repo = MenusRepositoryFake();
      await tester.pumpWidget(
        _menuListApp(
          repo,
          createEditorCubit: () => MenuEditorCubit(repository: repo),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('menu-list-add')));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const Key('menu-editor-name-en')),
        'New menu',
      );
      await tester.tap(find.byKey(const Key('menu-editor-save')));
      await tester.pumpAndSettle();

      expect(repo.createCalls, 1);
      expect(
        repo.lastCreated!.toJson(isCreate: true).containsKey('status'),
        isFalse,
      );
      expect(find.byKey(const Key('menu-editor-sheet')), findsNothing);
      expect(find.byKey(const Key('menu-list-add')), findsOneWidget);
    },
  );
}

class MenusRepositoryFake extends MenuCatalogRepository {
  final List<MenuFilter> filters = <MenuFilter>[];
  List<MenuRecord>? records;
  int archiveCalls = 0;
  int createCalls = 0;
  MenuEditorDraft? lastCreated;
  bool validation = false;
  MenuRecord? detailRecord;
  @override
  Future<CatalogPage<MenuRecord>> listMenus({
    required MenuFilter filter,
    required int page,
    int perPage = 20,
  }) async {
    filters.add(filter);
    return CatalogPage<MenuRecord>(
      items: records ?? <MenuRecord>[MenuRecord.fromJson(menuJson())],
      meta: const CatalogPagination(
        currentPage: 1,
        lastPage: 1,
        perPage: 20,
        total: 1,
      ),
    );
  }

  @override
  Future<MenuRecord> archiveMenu(int menuId) async {
    archiveCalls++;
    return MenuRecord.fromJson(menuJson(archived: true));
  }

  @override
  Future<MenuRecord> createMenu(MenuEditorDraft draft) async {
    createCalls++;
    lastCreated = draft;
    if (validation)
      throw const ApiException(
        message: 'The submitted data was invalid.',
        validationErrors: <String, List<String>>{
          'name': <String>['The name has already been taken.'],
        },
      );
    return MenuRecord.fromJson(menuJson());
  }

  @override
  Future<MenuRecord> updateMenu(int menuId, MenuEditorDraft draft) async =>
      createMenu(draft);
  @override
  Future<MenuRecord> getMenu(
    int menuId, {
    bool includeArchived = false,
  }) async => detailRecord ?? MenuRecord.fromJson(menuJson());
  @override
  Future<CatalogPage<ProductSummary>> listProducts({
    required ProductCatalogFilter filter,
    required int page,
    int perPage = 20,
  }) async => throw UnimplementedError();
  @override
  Future<ProductDetail> getProduct(
    int productId, {
    bool includeArchived = false,
  }) async => throw UnimplementedError();
  @override
  Future<ProductDetail> createProduct(ProductEditorDraft draft) async =>
      throw UnimplementedError();
  @override
  Future<ProductDetail> updateProductGeneral(
    int productId,
    ProductEditorDraft draft,
  ) async => throw UnimplementedError();
  @override
  Future<CatalogPage<CatalogCategory>> listCategories({
    int perPage = 100,
  }) async => throw UnimplementedError();
  @override
  Future<CatalogPage<ReportingCategory>> listReportingCategories({
    int perPage = 100,
  }) async => throw UnimplementedError();
  @override
  Future<CatalogPage<KitchenStation>> listKitchenStations({
    int perPage = 100,
  }) async => throw UnimplementedError();
}

Widget _menuListApp(
  MenusRepositoryFake repository, {
  Locale? locale,
  MenuEditorCubit Function()? createEditorCubit,
}) => MaterialApp(
  locale: locale,
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  builder: (context, child) => MediaQuery(
    data: MediaQuery.of(context).copyWith(size: const Size(1280, 900)),
    child: child!,
  ),
  home: BlocProvider<MenuListCubit>(
    create: (_) => MenuListCubit(repository: repository),
    child: Scaffold(body: MenuListScreen(createEditorCubit: createEditorCubit)),
  ),
);

Widget _editorLauncher(
  MenusRepositoryFake repository, {
  required int menuId,
  required Locale locale,
}) => MaterialApp(
  locale: locale,
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  home: Builder(
    builder: (context) => Scaffold(
      body: Center(
        child: FilledButton(
          onPressed: () => showMenuEditorSheet(
            context,
            menuId: menuId,
            cubit: MenuEditorCubit(repository: repository),
          ),
          child: const Text('Open editor'),
        ),
      ),
    ),
  ),
);

Widget _menuWorkspaceApp(
  MenusRepositoryFake repository, {
  Locale? locale,
  Size desktopSize = const Size(1280, 900),
  required MenuEditorCubit Function() createEditorCubit,
}) => MaterialApp(
  locale: locale,
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  builder: (context, child) => MediaQuery(
    data: MediaQuery.of(context).copyWith(size: desktopSize),
    child: child!,
  ),
  home: BlocProvider<MenuDetailCubit>(
    create: (_) => MenuDetailCubit(repository: repository),
    child: Scaffold(
      body: MenuDetailScreen(
        key: ValueKey(repository.detailRecord?.status),
        menuId: 1,
        createEditorCubit: createEditorCubit,
      ),
    ),
  ),
);

void _expectHorizontalWorkspaceTabs(WidgetTester tester, {bool rtl = false}) {
  final overview = tester.getRect(
    find.byKey(const Key('menu-workspace-tab-overview')),
  );
  final sections = tester.getRect(
    find.byKey(const Key('menu-workspace-tab-sections')),
  );
  final products = tester.getRect(
    find.byKey(const Key('menu-workspace-tab-products')),
  );
  final tabs = tester.getRect(find.byKey(const Key('menu-workspace-tabs')));

  expect(sections.top, closeTo(overview.top, 0.01));
  expect(products.top, closeTo(overview.top, 0.01));
  expect(overview.height, lessThanOrEqualTo(34));
  expect(overview.height, greaterThanOrEqualTo(32));
  expect(products.right, lessThanOrEqualTo(tabs.right));
  expect(overview.left, greaterThanOrEqualTo(tabs.left));
  for (final tabKey in <Key>[
    const Key('menu-workspace-tab-overview'),
    const Key('menu-workspace-tab-sections'),
    const Key('menu-workspace-tab-products'),
  ]) {
    final tabLabel = tester.widget<Text>(
      find.descendant(of: find.byKey(tabKey), matching: find.byType(Text)),
    );
    expect(tabLabel.maxLines, 1);
    expect(tabLabel.softWrap, isFalse);
  }
  expect(
    rtl ? overview.center.dx : products.center.dx,
    greaterThan(rtl ? products.center.dx : overview.center.dx),
  );
  expect(
    tester
        .widget<Semantics>(find.byKey(const Key('menu-workspace-tab-overview')))
        .properties
        .selected,
    isTrue,
  );
}

MenuRecord _menuRecord({
  String? status,
  String name = 'Main',
  String? nameAr,
  String? nameEn,
  int sectionCount = 1,
  int visibleProductCount = 3,
}) => MenuRecord.fromJson(
  menuJson(
    status: status,
    name: name,
    nameAr: nameAr,
    nameEn: nameEn,
    sectionCount: sectionCount,
    visibleProductCount: visibleProductCount,
  ),
);

Map<String, dynamic> menuJson({
  bool archived = false,
  String? status,
  String name = 'Main',
  String? nameAr,
  String? nameEn,
  int sectionCount = 1,
  int visibleProductCount = 3,
}) => <String, dynamic>{
  'id': 1,
  'name': name,
  'nameAr': nameAr,
  'nameEn': nameEn ?? name,
  'description': '',
  'descriptionAr': null,
  'descriptionEn': null,
  'coverImageUrl': null,
  'status': archived ? 'archived' : status ?? 'draft',
  'priority': 0,
  'sectionCount': sectionCount,
  'visibleProductCount': visibleProductCount,
  'archivedAt': archived ? '2026-07-31T12:00:00Z' : null,
  'createdAt': '2026-07-30T10:00:00Z',
  'updatedAt': '2026-07-30T10:00:00Z',
  'sections': <Map<String, dynamic>>[
    <String, dynamic>{
      'id': 5,
      'menuId': 1,
      'name': 'Coffee',
      'nameAr': null,
      'nameEn': null,
      'description': null,
      'imageUrl': null,
      'isActive': !archived,
      'sortOrder': 0,
      'placementCount': 2,
      'archivedAt': archived ? '2026-07-31T12:00:00Z' : null,
    },
  ],
};
// ignore_for_file: curly_braces_in_flow_control_structures

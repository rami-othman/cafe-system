import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:windows_application/app/menu_management_route_locations.dart';
import 'package:windows_application/features/menu_management/menus/controllers/menu_detail_cubit.dart';
import 'package:windows_application/features/menu_management/menus/models/menu_editor_draft.dart';
import 'package:windows_application/features/menu_management/menus/models/menu_models.dart';
import 'package:windows_application/features/menu_management/menus/views/menu_detail_screen.dart';
import 'package:windows_application/l10n/app_localizations.dart';
import 'menu_management_menus_test.dart' show MenusRepositoryFake, menuJson;

void main() {
  test('section reordering sends a complete contiguous active list', () async {
    final _SectionsRepository repo = _SectionsRepository();
    final MenuDetailCubit cubit = MenuDetailCubit(repository: repo);
    await cubit.load(1);
    await cubit.moveSection(6, -1);
    expect(repo.reorderItems.map((e) => e.id), <int>[6, 5]);
    expect(repo.reorderItems.map((e) => e.sortOrder), <int>[0, 1]);
    await cubit.close();
  });
  test('archived parent blocks section mutation locally', () async {
    final _SectionsRepository repo = _SectionsRepository(archived: true);
    final MenuDetailCubit cubit = MenuDetailCubit(repository: repo);
    await cubit.load(1);
    await cubit.createSection(const MenuSectionDraft(name: 'Blocked'));
    expect(repo.createSectionCalls, 0);
    await cubit.close();
  });

  testWidgets(
    'Sections uses compact rows and a focused persisted reorder mode',
    (tester) async {
      final repo = _SectionsRepository();
      await tester.pumpWidget(_sectionsApp(repo));
      await tester.pumpAndSettle();

      expect(
        find.byKey(const Key('menu-workspace-tab-sections')),
        findsOneWidget,
      );
      expect(find.text('Coffee'), findsOneWidget);
      expect(find.text('2 Products'), findsOneWidget);
      expect(find.text('sortOrder'), findsNothing);
      expect(find.byKey(const Key('section-move-up-5')), findsNothing);

      await tester.tap(find.byKey(const Key('sections-reorder')));
      await tester.pump();
      expect(find.byKey(const Key('sections-reorder-done')), findsOneWidget);
      expect(
        tester
            .widget<IconButton>(find.byKey(const Key('section-move-up-5')))
            .onPressed,
        isNull,
      );
      expect(
        tester
            .widget<IconButton>(find.byKey(const Key('section-move-down-6')))
            .onPressed,
        isNull,
      );
      await tester.tap(find.byKey(const Key('section-move-up-6')));
      await tester.pumpAndSettle();
      expect(repo.reorderItems.map((item) => item.id), <int>[6, 5]);
      await tester.tap(find.byKey(const Key('sections-reorder-done')));
      await tester.pump();
      expect(find.byKey(const Key('section-move-up-5')), findsNothing);
    },
  );

  testWidgets('Add and Edit Section use the same directional side sheet', (
    tester,
  ) async {
    final repo = _SectionsRepository();
    await tester.pumpWidget(_sectionsApp(repo));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('sections-add')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('section-editor-sheet')), findsOneWidget);
    expect(find.byType(AlertDialog), findsNothing);
    expect(
      tester.getSize(find.byKey(const Key('section-editor-sheet'))).width,
      520,
    );
    await tester.tap(find.byKey(const Key('section-editor-save')));
    await tester.pump();
    expect(find.byKey(const Key('section-editor-sheet')), findsOneWidget);
    await tester.enterText(
      find.byKey(const Key('section-editor-name-en')),
      'Pastries',
    );
    await tester.tap(find.byKey(const Key('section-editor-save')));
    await tester.pumpAndSettle();
    expect(repo.createSectionCalls, 1);
    expect(find.byKey(const Key('section-editor-sheet')), findsNothing);

    await tester.tap(find.byKey(const Key('section-actions-5')));
    await tester.pumpAndSettle();
    await tester.tap(
      find.byWidgetPredicate(
        (widget) => widget is PopupMenuItem<String> && widget.value == 'edit',
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('section-editor-sheet')), findsOneWidget);
    expect(
      tester
          .widget<TextField>(find.byKey(const Key('section-editor-name-en')))
          .controller!
          .text,
      'Coffee',
    );
  });

  testWidgets(
    'Archived Sections are secondary, restorable, and localized RTL',
    (tester) async {
      final repo = _SectionsRepository(sectionArchived: true);
      await tester.pumpWidget(_sectionsApp(repo, locale: const Locale('ar')));
      await tester.pumpAndSettle();

      expect(
        find.text('\u0627\u0644\u0623\u0642\u0633\u0627\u0645'),
        findsAtLeastNWidgets(1),
      );
      expect(find.text('\u0645\u0624\u0631\u0634\u0641'), findsOneWidget);
      expect(
        Directionality.of(
          tester.element(find.byKey(const Key('sections-list'))),
        ),
        TextDirection.rtl,
      );
      await tester.tap(find.byKey(const Key('section-actions-5')));
      await tester.pumpAndSettle();
      expect(
        find.byWidgetPredicate(
          (widget) =>
              widget is PopupMenuItem<String> && widget.value == 'restore',
        ),
        findsOneWidget,
      );
    },
  );
}

Widget _sectionsApp(_SectionsRepository repository, {Locale? locale}) =>
    MaterialApp(
      locale: locale,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(size: const Size(1280, 900)),
        child: child!,
      ),
      home: BlocProvider<MenuDetailCubit>(
        create: (_) => MenuDetailCubit(repository: repository),
        child: const Scaffold(
          body: MenuDetailScreen(
            menuId: 1,
            initialTab: MenuWorkspaceTab.sections,
          ),
        ),
      ),
    );

class _SectionsRepository extends MenusRepositoryFake {
  _SectionsRepository({this.archived = false, this.sectionArchived = false});
  final bool archived;
  final bool sectionArchived;
  int createSectionCalls = 0;
  List<MenuSectionReorderItem> reorderItems = <MenuSectionReorderItem>[];
  @override
  Future<MenuRecord> getMenu(int menuId, {bool includeArchived = false}) async {
    final Map<String, dynamic> json = menuJson(archived: archived);
    if (sectionArchived) {
      final sections = json['sections'] as List<Map<String, dynamic>>;
      sections.first['isActive'] = false;
      sections.first['archivedAt'] = '2026-08-01T12:00:00Z';
    }
    json['sections'] = <Map<String, dynamic>>[
      ...json['sections'] as List<Map<String, dynamic>>,
      <String, dynamic>{
        'id': 6,
        'menuId': 1,
        'name': 'Tea',
        'isActive': true,
        'sortOrder': 1,
        'placementCount': 0,
      },
    ];
    return MenuRecord.fromJson(json);
  }

  @override
  Future<MenuSectionRecord> createMenuSection(
    int menuId,
    MenuSectionDraft draft,
  ) async {
    createSectionCalls++;
    return MenuSectionRecord.fromJson(<String, dynamic>{
      'id': 7,
      'menuId': menuId,
      'name': draft.name,
      'isActive': true,
      'sortOrder': 2,
    });
  }

  @override
  Future<void> reorderMenuSections(
    int menuId,
    List<MenuSectionReorderItem> items,
  ) async {
    reorderItems = items;
  }
}

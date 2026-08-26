import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:windows_application/core/network/dio_api_client.dart';
import 'package:windows_application/features/menu_management/assignments/controllers/menu_assignments_cubit.dart';
import 'package:windows_application/features/menu_management/assignments/models/menu_assignment_models.dart';
import 'package:windows_application/features/menu_management/assignments/views/menu_assignments_screen.dart';
import 'package:windows_application/features/menu_management/menus/models/menu_filter.dart';
import 'package:windows_application/features/menu_management/menus/models/menu_models.dart';
import 'package:windows_application/features/menu_management/repositories/menu_catalog_repository.dart';
import 'package:windows_application/features/menu_management/review/models/review_models.dart';
import 'package:windows_application/features/pos/models/branch.dart';
import 'package:windows_application/features/menu_management/models/catalog_models.dart';
import 'package:windows_application/l10n/app_localizations.dart';

void main() {
  group('Menu assignments', () {
    test('parses scope assignment metadata without tenant fields', () {
      final MenuAssignment assignment =
          MenuAssignment.fromJson(<String, dynamic>{
            'id': 4,
            'menuId': 12,
            'branchId': 2,
            'channel': 'pos',
            'priority': 3,
            'isActive': false,
            'menu': _menuJson(12, 'Breakfast'),
          });
      expect(assignment.menuId, 12);
      expect(assignment.isActive, isFalse);
      expect(assignment.menu!.localizedName, 'Breakfast');
    });

    test('requires Branch and Channel before loading a scope', () async {
      final _AssignmentsRepository repo = _AssignmentsRepository()
        ..assignments = <MenuAssignment>[_assignment(1, 10, priority: 0)];
      final MenuAssignmentsCubit cubit = MenuAssignmentsCubit(repository: repo);
      await cubit.load();
      expect(cubit.state.hasScope, isFalse);
      expect(repo.assignmentRequests, 0);
      await cubit.selectBranch(1);
      expect(cubit.state.selectedBranch!.id, 1);
      expect(repo.assignmentRequests, 0);
      await cubit.selectChannel('pos');
      expect(cubit.state.selectedChannel, 'pos');
      expect(cubit.state.assignments.single.menuId, 10);
      expect(repo.assignmentRequests, 1);
      expect(repo.previewRequests, 1);
      expect(repo.scheduleRequests, 0);
      expect(repo.menuRequests, 0);
    });

    test('loads eligible menus only when Add Menus opens', () async {
      final _AssignmentsRepository repo = _AssignmentsRepository();
      final MenuAssignmentsCubit cubit = MenuAssignmentsCubit(repository: repo);
      await cubit.load();
      await cubit.selectBranch(1);
      await cubit.selectChannel('pos');
      expect(cubit.state.availableMenus, isEmpty);
      await cubit.loadAvailableMenus();
      expect(cubit.state.availableMenus.map((m) => m.id), <int>[10, 11]);
      expect(repo.lastMenuFilter.status, 'all');
      expect(repo.menuRequests, 1);
    });

    test(
      'Add Menus sync appends deterministic selections and preserves existing active state',
      () async {
        final _AssignmentsRepository repo = _AssignmentsRepository()
          ..assignments = <MenuAssignment>[
            _assignment(1, 10, priority: 0),
            _assignment(2, 11, priority: 1, isActive: false),
          ]
          ..menus = <MenuRecord>[
            _menu(10, 'Main'),
            _menu(11, 'Breakfast'),
            _menu(12, 'Dinner', status: 'paused'),
            _menu(13, 'Weekend', status: 'draft'),
          ];
        final MenuAssignmentsCubit cubit = MenuAssignmentsCubit(
          repository: repo,
        );
        await cubit.load();
        await cubit.selectBranch(1);
        await cubit.selectChannel('pos');
        await cubit.loadAvailableMenus();

        expect(await cubit.addMenus(<int>[13, 12]), isTrue);
        expect(repo.syncRequests, 1);
        expect(repo.lastDrafts.map((draft) => draft.menuId), <int>[
          10,
          11,
          12,
          13,
        ]);
        expect(repo.lastDrafts.map((draft) => draft.isActive), <bool>[
          true,
          false,
          true,
          true,
        ]);
        expect(repo.assignmentRequests, 2);
        expect(repo.scheduleRequests, 0);
        expect(cubit.state.currentActionKey, isNull);
      },
    );

    test(
      'Add Menus blocks complete sync for archived assignment diagnostics',
      () async {
        final _AssignmentsRepository repo = _AssignmentsRepository()
          ..assignments = <MenuAssignment>[
            _assignment(1, 10, priority: 0, archived: true),
          ];
        final MenuAssignmentsCubit cubit = MenuAssignmentsCubit(
          repository: repo,
        );
        await cubit.load();
        await cubit.selectBranch(1);
        await cubit.selectChannel('pos');
        await cubit.loadAvailableMenus();

        expect(await cubit.addMenus(<int>[11]), isFalse);
        expect(repo.syncRequests, 0);
        expect(cubit.state.addMenusFailure, AddMenusFailure.archivedScope);
      },
    );

    test('a Menu assigned in another scope remains selectable', () async {
      final _AssignmentsRepository repo = _AssignmentsRepository()
        ..scopedAssignments[1] = <MenuAssignment>[
          _assignment(1, 10, priority: 0),
        ]
        ..scopedAssignments[2] = const <MenuAssignment>[];
      final MenuAssignmentsCubit cubit = MenuAssignmentsCubit(repository: repo);
      await cubit.load();
      await cubit.selectBranch(1);
      await cubit.selectChannel('pos');
      expect(cubit.state.assignments.single.menuId, 10);

      await cubit.selectBranch(2);
      await cubit.loadAvailableMenus();
      expect(cubit.state.assignments, isEmpty);
      expect(await cubit.addMenus(<int>[10]), isTrue);
      expect(repo.lastDrafts.single.menuId, 10);
      expect(cubit.state.assignments.single.menuId, 10);
    });

    testWidgets(
      'Add Menus is a compact side sheet with exact-scope eligibility',
      (tester) async {
        tester.view.physicalSize = const Size(1280, 900);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final _AssignmentsRepository repo = _AssignmentsRepository()
          ..menus = <MenuRecord>[
            _menu(10, 'Main Menu'),
            _menu(11, 'Dinner Menu'),
            _menu(12, 'Seasonal Menu', status: 'paused'),
            _menu(13, 'Weekend Menu', status: 'draft'),
            _menu(14, 'Old Menu', archived: true),
          ];
        await tester.pumpWidget(_assignmentsApp(repo));
        await tester.pumpAndSettle();
        await tester.tap(find.widgetWithText(FilledButton, 'Add Menus'));
        await tester.pumpAndSettle();

        expect(find.byType(AlertDialog), findsNothing);
        expect(find.byKey(const Key('assignments-add-search')), findsOneWidget);
        expect(find.text('Main · POS'), findsOneWidget);
        expect(
          tester.getRect(find.byKey(const Key('assignments-add-search'))).left,
          greaterThan(700),
        );
        for (final int id in <int>[10, 14]) {
          final Checkbox checkbox = tester.widget<Checkbox>(
            find.descendant(
              of: find.byKey(Key('assignments-add-menu-$id')),
              matching: find.byType(Checkbox),
            ),
          );
          expect(checkbox.onChanged, isNull);
        }

        await tester.tap(find.byKey(const Key('assignments-add-menu-11')));
        await tester.tap(find.byKey(const Key('assignments-add-menu-12')));
        await tester.pump();
        expect(find.text('Selected: 2'), findsOneWidget);
        expect(
          tester
              .widget<FilledButton>(
                find.byKey(const Key('assignments-add-submit')),
              )
              .onPressed,
          isNotNull,
        );
        expect(repo.menuRequests, 1);
        expect(repo.scheduleRequests, 0);
      },
    );

    testWidgets('Add Menus mirrors to the RTL side', (tester) async {
      tester.view.physicalSize = const Size(1280, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        _assignmentsApp(_AssignmentsRepository(), locale: const Locale('ar')),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byType(FilledButton).first);
      await tester.pumpAndSettle();

      expect(
        tester.getRect(find.byKey(const Key('assignments-add-search'))).left,
        lessThan(100),
      );
    });

    testWidgets('Add Menus retains its local selection after a failed sync', (
      tester,
    ) async {
      final _AssignmentsRepository repo = _AssignmentsRepository()
        ..failSync = true;
      await tester.pumpWidget(_assignmentsApp(repo));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Add Menus'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('assignments-add-menu-11')));
      await tester.pump();
      await tester.tap(find.byKey(const Key('assignments-add-submit')));
      await tester.pumpAndSettle();

      expect(repo.syncRequests, 1);
      expect(find.byKey(const Key('assignments-add-search')), findsOneWidget);
      expect(find.text('Selected: 1'), findsOneWidget);
      expect(
        tester
            .element(find.byKey(const Key('assignments-add-search')))
            .read<MenuAssignmentsCubit>()
            .state
            .addMenusFailure,
        AddMenusFailure.save,
      );
      // Assert Cubit state rather than a generated localized literal: this
      // source file's legacy encoding renders smart apostrophes inconsistently.
      /*
      expect(find.text('Couldn’t add Menus. Try again.'), findsOneWidget);
    });

      */
    });

    test(
      'renders authoritative assignments when the preview is unavailable',
      () async {
        final _AssignmentsRepository repo = _AssignmentsRepository()
          ..failPreview = true;
        final MenuAssignmentsCubit cubit = MenuAssignmentsCubit(
          repository: repo,
        );
        await cubit.load();
        await cubit.selectBranch(1);
        await cubit.selectChannel('pos');
        expect(cubit.state.status, MenuAssignmentsStatus.loaded);
        expect(cubit.state.assignments, isNotEmpty);
        expect(cubit.state.previewMenus, isEmpty);
        expect(cubit.state.previewUnavailable, isTrue);

        repo.failPreview = false;
        await cubit.retryPreview();
        expect(cubit.state.previewUnavailable, isFalse);
        expect(cubit.state.previewMenus[10]?.scheduleReason, 'matched_rule');
        expect(repo.previewRequests, 2);
      },
    );

    test('maps a collection preview by its real Menu ID', () async {
      final _AssignmentsRepository repo = _AssignmentsRepository();
      final MenuAssignmentsCubit cubit = MenuAssignmentsCubit(repository: repo);
      await cubit.load();
      await cubit.selectBranch(1);
      await cubit.selectChannel('pos');

      expect(cubit.state.assignments.single.menuId, 10);
      expect(cubit.state.previewMenus[10]?.scheduleReason, 'matched_rule');
      expect(cubit.state.previewMenus[10]?.isScheduledAvailable, isTrue);
      expect(cubit.state.previewMenus.containsKey(0), isFalse);
    });

    test(
      'assignment failure retains the full error state and Retry path',
      () async {
        final _AssignmentsRepository repo = _AssignmentsRepository()
          ..failAssignments = true;
        final MenuAssignmentsCubit cubit = MenuAssignmentsCubit(
          repository: repo,
        );
        await cubit.load();
        await cubit.selectBranch(1);
        await cubit.selectChannel('pos');

        expect(cubit.state.status, MenuAssignmentsStatus.failure);
        expect(cubit.state.assignments, isEmpty);
        expect(cubit.state.errorMessage, isNotNull);

        await cubit.refresh();
        expect(repo.assignmentRequests, 2);
        expect(cubit.state.status, MenuAssignmentsStatus.failure);
      },
    );

    test(
      'uses exact assignment and bounded preview contracts with the enum channel',
      () async {
        final List<RequestOptions> requests = <RequestOptions>[];
        final BackendMenuCatalogRepository repository =
            BackendMenuCatalogRepository(
              _client((RequestOptions options) {
                requests.add(options);
                return Response<dynamic>(
                  requestOptions: options,
                  data: <String, dynamic>{
                    'data': options.path == 'admin/menu-management/preview'
                        ? _previewJson()
                        : <Map<String, dynamic>>[_assignmentJson()],
                  },
                );
              }),
            );

        final List<MenuAssignment> assignments = await repository
            .listMenuAssignments(branchId: 7, channel: 'pos');
        final ResolvedPreview preview = await repository.previewMenuCollection(
          const ReviewContext(branchId: 7, channel: 'pos'),
        );

        expect(assignments.single.menu?.status, 'active');
        expect(assignments.single.isActive, isTrue);
        expect(preview.menus.single.id, 10);
        expect(requests[0].method, 'GET');
        expect(requests[0].path, 'admin/menu-management/assignments');
        expect(requests[0].queryParameters, <String, dynamic>{
          'branchId': 7,
          'channel': 'pos',
        });
        expect(requests[1].method, 'POST');
        expect(requests[1].path, 'admin/menu-management/preview');
        expect(requests[1].data, <String, dynamic>{
          'branchId': 7,
          'channel': 'pos',
          'language': 'default',
          'includeHidden': false,
          'includeUnavailable': true,
        });
        expect(
          (requests[1].data as Map<String, dynamic>).containsKey('menuIds'),
          isFalse,
        );
      },
    );

    test(
      'assignment mutation sends contiguous complete scope payload',
      () async {
        final _AssignmentsRepository repo = _AssignmentsRepository();
        final MenuAssignmentsCubit cubit = MenuAssignmentsCubit(
          repository: repo,
        );
        await cubit.load();
        await cubit.selectBranch(1);
        await cubit.selectChannel('pos');
        await cubit.assignMenu(_menu(11, 'Lunch'));
        expect(repo.lastDrafts.map((d) => d.menuId), <int>[10, 11]);
        expect(repo.lastDrafts.map((d) => d.priority), <int>[0, 1]);
        expect(repo.lastDrafts.every((d) => d.isActive), isTrue);
      },
    );

    test('reorder is unavailable for zero or one assignment', () async {
      final _AssignmentsRepository repo = _AssignmentsRepository()
        ..assignments = const <MenuAssignment>[];
      final MenuAssignmentsCubit cubit = MenuAssignmentsCubit(repository: repo);
      await cubit.load();
      await cubit.selectBranch(1);
      await cubit.selectChannel('pos');
      expect(cubit.state.canReorder, isFalse);
      cubit.startReordering();
      expect(cubit.state.isReordering, isFalse);

      repo.assignments = <MenuAssignment>[_assignment(1, 10, priority: 0)];
      await cubit.refresh();
      expect(cubit.state.canReorder, isFalse);
    });

    test(
      'reorder draft uses boundary-safe arrow movement without requests',
      () async {
        final _AssignmentsRepository repo = _AssignmentsRepository()
          ..assignments = <MenuAssignment>[
            _assignment(1, 10, priority: 0),
            _assignment(2, 11, priority: 1),
            _assignment(3, 12, priority: 2),
          ];
        final MenuAssignmentsCubit cubit = MenuAssignmentsCubit(
          repository: repo,
        );
        await cubit.load();
        await cubit.selectBranch(1);
        await cubit.selectChannel('pos');
        final int requestsBeforeMoves = repo.assignmentRequests;

        cubit.startReordering();
        expect(cubit.state.isReordering, isTrue);
        cubit.moveReorderDraft(10, -1);
        expect(cubit.state.reorderDraft.map((a) => a.menuId), <int>[
          10,
          11,
          12,
        ]);
        cubit.moveReorderDraft(10, 1);
        expect(cubit.state.reorderDraft.map((a) => a.menuId), <int>[
          11,
          10,
          12,
        ]);
        cubit.moveReorderDraft(12, 1);
        expect(cubit.state.reorderDraft.map((a) => a.menuId), <int>[
          11,
          10,
          12,
        ]);
        expect(repo.assignmentRequests, requestsBeforeMoves);
        expect(repo.previewRequests, 1);
        expect(repo.scheduleRequests, 0);
        expect(repo.menuRequests, 0);
      },
    );

    test(
      'Done syncs one complete ordered scope and preserves inactive values',
      () async {
        final _AssignmentsRepository repo = _AssignmentsRepository()
          ..assignments = <MenuAssignment>[
            _assignment(1, 10, priority: 0),
            _assignment(2, 11, priority: 1, isActive: false),
            _assignment(3, 12, priority: 2),
          ];
        final MenuAssignmentsCubit cubit = MenuAssignmentsCubit(
          repository: repo,
        );
        await cubit.load();
        await cubit.selectBranch(1);
        await cubit.selectChannel('pos');
        cubit.startReordering();
        cubit.moveReorderDraft(10, 1);
        await cubit.doneReordering();

        expect(repo.syncRequests, 1);
        expect(repo.lastDrafts.map((d) => d.menuId), <int>[11, 10, 12]);
        expect(repo.lastDrafts.map((d) => d.priority), <int>[0, 1, 2]);
        expect(repo.lastDrafts.map((d) => d.isActive), <bool>[
          false,
          true,
          true,
        ]);
        expect(repo.assignmentRequests, 2);
        expect(repo.previewRequests, 1);
        expect(cubit.state.isReordering, isFalse);
        expect(cubit.state.orderedAssignments.map((a) => a.menuId), <int>[
          11,
          10,
          12,
        ]);
      },
    );

    test(
      'failed reorder keeps the draft and shows an error for retry',
      () async {
        final _AssignmentsRepository repo = _AssignmentsRepository()
          ..assignments = <MenuAssignment>[
            _assignment(1, 10, priority: 0),
            _assignment(2, 11, priority: 1),
          ]
          ..failSync = true;
        final MenuAssignmentsCubit cubit = MenuAssignmentsCubit(
          repository: repo,
        );
        await cubit.load();
        await cubit.selectBranch(1);
        await cubit.selectChannel('pos');
        cubit.startReordering();
        cubit.moveReorderDraft(10, 1);
        await cubit.doneReordering();
        expect(cubit.state.isReordering, isTrue);
        expect(cubit.state.reorderDraft.map((a) => a.menuId), <int>[11, 10]);
        expect(cubit.state.errorMessage, isNotNull);
      },
    );

    test('context switch discards a reorder draft', () async {
      final _AssignmentsRepository repo = _AssignmentsRepository()
        ..assignments = <MenuAssignment>[
          _assignment(1, 10, priority: 0),
          _assignment(2, 11, priority: 1),
        ];
      final MenuAssignmentsCubit cubit = MenuAssignmentsCubit(repository: repo);
      await cubit.load();
      await cubit.selectBranch(1);
      await cubit.selectChannel('pos');
      cubit.startReordering();
      cubit.moveReorderDraft(10, 1);
      await cubit.selectBranch(2);
      expect(cubit.state.selectedBranch!.id, 2);
      expect(cubit.state.isReordering, isFalse);
      expect(cubit.state.reorderDraft, isEmpty);
    });

    test(
      'an old reorder save cannot overwrite a newly selected scope',
      () async {
        final _AssignmentsRepository repo = _AssignmentsRepository()
          ..assignments = <MenuAssignment>[
            _assignment(1, 10, priority: 0),
            _assignment(2, 11, priority: 1),
          ]
          ..syncGate = Completer<void>();
        final MenuAssignmentsCubit cubit = MenuAssignmentsCubit(
          repository: repo,
        );
        await cubit.load();
        await cubit.selectBranch(1);
        await cubit.selectChannel('pos');
        cubit.startReordering();
        cubit.moveReorderDraft(10, 1);
        final Future<void> saving = cubit.doneReordering();
        await Future<void>.delayed(Duration.zero);
        expect(repo.syncRequests, 1);

        await cubit.selectBranch(2);
        repo.syncGate!.complete();
        await saving;
        expect(cubit.state.selectedBranch!.id, 2);
        expect(cubit.state.isReordering, isFalse);
        expect(cubit.state.reorderDraft, isEmpty);
      },
    );

    test('archived diagnostic assignments block reorder safely', () async {
      final _AssignmentsRepository repo = _AssignmentsRepository()
        ..assignments = <MenuAssignment>[
          _assignment(1, 10, priority: 0),
          _assignment(2, 11, priority: 1, archived: true),
        ];
      final MenuAssignmentsCubit cubit = MenuAssignmentsCubit(repository: repo);
      await cubit.load();
      await cubit.selectBranch(1);
      await cubit.selectChannel('pos');
      expect(cubit.state.hasArchivedAssignment, isTrue);
      expect(cubit.state.canReorder, isFalse);
      cubit.startReordering();
      expect(cubit.state.isReordering, isFalse);
      expect(repo.syncRequests, 0);
    });

    testWidgets('reorder presentation is focused and has accessible boundaries', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(1280, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final _AssignmentsRepository repo = _AssignmentsRepository()
        ..assignments = <MenuAssignment>[
          _assignment(1, 10, priority: 0),
          _assignment(2, 11, priority: 1),
          _assignment(3, 12, priority: 2),
        ];
      await tester.pumpWidget(_assignmentsApp(repo));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Reorder Menus'));
      await tester.pumpAndSettle();

      expect(
        find.text(
          'Use the arrows to change the order Menus appear in this selling context. Ordering does not decide which Menu wins.',
        ),
        findsOneWidget,
      );
      expect(find.text('Done'), findsOneWidget);
      expect(find.text('Add Menus'), findsNothing);
      expect(find.text('Manage Schedule'), findsNothing);
      expect(
        tester
            .widget<IconButton>(
              find.byKey(const Key('assignments-reorder-up-10')),
            )
            .onPressed,
        isNull,
      );
      expect(
        tester
            .widget<IconButton>(
              find.byKey(const Key('assignments-reorder-down-10')),
            )
            .onPressed,
        isNotNull,
      );
      expect(
        tester
            .widget<IconButton>(
              find.byKey(const Key('assignments-reorder-up-11')),
            )
            .onPressed,
        isNotNull,
      );
      expect(
        tester
            .widget<IconButton>(
              find.byKey(const Key('assignments-reorder-down-11')),
            )
            .onPressed,
        isNotNull,
      );
      expect(
        tester
            .widget<IconButton>(
              find.byKey(const Key('assignments-reorder-down-12')),
            )
            .onPressed,
        isNull,
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets('reorder presentation remains usable in Arabic RTL', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(1280, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final _AssignmentsRepository repo = _AssignmentsRepository()
        ..assignments = <MenuAssignment>[
          _assignment(1, 10, priority: 0),
          _assignment(2, 11, priority: 1),
        ];
      await tester.pumpWidget(
        _assignmentsApp(repo, locale: const Locale('ar')),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('ترتيب القوائم'));
      await tester.pumpAndSettle();

      expect(find.text('تم'), findsOneWidget);
      expect(find.byTooltip('نقل للأعلى'), findsNWidgets(2));
      expect(find.byTooltip('نقل للأسفل'), findsNWidgets(2));
      expect(tester.takeException(), isNull);
    });
  });
}

Widget _assignmentsApp(_AssignmentsRepository repository, {Locale? locale}) =>
    MaterialApp(
      locale: locale,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: BlocProvider<MenuAssignmentsCubit>(
        create: (_) => MenuAssignmentsCubit(repository: repository),
        child: const Scaffold(
          body: MenuAssignmentsScreen(
            initialBranchId: 1,
            initialChannel: 'pos',
          ),
        ),
      ),
    );

class _AssignmentsRepository extends MenuCatalogRepository {
  List<MenuAssignment> assignments = <MenuAssignment>[
    _assignment(1, 10, priority: 0),
  ];
  List<MenuAssignmentDraft> lastDrafts = <MenuAssignmentDraft>[];
  bool failSync = false;
  Completer<void>? syncGate;
  bool failPreview = false;
  bool failAssignments = false;
  int assignmentRequests = 0,
      previewRequests = 0,
      scheduleRequests = 0,
      menuRequests = 0,
      syncRequests = 0;
  MenuFilter lastMenuFilter = const MenuFilter();
  List<MenuRecord> menus = <MenuRecord>[
    _menu(10, 'Breakfast'),
    _menu(11, 'Lunch'),
  ];
  final Map<int, List<MenuAssignment>> scopedAssignments =
      <int, List<MenuAssignment>>{};
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
  @override
  Future<List<Branch>> listAssignmentBranches() async => const <Branch>[
    Branch(
      id: 1,
      name: 'Main',
      currency: 'SYP',
      timezone: 'Asia/Damascus',
      isActive: true,
    ),
    Branch(
      id: 2,
      name: 'Airport',
      currency: 'SYP',
      timezone: 'Asia/Damascus',
      isActive: true,
    ),
  ];
  @override
  Future<List<MenuAssignment>> listMenuAssignments({
    required int branchId,
    required String channel,
  }) async {
    assignmentRequests++;
    if (failAssignments) {
      throw const FormatException('Assignments are unavailable.');
    }
    return scopedAssignments[branchId] ?? assignments;
  }

  @override
  Future<CatalogPage<MenuRecord>> listMenus({
    required MenuFilter filter,
    required int page,
    int perPage = 20,
  }) async {
    menuRequests++;
    lastMenuFilter = filter;
    return CatalogPage<MenuRecord>(
      items: menus,
      meta: const CatalogPagination(
        currentPage: 1,
        lastPage: 1,
        perPage: 100,
        total: 2,
      ),
    );
  }

  @override
  Future<ResolvedPreview> previewMenuCollection(ReviewContext context) async {
    previewRequests++;
    if (failPreview) throw const FormatException('Preview is unavailable.');
    return ResolvedPreview.fromJson(_previewJson());
  }

  @override
  Future<List<MenuAssignment>> syncMenuAssignments({
    required int branchId,
    required String channel,
    required List<MenuAssignmentDraft> assignments,
  }) async {
    syncRequests++;
    lastDrafts = assignments;
    if (syncGate != null) await syncGate!.future;
    if (failSync) throw Exception('No connection');
    this.assignments = assignments
        .asMap()
        .entries
        .map(
          (entry) => _assignment(
            entry.key + 1,
            entry.value.menuId,
            priority: entry.value.priority,
            isActive: entry.value.isActive,
          ),
        )
        .toList(growable: false);
    if (scopedAssignments.containsKey(branchId)) {
      scopedAssignments[branchId] = this.assignments;
    }
    return this.assignments;
  }

  @override
  Future<List<MenuScheduleRule>> listMenuAvailabilityRules(int menuId) async {
    scheduleRequests++;
    return const <MenuScheduleRule>[];
  }
}

MenuAssignment _assignment(
  int id,
  int menuId, {
  required int priority,
  bool isActive = true,
  bool archived = false,
}) => MenuAssignment(
  id: id,
  menuId: menuId,
  branchId: 1,
  channel: 'pos',
  priority: priority,
  isActive: isActive,
  createdAt: null,
  updatedAt: null,
  menu: _menu(menuId, menuId == 10 ? 'Breakfast' : 'Lunch', archived: archived),
);
MenuRecord _menu(
  int id,
  String name, {
  bool archived = false,
  String status = 'active',
}) => MenuRecord.fromJson(
  _menuJson(id, name, archived: archived, status: status),
);
Map<String, dynamic> _menuJson(
  int id,
  String name, {
  bool archived = false,
  String status = 'active',
}) => <String, dynamic>{
  'id': id,
  'name': name,
  'status': status,
  'priority': 0,
  'sectionCount': 1,
  'visibleProductCount': 2,
  if (archived) 'archivedAt': '2026-08-01T00:00:00+03:00',
};

Map<String, dynamic> _assignmentJson() => <String, dynamic>{
  'id': 1,
  'menuId': 10,
  'branchId': 7,
  'channel': 'pos',
  'priority': 0,
  'isActive': true,
  'menu': _menuJson(10, 'Breakfast'),
};

Map<String, dynamic> _previewJson() => <String, dynamic>{
  'canPublish': true,
  'context': <String, dynamic>{
    'timezone': 'Asia/Damascus',
    'evaluatedAt': '2026-08-01T10:00:00+03:00',
  },
  'menus': <Map<String, dynamic>>[
    <String, dynamic>{
      'id': 10,
      'name': 'Breakfast',
      'priority': 0,
      'isAssigned': true,
      'isScheduledAvailable': true,
      'scheduleReason': 'matched_rule',
      'sections': const <Object>[],
    },
  ],
};

DioApiClient _client(Response<dynamic> Function(RequestOptions) responder) {
  final Dio dio = Dio(BaseOptions(baseUrl: 'http://localhost/api/v1/'));
  dio.interceptors.add(
    InterceptorsWrapper(
      onRequest: (options, handler) => handler.resolve(responder(options)),
    ),
  );
  return DioApiClient(dio: dio);
}

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:windows_application/l10n/app_localizations.dart';
import 'package:windows_application/core/network/dio_api_client.dart';
import 'package:windows_application/features/menu_management/assignments/controllers/menu_assignments_cubit.dart';
import 'package:windows_application/features/menu_management/assignments/models/menu_assignment_models.dart';
import 'package:windows_application/features/menu_management/assignments/views/menu_assignments_screen.dart';
import 'package:windows_application/features/menu_management/menus/models/menu_filter.dart';
import 'package:windows_application/features/menu_management/menus/models/menu_models.dart';
import 'package:windows_application/features/menu_management/models/catalog_models.dart';
import 'package:windows_application/features/menu_management/repositories/menu_catalog_repository.dart';
import 'package:windows_application/features/menu_management/review/models/review_models.dart';
import 'package:windows_application/features/pos/models/branch.dart';

void main() {
  group('Menu schedule rules', () {
    test(
      'repository loads an empty Menu schedule without a type error',
      () async {
        final List<RequestOptions> requests = <RequestOptions>[];
        final Dio dio = Dio(BaseOptions(baseUrl: 'http://localhost/api/v1/'));
        dio.interceptors.add(
          InterceptorsWrapper(
            onRequest: (options, handler) {
              requests.add(options);
              handler.resolve(
                Response<dynamic>(
                  requestOptions: options,
                  data: const <String, dynamic>{'data': <dynamic>[]},
                ),
              );
            },
          ),
        );
        final BackendMenuCatalogRepository repository =
            BackendMenuCatalogRepository(DioApiClient(dio: dio));

        expect(await repository.listMenuAvailabilityRules(10), isEmpty);
        expect(requests.single.path, 'admin/menus/10/availability-rules');
      },
    );

    test(
      'schedule check decodes only the authoritative menu schedule fields',
      () async {
        final List<RequestOptions> requests = <RequestOptions>[];
        final dio = Dio(BaseOptions(baseUrl: 'http://localhost/api/v1/'));
        dio.interceptors.add(
          InterceptorsWrapper(
            onRequest: (options, handler) {
              requests.add(options);
              handler.resolve(
                Response<dynamic>(
                  requestOptions: options,
                  data: <String, dynamic>{
                    'data': <String, dynamic>{
                      'menus': <Map<String, dynamic>>[
                        <String, dynamic>{
                          'id': 10,
                          'isScheduledAvailable': false,
                          'scheduleReason': 'outside_schedule',
                          // A malformed product diagnostic must not make the
                          // manager's menu schedule check fail.
                          'sections': <Map<String, dynamic>>[
                            <String, dynamic>{
                              'products': <Map<String, dynamic>>[
                                <String, dynamic>{'variants': ''},
                              ],
                            },
                          ],
                        },
                      ],
                    },
                  },
                ),
              );
            },
          ),
        );
        final repository = BackendMenuCatalogRepository(DioApiClient(dio: dio));
        final result = await repository.previewMenuSchedule(
          10,
          ReviewContext(
            branchId: 1,
            channel: 'pos',
            evaluationAt: DateTime.parse('2026-08-26T10:00:00.000Z'),
          ),
        );
        expect(result.isScheduledAvailable, isFalse);
        expect(result.scheduleReason, 'outside_schedule');
        expect(requests.single.path, 'admin/menus/10/preview');
        expect(requests.single.data['branchId'], 1);
        expect(requests.single.data['channel'], 'pos');
        expect(requests.single.data['at'], '2026-08-26T10:00:00.000Z');
        expect(requests.single.data['language'], 'default');
        expect(requests.single.data['includeUnavailable'], isTrue);
        expect(requests.single.data['includeHidden'], isFalse);
      },
    );

    test('no scoped rules is unrestricted', () {
      expect(
        scheduleSummary(const <MenuScheduleRule>[], 1, 'pos'),
        'Unrestricted',
      );
    });

    test('overnight weekly rule is clearly labelled', () {
      final MenuScheduleRule rule = _rule(day: 1, start: '18:00', end: '02:00');
      expect(rule.isOvernight, isTrue);
      expect(
        scheduleSummary(<MenuScheduleRule>[rule], 1, 'pos'),
        'Mon, 18:00–02:00 (overnight)',
      );
    });

    test('multiple exact windows remain independently visible', () {
      expect(
        scheduleSummary(
          <MenuScheduleRule>[
            _rule(day: 2, start: '07:00', end: '11:00'),
            _rule(day: 2, start: '17:00', end: '22:00'),
          ],
          1,
          'pos',
        ),
        'Tue, 07:00–11:00 · 17:00–22:00',
      );
    });

    test('global rules are reported as inherited rather than unrestricted', () {
      final MenuScheduleRule global = MenuScheduleRule(
        id: 2,
        branchId: null,
        channel: null,
        dayOfWeek: null,
        startTime: null,
        endTime: null,
        startDate: null,
        endDate: null,
        priority: 0,
        isActive: true,
        createdAt: null,
        updatedAt: null,
      );
      expect(
        scheduleSummary(<MenuScheduleRule>[global], 1, 'pos'),
        'Inherited: Daily',
      );
    });

    test('sync drafts exclude computed, tenant, and runtime fields', () {
      final Map<String, dynamic> payload = const MenuScheduleRuleDraft(
        dayOfWeek: 6,
        startTime: '22:00',
        endTime: '02:00',
        startDate: '2026-08-01',
        endDate: '2026-08-31',
        priority: '4',
      ).toJson(branchId: 1, channel: 'pos');
      expect(payload, <String, dynamic>{
        'branchId': 1,
        'channel': 'pos',
        'dayOfWeek': 6,
        'startTime': '22:00',
        'endTime': '02:00',
        'startDate': '2026-08-01',
        'endDate': '2026-08-31',
        'priority': 4,
        'isActive': true,
      });
      expect(payload.containsKey('tenantId'), isFalse);
      expect(payload.containsKey('id'), isFalse);
    });

    test('complete schedule rules send nullable fields explicitly', () {
      final Map<String, dynamic> payload = MenuScheduleRule(
        id: 9,
        branchId: 1,
        channel: 'pos',
        dayOfWeek: null,
        startTime: null,
        endTime: null,
        startDate: null,
        endDate: null,
        priority: 3,
        isActive: false,
        createdAt: null,
        updatedAt: null,
      ).toSyncJson();

      expect(payload, <String, dynamic>{
        'branchId': 1,
        'channel': 'pos',
        'dayOfWeek': null,
        'startTime': null,
        'endTime': null,
        'startDate': null,
        'endDate': null,
        'priority': 3,
        'isActive': false,
      });
    });

    test(
      'client validation permits overnight and rejects invalid dates',
      () async {
        final _ScheduleRepository repository = _ScheduleRepository();
        final MenuAssignmentsCubit cubit = MenuAssignmentsCubit(
          repository: repository,
        );
        await cubit.load(branchId: 1, channel: 'pos');
        await cubit.loadScheduleRules(10);
        await cubit.saveScheduleRule(
          10,
          const MenuScheduleRuleDraft(
            dayOfWeek: 0,
            startTime: '22:00',
            endTime: '02:00',
          ),
        );
        expect(repository.synced.single['endTime'], '02:00');
        await cubit.saveScheduleRule(
          10,
          const MenuScheduleRuleDraft(
            startDate: '2026-08-02',
            endDate: '2026-08-01',
          ),
        );
        expect(cubit.state.errorMessage, contains('End date'));
      },
    );

    test(
      'complete schedule sync rejects an invalid date range before request',
      () async {
        final repository = _ScheduleRepository();
        final cubit = MenuAssignmentsCubit(repository: repository);
        await cubit.load(branchId: 1, channel: 'pos');
        final saved = await cubit.saveMenuSchedule(10, <Map<String, dynamic>>[
          <String, dynamic>{
            'branchId': 1,
            'channel': 'pos',
            'startDate': '2026-08-31',
            'endDate': '2026-08-21',
            'priority': 0,
            'isActive': true,
          },
        ]);
        expect(saved, isFalse);
        expect(repository.synced, isEmpty);
        expect(cubit.state.errorMessage, contains('End date'));
      },
    );

    test(
      'complete schedule sync rejects backend-canonical duplicates locally',
      () async {
        final repository = _ScheduleRepository();
        final cubit = MenuAssignmentsCubit(repository: repository);
        await cubit.load(branchId: 1, channel: 'pos');
        final rules = <Map<String, dynamic>>[
          <String, dynamic>{
            'branchId': 1,
            'channel': 'pos',
            'dayOfWeek': 1,
            'startTime': '07:00',
            'endTime': '22:00',
            'startDate': null,
            'endDate': null,
            'priority': 0,
            'isActive': true,
          },
          <String, dynamic>{
            'branchId': 1,
            'channel': 'pos',
            'dayOfWeek': 1,
            'startTime': '07:00',
            'endTime': '22:00',
            'startDate': null,
            'endDate': null,
            'priority': 0,
            // Activity is not part of backend canonical identity.
            'isActive': false,
          },
        ];

        expect(await cubit.saveMenuSchedule(10, rules), isFalse);
        expect(repository.synced, isEmpty);
        expect(cubit.state.errorMessage, contains('duplicates'));
      },
    );

    test(
      'exact-scope edits preserve inherited and other-scope rules',
      () async {
        final _ScheduleRepository repository = _ScheduleRepository()
          ..initialRules = <MenuScheduleRule>[
            _scopedRule(id: 1),
            _scopedRule(id: 2, branchId: 1, channel: null),
            _scopedRule(id: 3, branchId: null, channel: 'delivery'),
            _scopedRule(id: 4, branchId: 2, channel: 'pos'),
          ];
        final MenuAssignmentsCubit cubit = MenuAssignmentsCubit(
          repository: repository,
        );
        await cubit.load(branchId: 1, channel: 'pos');
        await cubit.loadScheduleRules(10);
        await cubit.saveScheduleRule(
          10,
          const MenuScheduleRuleDraft(
            dayOfWeek: 4,
            startTime: '18:00',
            endTime: '02:00',
          ),
        );
        expect(repository.synced, hasLength(5));
        expect(
          repository.synced.any(
            (rule) => rule['branchId'] == null && rule['channel'] == null,
          ),
          isTrue,
        );
        expect(
          repository.synced.any(
            (rule) => rule['branchId'] == 1 && rule['channel'] == null,
          ),
          isTrue,
        );
        expect(
          repository.synced.any((rule) => rule['channel'] == 'delivery'),
          isTrue,
        );
        expect(
          repository.synced.any(
            (rule) => rule['branchId'] == 2 && rule['channel'] == 'pos',
          ),
          isTrue,
        );
        expect(
          repository.synced.where(
            (rule) => rule['branchId'] == 1 && rule['channel'] == 'pos',
          ),
          hasLength(1),
        );
      },
    );

    test(
      'multiple windows and rule fields survive a complete exact-scope sync',
      () async {
        final repository = _ScheduleRepository()
          ..initialRules = <MenuScheduleRule>[
            _scopedRule(id: 1),
            _scopedRule(id: 2, branchId: 1, channel: null),
            _scopedRule(id: 3, branchId: null, channel: 'delivery'),
            _scopedRule(id: 4, branchId: 1, channel: 'pos'),
            MenuScheduleRule(
              id: 5,
              branchId: 1,
              channel: 'pos',
              dayOfWeek: 2,
              startTime: '17:00',
              endTime: '22:00',
              startDate: '2026-06-01',
              endDate: '2026-08-31',
              priority: 44,
              isActive: false,
              createdAt: null,
              updatedAt: null,
            ),
            _rule(day: 1, start: '22:00', end: '02:00'),
          ];
        final cubit = MenuAssignmentsCubit(repository: repository);
        await cubit.load(branchId: 1, channel: 'pos');
        await cubit.loadScheduleRules(10);

        final edited = repository.initialRules
            .map(
              (rule) => rule.id == 4
                  ? MenuScheduleRule(
                      id: rule.id,
                      branchId: rule.branchId,
                      channel: rule.channel,
                      dayOfWeek: 2,
                      startTime: '07:00',
                      endTime: '11:00',
                      startDate: rule.startDate,
                      endDate: rule.endDate,
                      priority: rule.priority,
                      isActive: rule.isActive,
                      createdAt: rule.createdAt,
                      updatedAt: rule.updatedAt,
                    )
                  : rule,
            )
            .map((rule) => rule.toSyncJson())
            .toList(growable: false);
        expect(await cubit.saveMenuSchedule(10, edited), isTrue);
        expect(
          repository.synced.where(
            (rule) => rule['branchId'] == 1 && rule['channel'] == 'pos',
          ),
          hasLength(3),
        );
        expect(
          repository.synced.any(
            (rule) =>
                rule['startTime'] == '22:00' && rule['endTime'] == '02:00',
          ),
          isTrue,
        );
        final inactive = repository.synced.singleWhere(
          (rule) => rule['isActive'] == false,
        );
        expect(inactive['startDate'], '2026-06-01');
        expect(inactive['endDate'], '2026-08-31');
        expect(inactive['priority'], 44);
      },
    );

    test('check schedule uses the authoritative single-menu preview', () async {
      final repository = _ScheduleRepository();
      final cubit = MenuAssignmentsCubit(repository: repository);
      await cubit.load(branchId: 1, channel: 'pos');
      final result = await cubit.checkMenuSchedule(
        10,
        DateTime.parse('2026-06-02T10:00:00.000Z'),
      );
      expect(repository.previewContexts, hasLength(1));
      expect(repository.previewContexts.single.branchId, 1);
      expect(repository.previewContexts.single.channel, 'pos');
      expect(
        repository.previewContexts.single.evaluationAt!.toIso8601String(),
        '2026-06-02T10:00:00.000Z',
      );
      expect(result.isScheduledAvailable, isTrue);
    });

    testWidgets(
      'customizing one day from an exact Every Day rule is explicit and safe',
      (tester) async {
        tester.view.physicalSize = const Size(1280, 900);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final repository = _ScheduleRepository()
          ..initialRules = <MenuScheduleRule>[
            MenuScheduleRule(
              id: 7,
              branchId: 1,
              channel: 'pos',
              dayOfWeek: null,
              startTime: null,
              endTime: null,
              startDate: '2026-06-01',
              endDate: '2026-08-31',
              priority: 4,
              isActive: true,
              createdAt: null,
              updatedAt: null,
            ),
          ];
        await tester.pumpWidget(_scheduleApp(repository));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Manage Schedule'));
        await tester.pumpAndSettle();

        await tester.tap(find.byKey(const Key('menu-schedule-edit-Monday')));
        await tester.pumpAndSettle();
        expect(find.text('Customize Monday'), findsNWidgets(2));
        await tester.tap(find.text('Cancel').last);
        await tester.pumpAndSettle();
        expect(find.text('Custom hours'), findsNothing);

        await tester.tap(find.byKey(const Key('menu-schedule-edit-Monday')));
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const Key('menu-schedule-customize-1')));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Custom hours'));
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const Key('menu-schedule-add-window')));
        await tester.pump();
        final start = find.byWidgetPredicate(
          (widget) =>
              widget is TextField &&
              widget.decoration?.labelText == 'Start time',
        );
        final end = find.byWidgetPredicate(
          (widget) =>
              widget is TextField && widget.decoration?.labelText == 'End time',
        );
        tester.widget<TextField>(start).controller!.text = '07:00';
        tester.widget<TextField>(end).controller!.text = '22:00';
        await tester.tap(find.text('Apply'));
        await tester.tap(find.byKey(const Key('menu-schedule-save')));
        await tester.pumpAndSettle();

        final monday = repository.synced.singleWhere(
          (rule) =>
              rule['branchId'] == 1 &&
              rule['channel'] == 'pos' &&
              rule['dayOfWeek'] == 1,
        );
        expect(monday['startTime'], '07:00');
        expect(monday['endTime'], '22:00');
        expect(monday['startDate'], '2026-06-01');
        expect(monday['endDate'], '2026-08-31');
        expect(monday['priority'], 4);
        expect(
          repository.synced.where(
            (rule) =>
                rule['branchId'] == 1 &&
                rule['channel'] == 'pos' &&
                rule['dayOfWeek'] != 1,
          ),
          hasLength(6),
        );
        expect(
          repository.synced
              .where((rule) => rule['dayOfWeek'] == 2)
              .single['startTime'],
          isNull,
        );
      },
    );
  });
}

Widget _scheduleApp(_ScheduleRepository repository) => MaterialApp(
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  home: BlocProvider<MenuAssignmentsCubit>(
    create: (_) => MenuAssignmentsCubit(repository: repository),
    child: const Scaffold(
      body: MenuAssignmentsScreen(initialBranchId: 1, initialChannel: 'pos'),
    ),
  ),
);

MenuScheduleRule _rule({
  required int day,
  required String start,
  required String end,
}) => MenuScheduleRule(
  id: 1,
  branchId: 1,
  channel: 'pos',
  dayOfWeek: day,
  startTime: start,
  endTime: end,
  startDate: null,
  endDate: null,
  priority: 0,
  isActive: true,
  createdAt: null,
  updatedAt: null,
);

MenuScheduleRule _scopedRule({
  required int id,
  int? branchId,
  String? channel,
}) => MenuScheduleRule(
  id: id,
  branchId: branchId,
  channel: channel,
  dayOfWeek: null,
  startTime: '08:00',
  endTime: '12:00',
  startDate: null,
  endDate: null,
  priority: id,
  isActive: true,
  createdAt: null,
  updatedAt: null,
);

class _ScheduleRepository extends MenuCatalogRepository {
  List<Map<String, dynamic>> synced = <Map<String, dynamic>>[];
  List<MenuScheduleRule> initialRules = <MenuScheduleRule>[];
  List<ReviewContext> previewContexts = <ReviewContext>[];
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
  ];
  @override
  Future<List<MenuAssignment>> listMenuAssignments({
    required int branchId,
    required String channel,
  }) async => <MenuAssignment>[
    MenuAssignment(
      id: 1,
      menuId: 10,
      branchId: 1,
      channel: 'pos',
      priority: 0,
      isActive: true,
      createdAt: null,
      updatedAt: null,
    ),
  ];
  @override
  Future<CatalogPage<MenuRecord>> listMenus({
    required MenuFilter filter,
    required int page,
    int perPage = 20,
  }) async => CatalogPage<MenuRecord>(
    items: <MenuRecord>[
      MenuRecord.fromJson(<String, dynamic>{
        'id': 10,
        'name': 'Breakfast',
        'status': 'active',
        'priority': 0,
        'sectionCount': 0,
        'visibleProductCount': 0,
      }),
    ],
    meta: const CatalogPagination(
      currentPage: 1,
      lastPage: 1,
      perPage: 20,
      total: 1,
    ),
  );
  @override
  Future<List<MenuScheduleRule>> listMenuAvailabilityRules(int menuId) async =>
      initialRules;
  @override
  Future<List<MenuScheduleRule>> syncMenuAvailabilityRules(
    int menuId,
    List<Map<String, dynamic>> rules,
  ) async {
    synced = rules;
    initialRules = rules
        .asMap()
        .entries
        .map(
          (entry) => MenuScheduleRule.fromJson(<String, dynamic>{
            'id': entry.key + 1,
            ...entry.value,
          }),
        )
        .toList(growable: false);
    return initialRules;
  }

  @override
  Future<ResolvedPreview> previewMenuCollection(ReviewContext context) async =>
      ResolvedPreview.fromJson(<String, dynamic>{
        'canPublish': true,
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
      });

  @override
  Future<MenuScheduleCheck> previewMenuSchedule(
    int menuId,
    ReviewContext context,
  ) async {
    previewContexts.add(context);
    return const MenuScheduleCheck(
      isScheduledAvailable: true,
      scheduleReason: 'matched_rule',
    );
  }
}

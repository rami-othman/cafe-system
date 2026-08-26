import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:windows_application/l10n/app_localizations.dart';
import 'package:windows_application/core/network/api_exception.dart';
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

    test(
      'schedule check uses the Laravel single-menu envelope through Cubit, repository, and response unwrapping',
      () async {
        bool isAvailable = true;
        bool networkFailure = false;
        final dio = Dio(BaseOptions(baseUrl: 'http://localhost/api/v1/'));
        dio.interceptors.add(
          InterceptorsWrapper(
            onRequest: (options, handler) {
              final data = switch (options.path) {
                'branches' => <String, dynamic>{
                  'data': <Map<String, dynamic>>[
                    <String, dynamic>{
                      'id': 1,
                      'name': 'Downtown',
                      'timezone': 'Asia/Damascus',
                      'isActive': true,
                    },
                  ],
                },
                'admin/menu-management/assignments' => <String, dynamic>{
                  'data': <Map<String, dynamic>>[
                    <String, dynamic>{
                      'id': 1,
                      'menuId': 10,
                      'branchId': 1,
                      'channel': 'pos',
                      'priority': 0,
                      'isActive': true,
                      'menu': <String, dynamic>{
                        'id': 10,
                        'name': 'RAMI',
                        'status': 'active',
                        'priority': 0,
                        'sectionCount': 0,
                        'visibleProductCount': 0,
                      },
                    },
                  ],
                },
                'admin/menu-management/preview' => <String, dynamic>{
                  'data': <String, dynamic>{
                    'canPublish': true,
                    'context': <String, dynamic>{
                      'timezone': 'Asia/Damascus',
                      'evaluatedAt': '2026-08-26T10:00:00+00:00',
                    },
                    'menus': const <Map<String, dynamic>>[],
                  },
                },
                'admin/menus/10/preview' when networkFailure => null,
                'admin/menus/10/preview' => _laravelSingleMenuPreviewFixture(
                  isAvailable: isAvailable,
                  scheduleReason: isAvailable
                      ? 'matched_rule'
                      : 'outside_schedule',
                ),
                _ => throw StateError('Unexpected request: ${options.path}'),
              };
              if (networkFailure && options.path == 'admin/menus/10/preview') {
                handler.reject(
                  DioException(
                    requestOptions: options,
                    type: DioExceptionType.connectionError,
                  ),
                );
                return;
              }
              handler.resolve(
                Response<dynamic>(requestOptions: options, data: data),
              );
            },
          ),
        );
        final repository = BackendMenuCatalogRepository(DioApiClient(dio: dio));
        final cubit = MenuAssignmentsCubit(repository: repository);

        await cubit.load(branchId: 1, channel: 'pos');
        final available = await cubit.checkMenuSchedule(
          10,
          DateTime.utc(2026, 8, 26, 10),
        );
        expect(available.isScheduledAvailable, isTrue);
        expect(available.scheduleReason, 'matched_rule');

        isAvailable = false;
        final outsideHours = await cubit.checkMenuSchedule(
          10,
          DateTime.utc(2026, 8, 26, 22),
        );
        expect(outsideHours.isScheduledAvailable, isFalse);
        expect(outsideHours.scheduleReason, 'outside_schedule');

        networkFailure = true;
        await expectLater(
          cubit.checkMenuSchedule(10, DateTime.utc(2026, 8, 26, 10)),
          throwsA(isA<ApiException>()),
        );
      },
    );

    testWidgets('schedule-check UI presents results and never leaks errors', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(1280, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final repository = _ScheduleRepository()
        ..initialRules = <MenuScheduleRule>[
          _rule(day: 1, start: '07:00', end: '22:00'),
        ];
      await tester.pumpWidget(_scheduleApp(repository));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Manage Schedule'));
      await tester.pumpAndSettle();

      final check = find.byKey(const Key('menu-schedule-check'));
      await tester.ensureVisible(check);
      await tester.pumpAndSettle();
      await tester.tap(check);
      await tester.pumpAndSettle();
      expect(find.text('Available'), findsOneWidget);

      repository.scheduleCheck = const MenuScheduleCheck(
        isScheduledAvailable: false,
        scheduleReason: 'outside_schedule',
      );
      await tester.tap(check);
      await tester.pumpAndSettle();
      expect(find.text('Outside scheduled hours'), findsOneWidget);

      repository.scheduleCheckError = RangeError.range(2, 0, 1);
      await tester.tap(check);
      await tester.pumpAndSettle();
      expect(
        find.text('Could not check the schedule. Try again.'),
        findsOneWidget,
      );
      expect(find.textContaining('RangeError'), findsNothing);
    });

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

    test(
      'production save path persists the complete draft, reloads it, and refreshes one bounded preview',
      () async {
        final requests = <RequestOptions>[];
        var previewCalls = 0;
        var nextRuleId = 100;
        var storedRules = <Map<String, dynamic>>[
          <String, dynamic>{
            'id': 1,
            'branchId': 1,
            'channel': 'pos',
            'dayOfWeek': null,
            'startTime': null,
            'endTime': null,
            'startDate': null,
            'endDate': null,
            'priority': 0,
            'isActive': true,
          },
          <String, dynamic>{
            'id': 2,
            'branchId': 1,
            'channel': null,
            'dayOfWeek': null,
            'startTime': null,
            'endTime': null,
            'startDate': null,
            'endDate': null,
            'priority': 0,
            'isActive': true,
          },
          <String, dynamic>{
            'id': 3,
            'branchId': null,
            'channel': 'delivery',
            'dayOfWeek': null,
            'startTime': null,
            'endTime': null,
            'startDate': null,
            'endDate': null,
            'priority': 0,
            'isActive': true,
          },
          <String, dynamic>{
            'id': 4,
            'branchId': null,
            'channel': null,
            'dayOfWeek': null,
            'startTime': null,
            'endTime': null,
            'startDate': null,
            'endDate': null,
            'priority': 0,
            'isActive': true,
          },
        ];
        final dio = Dio(BaseOptions(baseUrl: 'http://localhost:8000/api/v1/'));
        dio.interceptors.add(
          InterceptorsWrapper(
            onRequest: (options, handler) {
              requests.add(options);
              final Map<String, dynamic> response;
              switch ('${options.method} ${options.path}') {
                case 'GET branches':
                  response = <String, dynamic>{
                    'data': <Map<String, dynamic>>[
                      <String, dynamic>{
                        'id': 1,
                        'name': 'Downtown',
                        'timezone': 'Asia/Damascus',
                        'isActive': true,
                      },
                    ],
                  };
                case 'GET admin/menu-management/assignments':
                  response = _assignmentFixture();
                case 'POST admin/menu-management/preview':
                  previewCalls++;
                  response = _collectionPreviewFixture(
                    isAvailable: previewCalls == 1,
                  );
                case 'GET admin/menus/10/availability-rules':
                  response = <String, dynamic>{'data': storedRules};
                case 'PUT admin/menus/10/availability-rules':
                  final body = Map<String, dynamic>.from(options.data as Map);
                  final rules = (body['rules'] as List)
                      .cast<Map>()
                      .map(
                        (rule) => <String, dynamic>{
                          'id': nextRuleId++,
                          ...Map<String, dynamic>.from(rule),
                        },
                      )
                      .toList(growable: false);
                  storedRules = rules;
                  response = <String, dynamic>{'data': rules};
                default:
                  throw StateError(
                    'Unexpected production-path request: '
                    '${options.method} ${options.path}',
                  );
              }
              handler.resolve(
                Response<dynamic>(
                  requestOptions: options,
                  statusCode: 200,
                  data: response,
                ),
              );
            },
          ),
        );
        final cubit = MenuAssignmentsCubit(
          repository: BackendMenuCatalogRepository(DioApiClient(dio: dio)),
        );
        await cubit.load(branchId: 1, channel: 'pos');
        await cubit.loadScheduleRules(10);

        // This is the exact complete-rule draft produced after the drawer
        // expands an Every Day exact rule and customizes Monday.
        final draft = <Map<String, dynamic>>[
          _syncRule(day: 1, start: '07:00', end: '22:00'),
          _syncRule(day: 2, startDate: '2026-09-01'),
          _syncRule(day: 3, endDate: '2026-09-30'),
          _syncRule(day: 4, startDate: '2026-09-01', endDate: '2026-09-30'),
          _syncRule(day: 5, start: '07:00', end: '11:00'),
          _syncRule(day: 5, start: '17:00', end: '22:00'),
          _syncRule(day: 6, start: '22:00', end: '02:00'),
          _syncRule(day: 0),
          _syncRule(branchId: 1, channel: null),
          _syncRule(branchId: null, channel: 'delivery'),
          _syncRule(branchId: null, channel: null),
        ];
        final start = requests.length;

        expect(await cubit.saveMenuSchedule(10, draft), isTrue);

        final saveRequests = requests.skip(start).toList(growable: false);
        expect(
          saveRequests
              .where(
                (request) =>
                    request.method == 'PUT' &&
                    request.path == 'admin/menus/10/availability-rules',
              )
              .length,
          1,
        );
        expect(
          saveRequests
              .where(
                (request) =>
                    request.method == 'GET' &&
                    request.path == 'admin/menus/10/availability-rules',
              )
              .length,
          1,
        );
        expect(
          saveRequests
              .where(
                (request) =>
                    request.method == 'POST' &&
                    request.path == 'admin/menu-management/preview',
              )
              .length,
          1,
        );
        expect(
          saveRequests.where((request) => request.path == 'admin/menus/10'),
          isEmpty,
        );
        expect(
          saveRequests.where((request) => request.path.contains('price')),
          isEmpty,
        );

        final put = saveRequests.singleWhere(
          (request) => request.method == 'PUT',
        );
        final payload = Map<String, dynamic>.from(put.data as Map);
        final exact = (payload['rules'] as List)
            .cast<Map>()
            .map(Map<String, dynamic>.from)
            .where((rule) => rule['branchId'] == 1 && rule['channel'] == 'pos')
            .toList(growable: false);
        expect(exact, hasLength(8));
        expect(exact.where((rule) => rule['dayOfWeek'] == null), isEmpty);
        expect(
          exact.singleWhere((rule) => rule['dayOfWeek'] == 1)['startTime'],
          '07:00',
        );
        expect(
          exact.singleWhere((rule) => rule['dayOfWeek'] == 1)['endTime'],
          '22:00',
        );
        expect(
          exact
              .where((rule) => rule['dayOfWeek'] == 5)
              .map((rule) => '${rule['startTime']}–${rule['endTime']}'),
          containsAll(<String>['07:00–11:00', '17:00–22:00']),
        );
        expect(
          exact.singleWhere((rule) => rule['dayOfWeek'] == 6)['endTime'],
          '02:00',
        );
        expect(
          exact.singleWhere((rule) => rule['dayOfWeek'] == 2)['startDate'],
          '2026-09-01',
        );
        expect(
          exact.singleWhere((rule) => rule['dayOfWeek'] == 3)['endDate'],
          '2026-09-30',
        );
        expect(
          exact.singleWhere((rule) => rule['dayOfWeek'] == 0)['startDate'],
          isNull,
        );
        for (final rule in payload['rules'] as List) {
          final map = Map<String, dynamic>.from(rule as Map);
          expect(
            map.keys,
            containsAll(<String>[
              'branchId',
              'channel',
              'dayOfWeek',
              'startTime',
              'endTime',
              'startDate',
              'endDate',
              'priority',
              'isActive',
            ]),
          );
          expect(
            map['channel'],
            anyOf(isNull, equals('pos'), equals('delivery')),
          );
        }
        expect(cubit.state.scheduleRules[10], hasLength(11));
        expect(cubit.state.previewMenus[10]!.isScheduledAvailable, isFalse);
        expect(cubit.state.currentActionKey, isNull);

        // The Use broader action submits the same complete collection without
        // only the exact Downtown/POS rules; all broader scopes survive.
        final broader = draft
            .where(
              (rule) => !(rule['branchId'] == 1 && rule['channel'] == 'pos'),
            )
            .toList(growable: false);
        expect(await cubit.saveMenuSchedule(10, broader), isTrue);
        expect(
          cubit.state.scheduleRules[10]!.where(
            (rule) => rule.matchesExactScope(1, 'pos'),
          ),
          isEmpty,
        );
        expect(
          cubit.state.scheduleRules[10]!.where(
            (rule) => rule.branchId == 1 && rule.channel == null,
          ),
          hasLength(1),
        );
        expect(
          cubit.state.scheduleRules[10]!.where(
            (rule) => rule.branchId == null && rule.channel == 'delivery',
          ),
          hasLength(1),
        );
        expect(
          cubit.state.scheduleRules[10]!.where(
            (rule) => rule.branchId == null && rule.channel == null,
          ),
          hasLength(1),
        );
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

Widget _scheduleApp(MenuCatalogRepository repository) => MaterialApp(
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  home: BlocProvider<MenuAssignmentsCubit>(
    create: (_) => MenuAssignmentsCubit(repository: repository),
    child: const Scaffold(
      body: MenuAssignmentsScreen(initialBranchId: 1, initialChannel: 'pos'),
    ),
  ),
);

/// This is the real Laravel single-menu preview envelope. The deliberately
/// malformed deep diagnostics mirror the response class that the schedule
/// check must ignore: only the returned Menu schedule fields are authoritative
/// to this manager-facing operation.
Map<String, dynamic> _laravelSingleMenuPreviewFixture({
  required bool isAvailable,
  required String scheduleReason,
}) => <String, dynamic>{
  'data': <String, dynamic>{
    'context': <String, dynamic>{
      'branchId': 1,
      'channel': 'pos',
      'language': 'default',
      'evaluatedAt': '2026-08-26T10:00:00+00:00',
      'timezone': 'Asia/Damascus',
    },
    'canPublish': false,
    'validation': const <String, dynamic>{
      'errorCount': 0,
      'warningCount': 0,
      'informationCount': 0,
      'errors': <Object>[],
      'warnings': <Object>[],
      'information': <Object>[],
    },
    'menus': <Map<String, dynamic>>[
      <String, dynamic>{
        'id': 10,
        'name': 'RAMI',
        'description': null,
        'coverImageUrl': null,
        'priority': 0,
        'isAssigned': true,
        'isScheduledAvailable': isAvailable,
        'scheduleReason': scheduleReason,
        'sections': <Map<String, dynamic>>[
          <String, dynamic>{
            'id': 1,
            'name': 'Coffee',
            'products': <Map<String, dynamic>>[
              <String, dynamic>{'variants': ''},
            ],
          },
        ],
      },
    ],
  },
};

Map<String, dynamic> _assignmentFixture() => <String, dynamic>{
  'data': <Map<String, dynamic>>[
    <String, dynamic>{
      'id': 1,
      'menuId': 10,
      'branchId': 1,
      'channel': 'pos',
      'priority': 0,
      'isActive': true,
      'menu': <String, dynamic>{
        'id': 10,
        'name': 'RAMI',
        'status': 'active',
        'priority': 0,
        'sectionCount': 0,
        'visibleProductCount': 0,
      },
    },
  ],
};

Map<String, dynamic> _collectionPreviewFixture({required bool isAvailable}) =>
    <String, dynamic>{
      'data': <String, dynamic>{
        'canPublish': true,
        'context': <String, dynamic>{
          'timezone': 'Asia/Damascus',
          'evaluatedAt': '2026-08-26T10:00:00+00:00',
        },
        'menus': <Map<String, dynamic>>[
          <String, dynamic>{
            'id': 10,
            'name': 'RAMI',
            'priority': 0,
            'isAssigned': true,
            'isScheduledAvailable': isAvailable,
            'scheduleReason': isAvailable ? 'matched_rule' : 'outside_schedule',
            'sections': const <Object>[],
          },
        ],
      },
    };

Map<String, dynamic> _syncRule({
  int? branchId = 1,
  String? channel = 'pos',
  int? day,
  String? start,
  String? end,
  String? startDate,
  String? endDate,
  int priority = 0,
  bool isActive = true,
}) => <String, dynamic>{
  'branchId': branchId,
  'channel': channel,
  'dayOfWeek': day,
  'startTime': start,
  'endTime': end,
  'startDate': startDate,
  'endDate': endDate,
  'priority': priority,
  'isActive': isActive,
};

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
  MenuScheduleCheck scheduleCheck = const MenuScheduleCheck(
    isScheduledAvailable: true,
    scheduleReason: 'matched_rule',
  );
  Object? scheduleCheckError;
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
        'context': <String, dynamic>{
          'timezone': 'Asia/Damascus',
          'evaluatedAt': '2026-08-26T10:00:00+00:00',
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
      });

  @override
  Future<MenuScheduleCheck> previewMenuSchedule(
    int menuId,
    ReviewContext context,
  ) async {
    previewContexts.add(context);
    if (scheduleCheckError != null) throw scheduleCheckError!;
    return scheduleCheck;
  }
}

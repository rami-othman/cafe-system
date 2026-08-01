import 'package:flutter_test/flutter_test.dart';
import 'package:windows_application/features/menu_management/assignments/controllers/menu_assignments_cubit.dart';
import 'package:windows_application/features/menu_management/assignments/models/menu_assignment_models.dart';
import 'package:windows_application/features/menu_management/assignments/views/menu_assignments_screen.dart';
import 'package:windows_application/features/menu_management/menus/models/menu_filter.dart';
import 'package:windows_application/features/menu_management/menus/models/menu_models.dart';
import 'package:windows_application/features/menu_management/models/catalog_models.dart';
import 'package:windows_application/features/menu_management/repositories/menu_catalog_repository.dart';
import 'package:windows_application/features/pos/models/branch.dart';

void main() {
  group('Menu schedule rules', () {
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

    test(
      'client validation permits overnight and rejects invalid dates',
      () async {
        final _ScheduleRepository repository = _ScheduleRepository();
        final MenuAssignmentsCubit cubit = MenuAssignmentsCubit(
          repository: repository,
        );
        await cubit.load();
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
        await cubit.load();
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
  });
}

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
    return rules
        .asMap()
        .entries
        .map(
          (entry) => MenuScheduleRule.fromJson(<String, dynamic>{
            'id': entry.key + 1,
            ...entry.value,
          }),
        )
        .toList(growable: false);
  }
}

import 'package:flutter_test/flutter_test.dart';
import 'package:windows_application/features/menu_management/assignments/controllers/menu_assignments_cubit.dart';
import 'package:windows_application/features/menu_management/assignments/models/menu_assignment_models.dart';
import 'package:windows_application/features/menu_management/menus/models/menu_filter.dart';
import 'package:windows_application/features/menu_management/menus/models/menu_models.dart';
import 'package:windows_application/features/menu_management/repositories/menu_catalog_repository.dart';
import 'package:windows_application/features/pos/models/branch.dart';
import 'package:windows_application/features/menu_management/models/catalog_models.dart';

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

    test('scope loading separates assigned from eligible menus', () async {
      final _AssignmentsRepository repo = _AssignmentsRepository()
        ..assignments = <MenuAssignment>[_assignment(1, 10, priority: 0)];
      final MenuAssignmentsCubit cubit = MenuAssignmentsCubit(repository: repo);
      await cubit.load();
      expect(cubit.state.selectedBranch!.id, 1);
      expect(cubit.state.selectedChannel, 'pos');
      expect(cubit.state.assignments.single.menuId, 10);
      expect(cubit.state.availableMenus.map((m) => m.id), <int>[11]);
    });

    test(
      'assignment mutation sends contiguous complete scope payload',
      () async {
        final _AssignmentsRepository repo = _AssignmentsRepository();
        final MenuAssignmentsCubit cubit = MenuAssignmentsCubit(
          repository: repo,
        );
        await cubit.load();
        await cubit.assignMenu(_menu(11, 'Lunch'));
        expect(repo.lastDrafts.map((d) => d.menuId), <int>[10, 11]);
        expect(repo.lastDrafts.map((d) => d.priority), <int>[0, 1]);
        expect(repo.lastDrafts.every((d) => d.isActive), isTrue);
      },
    );

    test('failed reorder restores the previous visible order', () async {
      final _AssignmentsRepository repo = _AssignmentsRepository()
        ..assignments = <MenuAssignment>[
          _assignment(1, 10, priority: 0),
          _assignment(2, 11, priority: 1),
        ]
        ..failSync = true;
      final MenuAssignmentsCubit cubit = MenuAssignmentsCubit(repository: repo);
      await cubit.load();
      await cubit.moveAssignment(10, 1);
      expect(cubit.state.orderedAssignments.map((a) => a.menuId), <int>[
        10,
        11,
      ]);
      expect(cubit.state.errorMessage, isNotNull);
    });
  });
}

class _AssignmentsRepository extends MenuCatalogRepository {
  List<MenuAssignment> assignments = <MenuAssignment>[
    _assignment(1, 10, priority: 0),
  ];
  List<MenuAssignmentDraft> lastDrafts = <MenuAssignmentDraft>[];
  bool failSync = false;
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
  }) async => assignments;
  @override
  Future<CatalogPage<MenuRecord>> listMenus({
    required MenuFilter filter,
    required int page,
    int perPage = 20,
  }) async => CatalogPage<MenuRecord>(
    items: <MenuRecord>[_menu(10, 'Breakfast'), _menu(11, 'Lunch')],
    meta: const CatalogPagination(
      currentPage: 1,
      lastPage: 1,
      perPage: 100,
      total: 2,
    ),
  );
  @override
  Future<List<MenuAssignment>> syncMenuAssignments({
    required int branchId,
    required String channel,
    required List<MenuAssignmentDraft> assignments,
  }) async {
    lastDrafts = assignments;
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
    return this.assignments;
  }

  @override
  Future<List<MenuScheduleRule>> listMenuAvailabilityRules(int menuId) async =>
      const <MenuScheduleRule>[];
}

MenuAssignment _assignment(
  int id,
  int menuId, {
  required int priority,
  bool isActive = true,
}) => MenuAssignment(
  id: id,
  menuId: menuId,
  branchId: 1,
  channel: 'pos',
  priority: priority,
  isActive: isActive,
  createdAt: null,
  updatedAt: null,
  menu: _menu(menuId, menuId == 10 ? 'Breakfast' : 'Lunch'),
);
MenuRecord _menu(int id, String name) =>
    MenuRecord.fromJson(_menuJson(id, name));
Map<String, dynamic> _menuJson(int id, String name) => <String, dynamic>{
  'id': id,
  'name': name,
  'status': 'active',
  'priority': 0,
  'sectionCount': 1,
  'visibleProductCount': 2,
};

import 'package:flutter_test/flutter_test.dart';
import 'package:windows_application/features/menu_management/menus/controllers/menu_detail_cubit.dart';
import 'package:windows_application/features/menu_management/menus/models/menu_editor_draft.dart';
import 'package:windows_application/features/menu_management/menus/models/menu_models.dart';
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
}

class _SectionsRepository extends MenusRepositoryFake {
  _SectionsRepository({this.archived = false});
  final bool archived;
  int createSectionCalls = 0;
  List<MenuSectionReorderItem> reorderItems = <MenuSectionReorderItem>[];
  @override
  Future<MenuRecord> getMenu(int menuId, {bool includeArchived = false}) async {
    final Map<String, dynamic> json = menuJson(archived: archived);
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

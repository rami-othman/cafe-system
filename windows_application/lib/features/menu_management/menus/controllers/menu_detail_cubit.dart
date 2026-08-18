import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../core/network/api_exception.dart';
import '../../repositories/menu_catalog_repository.dart';
import '../models/menu_editor_draft.dart';
import '../models/menu_models.dart';

enum MenuDetailStatus { loading, loaded, failure }

enum MenuSectionFilter { active, inactive, archived, all }

class MenuDetailState extends Equatable {
  const MenuDetailState({
    this.status = MenuDetailStatus.loading,
    this.menu,
    this.sectionFilter = MenuSectionFilter.active,
    this.errorMessage,
    this.currentSectionId,
    this.menuLifecycleInProgress = false,
    this.reorderInProgress = false,
  });
  final MenuDetailStatus status;
  final MenuRecord? menu;
  final MenuSectionFilter sectionFilter;
  final String? errorMessage;
  final int? currentSectionId;
  final bool menuLifecycleInProgress, reorderInProgress;
  bool get isBusy =>
      menuLifecycleInProgress || currentSectionId != null || reorderInProgress;
  bool get isReadOnly => menu?.isArchived ?? false;
  List<MenuSectionRecord> get sections {
    final List<MenuSectionRecord> all =
        menu?.sections ?? const <MenuSectionRecord>[];
    return switch (sectionFilter) {
      MenuSectionFilter.active =>
        all.where((s) => s.isActiveLifecycle).toList(),
      MenuSectionFilter.inactive => all.where((s) => s.isInactive).toList(),
      MenuSectionFilter.archived => all.where((s) => s.isArchived).toList(),
      MenuSectionFilter.all => all,
    };
  }

  MenuDetailState copyWith({
    MenuDetailStatus? status,
    MenuRecord? menu,
    MenuSectionFilter? sectionFilter,
    String? errorMessage,
    int? currentSectionId,
    bool? menuLifecycleInProgress,
    bool? reorderInProgress,
    bool clearError = false,
    bool clearSection = false,
  }) => MenuDetailState(
    status: status ?? this.status,
    menu: menu ?? this.menu,
    sectionFilter: sectionFilter ?? this.sectionFilter,
    errorMessage: clearError ? null : errorMessage ?? this.errorMessage,
    currentSectionId: clearSection
        ? null
        : currentSectionId ?? this.currentSectionId,
    menuLifecycleInProgress:
        menuLifecycleInProgress ?? this.menuLifecycleInProgress,
    reorderInProgress: reorderInProgress ?? this.reorderInProgress,
  );
  @override
  List<Object?> get props => <Object?>[
    status,
    menu,
    sectionFilter,
    errorMessage,
    currentSectionId,
    menuLifecycleInProgress,
    reorderInProgress,
  ];
}

class MenuDetailCubit extends Cubit<MenuDetailState> {
  MenuDetailCubit({required this.repository}) : super(const MenuDetailState());
  final MenuCatalogRepository repository;
  Future<void> load(int menuId) async {
    emit(state.copyWith(status: MenuDetailStatus.loading, clearError: true));
    try {
      emit(
        state.copyWith(
          status: MenuDetailStatus.loaded,
          menu: await repository.getMenu(menuId, includeArchived: true),
        ),
      );
    } catch (e) {
      emit(
        state.copyWith(
          status: MenuDetailStatus.failure,
          errorMessage: _message(e),
        ),
      );
    }
  }

  void setSectionFilter(MenuSectionFilter value) =>
      emit(state.copyWith(sectionFilter: value));
  Future<void> archiveMenu() => _menuLifecycle(false);
  Future<void> restoreMenu() => _menuLifecycle(true);
  Future<void> _menuLifecycle(bool restore) async {
    final int? id = state.menu?.id;
    if (id == null || state.isBusy) return;
    emit(state.copyWith(menuLifecycleInProgress: true, clearError: true));
    try {
      await (restore ? repository.restoreMenu(id) : repository.archiveMenu(id));
      emit(state.copyWith(menuLifecycleInProgress: false));
      await load(id);
    } catch (e) {
      emit(
        state.copyWith(
          menuLifecycleInProgress: false,
          errorMessage: _message(e),
        ),
      );
    }
  }

  Future<void> createSection(MenuSectionDraft draft) => _sectionMutation(
    null,
    () => repository.createMenuSection(state.menu!.id, draft),
  );
  Future<void> updateSection(int id, MenuSectionDraft draft) =>
      _sectionMutation(id, () => repository.updateMenuSection(id, draft));
  Future<void> archiveSection(int id) =>
      _sectionMutation(id, () => repository.archiveMenuSection(id));
  Future<void> restoreSection(int id) =>
      _sectionMutation(id, () => repository.restoreMenuSection(id));
  Future<void> activateSection(MenuSectionRecord section) =>
      _sectionLifecycle(section, true);
  Future<void> deactivateSection(MenuSectionRecord section) =>
      _sectionLifecycle(section, false);
  Future<void> _sectionLifecycle(MenuSectionRecord section, bool isActive) =>
      _sectionMutation(
        section.id,
        () => repository.updateMenuSection(
          section.id,
          MenuSectionDraft(
            name: section.name,
            nameAr: section.nameAr,
            nameEn: section.nameEn,
            description: section.description,
            imageUrl: section.imageUrl,
            isActive: isActive,
            sortOrder: section.sortOrder.toString(),
          ),
        ),
      );
  Future<void> _sectionMutation(
    int? id,
    Future<MenuSectionRecord> Function() action,
  ) async {
    if (state.menu == null || state.isReadOnly || state.isBusy) return;
    emit(state.copyWith(currentSectionId: id ?? -1, clearError: true));
    try {
      await action();
      final int menuId = state.menu!.id;
      emit(state.copyWith(clearSection: true));
      await load(menuId);
    } catch (e) {
      emit(state.copyWith(clearSection: true, errorMessage: _message(e)));
    }
  }

  Future<void> moveSection(int sectionId, int delta) async {
    if (state.isReadOnly || state.isBusy) return;
    final List<MenuSectionRecord> active =
        (state.menu?.sections.where((s) => !s.isArchived).toList() ??
              <MenuSectionRecord>[])
          ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
    final int from = active.indexWhere((s) => s.id == sectionId),
        to = from + delta;
    if (from < 0 || to < 0 || to >= active.length) return;
    final MenuSectionRecord moved = active.removeAt(from);
    active.insert(to, moved);
    final List<MenuSectionReorderItem> payload =
        List<MenuSectionReorderItem>.generate(
          active.length,
          (i) => MenuSectionReorderItem(id: active[i].id, sortOrder: i),
        );
    final MenuRecord before = state.menu!;
    emit(state.copyWith(reorderInProgress: true));
    try {
      await repository.reorderMenuSections(before.id, payload);
      emit(state.copyWith(reorderInProgress: false));
      await load(before.id);
    } catch (e) {
      emit(
        state.copyWith(
          reorderInProgress: false,
          menu: before,
          errorMessage: _message(e),
        ),
      );
    }
  }

  String _message(Object e) =>
      e is ApiException ? e.message : 'Unable to update this menu.';
}

// ignore_for_file: curly_braces_in_flow_control_structures

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../core/network/api_exception.dart';
import '../../repositories/menu_catalog_repository.dart';
import '../../recipes/models/recipe_models.dart';
import '../models/modifier_editor_drafts.dart';
import '../models/modifier_models.dart';

enum ModifierDetailStatus { loading, loaded, failure }

class ModifierGroupDetailState extends Equatable {
  const ModifierGroupDetailState({
    this.status = ModifierDetailStatus.loading,
    this.group,
    this.errorMessage,
    this.currentActionId,
    this.isReordering = false,
    this.optionFilter = 'active',
    this.materialEffects = const <int, ModifierRecipeProfile>{},
    this.recipeMaterials = const <RecipeMaterial>[],
  });
  final ModifierDetailStatus status;
  final ModifierGroupRecord? group;
  final String? errorMessage;
  final int? currentActionId;
  final bool isReordering;
  final String optionFilter;
  final Map<int, ModifierRecipeProfile> materialEffects;
  final List<RecipeMaterial> recipeMaterials;
  List<ModifierOptionRecord> get visibleOptions =>
      group?.options
          .where(
            (option) => optionFilter == 'all'
                ? true
                : optionFilter == 'archived'
                ? option.isArchived
                : optionFilter == 'inactive'
                ? option.isInactive
                : option.isActiveLifecycle,
          )
          .toList() ??
      const <ModifierOptionRecord>[];
  ModifierGroupDetailState copyWith({
    ModifierDetailStatus? status,
    ModifierGroupRecord? group,
    String? errorMessage,
    int? currentActionId,
    bool? isReordering,
    String? optionFilter,
    Map<int, ModifierRecipeProfile>? materialEffects,
    List<RecipeMaterial>? recipeMaterials,
    bool clearGroup = false,
    bool clearError = false,
    bool clearAction = false,
  }) => ModifierGroupDetailState(
    status: status ?? this.status,
    group: clearGroup ? null : group ?? this.group,
    errorMessage: clearError ? null : errorMessage ?? this.errorMessage,
    currentActionId: clearAction
        ? null
        : currentActionId ?? this.currentActionId,
    isReordering: isReordering ?? this.isReordering,
    optionFilter: optionFilter ?? this.optionFilter,
    materialEffects: materialEffects ?? this.materialEffects,
    recipeMaterials: recipeMaterials ?? this.recipeMaterials,
  );
  @override
  List<Object?> get props => <Object?>[
    status,
    group,
    errorMessage,
    currentActionId,
    isReordering,
    optionFilter,
    materialEffects,
    recipeMaterials,
  ];
}

class ModifierGroupDetailCubit extends Cubit<ModifierGroupDetailState> {
  ModifierGroupDetailCubit({required this.repository})
    : super(const ModifierGroupDetailState());
  final MenuCatalogRepository repository;
  int? _id;
  Future<void> load(int id) async {
    _id = id;
    emit(
      state.copyWith(
        status: ModifierDetailStatus.loading,
        clearError: true,
        materialEffects: const <int, ModifierRecipeProfile>{},
        recipeMaterials: const <RecipeMaterial>[],
      ),
    );
    try {
      final ModifierGroupRecord group = await repository.getModifierGroup(
        id,
        includeArchived: true,
      );
      emit(state.copyWith(status: ModifierDetailStatus.loaded, group: group));
      await loadMaterialEffects();
    } catch (error) {
      emit(
        state.copyWith(
          status: ModifierDetailStatus.failure,
          errorMessage: _message(error),
        ),
      );
    }
  }

  Future<void> refresh() => _id == null ? Future<void>.value() : load(_id!);

  Future<void> loadMaterialEffects() async {
    final ModifierGroupRecord? group = state.group;
    if (group == null) return;
    try {
      final List<ModifierRecipeProfile> profiles = await repository
          .getModifierGroupMaterialEffects(group.id);
      final List<RecipeMaterial> materials = profiles.isEmpty
          ? const <RecipeMaterial>[]
          : await repository.listRecipeMaterials();
      emit(
        state.copyWith(
          materialEffects: <int, ModifierRecipeProfile>{
            for (final profile in profiles) profile.optionId: profile,
          },
          recipeMaterials: materials,
          clearError: true,
        ),
      );
    } catch (error) {
      emit(state.copyWith(errorMessage: _message(error)));
    }
  }

  void setOptionFilter(String value) =>
      emit(state.copyWith(optionFilter: value));
  Future<void> saveOption(ModifierOptionDraft draft, {int? optionId}) async {
    if (state.currentActionId != null || _id == null) return;
    emit(state.copyWith(currentActionId: optionId ?? -1, clearError: true));
    try {
      if (optionId == null) {
        await repository.createModifierOption(_id!, draft);
      } else {
        await repository.updateModifierOption(optionId, draft);
      }
      emit(state.copyWith(clearAction: true));
      await refresh();
    } catch (error) {
      emit(state.copyWith(clearAction: true, errorMessage: _message(error)));
      rethrow;
    }
  }

  Future<void> archiveGroup() =>
      _groupAction(() => repository.archiveModifierGroup(_id!));

  Future<void> restoreGroup() =>
      _groupAction(() => repository.restoreModifierGroup(_id!));
  Future<void> activateGroup() => _groupLifecycle(true);
  Future<void> deactivateGroup() => _groupLifecycle(false);

  Future<void> _groupLifecycle(bool isActive) {
    final ModifierGroupRecord? group = state.group;
    if (group == null) return Future<void>.value();
    return _groupAction(
      () => repository.updateModifierGroup(
        group.id,
        ModifierGroupDraft(
          name: group.name,
          nameAr: group.nameAr ?? '',
          nameEn: group.nameEn ?? '',
          code: group.code ?? '',
          groupType: group.groupType,
          selectionType: group.selectionType,
          isRequired: group.isRequired,
          minSelections: group.minSelections.toString(),
          maxSelections: group.maxSelections.toString(),
          allowQuantity: group.allowQuantity,
          isActive: isActive,
          sortOrder: group.sortOrder.toString(),
        ),
      ),
    );
  }

  Future<void> _groupAction(
    Future<ModifierGroupRecord> Function() action,
  ) async {
    if (state.currentActionId != null || _id == null) return;
    emit(state.copyWith(currentActionId: _id, clearError: true));
    try {
      await action();
      emit(state.copyWith(clearAction: true));
      await refresh();
    } catch (error) {
      emit(state.copyWith(clearAction: true, errorMessage: _message(error)));
    }
  }

  Future<void> archiveOption(int id) =>
      _optionAction(id, () => repository.archiveModifierOption(id));
  Future<void> restoreOption(int id) =>
      _optionAction(id, () => repository.restoreModifierOption(id));
  Future<void> activateOption(ModifierOptionRecord option) =>
      _optionLifecycle(option, true);
  Future<void> deactivateOption(ModifierOptionRecord option) =>
      _optionLifecycle(option, false);
  Future<void> _optionLifecycle(ModifierOptionRecord option, bool isActive) =>
      _optionAction(
        option.id,
        () => repository.updateModifierOption(
          option.id,
          ModifierOptionDraft(
            name: option.name,
            nameAr: option.nameAr ?? '',
            nameEn: option.nameEn ?? '',
            priceDelta: option.priceDelta.toString(),
            isDefault: option.isDefault,
            isActive: isActive,
            isAvailable: option.isAvailable,
            sortOrder: option.sortOrder.toString(),
          ),
        ),
      );
  Future<void> _optionAction(
    int id,
    Future<ModifierOptionRecord> Function() action,
  ) async {
    if (state.currentActionId != null) return;
    emit(state.copyWith(currentActionId: id, clearError: true));
    try {
      await action();
      emit(state.copyWith(clearAction: true));
      await refresh();
    } catch (error) {
      emit(state.copyWith(clearAction: true, errorMessage: _message(error)));
    }
  }

  Future<void> move(ModifierOptionRecord option, int direction) async {
    final List<ModifierOptionRecord> active = state.group!.options
        .where((item) => !item.isArchived)
        .toList();
    final int index = active.indexWhere((item) => item.id == option.id);
    final int target = index + direction;
    if (index < 0 ||
        target < 0 ||
        target >= active.length ||
        state.isReordering)
      return;
    final List<ModifierOptionRecord> previous = List<ModifierOptionRecord>.from(
      state.group!.options,
    );
    final ModifierOptionRecord swapped = active[target];
    active[index] = swapped;
    active[target] = option;
    final Map<int, int> orders = <int, int>{
      for (int i = 0; i < active.length; i++) active[i].id: i,
    };
    final List<ModifierOptionRecord> optimistic =
        previous
            .map(
              (item) => orders.containsKey(item.id)
                  ? ModifierOptionRecord(
                      id: item.id,
                      modifierGroupId: item.modifierGroupId,
                      name: item.name,
                      nameAr: item.nameAr,
                      nameEn: item.nameEn,
                      priceDelta: item.priceDelta,
                      isDefault: item.isDefault,
                      isActive: item.isActive,
                      isAvailable: item.isAvailable,
                      sortOrder: orders[item.id]!,
                      archivedAt: item.archivedAt,
                    )
                  : item,
            )
            .toList()
          ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
    emit(
      state.copyWith(
        isReordering: true,
        group: _withOptions(state.group!, optimistic),
        clearError: true,
      ),
    );
    try {
      await repository.reorderModifierOptions(
        _id!,
        active
            .asMap()
            .entries
            .map((entry) => ModifierReorderItem(entry.value.id, entry.key))
            .toList(),
      );
      await refresh();
    } catch (error) {
      emit(
        state.copyWith(
          isReordering: false,
          group: _withOptions(state.group!, previous),
          errorMessage: _message(error),
        ),
      );
      return;
    }
    emit(state.copyWith(isReordering: false));
  }

  ModifierGroupRecord _withOptions(
    ModifierGroupRecord g,
    List<ModifierOptionRecord> options,
  ) => ModifierGroupRecord(
    id: g.id,
    name: g.name,
    nameAr: g.nameAr,
    nameEn: g.nameEn,
    code: g.code,
    groupType: g.groupType,
    selectionType: g.selectionType,
    isRequired: g.isRequired,
    minSelections: g.minSelections,
    maxSelections: g.maxSelections,
    allowQuantity: g.allowQuantity,
    isActive: g.isActive,
    sortOrder: g.sortOrder,
    optionCount: g.optionCount,
    activeOptionCount: g.activeOptionCount,
    options: options,
    optionPreview: g.optionPreview,
    remainingOptionCount: g.remainingOptionCount,
    materialImpactConfigured: g.materialImpactConfigured,
    archivedAt: g.archivedAt,
    createdAt: g.createdAt,
    updatedAt: g.updatedAt,
  );
  String _message(Object error) => error is ApiException
      ? error.message
      : 'Unable to update modifier options.';
}

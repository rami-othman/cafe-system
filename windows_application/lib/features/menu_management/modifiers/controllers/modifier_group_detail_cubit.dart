// ignore_for_file: curly_braces_in_flow_control_structures

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../core/network/api_exception.dart';
import '../../repositories/menu_catalog_repository.dart';
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
  });
  final ModifierDetailStatus status;
  final ModifierGroupRecord? group;
  final String? errorMessage;
  final int? currentActionId;
  final bool isReordering;
  final String optionFilter;
  List<ModifierOptionRecord> get visibleOptions =>
      group?.options
          .where(
            (option) => optionFilter == 'all'
                ? true
                : optionFilter == 'archived'
                ? option.isArchived
                : !option.isArchived,
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
  );
  @override
  List<Object?> get props => <Object?>[
    status,
    group,
    errorMessage,
    currentActionId,
    isReordering,
    optionFilter,
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
      state.copyWith(status: ModifierDetailStatus.loading, clearError: true),
    );
    try {
      emit(
        state.copyWith(
          status: ModifierDetailStatus.loaded,
          group: await repository.getModifierGroup(id, includeArchived: true),
        ),
      );
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

  Future<void> archiveOption(int id) =>
      _optionAction(id, () => repository.archiveModifierOption(id));
  Future<void> restoreOption(int id) =>
      _optionAction(id, () => repository.restoreModifierOption(id));
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
    archivedAt: g.archivedAt,
    createdAt: g.createdAt,
    updatedAt: g.updatedAt,
  );
  String _message(Object error) => error is ApiException
      ? error.message
      : 'Unable to update modifier options.';
}

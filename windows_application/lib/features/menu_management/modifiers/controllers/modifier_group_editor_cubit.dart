// ignore_for_file: curly_braces_in_flow_control_structures

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../core/network/api_exception.dart';
import '../../repositories/menu_catalog_repository.dart';
import '../models/modifier_editor_drafts.dart';
import '../models/modifier_models.dart';

enum ModifierEditorStatus {
  initial,
  loading,
  ready,
  submitting,
  success,
  failure,
}

class ModifierGroupEditorState extends Equatable {
  const ModifierGroupEditorState({
    this.status = ModifierEditorStatus.initial,
    this.draft = const ModifierGroupDraft(),
    this.groupId,
    this.fieldErrors = const <String, String>{},
    this.formError,
    this.formErrorCode,
    this.savedGroup,
    this.isDirty = false,
  });
  final ModifierEditorStatus status;
  final ModifierGroupDraft draft;
  final int? groupId;
  final Map<String, String> fieldErrors;
  final String? formError;
  final String? formErrorCode;
  final ModifierGroupRecord? savedGroup;
  final bool isDirty;
  bool get isCreate => groupId == null;
  ModifierGroupEditorState copyWith({
    ModifierEditorStatus? status,
    ModifierGroupDraft? draft,
    int? groupId,
    Map<String, String>? fieldErrors,
    String? formError,
    String? formErrorCode,
    ModifierGroupRecord? savedGroup,
    bool? isDirty,
    bool clearErrors = false,
    bool clearFormError = false,
  }) => ModifierGroupEditorState(
    status: status ?? this.status,
    draft: draft ?? this.draft,
    groupId: groupId ?? this.groupId,
    fieldErrors: clearErrors
        ? const <String, String>{}
        : fieldErrors ?? this.fieldErrors,
    formError: clearFormError ? null : formError ?? this.formError,
    formErrorCode:
        formErrorCode ?? (clearFormError ? null : this.formErrorCode),
    savedGroup: savedGroup ?? this.savedGroup,
    isDirty: isDirty ?? this.isDirty,
  );
  @override
  List<Object?> get props => <Object?>[
    status,
    draft.name,
    draft.nameAr,
    draft.nameEn,
    draft.code,
    draft.groupType,
    draft.selectionType,
    draft.isRequired,
    draft.minSelections,
    draft.maxSelections,
    draft.allowQuantity,
    draft.isActive,
    draft.sortOrder,
    draft.initialOptionName,
    draft.initialOptionPriceDelta,
    draft.initialOptions,
    groupId,
    fieldErrors,
    formError,
    formErrorCode,
    savedGroup,
    isDirty,
  ];
}

class ModifierGroupEditorCubit extends Cubit<ModifierGroupEditorState> {
  ModifierGroupEditorCubit({required this.repository})
    : super(const ModifierGroupEditorState());
  final MenuCatalogRepository repository;
  void initializeCreate() =>
      emit(const ModifierGroupEditorState(status: ModifierEditorStatus.ready));
  Future<void> loadForEdit(int id) async {
    emit(
      ModifierGroupEditorState(
        status: ModifierEditorStatus.loading,
        groupId: id,
      ),
    );
    try {
      final ModifierGroupRecord group = await repository.getModifierGroup(
        id,
        includeArchived: true,
      );
      emit(
        ModifierGroupEditorState(
          status: ModifierEditorStatus.ready,
          groupId: id,
          draft: ModifierGroupDraft(
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
            isActive: group.isActive,
            sortOrder: group.sortOrder.toString(),
          ),
          isDirty: false,
        ),
      );
    } catch (error) {
      emit(
        state.copyWith(
          status: ModifierEditorStatus.failure,
          formError: _message(error),
        ),
      );
    }
  }

  void updateDraft(ModifierGroupDraft draft) => emit(
    state.copyWith(
      draft: draft,
      isDirty: true,
      clearErrors: true,
      clearFormError: true,
    ),
  );
  Future<void> submit() async {
    if (state.status == ModifierEditorStatus.submitting) return;
    final Map<String, String> errors = _validate(state.draft, state.isCreate);
    if (errors.isNotEmpty) {
      emit(
        state.copyWith(
          status: ModifierEditorStatus.failure,
          fieldErrors: errors,
          clearFormError: true,
          formErrorCode: errors.containsValue(_initialOptionsCountError)
              ? 'initialOptionsCount'
              : null,
        ),
      );
      return;
    }
    emit(
      state.copyWith(
        status: ModifierEditorStatus.submitting,
        clearErrors: true,
        clearFormError: true,
      ),
    );
    try {
      final ModifierGroupRecord saved = state.isCreate
          ? await repository.createModifierGroup(state.draft)
          : await repository.updateModifierGroup(state.groupId!, state.draft);
      emit(
        state.copyWith(
          status: ModifierEditorStatus.success,
          savedGroup: saved,
          isDirty: false,
        ),
      );
    } catch (error) {
      if (error is ApiException && error.validationErrors != null) {
        final Map<String, String> fields = error.validationErrors!.map(
          (key, value) => MapEntry(key, value.first),
        );
        emit(
          state.copyWith(
            status: ModifierEditorStatus.failure,
            fieldErrors: fields,
            formError: _formError(fields, error.message),
            formErrorCode: _formErrorCode(fields),
          ),
        );
      } else {
        emit(
          state.copyWith(
            status: ModifierEditorStatus.failure,
            formError: _message(error),
          ),
        );
      }
    }
  }

  Map<String, String> _validate(ModifierGroupDraft draft, bool create) {
    final Map<String, String> errors = <String, String>{};
    final int? min = int.tryParse(draft.minSelections.trim());
    final int? max = int.tryParse(draft.maxSelections.trim());
    if (draft.name.trim().isEmpty)
      errors['name'] = 'Modifier group name is required.';
    if (min == null || min < 0)
      errors['minSelections'] = 'Enter zero or a positive whole number.';
    if (max == null || max < 0)
      errors['maxSelections'] = 'Enter zero or a positive whole number.';
    if (min != null && max != null && max < min)
      errors['maxSelections'] = 'Maximum must be at least the minimum.';
    if (draft.selectionType == 'single' && max != null && max > 1)
      errors['maxSelections'] =
          'Single selection groups cannot have a maximum above 1.';
    if (draft.isRequired && (min == null || min < 1))
      errors['minSelections'] = 'Required groups need a minimum of at least 1.';
    if (int.tryParse(draft.sortOrder.trim()) == null)
      errors['sortOrder'] = 'Enter a whole number.';
    if (create) {
      final List<ModifierOptionDraft> options = draft.createOptions;
      if (options.isEmpty) {
        errors['options.0.name'] =
            'An initial active option is required by the backend.';
      }
      for (int index = 0; index < options.length; index++) {
        final ModifierOptionDraft option = options[index];
        if (option.name.trim().isEmpty)
          errors['options.$index.name'] =
              'An initial active option is required by the backend.';
        if (!isValidModifierPriceAdjustment(option.priceDelta))
          errors['options.$index.priceDelta'] =
              modifierPriceAdjustmentInvalidCode;
      }
      final int activeOptionCount = options
          .where((option) => option.isActive)
          .length;
      if (max != null && max > activeOptionCount && !draft.allowQuantity)
        errors['maxSelections'] = _initialOptionsCountError;
    }
    return errors;
  }

  static const String _initialOptionsCountError = '__initial_options_count__';

  String? _formErrorCode(Map<String, String> fields) {
    if (fields.containsKey('modifierGroup') || fields.containsKey('options')) {
      return 'groupSave';
    }
    return null;
  }

  String _formError(Map<String, String> fields, String fallback) {
    for (final String key in fields.keys) {
      if (!<String>{
            'name',
            'nameAr',
            'nameEn',
            'code',
            'groupType',
            'selectionType',
            'isRequired',
            'minSelections',
            'maxSelections',
            'allowQuantity',
            'isActive',
            'sortOrder',
          }.contains(key) &&
          !key.startsWith('options.'))
        return fields[key]!;
    }
    return fallback;
  }

  String _message(Object error) => error is ApiException
      ? error.message
      : 'Unable to save this modifier group.';
}

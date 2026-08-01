import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../core/network/api_exception.dart';
import '../../repositories/menu_catalog_repository.dart';
import '../models/menu_editor_draft.dart';
import '../models/menu_models.dart';

enum MenuEditorStatus {
  initializing,
  loading,
  ready,
  submitting,
  success,
  failure,
}

class MenuEditorState extends Equatable {
  const MenuEditorState({
    this.status = MenuEditorStatus.initializing,
    this.draft = const MenuEditorDraft(),
    this.menuId,
    this.result,
    this.fieldErrors = const <String, String>{},
    this.errorMessage,
    this.isDirty = false,
  });
  final MenuEditorStatus status;
  final MenuEditorDraft draft;
  final int? menuId;
  final MenuRecord? result;
  final Map<String, String> fieldErrors;
  final String? errorMessage;
  final bool isDirty;
  bool get isEdit => menuId != null;
  MenuEditorState copyWith({
    MenuEditorStatus? status,
    MenuEditorDraft? draft,
    int? menuId,
    MenuRecord? result,
    Map<String, String>? fieldErrors,
    String? errorMessage,
    bool? isDirty,
    bool clearErrors = false,
  }) => MenuEditorState(
    status: status ?? this.status,
    draft: draft ?? this.draft,
    menuId: menuId ?? this.menuId,
    result: result ?? this.result,
    fieldErrors: clearErrors
        ? const <String, String>{}
        : fieldErrors ?? this.fieldErrors,
    errorMessage: clearErrors ? null : errorMessage ?? this.errorMessage,
    isDirty: isDirty ?? this.isDirty,
  );
  @override
  List<Object?> get props => <Object?>[
    status,
    draft.name,
    draft.nameAr,
    draft.nameEn,
    draft.description,
    draft.descriptionAr,
    draft.descriptionEn,
    draft.coverImageUrl,
    draft.status,
    draft.priority,
    menuId,
    result?.id,
    fieldErrors,
    errorMessage,
    isDirty,
  ];
}

class MenuEditorCubit extends Cubit<MenuEditorState> {
  MenuEditorCubit({required this.repository}) : super(const MenuEditorState());
  final MenuCatalogRepository repository;
  Future<void> initializeCreate() async =>
      emit(const MenuEditorState(status: MenuEditorStatus.ready));
  Future<void> loadForEdit(int id) async {
    emit(const MenuEditorState(status: MenuEditorStatus.loading));
    try {
      final MenuRecord m = await repository.getMenu(id, includeArchived: true);
      emit(
        MenuEditorState(
          status: MenuEditorStatus.ready,
          menuId: id,
          draft: MenuEditorDraft(
            name: m.name,
            nameAr: m.nameAr,
            nameEn: m.nameEn,
            description: m.description,
            descriptionAr: m.descriptionAr,
            descriptionEn: m.descriptionEn,
            coverImageUrl: m.coverImageUrl,
            status: m.status,
            priority: '${m.priority}',
          ),
        ),
      );
    } catch (e) {
      emit(
        state.copyWith(
          status: MenuEditorStatus.failure,
          errorMessage: _message(e),
        ),
      );
    }
  }

  void updateDraft(MenuEditorDraft draft) =>
      emit(state.copyWith(draft: draft, isDirty: true, clearErrors: true));
  Future<void> submit() async {
    if (state.status == MenuEditorStatus.submitting) return;
    final Map<String, String> errors = _validate(state.draft);
    if (errors.isNotEmpty) {
      emit(
        state.copyWith(status: MenuEditorStatus.failure, fieldErrors: errors),
      );
      return;
    }
    emit(
      state.copyWith(status: MenuEditorStatus.submitting, clearErrors: true),
    );
    try {
      final MenuRecord result = state.isEdit
          ? await repository.updateMenu(state.menuId!, state.draft)
          : await repository.createMenu(state.draft);
      emit(
        state.copyWith(
          status: MenuEditorStatus.success,
          result: result,
          isDirty: false,
        ),
      );
    } catch (e) {
      emit(
        state.copyWith(
          status: MenuEditorStatus.failure,
          fieldErrors: _fields(e),
          errorMessage: _message(e),
        ),
      );
    }
  }

  Map<String, String> _validate(MenuEditorDraft draft) {
    final Map<String, String> out = <String, String>{};
    if (draft.name.trim().isEmpty) out['name'] = 'Default name is required.';
    if (draft.priority.trim().isEmpty ||
        int.tryParse(draft.priority.trim()) == null)
      out['priority'] = 'Priority must be an integer.';
    return out;
  }

  Map<String, String> _fields(Object e) => e is ApiException
      ? <String, String>{
          for (final MapEntry<String, List<String>> x
              in (e.validationErrors ?? const <String, List<String>>{}).entries)
            x.key: x.value.first,
        }
      : const <String, String>{};
  String _message(Object e) =>
      e is ApiException ? e.message : 'Unable to save this menu.';
}

// ignore_for_file: curly_braces_in_flow_control_structures

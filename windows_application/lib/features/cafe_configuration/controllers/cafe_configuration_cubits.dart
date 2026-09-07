import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/network/api_exception.dart';
import '../models/cafe_configuration_models.dart';
import '../repositories/cafe_configuration_repository.dart';

enum CafeConfigurationLoadStatus {
  loading,
  ready,
  failure,
  submitting,
  success,
}

class ProfileState extends Equatable {
  const ProfileState({
    this.status = CafeConfigurationLoadStatus.loading,
    this.profile,
    this.draft = const CafeProfileDraft(),
    this.errors = const <String, String>{},
    this.errorMessage,
    this.isDirty = false,
  });
  final CafeConfigurationLoadStatus status;
  final CafeProfile? profile;
  final CafeProfileDraft draft;
  final Map<String, String> errors;
  final String? errorMessage;
  final bool isDirty;
  ProfileState copyWith({
    CafeConfigurationLoadStatus? status,
    CafeProfile? profile,
    CafeProfileDraft? draft,
    Map<String, String>? errors,
    String? errorMessage,
    bool? isDirty,
    bool clearMessages = false,
  }) => ProfileState(
    status: status ?? this.status,
    profile: profile ?? this.profile,
    draft: draft ?? this.draft,
    errors: clearMessages ? const <String, String>{} : errors ?? this.errors,
    errorMessage: clearMessages ? null : errorMessage ?? this.errorMessage,
    isDirty: isDirty ?? this.isDirty,
  );
  @override
  List<Object?> get props => <Object?>[
    status,
    profile?.name,
    profile?.currency,
    profile?.status,
    draft.name,
    draft.email,
    draft.phone,
    draft.timezone,
    errors,
    errorMessage,
    isDirty,
  ];
}

class CafeProfileCubit extends Cubit<ProfileState> {
  CafeProfileCubit(this._repository) : super(const ProfileState());
  final CafeConfigurationRepository _repository;
  Future<void> load() async {
    emit(const ProfileState());
    try {
      final CafeProfile profile = await _repository.getProfile();
      emit(
        ProfileState(
          status: CafeConfigurationLoadStatus.ready,
          profile: profile,
          draft: CafeProfileDraft.fromProfile(profile),
        ),
      );
    } catch (_) {
      emit(
        state.copyWith(
          status: CafeConfigurationLoadStatus.failure,
          errorMessage: 'load',
        ),
      );
    }
  }

  void update(CafeProfileDraft draft) => emit(
    state.copyWith(
      draft: draft,
      isDirty: _different(draft, state.profile),
      clearMessages: true,
    ),
  );
  void reset() {
    final CafeProfile? profile = state.profile;
    if (profile != null) {
      emit(
        state.copyWith(
          draft: CafeProfileDraft.fromProfile(profile),
          isDirty: false,
          clearMessages: true,
        ),
      );
    }
  }

  Future<void> save() async {
    if (state.status == CafeConfigurationLoadStatus.submitting ||
        !state.isDirty) {
      return;
    }
    final Map<String, String> errors = _validate(state.draft);
    if (errors.isNotEmpty) {
      emit(
        state.copyWith(
          status: CafeConfigurationLoadStatus.failure,
          errors: errors,
        ),
      );
      return;
    }
    emit(
      state.copyWith(
        status: CafeConfigurationLoadStatus.submitting,
        clearMessages: true,
      ),
    );
    try {
      final CafeProfile saved = await _repository.updateProfile(state.draft);
      emit(
        ProfileState(
          status: CafeConfigurationLoadStatus.success,
          profile: saved,
          draft: CafeProfileDraft.fromProfile(saved),
        ),
      );
    } catch (e) {
      emit(
        state.copyWith(
          status: CafeConfigurationLoadStatus.failure,
          errors: _fields(e),
          errorMessage: 'save',
        ),
      );
    }
  }

  Map<String, String> _validate(CafeProfileDraft d) {
    final Map<String, String> e = <String, String>{};
    if (d.name.trim().isEmpty) {
      e['name'] = 'required';
    }
    if (d.email.trim().isNotEmpty &&
        !RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(d.email.trim())) {
      e['email'] = 'invalidEmail';
    }
    if (d.timezone.trim().isEmpty) {
      e['timezone'] = 'required';
    }
    return e;
  }
}

class BranchesState extends Equatable {
  const BranchesState({
    this.status = CafeConfigurationLoadStatus.loading,
    this.branches = const <CafeConfigurationBranch>[],
    this.errorMessage,
  });
  final CafeConfigurationLoadStatus status;
  final List<CafeConfigurationBranch> branches;
  final String? errorMessage;
  @override
  List<Object?> get props => <Object?>[status, branches, errorMessage];
}

class CafeBranchesCubit extends Cubit<BranchesState> {
  CafeBranchesCubit(this._repository) : super(const BranchesState());
  final CafeConfigurationRepository _repository;
  Future<void> load() async {
    emit(const BranchesState());
    try {
      emit(
        BranchesState(
          status: CafeConfigurationLoadStatus.ready,
          branches: await _repository.getBranches(),
        ),
      );
    } catch (_) {
      emit(
        const BranchesState(
          status: CafeConfigurationLoadStatus.failure,
          errorMessage: 'load',
        ),
      );
    }
  }
}

class BranchEditorState extends Equatable {
  const BranchEditorState({
    this.status = CafeConfigurationLoadStatus.loading,
    this.branchId,
    this.branch,
    this.draft = const BranchDraft(),
    this.errors = const <String, String>{},
    this.errorMessage,
    this.isDirty = false,
  });
  final CafeConfigurationLoadStatus status;
  final int? branchId;
  final CafeConfigurationBranch? branch;
  final BranchDraft draft;
  final Map<String, String> errors;
  final String? errorMessage;
  final bool isDirty;
  bool get isEdit => branchId != null;
  BranchEditorState copyWith({
    CafeConfigurationLoadStatus? status,
    CafeConfigurationBranch? branch,
    BranchDraft? draft,
    Map<String, String>? errors,
    String? errorMessage,
    bool? isDirty,
    bool clearMessages = false,
  }) => BranchEditorState(
    status: status ?? this.status,
    branchId: branchId,
    branch: branch ?? this.branch,
    draft: draft ?? this.draft,
    errors: clearMessages ? const <String, String>{} : errors ?? this.errors,
    errorMessage: clearMessages ? null : errorMessage ?? this.errorMessage,
    isDirty: isDirty ?? this.isDirty,
  );
  @override
  List<Object?> get props => <Object?>[
    status,
    branchId,
    branch?.id,
    branch?.currency,
    branch?.isActive,
    draft.name,
    draft.address,
    draft.phone,
    draft.timezone,
    errors,
    errorMessage,
    isDirty,
  ];
}

class BranchEditorCubit extends Cubit<BranchEditorState> {
  BranchEditorCubit(this._repository, {this.branchId})
    : super(BranchEditorState(branchId: branchId));
  final CafeConfigurationRepository _repository;
  final int? branchId;
  Future<void> initialize({String timezone = 'UTC'}) async {
    if (branchId == null) {
      emit(const BranchEditorState());
      try {
        final CafeProfile profile = await _repository.getProfile();
        emit(
          BranchEditorState(
            status: CafeConfigurationLoadStatus.ready,
            draft: BranchDraft(timezone: profile.timezone),
          ),
        );
      } catch (_) {
        emit(
          BranchEditorState(
            status: CafeConfigurationLoadStatus.ready,
            draft: BranchDraft(timezone: timezone),
          ),
        );
      }
      return;
    }
    emit(BranchEditorState(branchId: branchId));
    try {
      final CafeConfigurationBranch branch = await _repository.getBranch(
        branchId!,
      );
      emit(
        BranchEditorState(
          status: CafeConfigurationLoadStatus.ready,
          branchId: branchId,
          branch: branch,
          draft: BranchDraft.fromBranch(branch),
        ),
      );
    } catch (_) {
      emit(
        state.copyWith(
          status: CafeConfigurationLoadStatus.failure,
          errorMessage: 'load',
        ),
      );
    }
  }

  void update(BranchDraft draft) => emit(
    state.copyWith(
      draft: draft,
      isDirty: _differentBranch(draft, state.branch),
      clearMessages: true,
    ),
  );
  void reset() {
    final CafeConfigurationBranch? branch = state.branch;
    if (branch != null) {
      emit(
        state.copyWith(
          draft: BranchDraft.fromBranch(branch),
          isDirty: false,
          clearMessages: true,
        ),
      );
    }
  }

  Future<void> save() async {
    if (state.status == CafeConfigurationLoadStatus.submitting ||
        (state.isEdit && !state.isDirty)) {
      return;
    }
    final Map<String, String> errors = _validate(state.draft);
    if (errors.isNotEmpty) {
      emit(
        state.copyWith(
          status: CafeConfigurationLoadStatus.failure,
          errors: errors,
        ),
      );
      return;
    }
    emit(
      state.copyWith(
        status: CafeConfigurationLoadStatus.submitting,
        clearMessages: true,
      ),
    );
    try {
      final CafeConfigurationBranch saved = state.isEdit
          ? await _repository.updateBranch(branchId!, state.draft)
          : await _repository.createBranch(state.draft);
      emit(
        BranchEditorState(
          status: CafeConfigurationLoadStatus.success,
          branchId: branchId,
          branch: saved,
          draft: BranchDraft.fromBranch(saved),
        ),
      );
    } catch (e) {
      emit(
        state.copyWith(
          status: CafeConfigurationLoadStatus.failure,
          errors: _fields(e),
          errorMessage: 'save',
        ),
      );
    }
  }

  Map<String, String> _validate(BranchDraft d) {
    final Map<String, String> e = <String, String>{};
    if (d.name.trim().isEmpty) e['name'] = 'required';
    if (d.timezone.trim().isEmpty) e['timezone'] = 'required';
    return e;
  }
}

bool _different(CafeProfileDraft draft, CafeProfile? profile) =>
    profile == null ||
    draft.name.trim() != profile.name ||
    draft.email.trim() != (profile.email ?? '') ||
    draft.phone.trim() != (profile.phone ?? '') ||
    draft.timezone != profile.timezone;
bool _differentBranch(BranchDraft draft, CafeConfigurationBranch? branch) =>
    branch == null ||
    draft.name.trim() != branch.name ||
    draft.address.trim() != (branch.address ?? '') ||
    draft.phone.trim() != (branch.phone ?? '') ||
    draft.timezone != branch.timezone;
Map<String, String> _fields(Object e) => e is ApiException
    ? <String, String>{
        for (final MapEntry<String, List<String>> entry
            in (e.validationErrors ?? const <String, List<String>>{}).entries)
          entry.key: entry.value.first,
      }
    : const <String, String>{};

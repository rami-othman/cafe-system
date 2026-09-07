import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/network/api_exception.dart';
import '../models/cafe_configuration_models.dart';
import '../repositories/cafe_configuration_repository.dart';

enum TeamLoadStatus { loading, ready, failure, mutating, success }

class TeamState extends Equatable {
  const TeamState({
    this.status = TeamLoadStatus.loading,
    this.members = const <TeamMember>[],
    this.roles = const <TenantRole>[],
    this.branches = const <CafeConfigurationBranch>[],
    this.currentPage = 1,
    this.lastPage = 1,
    this.perPage = 20,
    this.total = 0,
    this.search = '',
    this.roleFilter,
    this.statusFilter,
    this.branchFilter,
    this.errors = const <String, String>{},
    this.errorMessage,
  });

  final TeamLoadStatus status;
  final List<TeamMember> members;
  final List<TenantRole> roles;
  final List<CafeConfigurationBranch> branches;
  final int currentPage;
  final int lastPage;
  final int perPage;
  final int total;
  final String search;
  final String? roleFilter;
  final String? statusFilter;
  final int? branchFilter;
  final Map<String, String> errors;
  final String? errorMessage;

  TeamState copyWith({
    TeamLoadStatus? status,
    List<TeamMember>? members,
    List<TenantRole>? roles,
    List<CafeConfigurationBranch>? branches,
    int? currentPage,
    int? lastPage,
    int? perPage,
    int? total,
    String? search,
    String? roleFilter,
    String? statusFilter,
    int? branchFilter,
    Map<String, String>? errors,
    String? errorMessage,
    bool clearRoleFilter = false,
    bool clearStatusFilter = false,
    bool clearBranchFilter = false,
    bool clearMessages = false,
  }) => TeamState(
    status: status ?? this.status,
    members: members ?? this.members,
    roles: roles ?? this.roles,
    branches: branches ?? this.branches,
    currentPage: currentPage ?? this.currentPage,
    lastPage: lastPage ?? this.lastPage,
    perPage: perPage ?? this.perPage,
    total: total ?? this.total,
    search: search ?? this.search,
    roleFilter: clearRoleFilter ? null : roleFilter ?? this.roleFilter,
    statusFilter: clearStatusFilter ? null : statusFilter ?? this.statusFilter,
    branchFilter: clearBranchFilter ? null : branchFilter ?? this.branchFilter,
    errors: clearMessages ? const <String, String>{} : errors ?? this.errors,
    errorMessage: clearMessages ? null : errorMessage ?? this.errorMessage,
  );

  @override
  List<Object?> get props => <Object?>[
    status,
    members,
    roles,
    branches,
    currentPage,
    lastPage,
    perPage,
    total,
    search,
    roleFilter,
    statusFilter,
    branchFilter,
    errors,
    errorMessage,
  ];
}

class TeamCubit extends Cubit<TeamState> {
  TeamCubit(this._repository) : super(const TeamState());
  final CafeConfigurationRepository _repository;

  Future<void> load({int page = 1}) async {
    if (isClosed) return;
    emit(state.copyWith(status: TeamLoadStatus.loading, clearMessages: true));
    try {
      final (List<TenantRole>, List<CafeConfigurationBranch>, TeamPage) values =
          await (
            _repository.getRoles(),
            _repository.getBranches(),
            _repository.getEmployees(
              page: page,
              perPage: state.perPage,
              search: state.search,
              role: state.roleFilter,
              status: state.statusFilter,
              branchId: state.branchFilter,
            ),
          ).wait;
      if (isClosed) return;
      emit(
        state.copyWith(
          status: TeamLoadStatus.ready,
          roles: values.$1,
          branches: values.$2,
          members: values.$3.members,
          currentPage: values.$3.currentPage,
          lastPage: values.$3.lastPage,
          perPage: values.$3.perPage,
          total: values.$3.total,
        ),
      );
    } catch (_) {
      if (isClosed) return;
      emit(
        state.copyWith(status: TeamLoadStatus.failure, errorMessage: 'load'),
      );
    }
  }

  Future<void> setFilters({
    String? search,
    String? role,
    String? status,
    int? branchId,
    bool clearRole = false,
    bool clearStatus = false,
    bool clearBranch = false,
  }) async {
    if (isClosed) return;
    emit(
      state.copyWith(
        search: search,
        roleFilter: role,
        statusFilter: status,
        branchFilter: branchId,
        clearRoleFilter: clearRole,
        clearStatusFilter: clearStatus,
        clearBranchFilter: clearBranch,
        clearMessages: true,
      ),
    );
    await load();
  }

  Future<TeamMember?> create(TeamMemberDraft draft) =>
      _mutate(() => _repository.createEmployee(draft), draft: draft);

  Future<TeamMember?> update(
    int id,
    TeamMemberDraft draft, {
    required bool includePassword,
  }) => _mutate(
    () =>
        _repository.updateEmployee(id, draft, includePassword: includePassword),
    draft: draft,
    requirePassword: includePassword,
  );

  Future<TeamMember?> resetPassword(int id, String password, int minimum) {
    final Map<String, String> validation = _passwordErrors(
      password,
      password,
      minimum,
    );
    if (validation.isNotEmpty) {
      emit(state.copyWith(status: TeamLoadStatus.failure, errors: validation));
      return Future<TeamMember?>.value(null);
    }
    return _mutate(() => _repository.resetEmployeePassword(id, password));
  }

  Future<TeamMember?> activate(int id) =>
      _mutate(() => _repository.activateEmployee(id));
  Future<TeamMember?> deactivate(int id) =>
      _mutate(() => _repository.deactivateEmployee(id));
  Future<TeamMember?> archive(int id) =>
      _mutate(() => _repository.archiveEmployee(id));

  Future<TeamMember?> _mutate(
    Future<TeamMember> Function() action, {
    TeamMemberDraft? draft,
    bool requirePassword = true,
  }) async {
    if (state.status == TeamLoadStatus.mutating) return null;
    if (draft != null) {
      final Map<String, String> validation = _draftErrors(
        draft,
        requirePassword: requirePassword,
      );
      if (validation.isNotEmpty) {
        emit(
          state.copyWith(status: TeamLoadStatus.failure, errors: validation),
        );
        return null;
      }
    }
    emit(state.copyWith(status: TeamLoadStatus.mutating, clearMessages: true));
    try {
      final TeamMember member = await action();
      await load(page: state.currentPage);
      if (isClosed) return member;
      emit(state.copyWith(status: TeamLoadStatus.success));
      return member;
    } catch (error) {
      if (isClosed) return null;
      emit(
        state.copyWith(
          status: TeamLoadStatus.failure,
          errors: _fieldErrors(error),
          errorMessage: 'mutation',
        ),
      );
      return null;
    }
  }

  Map<String, String> _draftErrors(
    TeamMemberDraft draft, {
    required bool requirePassword,
  }) {
    final Map<String, String> errors = <String, String>{};
    if (draft.name.trim().isEmpty) errors['name'] = 'required';
    if (!_email(draft.email)) errors['email'] = 'invalidEmail';
    if (!draft.isManager && draft.username.trim().isEmpty) {
      errors['username'] = 'required';
    }
    if (draft.roleId <= 0) errors['roleId'] = 'required';
    if (draft.branchIds.isEmpty) errors['branchIds'] = 'required';
    if (requirePassword) {
      errors.addAll(
        _passwordErrors(
          draft.temporaryPassword,
          draft.temporaryPasswordConfirmation,
          draft.passwordMinimum,
        ),
      );
    }
    return errors;
  }

  Map<String, String> _passwordErrors(
    String password,
    String confirmation,
    int min,
  ) {
    final Map<String, String> errors = <String, String>{};
    if (password.length < min) errors['temporaryPassword'] = 'passwordMinimum';
    if (password != confirmation) {
      errors['temporaryPassword_confirmation'] = 'passwordMismatch';
    }
    return errors;
  }
}

bool _email(String value) =>
    RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(value.trim());

Map<String, String> _fieldErrors(Object error) => error is ApiException
    ? <String, String>{
        for (final MapEntry<String, List<String>> entry
            in (error.validationErrors ?? const <String, List<String>>{})
                .entries)
          entry.key: entry.value.first,
      }
    : const <String, String>{};

import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';

import '../models/customer_failure.dart';
import '../models/customer_group_models.dart';
import '../models/customer_models.dart';
import '../models/customer_queries.dart';
import '../repositories/customer_management_repository.dart';
import 'customer_group_detail_state.dart';

class CustomerGroupDetailCubit extends Cubit<CustomerGroupDetailState> {
  CustomerGroupDetailCubit(this._repository, {CustomerGroup? initialGroup})
    : super(CustomerGroupDetailState(group: initialGroup));

  final CustomerManagementRepository _repository;
  Timer? _debounce;
  int _generation = 0;
  Future<void>? _mutation;

  Future<void> load(int groupId) async {
    if (groupId <= 0) return;
    final int generation = ++_generation;
    final bool sameGroup = state.groupId == groupId;
    emit(
      CustomerGroupDetailState(
        status: CustomerGroupDetailStatus.loading,
        groupId: groupId,
        group: sameGroup ? state.group : null,
        members: sameGroup ? state.members : null,
        memberQuery: sameGroup
            ? state.memberQuery
            : const CustomerGroupListQuery(),
        memberFailure: null,
      ),
    );
    try {
      final results = await Future.wait<dynamic>(<Future<dynamic>>[
        _repository.getGroup(groupId),
        _repository.listGroupMembers(groupId, state.memberQuery),
      ]);
      if (isClosed || generation != _generation) return;
      final CustomerGroup group = results[0] as CustomerGroup;
      final CustomerPage<Customer> members =
          results[1] as CustomerPage<Customer>;
      emit(
        CustomerGroupDetailState(
          status: CustomerGroupDetailStatus.success,
          groupId: groupId,
          group: group,
          members: members,
          memberQuery: state.memberQuery,
        ),
      );
    } catch (error) {
      if (isClosed || generation != _generation) return;
      emit(
        CustomerGroupDetailState(
          status: CustomerGroupDetailStatus.failure,
          groupId: groupId,
          group: sameGroup ? state.group : null,
          members: sameGroup ? state.members : null,
          memberQuery: state.memberQuery,
          failure: CustomerFailure.fromError(error),
        ),
      );
    }
  }

  Future<void> loadMembers({CustomerGroupListQuery? query}) async {
    final int? groupId = state.groupId;
    if (groupId == null) return;
    final CustomerGroupListQuery requested = query ?? state.memberQuery;
    final int generation = ++_generation;
    emit(
      state.copyWith(
        memberQuery: requested,
        status: CustomerGroupDetailStatus.loading,
        clearFailure: true,
        clearMemberFailure: true,
      ),
    );
    try {
      final CustomerPage<Customer> members = await _repository.listGroupMembers(
        groupId,
        requested,
      );
      if (isClosed || generation != _generation) return;
      emit(
        state.copyWith(
          status: CustomerGroupDetailStatus.success,
          members: members,
          memberQuery: requested,
          clearFailure: true,
          clearMemberFailure: true,
        ),
      );
    } catch (error) {
      if (isClosed || generation != _generation) return;
      emit(
        state.copyWith(
          status: CustomerGroupDetailStatus.failure,
          memberQuery: requested,
          memberFailure: CustomerFailure.fromError(error),
        ),
      );
    }
  }

  void memberSearchChanged(String value) {
    _debounce?.cancel();
    final CustomerGroupListQuery query = state.memberQuery.copyWith(
      search: value,
      page: 1,
    );
    if (value.isEmpty && state.memberQuery.search.isNotEmpty) {
      unawaited(loadMembers(query: query));
      return;
    }
    _debounce = Timer(
      const Duration(milliseconds: 300),
      () => unawaited(loadMembers(query: query)),
    );
  }

  void submitMemberSearch(String value) {
    _debounce?.cancel();
    unawaited(
      loadMembers(query: state.memberQuery.copyWith(search: value, page: 1)),
    );
  }

  void setMemberPage(int page) {
    if (page > 0) {
      unawaited(loadMembers(query: state.memberQuery.copyWith(page: page)));
    }
  }

  Future<void> refresh() =>
      state.groupId == null ? Future<void>.value() : load(state.groupId!);

  void replaceGroup(CustomerGroup group) {
    if (!isClosed && (state.groupId == null || state.groupId == group.id)) {
      emit(
        state.copyWith(
          group: group,
          status: CustomerGroupDetailStatus.success,
          clearFailure: true,
          clearMemberFailure: true,
        ),
      );
    }
  }

  Future<void> changeLifecycle(String action) {
    if (isClosed) return Future<void>.value();
    final CustomerGroup? group = state.group;
    if (group == null || state.isMutating) return Future<void>.value();
    if (action == 'archive' && group.lifecycle == CustomerLifecycle.archived ||
        action == 'restore' && group.lifecycle != CustomerLifecycle.archived) {
      emit(
        state.copyWith(
          failure: const CustomerFailure(
            code: 'CUSTOMER_GROUP_INVALID_TRANSITION',
            kind: CustomerFailureKind.conflict,
          ),
        ),
      );
      return Future<void>.value();
    }
    final Future<void> request = _changeLifecycle(group, action);
    _mutation = request;
    return request.whenComplete(() {
      if (identical(_mutation, request)) _mutation = null;
    });
  }

  Future<void> _changeLifecycle(CustomerGroup oldGroup, String action) async {
    emit(
      state.copyWith(
        isMutating: true,
        mutationAction: action,
        clearFailure: true,
      ),
    );
    try {
      final CustomerGroup updated = await _repository.changeGroupLifecycle(
        oldGroup.id,
        action,
      );
      if (isClosed) return;
      emit(
        state.copyWith(
          group: updated,
          isMutating: false,
          clearMutationAction: true,
          clearFailure: true,
        ),
      );
    } catch (error) {
      if (isClosed) return;
      emit(
        state.copyWith(
          isMutating: false,
          clearMutationAction: true,
          failure: CustomerFailure.fromError(error),
        ),
      );
    }
  }

  @override
  Future<void> close() {
    _generation++;
    _debounce?.cancel();
    _mutation = null;
    return super.close();
  }
}

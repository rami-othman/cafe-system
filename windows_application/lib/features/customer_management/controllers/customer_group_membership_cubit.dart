import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';

import '../models/customer_failure.dart';
import '../models/customer_queries.dart';
import '../repositories/customer_management_repository.dart';
import 'customer_group_membership_state.dart';

class CustomerGroupMembershipCubit extends Cubit<CustomerGroupMembershipState> {
  CustomerGroupMembershipCubit(
    this._repository, {
    required int groupId,
    this.onChanged,
  }) : super(CustomerGroupMembershipState(groupId: groupId));

  final CustomerManagementRepository _repository;
  final Future<void> Function()? onChanged;
  Timer? _debounce;
  int _generation = 0;
  Future<void>? _mutation;

  Future<void> loadCandidates({CustomerGroupListQuery? query}) async {
    final CustomerGroupListQuery requested = query ?? state.query;
    final int generation = ++_generation;
    emit(
      state.copyWith(
        status: CustomerGroupMembershipStatus.loading,
        query: requested,
        clearFailure: true,
      ),
    );
    try {
      final page = await _repository.listEligibleMembers(
        state.groupId,
        requested,
      );
      if (isClosed || generation != _generation) return;
      final selected = state.selectedCustomerIds;
      emit(
        state.copyWith(
          status: CustomerGroupMembershipStatus.success,
          candidates: page,
          query: requested,
          selectedCustomerIds: selected,
          clearFailure: true,
        ),
      );
    } catch (error) {
      if (!isClosed && generation == _generation) {
        emit(
          state.copyWith(
            status: CustomerGroupMembershipStatus.failure,
            query: requested,
            failure: CustomerFailure.fromError(error),
          ),
        );
      }
    }
  }

  void candidateSearchChanged(String value) {
    _debounce?.cancel();
    final query = state.query.copyWith(search: value, page: 1);
    if (value.isEmpty && state.query.search.isNotEmpty) {
      unawaited(loadCandidates(query: query));
      return;
    }
    _debounce = Timer(
      const Duration(milliseconds: 300),
      () => unawaited(loadCandidates(query: query)),
    );
  }

  void submitCandidateSearch(String value) {
    _debounce?.cancel();
    unawaited(
      loadCandidates(query: state.query.copyWith(search: value, page: 1)),
    );
  }

  void setCandidatePage(int page) {
    if (page > 0) {
      unawaited(loadCandidates(query: state.query.copyWith(page: page)));
    }
  }

  void toggleSelected(int customerId) {
    if (isClosed || state.isMutating) return;
    final Set<int> selected = Set<int>.from(state.selectedCustomerIds);
    if (!selected.add(customerId)) selected.remove(customerId);
    emit(state.copyWith(selectedCustomerIds: selected));
  }

  void clearSelection() {
    if (isClosed) return;
    emit(state.copyWith(selectedCustomerIds: <int>{}));
  }

  Future<void> addSelected() {
    if (state.selectedCustomerIds.isEmpty || _mutation != null) {
      return Future<void>.value();
    }
    final Future<void> request = _addSelected();
    _mutation = request;
    return request.whenComplete(() {
      if (identical(_mutation, request)) _mutation = null;
    });
  }

  Future<void> _addSelected() async {
    final Set<int> selected = Set<int>.from(state.selectedCustomerIds);
    emit(
      state.copyWith(
        status: CustomerGroupMembershipStatus.mutating,
        clearFailure: true,
      ),
    );
    try {
      await _repository.addGroupMembers(state.groupId, selected);
      if (isClosed) return;
      emit(
        state.copyWith(
          status: CustomerGroupMembershipStatus.success,
          selectedCustomerIds: <int>{},
          clearFailure: true,
        ),
      );
      await onChanged?.call();
    } catch (error) {
      if (!isClosed) {
        emit(
          state.copyWith(
            status: CustomerGroupMembershipStatus.failure,
            selectedCustomerIds: selected,
            failure: CustomerFailure.fromError(error),
          ),
        );
      }
    }
  }

  Future<void> remove(int customerId) {
    if (_mutation != null) return Future<void>.value();
    final Future<void> request = _remove(customerId);
    _mutation = request;
    return request.whenComplete(() {
      if (identical(_mutation, request)) _mutation = null;
    });
  }

  Future<void> _remove(int customerId) async {
    emit(
      state.copyWith(
        status: CustomerGroupMembershipStatus.mutating,
        clearFailure: true,
      ),
    );
    try {
      await _repository.removeGroupMember(state.groupId, customerId);
      if (isClosed) return;
      emit(
        state.copyWith(
          status: CustomerGroupMembershipStatus.success,
          clearFailure: true,
        ),
      );
      await onChanged?.call();
    } catch (error) {
      if (!isClosed) {
        emit(
          state.copyWith(
            status: CustomerGroupMembershipStatus.failure,
            failure: CustomerFailure.fromError(error),
          ),
        );
      }
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

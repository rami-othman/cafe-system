import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';

import '../models/customer_failure.dart';
import '../models/customer_models.dart';
import '../models/customer_queries.dart';
import '../models/customer_group_models.dart';
import '../repositories/customer_management_repository.dart';
import 'customer_list_state.dart';

class CustomerListCubit extends Cubit<CustomerListState> {
  CustomerListCubit(this._repository) : super(const CustomerListState());

  final CustomerManagementRepository _repository;
  Timer? _debounce;
  int _generation = 0;
  CustomerListQuery? _inFlightQuery;
  Future<void>? _inFlightLoad;

  Future<void> load({CustomerListQuery? query}) {
    final CustomerListQuery requested = query ?? state.query;
    if (_inFlightQuery == requested && _inFlightLoad != null) {
      return _inFlightLoad!;
    }
    final Future<void> request = _load(requested);
    _inFlightQuery = requested;
    _inFlightLoad = request;
    return request.whenComplete(() {
      if (identical(_inFlightLoad, request)) {
        _inFlightLoad = null;
        _inFlightQuery = null;
      }
    });
  }

  Future<void> _load(CustomerListQuery requested) async {
    final int generation = ++_generation;
    emit(
      state.copyWith(
        status: CustomerListStatus.loading,
        query: requested,
        clearFailure: true,
      ),
    );
    try {
      final page = await _repository.listCustomers(requested);
      if (isClosed || generation != _generation) return;
      emit(
        state.copyWith(
          status: CustomerListStatus.success,
          query: requested,
          page: page,
          clearFailure: true,
        ),
      );
    } catch (error) {
      if (isClosed || generation != _generation) return;
      emit(
        state.copyWith(
          status: CustomerListStatus.failure,
          query: requested,
          failure: CustomerFailure.fromError(error),
        ),
      );
    }
  }

  void searchChanged(String value) {
    _debounce?.cancel();
    final query = state.query.copyWith(search: value, page: 1);
    if (value.isEmpty && state.query.search.isNotEmpty) {
      unawaited(load(query: query));
      return;
    }
    _debounce = Timer(
      const Duration(milliseconds: 300),
      () => unawaited(load(query: query)),
    );
  }

  void submitSearch(String value) {
    _debounce?.cancel();
    unawaited(load(query: state.query.copyWith(search: value, page: 1)));
  }

  void setStatus(CustomerStatusFilter? status) => unawaited(
    load(
      query: state.query.copyWith(
        status: status,
        page: 1,
        clearStatus: status == null,
      ),
    ),
  );

  void setGroup(int? groupId) => unawaited(
    load(
      query: state.query.copyWith(
        groupId: groupId,
        page: 1,
        clearGroup: groupId == null,
      ),
    ),
  );

  void setPage(int page) {
    if (page > 0) unawaited(load(query: state.query.copyWith(page: page)));
  }

  void clearFilters() => unawaited(load(query: const CustomerListQuery()));

  Future<void> refresh() => load();

  Future<void> loadGroupOptions() async {
    try {
      final CustomerPage<CustomerGroup> page = await _repository.listGroups(
        const CustomerGroupListQuery(perPage: 25),
      );
      if (!isClosed) emit(state.copyWith(groupOptions: page.items));
    } catch (_) {
      // A filter-option lookup must not disguise a customer-list result.
    }
  }

  @override
  Future<void> close() {
    _generation++;
    _debounce?.cancel();
    _inFlightLoad = null;
    _inFlightQuery = null;
    return super.close();
  }
}

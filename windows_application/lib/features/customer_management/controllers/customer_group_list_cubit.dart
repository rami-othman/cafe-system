import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';

import '../models/customer_failure.dart';
import '../models/customer_queries.dart';
import '../repositories/customer_management_repository.dart';
import 'customer_group_list_state.dart';

class CustomerGroupListCubit extends Cubit<CustomerGroupListState> {
  CustomerGroupListCubit(this._repository)
    : super(const CustomerGroupListState());

  final CustomerManagementRepository _repository;
  Timer? _debounce;
  int _generation = 0;
  CustomerGroupListQuery? _inFlightQuery;
  Future<void>? _inFlightLoad;

  Future<void> load({CustomerGroupListQuery? query}) {
    final CustomerGroupListQuery requested = query ?? state.query;
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

  Future<void> _load(CustomerGroupListQuery requested) async {
    final int generation = ++_generation;
    emit(
      state.copyWith(
        status: CustomerGroupListStatus.loading,
        query: requested,
        clearFailure: true,
      ),
    );
    try {
      final page = await _repository.listGroups(requested);
      if (isClosed || generation != _generation) return;
      emit(
        state.copyWith(
          status: CustomerGroupListStatus.success,
          query: requested,
          page: page,
          clearFailure: true,
        ),
      );
    } catch (error) {
      if (isClosed || generation != _generation) return;
      emit(
        state.copyWith(
          status: CustomerGroupListStatus.failure,
          query: requested,
          failure: CustomerFailure.fromError(error),
        ),
      );
    }
  }

  void searchChanged(String value) {
    _debounce?.cancel();
    final CustomerGroupListQuery query = state.query.copyWith(
      search: value,
      page: 1,
    );
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

  void setPage(int page) {
    if (page > 0) unawaited(load(query: state.query.copyWith(page: page)));
  }

  void clearFilters() => unawaited(load(query: const CustomerGroupListQuery()));

  Future<void> refresh() => load();

  @override
  Future<void> close() {
    _generation++;
    _debounce?.cancel();
    _inFlightLoad = null;
    _inFlightQuery = null;
    return super.close();
  }
}

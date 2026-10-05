import 'package:flutter_bloc/flutter_bloc.dart';
import '../models/customer_failure.dart';
import '../models/customer_models.dart';
import '../models/customer_queries.dart';
import '../repositories/customer_management_repository.dart';
import 'customer_order_history_state.dart';

class CustomerOrderHistoryCubit extends Cubit<CustomerOrderHistoryState> {
  CustomerOrderHistoryCubit(this._repository)
    : super(const CustomerOrderHistoryState());

  final CustomerManagementRepository _repository;
  int _generation = 0;

  Future<void> load(int customerId, {CustomerOrderQuery? query}) async {
    final int generation = ++_generation;
    final CustomerOrderQuery next = query ?? state.query;
    emit(
      CustomerOrderHistoryState(
        status: CustomerOrderHistoryStatus.loading,
        customer: state.customer,
        page: state.page,
        branches: state.branches,
        query: next,
      ),
    );
    Customer? customer = state.customer;
    List<CustomerOrderBranch> branches = state.branches;
    try {
      customer = await _repository.getCustomer(customerId);
      branches = await _repository.listPermittedOrderBranches();
      final CustomerPage<CustomerOrder> page = await _repository
          .listCustomerOrders(customerId, next);
      if (isClosed || generation != _generation) return;
      emit(
        CustomerOrderHistoryState(
          status: CustomerOrderHistoryStatus.success,
          customer: customer,
          page: page,
          branches: branches,
          query: next,
        ),
      );
    } catch (error) {
      if (isClosed || generation != _generation) return;
      emit(
        CustomerOrderHistoryState(
          status: CustomerOrderHistoryStatus.failure,
          customer: customer,
          page: state.page,
          branches: branches,
          query: next,
          failure: CustomerFailure.fromError(error),
        ),
      );
    }
  }

  Future<void> apply(CustomerOrderQuery query) => state.customer == null
      ? Future<void>.value()
      : load(state.customer!.id, query: query);

  Future<void> retry() => state.customer == null
      ? Future<void>.value()
      : load(state.customer!.id, query: state.query);

  @override
  Future<void> close() {
    _generation++;
    return super.close();
  }
}

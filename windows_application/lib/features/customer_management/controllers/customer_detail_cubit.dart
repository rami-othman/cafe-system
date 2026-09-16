import 'package:flutter_bloc/flutter_bloc.dart';

import '../models/customer_failure.dart';
import '../models/customer_models.dart';
import '../repositories/customer_management_repository.dart';
import 'customer_detail_state.dart';

class CustomerDetailCubit extends Cubit<CustomerDetailState> {
  CustomerDetailCubit(this._repository) : super(const CustomerDetailState());

  final CustomerManagementRepository _repository;
  int _generation = 0;

  Future<void> load(int customerId) async {
    if (customerId <= 0) return;
    final int generation = ++_generation;
    emit(
      CustomerDetailState(
        status: CustomerDetailStatus.loading,
        customerId: customerId,
        customer: customerId == state.customerId ? state.customer : null,
        overview: customerId == state.customerId ? state.overview : null,
      ),
    );
    try {
      final CustomerOverview overview = await _repository.getCustomerOverview(
        customerId,
      );
      if (isClosed || generation != _generation) return;
      emit(
        CustomerDetailState(
          status: CustomerDetailStatus.success,
          customerId: customerId,
          customer: overview.customer,
          overview: overview,
        ),
      );
    } catch (error) {
      if (isClosed || generation != _generation) return;
      emit(
        CustomerDetailState(
          status: CustomerDetailStatus.failure,
          customerId: customerId,
          customer: customerId == state.customerId ? state.customer : null,
          overview: customerId == state.customerId ? state.overview : null,
          failure: CustomerFailure.fromError(error),
        ),
      );
    }
  }

  Future<void> refresh() {
    final int? id = state.customerId;
    return id == null ? Future<void>.value() : load(id);
  }

  void replace(Customer customer) {
    if (isClosed) return;
    emit(
      CustomerDetailState(
        status: CustomerDetailStatus.success,
        customerId: customer.id,
        customer: customer,
      ),
    );
  }

  @override
  Future<void> close() {
    _generation++;
    return super.close();
  }
}

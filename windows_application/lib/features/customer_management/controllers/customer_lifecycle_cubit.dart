import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';

import '../models/customer_failure.dart';
import '../models/customer_models.dart';
import '../repositories/customer_management_repository.dart';
import 'customer_lifecycle_state.dart';

class CustomerLifecycleCubit extends Cubit<CustomerLifecycleState> {
  CustomerLifecycleCubit(
    this._repository, {
    required Customer initialCustomer,
    this.onCustomerReplaced,
    this.onCollectionsRefresh,
  }) : super(CustomerLifecycleState(customer: initialCustomer));

  final CustomerManagementRepository _repository;
  final Future<void> Function(Customer customer)? onCustomerReplaced;
  final Future<void> Function()? onCollectionsRefresh;
  Future<void>? _request;

  Future<void> perform(String action) {
    final Future<void>? current = _request;
    if (current != null) return current;

    final CustomerFailure? invalid = _invalidAction(action);
    if (invalid != null) {
      emit(
        state.copyWith(
          status: CustomerLifecycleStatus.failure,
          action: action,
          failure: invalid,
        ),
      );
      return Future<void>.value();
    }

    final Future<void> request = _perform(action);
    _request = request;
    return request.whenComplete(() {
      if (identical(_request, request)) _request = null;
    });
  }

  Future<void> _perform(String action) async {
    emit(
      state.copyWith(
        status: CustomerLifecycleStatus.submitting,
        action: action,
        clearFailure: true,
      ),
    );
    try {
      final Customer saved = await _repository.changeCustomerLifecycle(
        state.customer.id,
        action,
      );
      if (isClosed) return;
      emit(
        state.copyWith(
          customer: saved,
          status: CustomerLifecycleStatus.success,
          action: action,
          clearFailure: true,
        ),
      );
      await onCustomerReplaced?.call(saved);
      await onCollectionsRefresh?.call();
    } catch (error) {
      if (isClosed) return;
      emit(
        state.copyWith(
          status: CustomerLifecycleStatus.failure,
          action: action,
          failure: CustomerFailure.fromError(error),
        ),
      );
    }
  }

  void replaceCustomer(Customer customer) {
    if (isClosed) return;
    emit(CustomerLifecycleState(customer: customer));
  }

  CustomerFailure? _invalidAction(String action) {
    final Set<String> validForLifecycle = switch (state.customer.lifecycle) {
      CustomerLifecycle.active => <String>{'deactivate', 'archive'},
      CustomerLifecycle.inactive => <String>{'activate', 'archive'},
      CustomerLifecycle.archived => <String>{'restore'},
    };
    if (!validForLifecycle.contains(action)) {
      return const CustomerFailure(
        kind: CustomerFailureKind.validation,
        code: 'CUSTOMER_INVALID_TRANSITION',
      );
    }
    if (!state.customer.allowedActions.contains(action)) {
      return const CustomerFailure(
        kind: CustomerFailureKind.forbidden,
        code: 'CUSTOMER_PERMISSION_DENIED',
      );
    }
    return null;
  }

  @override
  Future<void> close() {
    _request = null;
    return super.close();
  }
}

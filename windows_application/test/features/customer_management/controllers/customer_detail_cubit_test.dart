import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:windows_application/core/network/api_exception.dart';
import 'package:windows_application/features/customer_management/controllers/customer_detail_cubit.dart';
import 'package:windows_application/features/customer_management/controllers/customer_detail_state.dart';
import 'package:windows_application/features/customer_management/models/customer_failure.dart';
import 'package:windows_application/features/customer_management/models/customer_models.dart';
import 'package:windows_application/features/customer_management/repositories/customer_management_repository.dart';

void main() {
  test(
    'retains the current entity while a direct-detail refresh is loading',
    () async {
      final _DetailRepository repository = _DetailRepository();
      final CustomerDetailCubit cubit = CustomerDetailCubit(repository);
      final Future<void> initial = cubit.load(3);
      repository.complete(3);
      await initial;

      final Future<void> refresh = cubit.refresh();

      expect(cubit.state.status, CustomerDetailStatus.loading);
      expect(cubit.state.customer?.id, 3);
      repository.complete(3);
      await refresh;
      await cubit.close();
    },
  );

  test('retains the entity when a refresh fails and allows a retry', () async {
    final _DetailRepository repository = _DetailRepository();
    final CustomerDetailCubit cubit = CustomerDetailCubit(repository);
    final Future<void> initial = cubit.load(3);
    repository.complete(3);
    await initial;

    final Future<void> refresh = cubit.refresh();
    repository.fail(StateError('network'));
    await refresh;

    expect(cubit.state.status, CustomerDetailStatus.failure);
    expect(cubit.state.customer?.id, 3);
    final Future<void> retry = cubit.refresh();
    repository.complete(3);
    await retry;
    expect(cubit.state.status, CustomerDetailStatus.success);
    await cubit.close();
  });

  test(
    'loads a direct route ID and ignores a late response for an older ID',
    () async {
      final _DetailRepository repository = _DetailRepository();
      final CustomerDetailCubit cubit = CustomerDetailCubit(repository);

      final Future<void> first = cubit.load(7);
      final Future<void> second = cubit.load(8);
      repository.complete(8);
      await second;
      repository.complete(7);
      await first;

      expect(cubit.state.customerId, 8);
      expect(cubit.state.customer?.id, 8);
      await cubit.close();
    },
  );

  test(
    'maps forbidden and not-found detail responses without retrying them',
    () async {
      final _DetailRepository repository = _DetailRepository();
      final CustomerDetailCubit cubit = CustomerDetailCubit(repository);

      final Future<void> forbidden = cubit.load(9);
      repository.fail(
        const ApiException(
          message: 'forbidden',
          statusCode: 403,
          type: ApiErrorType.forbidden,
        ),
      );
      await forbidden;
      expect(cubit.state.status, CustomerDetailStatus.failure);
      expect(cubit.state.failure?.kind, CustomerFailureKind.forbidden);

      final Future<void> missing = cubit.load(10);
      repository.fail(const ApiException(message: 'missing', statusCode: 404));
      await missing;
      expect(cubit.state.failure?.kind, CustomerFailureKind.notFound);
      await cubit.close();
    },
  );
}

class _DetailRepository implements CustomerManagementRepository {
  final List<_PendingDetail> _pending = <_PendingDetail>[];

  @override
  Future<Customer> getCustomer(int customerId) {
    final Completer<Customer> completer = Completer<Customer>();
    _pending.add(_PendingDetail(customerId, completer));
    return completer.future;
  }

  void complete(int id) {
    final _PendingDetail pending = _pending.firstWhere(
      (_PendingDetail request) => request.id == id,
    );
    _pending.remove(pending);
    pending.completer.complete(
      Customer(
        id: id,
        customerNumber: 'C-$id',
        name: 'Customer',
        lifecycle: CustomerLifecycle.active,
        phones: const <CustomerPhone>[],
        groups: const <CustomerGroupSummary>[],
        allowedActions: const <String>{},
      ),
    );
  }

  void fail(Object error) {
    final _PendingDetail pending = _pending.removeAt(0);
    pending.completer.completeError(error);
  }

  @override
  noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _PendingDetail {
  const _PendingDetail(this.id, this.completer);
  final int id;
  final Completer<Customer> completer;
}

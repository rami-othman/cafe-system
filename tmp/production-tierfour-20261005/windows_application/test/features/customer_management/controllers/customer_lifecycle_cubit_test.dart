import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:windows_application/core/network/api_exception.dart';
import 'package:windows_application/features/customer_management/controllers/customer_lifecycle_cubit.dart';
import 'package:windows_application/features/customer_management/controllers/customer_lifecycle_state.dart';
import 'package:windows_application/features/customer_management/models/customer_failure.dart';
import 'package:windows_application/features/customer_management/models/customer_models.dart';
import 'package:windows_application/features/customer_management/repositories/customer_management_repository.dart';

void main() {
  test(
    'valid lifecycle actions are limited by the returned status contract',
    () async {
      for (final (CustomerLifecycle lifecycle, String action)
          in <(CustomerLifecycle, String)>[
            (CustomerLifecycle.active, 'deactivate'),
            (CustomerLifecycle.active, 'archive'),
            (CustomerLifecycle.inactive, 'activate'),
            (CustomerLifecycle.inactive, 'archive'),
            (CustomerLifecycle.archived, 'restore'),
          ]) {
        final _LifecycleRepository repository = _LifecycleRepository(
          response: _customer(lifecycle: _nextLifecycle(action)),
        );
        final CustomerLifecycleCubit cubit = CustomerLifecycleCubit(
          repository,
          initialCustomer: _customer(lifecycle: lifecycle),
        );

        await cubit.perform(action);

        expect(repository.actions, <String>[action]);
        expect(cubit.state.status, CustomerLifecycleStatus.success);
        expect(cubit.state.customer.lifecycle, _nextLifecycle(action));
        await cubit.close();
      }
    },
  );

  test(
    'keeps the old customer while one mutation is in flight and coalesces repeats',
    () async {
      final _LifecycleRepository repository = _LifecycleRepository(defer: true);
      final CustomerLifecycleCubit cubit = CustomerLifecycleCubit(
        repository,
        initialCustomer: _customer(lifecycle: CustomerLifecycle.active),
      );

      final Future<void> first = cubit.perform('deactivate');
      final Future<void> second = cubit.perform('archive');

      expect(repository.actions, <String>['deactivate']);
      expect(cubit.state.status, CustomerLifecycleStatus.submitting);
      expect(cubit.state.customer.lifecycle, CustomerLifecycle.active);
      repository.complete(_customer(lifecycle: CustomerLifecycle.inactive));
      await Future.wait(<Future<void>>[first, second]);
      expect(cubit.state.customer.lifecycle, CustomerLifecycle.inactive);
      await cubit.close();
    },
  );

  test(
    'success replaces the mounted entity and refreshes affected collections',
    () async {
      final _LifecycleRepository repository = _LifecycleRepository(
        response: _customer(lifecycle: CustomerLifecycle.inactive),
      );
      Customer? mounted;
      int refreshes = 0;
      final CustomerLifecycleCubit cubit = CustomerLifecycleCubit(
        repository,
        initialCustomer: _customer(lifecycle: CustomerLifecycle.active),
        onCustomerReplaced: (Customer customer) async => mounted = customer,
        onCollectionsRefresh: () async => refreshes++,
      );

      await cubit.perform('deactivate');

      expect(mounted?.lifecycle, CustomerLifecycle.inactive);
      expect(refreshes, 1);
      expect(cubit.state.customer.lifecycle, CustomerLifecycle.inactive);
      await cubit.close();
    },
  );

  test(
    'invalid transitions and permission revocation never call the repository',
    () async {
      final _LifecycleRepository repository = _LifecycleRepository();
      final CustomerLifecycleCubit cubit = CustomerLifecycleCubit(
        repository,
        initialCustomer: _customer(
          lifecycle: CustomerLifecycle.active,
          allowedActions: <String>{'deactivate'},
        ),
      );

      await cubit.perform('restore');
      expect(repository.actions, isEmpty);
      expect(cubit.state.failure?.code, 'CUSTOMER_INVALID_TRANSITION');

      cubit.replaceCustomer(
        _customer(
          lifecycle: CustomerLifecycle.active,
          allowedActions: const <String>{},
        ),
      );
      await cubit.perform('deactivate');
      expect(repository.actions, isEmpty);
      expect(cubit.state.failure?.kind, CustomerFailureKind.forbidden);
      expect(cubit.state.customer.lifecycle, CustomerLifecycle.active);
      await cubit.close();
    },
  );

  test(
    'all lifecycle failure classes retain the prior entity and are retry-safe',
    () async {
      final List<(Object, CustomerFailureKind)> failures =
          <(Object, CustomerFailureKind)>[
            (
              const ApiException(
                message: 'validation',
                type: ApiErrorType.validation,
              ),
              CustomerFailureKind.validation,
            ),
            (
              const ApiException(
                message: 'forbidden',
                type: ApiErrorType.forbidden,
              ),
              CustomerFailureKind.forbidden,
            ),
            (
              const ApiException(message: 'missing', statusCode: 404),
              CustomerFailureKind.notFound,
            ),
            (
              const ApiException(
                message: 'conflict',
                type: ApiErrorType.conflict,
              ),
              CustomerFailureKind.conflict,
            ),
            (
              const ApiException(
                message: 'timeout',
                type: ApiErrorType.receiveTimeout,
              ),
              CustomerFailureKind.timeout,
            ),
            (
              const ApiException(
                message: 'offline',
                type: ApiErrorType.networkUnavailable,
              ),
              CustomerFailureKind.network,
            ),
            (
              const ApiException(message: 'server', type: ApiErrorType.server),
              CustomerFailureKind.server,
            ),
          ];

      for (final (Object error, CustomerFailureKind kind) in failures) {
        final _LifecycleRepository repository = _LifecycleRepository(
          error: error,
        );
        final CustomerLifecycleCubit cubit = CustomerLifecycleCubit(
          repository,
          initialCustomer: _customer(lifecycle: CustomerLifecycle.active),
        );

        await cubit.perform('deactivate');

        expect(cubit.state.status, CustomerLifecycleStatus.failure);
        expect(cubit.state.failure?.kind, kind);
        expect(cubit.state.customer.lifecycle, CustomerLifecycle.active);
        await cubit.close();
      }
    },
  );
}

class _LifecycleRepository implements CustomerManagementRepository {
  _LifecycleRepository({this.response, this.error, this.defer = false});

  final Customer? response;
  final Object? error;
  final bool defer;
  final List<String> actions = <String>[];
  final Completer<Customer> _pending = Completer<Customer>();

  @override
  Future<Customer> changeCustomerLifecycle(int customerId, String action) {
    actions.add(action);
    if (error != null) return Future<Customer>.error(error!);
    if (defer) return _pending.future;
    return Future<Customer>.value(
      response ?? _customer(lifecycle: CustomerLifecycle.inactive),
    );
  }

  void complete(Customer customer) => _pending.complete(customer);

  @override
  noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

CustomerLifecycle _nextLifecycle(String action) => switch (action) {
  'activate' => CustomerLifecycle.active,
  'deactivate' => CustomerLifecycle.inactive,
  'archive' => CustomerLifecycle.archived,
  'restore' => CustomerLifecycle.inactive,
  _ => throw ArgumentError(action),
};

Customer _customer({
  required CustomerLifecycle lifecycle,
  Set<String> allowedActions = const <String>{
    'activate',
    'deactivate',
    'archive',
    'restore',
  },
}) => Customer(
  id: 7,
  customerNumber: 'C-000007',
  name: 'Ada Lovelace',
  lifecycle: lifecycle,
  phones: const <CustomerPhone>[],
  groups: const <CustomerGroupSummary>[],
  allowedActions: allowedActions,
);

import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:windows_application/features/pos/controllers/pos_customer_quick_create_cubit.dart';
import 'package:windows_application/features/pos/controllers/pos_customer_quick_create_state.dart';
import 'package:windows_application/features/pos/models/customer.dart';
import 'package:windows_application/features/pos/models/pos_customer_create_result.dart';
import 'package:windows_application/features/pos/models/pos_customer_group.dart';
import 'package:windows_application/features/pos/models/pos_quick_create_customer_request.dart';
import 'package:windows_application/features/pos/repositories/pos_repository.dart';

void main() {
  test('loads authoritative active groups and keeps selection by ID', () async {
    final _GroupsRepository repository = _GroupsRepository(
      groups: const <PosCustomerGroup>[
        PosCustomerGroup(id: 4, name: 'VIP'),
        PosCustomerGroup(id: 9, name: 'Regular'),
      ],
    );
    final PosCustomerQuickCreateCubit cubit = PosCustomerQuickCreateCubit(
      repository: repository,
      onCreate: (_) async => _result(),
    );
    addTearDown(cubit.close);

    await cubit.loadGroups();
    cubit.toggleGroup(9, true);

    expect(cubit.state.groupStatus, PosCustomerGroupStatus.ready);
    expect(cubit.state.groups.map((PosCustomerGroup item) => item.id), [4, 9]);
    expect(cubit.state.groupIds, <int>{9});
  });

  test('validates required fields without submitting', () async {
    bool called = false;
    final PosCustomerQuickCreateCubit cubit = PosCustomerQuickCreateCubit(
      repository: _GroupsRepository(),
      onCreate: (_) async {
        called = true;
        return _result();
      },
    );
    addTearDown(cubit.close);

    await cubit.submit();

    expect(
      cubit.state.fieldErrors.keys,
      containsAll(<String>['name', 'phone']),
    );
    expect(called, isFalse);
  });

  test(
    'blocks duplicate submissions and preserves the draft on failure',
    () async {
      final Completer<PosCustomerCreateResult> completer =
          Completer<PosCustomerCreateResult>();
      int calls = 0;
      final PosCustomerQuickCreateCubit cubit = PosCustomerQuickCreateCubit(
        repository: _GroupsRepository(),
        onCreate: (PosQuickCreateCustomerRequest request) {
          calls++;
          return completer.future;
        },
      );
      addTearDown(cubit.close);
      cubit.updateName('New customer');
      cubit.updatePhone('091234567');
      cubit.updateNotes('Keep me');

      final Future<PosCustomerCreateResult?> first = cubit.submit();
      final Future<PosCustomerCreateResult?> second = cubit.submit();
      completer.completeError(StateError('temporary failure'));
      await first;
      await second;

      expect(calls, 1);
      expect(cubit.state.name, 'New customer');
      expect(cubit.state.phone, '091234567');
      expect(cubit.state.notes, 'Keep me');
      expect(cubit.state.isDirty, isTrue);
      expect(cubit.state.submitFailure, PosCustomerFailureKind.retryable);
    },
  );

  test(
    'returns the authoritative customer after a successful create',
    () async {
      PosQuickCreateCustomerRequest? submitted;
      final PosCustomerQuickCreateCubit cubit = PosCustomerQuickCreateCubit(
        repository: _GroupsRepository(),
        onCreate: (PosQuickCreateCustomerRequest request) async {
          submitted = request;
          return _result();
        },
      );
      addTearDown(cubit.close);
      cubit.updateName('Created');
      cubit.updatePhone('091234567');
      cubit.toggleGroup(4, true);

      final PosCustomerCreateResult? result = await cubit.submit();

      expect(result?.customer.backendId, 42);
      expect(submitted?.groupIds, <int>{4});
      expect(cubit.state.isDirty, isFalse);
    },
  );
}

PosCustomerCreateResult _result() => const PosCustomerCreateResult(
  customer: Customer(
    id: '42',
    backendId: 42,
    name: 'Authoritative',
    phone: '091234567',
  ),
  attachedToOrder: false,
);

class _GroupsRepository extends PosRepository {
  _GroupsRepository({this.groups = const <PosCustomerGroup>[]});

  final List<PosCustomerGroup> groups;

  @override
  Future<List<PosCustomerGroup>> getCustomerGroups({int perPage = 100}) async =>
      groups;
}

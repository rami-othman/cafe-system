import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:windows_application/core/network/api_exception.dart';
import 'package:windows_application/features/customer_management/controllers/customer_form_cubit.dart';
import 'package:windows_application/features/customer_management/controllers/customer_form_state.dart';
import 'package:windows_application/features/customer_management/models/customer_drafts.dart';
import 'package:windows_application/features/customer_management/models/customer_group_models.dart';
import 'package:windows_application/features/customer_management/models/customer_models.dart';
import 'package:windows_application/features/customer_management/models/customer_queries.dart';
import 'package:windows_application/features/customer_management/repositories/customer_management_repository.dart';

void main() {
  test(
    'initializes a create draft with zero phones and no generated identity',
    () {
      final CustomerFormCubit cubit = CustomerFormCubit(_FormRepository());

      cubit.initializeCreate();

      expect(cubit.state.status, CustomerFormStatus.ready);
      expect(cubit.state.isCreate, isTrue);
      expect(cubit.state.customerNumber, isNull);
      expect(cubit.state.draft.phones, isEmpty);
      expect(cubit.state.draft.isReadyToSubmit, isFalse);
    },
  );

  test(
    'loads edit state directly and preserves customer number and archived group',
    () async {
      final CustomerFormCubit cubit = CustomerFormCubit(_FormRepository());

      await cubit.loadForEdit(7);

      expect(cubit.state.status, CustomerFormStatus.ready);
      expect(cubit.state.customerId, 7);
      expect(cubit.state.customerNumber, 'C-000007');
      expect(cubit.state.draft.name, 'Ada');
      expect(cubit.state.draft.phones.single.rowId, 'phone-1');
      expect(cubit.state.archivedGroupIds, <int>{9});
      expect(cubit.state.loadedCustomer?.id, 7);
      expect(cubit.state.isDirty, isFalse);
    },
  );

  test(
    'lifecycle replacement updates edit identity without discarding a dirty draft',
    () async {
      final CustomerFormCubit cubit = CustomerFormCubit(_FormRepository());
      await cubit.loadForEdit(7);
      cubit.updateDraft(cubit.state.draft.copyWith(name: 'Unsaved Ada'));

      cubit.replaceCustomerLifecycle(
        _customer.copyWithForTest(lifecycle: CustomerLifecycle.inactive),
      );

      expect(cubit.state.loadedCustomer?.lifecycle, CustomerLifecycle.inactive);
      expect(cubit.state.draft.name, 'Unsaved Ada');
      expect(cubit.state.isDirty, isTrue);
    },
  );

  test(
    'phone edits preserve row identity and do not replace another primary implicitly',
    () {
      final CustomerFormCubit cubit = CustomerFormCubit(_FormRepository());
      cubit.initializeCreate();
      cubit.updateDraft(
        const CustomerDraft(
          name: 'Ada',
          phones: <CustomerPhoneDraft>[
            CustomerPhoneDraft(
              rowId: 'a',
              rawNumber: '+1 raw',
              type: 'mobile',
              isPrimary: true,
            ),
            CustomerPhoneDraft(
              rowId: 'b',
              rawNumber: '+2 raw',
              type: 'home',
              isPrimary: false,
            ),
          ],
        ),
      );

      cubit.removePhone('a');

      expect(cubit.state.draft.phones.single.rowId, 'b');
      expect(cubit.state.draft.phones.single.isPrimary, isFalse);
      expect(cubit.state.draft.isReadyToSubmit, isFalse);
    },
  );

  test(
    'group selection offers active groups and keeps archived membership until removal',
    () async {
      final CustomerFormCubit cubit = CustomerFormCubit(_FormRepository());
      await cubit.loadForEdit(7);

      expect(
        cubit.state.groupOptions.map((CustomerGroup group) => group.id),
        contains(3),
      );
      expect(
        cubit.state.groupOptions.map((CustomerGroup group) => group.id),
        isNot(contains(9)),
      );
      expect(cubit.state.draft.groupIds, contains(9));

      cubit.removeGroup(9);
      expect(cubit.state.draft.groupIds, isNot(contains(9)));
    },
  );

  test(
    'local validation retains the dirty draft and prevents submission',
    () async {
      final _FormRepository repository = _FormRepository();
      final CustomerFormCubit cubit = CustomerFormCubit(repository);
      cubit.initializeCreate();
      cubit.updateDraft(
        const CustomerDraft(
          name: ' ',
          phones: <CustomerPhoneDraft>[
            CustomerPhoneDraft(
              rowId: 'a',
              rawNumber: 'raw',
              type: 'mobile',
              isPrimary: false,
            ),
          ],
        ),
      );

      await cubit.submit();

      expect(cubit.state.status, CustomerFormStatus.failure);
      expect(cubit.state.isDirty, isTrue);
      expect(cubit.state.draft.phones.single.rawNumber, 'raw');
      expect(repository.createCalls, 0);
    },
  );

  test('maps nested backend validation and retains all draft values', () async {
    final _FormRepository repository = _FormRepository(
      submitError: const ApiException(
        message: 'validation',
        type: ApiErrorType.validation,
        statusCode: 422,
        validationErrors: <String, List<String>>{
          'phones.0.rawNumber': <String>['Invalid phone'],
          'groups': <String>['A group is invalid'],
        },
      ),
    );
    final CustomerFormCubit cubit = CustomerFormCubit(repository);
    cubit.initializeCreate();
    cubit.updateDraft(
      const CustomerDraft(
        name: 'Ada',
        phones: <CustomerPhoneDraft>[
          CustomerPhoneDraft(
            rowId: 'stable',
            rawNumber: 'keep exactly',
            type: 'mobile',
            isPrimary: true,
          ),
        ],
        groupIds: <int>{3},
      ),
    );

    await cubit.submit();

    expect(cubit.state.status, CustomerFormStatus.failure);
    expect(
      cubit.state.fieldErrors.keys,
      containsAll(<String>['phones.0.rawNumber', 'groups']),
    );
    expect(cubit.state.draft.phones.single.rawNumber, 'keep exactly');
    expect(cubit.state.draft.groupIds, <int>{3});
  });

  test(
    'prevents duplicate submits and exposes the authoritative success customer',
    () async {
      final _FormRepository repository = _FormRepository(deferSubmit: true);
      final CustomerFormCubit cubit = CustomerFormCubit(repository);
      cubit.initializeCreate();
      cubit.updateDraft(const CustomerDraft(name: 'Ada'));

      final Future<void> first = cubit.submit();
      final Future<void> second = cubit.submit();

      expect(repository.createCalls, 1);
      expect(cubit.state.status, CustomerFormStatus.submitting);
      repository.completeSubmit();
      await Future.wait(<Future<void>>[first, second]);

      expect(cubit.state.status, CustomerFormStatus.success);
      expect(cubit.state.savedCustomer?.id, 22);
      expect(cubit.state.isDirty, isFalse);
    },
  );

  test(
    'successful edit uses update and returns the backend customer identity',
    () async {
      final _FormRepository repository = _FormRepository();
      final CustomerFormCubit cubit = CustomerFormCubit(repository);
      await cubit.loadForEdit(7);
      cubit.updateDraft(cubit.state.draft.copyWith(name: 'Updated Ada'));

      await cubit.submit();

      expect(repository.updateCalls, 1);
      expect(repository.updatedId, 7);
      expect(cubit.state.savedCustomer?.id, 7);
      expect(cubit.state.savedCustomer?.name, 'Updated Ada');
    },
  );
}

class _FormRepository implements CustomerManagementRepository {
  _FormRepository({this.submitError, this.deferSubmit = false});

  final Object? submitError;
  final bool deferSubmit;
  int createCalls = 0;
  int updateCalls = 0;
  int? updatedId;
  final Completer<Customer> _submit = Completer<Customer>();

  @override
  Future<Customer> getCustomer(int customerId) async => _customer;

  @override
  Future<CustomerPage<CustomerGroup>> listGroups(
    CustomerGroupListQuery query,
  ) async => const CustomerPage<CustomerGroup>(
    items: <CustomerGroup>[_activeGroup],
    meta: CustomerPageMeta(currentPage: 1, lastPage: 1, perPage: 100, total: 1),
  );

  @override
  Future<Customer> createCustomer(CustomerDraft draft) {
    createCalls++;
    if (submitError != null) return Future<Customer>.error(submitError!);
    if (deferSubmit) return _submit.future;
    return Future<Customer>.value(_createdCustomer);
  }

  @override
  Future<Customer> updateCustomer(int customerId, CustomerDraft draft) async {
    updateCalls++;
    updatedId = customerId;
    return _customer.copyWithForTest(name: draft.name);
  }

  void completeSubmit() => _submit.complete(_createdCustomer);

  @override
  noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

const CustomerGroup _activeGroup = CustomerGroup(
  id: 3,
  name: 'VIP',
  lifecycle: CustomerLifecycle.active,
  memberCount: 1,
);

const Customer _customer = Customer(
  id: 7,
  customerNumber: 'C-000007',
  name: 'Ada',
  lifecycle: CustomerLifecycle.active,
  phones: <CustomerPhone>[
    CustomerPhone(id: 1, rawNumber: '+1 raw', type: 'mobile', isPrimary: true),
  ],
  groups: <CustomerGroupSummary>[
    CustomerGroupSummary(
      id: 9,
      name: 'Archived',
      lifecycle: CustomerLifecycle.archived,
    ),
  ],
  allowedActions: <String>{'update'},
);

const Customer _createdCustomer = Customer(
  id: 22,
  customerNumber: 'C-000022',
  name: 'Ada',
  lifecycle: CustomerLifecycle.active,
  phones: <CustomerPhone>[],
  groups: <CustomerGroupSummary>[],
  allowedActions: <String>{'update'},
);

extension on Customer {
  Customer copyWithForTest({String? name, CustomerLifecycle? lifecycle}) =>
      Customer(
        id: id,
        customerNumber: customerNumber,
        name: name ?? this.name,
        lifecycle: lifecycle ?? this.lifecycle,
        email: email,
        birthDate: birthDate,
        notes: notes,
        phones: phones,
        groups: groups,
        allowedActions: allowedActions,
      );
}

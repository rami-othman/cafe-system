import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';

import '../models/customer_drafts.dart';
import '../models/customer_failure.dart';
import '../models/customer_group_models.dart';
import '../models/customer_models.dart';
import '../models/customer_queries.dart';
import '../repositories/customer_management_repository.dart';
import 'customer_form_state.dart';

class CustomerFormCubit extends Cubit<CustomerFormState> {
  CustomerFormCubit(this._repository) : super(const CustomerFormState());

  final CustomerManagementRepository _repository;
  int _generation = 0;
  int _newPhoneSequence = 0;
  Future<void>? _submitRequest;

  void initializeCreate() {
    _generation++;
    const CustomerDraft draft = CustomerDraft(name: '');
    emit(
      const CustomerFormState(
        status: CustomerFormStatus.ready,
        draft: draft,
        baseline: draft,
      ),
    );
    unawaited(_loadGroupOptions(_generation));
  }

  Future<void> loadForEdit(int customerId) async {
    if (customerId <= 0) return;
    final int generation = ++_generation;
    emit(
      CustomerFormState(
        status: CustomerFormStatus.loading,
        customerId: customerId,
      ),
    );
    try {
      final Customer customer = await _repository.getCustomer(customerId);
      if (isClosed || generation != _generation) return;
      final CustomerDraft draft = _draftForCustomer(customer);
      emit(
        CustomerFormState(
          status: CustomerFormStatus.ready,
          customerId: customer.id,
          customerNumber: customer.customerNumber,
          loadedCustomer: customer,
          draft: draft,
          baseline: draft,
          archivedGroupIds: customer.groups
              .where(
                (CustomerGroupSummary group) =>
                    group.lifecycle == CustomerLifecycle.archived,
              )
              .map((CustomerGroupSummary group) => group.id)
              .toSet(),
          archivedGroups: customer.groups
              .where(
                (CustomerGroupSummary group) =>
                    group.lifecycle == CustomerLifecycle.archived,
              )
              .toList(growable: false),
        ),
      );
      await _loadGroupOptions(generation);
    } catch (error) {
      if (isClosed || generation != _generation) return;
      emit(
        CustomerFormState(
          status: CustomerFormStatus.failure,
          customerId: customerId,
          failure: CustomerFailure.fromError(error),
        ),
      );
    }
  }

  void updateDraft(CustomerDraft draft) => _setDraft(draft);

  void addPhone({String rawNumber = '', String type = 'mobile'}) {
    final List<CustomerPhoneDraft> phones = List<CustomerPhoneDraft>.from(
      state.draft.phones,
    );
    phones.add(
      CustomerPhoneDraft(
        rowId: 'phone-new-${_newPhoneSequence++}',
        rawNumber: rawNumber,
        type: type,
        isPrimary: phones.isEmpty,
      ),
    );
    _setDraft(state.draft.copyWith(phones: phones));
  }

  void removePhone(String rowId) {
    _setDraft(
      state.draft.copyWith(
        phones: state.draft.phones
            .where((CustomerPhoneDraft phone) => phone.rowId != rowId)
            .toList(growable: false),
      ),
    );
  }

  void updatePhone(
    String rowId, {
    String? rawNumber,
    String? type,
    bool? isPrimary,
  }) {
    final List<CustomerPhoneDraft> phones = state.draft.phones
        .map((phone) {
          final bool primary = isPrimary == true
              ? phone.rowId == rowId
              : isPrimary == false && phone.rowId == rowId
              ? false
              : phone.isPrimary;
          return phone.rowId == rowId
              ? phone.copyWith(
                  rawNumber: rawNumber,
                  type: type,
                  isPrimary: primary,
                )
              : phone.copyWith(isPrimary: isPrimary == true ? false : null);
        })
        .toList(growable: false);
    _setDraft(state.draft.copyWith(phones: phones));
  }

  void setPrimaryPhone(String rowId) => updatePhone(rowId, isPrimary: true);

  void setGroupSelected(int groupId, bool selected) {
    final Set<int> groups = Set<int>.from(state.draft.groupIds);
    if (selected) {
      groups.add(groupId);
    } else {
      groups.remove(groupId);
    }
    _setDraft(state.draft.copyWith(groupIds: groups));
  }

  void removeGroup(int groupId) => setGroupSelected(groupId, false);

  void replaceCustomerLifecycle(Customer customer) {
    if (isClosed || customer.id != state.customerId) return;
    emit(state.copyWith(loadedCustomer: customer, clearFailure: true));
  }

  Future<void> submit() {
    final Future<void>? current = _submitRequest;
    if (current != null) return current;
    final Map<String, List<String>> errors = _validate(state.draft);
    if (errors.isNotEmpty) {
      emit(
        state.copyWith(
          status: CustomerFormStatus.failure,
          fieldErrors: errors,
          clearFailure: true,
          clearSavedCustomer: true,
        ),
      );
      return Future<void>.value();
    }
    final Future<void> request = _submit();
    _submitRequest = request;
    return request.whenComplete(() {
      if (identical(_submitRequest, request)) _submitRequest = null;
    });
  }

  Future<void> _submit() async {
    emit(
      state.copyWith(
        status: CustomerFormStatus.submitting,
        clearErrors: true,
        clearFailure: true,
        clearSavedCustomer: true,
      ),
    );
    try {
      final Customer saved = state.isCreate
          ? await _repository.createCustomer(state.draft)
          : await _repository.updateCustomer(state.customerId!, state.draft);
      if (isClosed) return;
      emit(
        state.copyWith(
          status: CustomerFormStatus.success,
          savedCustomer: saved,
          isDirty: false,
          clearErrors: true,
          clearFailure: true,
        ),
      );
    } catch (error) {
      if (isClosed) return;
      final CustomerFailure mapped = CustomerFailure.fromError(error);
      emit(
        state.copyWith(
          status: CustomerFormStatus.failure,
          failure: mapped,
          fieldErrors: mapped.fieldErrors,
        ),
      );
    }
  }

  Future<void> _loadGroupOptions(int generation) async {
    try {
      final CustomerPage<CustomerGroup> page = await _repository.listGroups(
        const CustomerGroupListQuery(
          status: CustomerStatusFilter.active,
          perPage: 100,
        ),
      );
      if (isClosed || generation != _generation) return;
      emit(state.copyWith(groupOptions: page.items));
    } catch (_) {
      // The profile can still be edited; the server remains authoritative.
    }
  }

  void _setDraft(CustomerDraft draft) {
    emit(
      state.copyWith(
        draft: draft,
        isDirty: draft != state.baseline,
        clearErrors: true,
        clearFailure: true,
        clearSavedCustomer: true,
      ),
    );
  }

  CustomerDraft _draftForCustomer(Customer customer) => CustomerDraft(
    name: customer.name,
    email: customer.email,
    birthDate: customer.birthDate,
    notes: customer.notes,
    phones: customer.phones
        .map(
          (CustomerPhone phone) => CustomerPhoneDraft(
            rowId: 'phone-${phone.id}',
            rawNumber: phone.rawNumber,
            type: phone.type,
            isPrimary: phone.isPrimary,
          ),
        )
        .toList(growable: false),
    groupIds: customer.groups
        .map((CustomerGroupSummary group) => group.id)
        .toSet(),
  );

  Map<String, List<String>> _validate(CustomerDraft draft) {
    final Map<String, List<String>> errors = <String, List<String>>{};
    if (draft.name.trim().isEmpty) {
      errors['name'] = const <String>['required'];
    }
    if (draft.phones.isNotEmpty && !draft.hasExactlyOnePrimary) {
      errors['phones'] = const <String>['primaryRequired'];
    }
    return errors;
  }

  @override
  Future<void> close() {
    _generation++;
    _submitRequest = null;
    return super.close();
  }
}

import 'package:flutter_bloc/flutter_bloc.dart';

import '../models/customer_drafts.dart';
import '../models/customer_failure.dart';
import '../models/customer_group_models.dart';
import '../repositories/customer_management_repository.dart';
import 'customer_group_form_state.dart';

class CustomerGroupFormCubit extends Cubit<CustomerGroupFormState> {
  CustomerGroupFormCubit(this._repository)
    : super(const CustomerGroupFormState());

  final CustomerManagementRepository _repository;
  Future<void>? _submitRequest;
  int _generation = 0;

  void initializeCreate() {
    _generation++;
    const GroupDraft draft = GroupDraft(name: '');
    emit(
      const CustomerGroupFormState(
        status: CustomerGroupFormStatus.ready,
        draft: draft,
        baseline: draft,
      ),
    );
  }

  Future<void> loadForEdit(int groupId) async {
    if (groupId <= 0) return;
    final int generation = ++_generation;
    emit(
      CustomerGroupFormState(
        status: CustomerGroupFormStatus.loading,
        groupId: groupId,
      ),
    );
    try {
      final CustomerGroup group = await _repository.getGroup(groupId);
      if (isClosed || generation != _generation) return;
      final GroupDraft draft = GroupDraft(name: group.name);
      emit(
        CustomerGroupFormState(
          status: CustomerGroupFormStatus.ready,
          groupId: group.id,
          loadedGroup: group,
          draft: draft,
          baseline: draft,
        ),
      );
    } catch (error) {
      if (!isClosed && generation == _generation) {
        emit(
          CustomerGroupFormState(
            status: CustomerGroupFormStatus.failure,
            groupId: groupId,
            failure: CustomerFailure.fromError(error),
          ),
        );
      }
    }
  }

  void setName(String value) => emit(
    state.copyWith(
      draft: GroupDraft(name: value),
      isDirty: GroupDraft(name: value) != state.baseline,
      clearErrors: true,
      clearFailure: true,
      clearSavedGroup: true,
    ),
  );

  Future<void> submit() {
    if (_submitRequest != null) return _submitRequest!;
    if (!state.draft.isReadyToSubmit) {
      emit(
        state.copyWith(
          status: CustomerGroupFormStatus.failure,
          fieldErrors: const <String, List<String>>{
            'name': <String>['required'],
          },
          clearFailure: true,
          clearSavedGroup: true,
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
        status: CustomerGroupFormStatus.submitting,
        clearErrors: true,
        clearFailure: true,
        clearSavedGroup: true,
      ),
    );
    try {
      final CustomerGroup saved = state.isCreate
          ? await _repository.createGroup(state.draft)
          : await _repository.updateGroup(state.groupId!, state.draft);
      if (isClosed) return;
      emit(
        state.copyWith(
          status: CustomerGroupFormStatus.success,
          savedGroup: saved,
          isDirty: false,
          clearErrors: true,
          clearFailure: true,
        ),
      );
    } catch (error) {
      if (!isClosed) {
        final CustomerFailure failure = CustomerFailure.fromError(error);
        emit(
          state.copyWith(
            status: CustomerGroupFormStatus.failure,
            failure: failure,
            fieldErrors: failure.fieldErrors,
          ),
        );
      }
    }
  }

  @override
  Future<void> close() {
    _generation++;
    _submitRequest = null;
    return super.close();
  }
}

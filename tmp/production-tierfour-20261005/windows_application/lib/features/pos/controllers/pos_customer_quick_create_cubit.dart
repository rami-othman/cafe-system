import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/network/api_exception.dart';
import '../models/pos_customer_create_result.dart';
import '../models/pos_quick_create_customer_request.dart';
import '../repositories/pos_repository.dart';
import 'pos_customer_quick_create_state.dart';

class PosCustomerQuickCreateCubit extends Cubit<PosCustomerQuickCreateState> {
  PosCustomerQuickCreateCubit({
    required this.repository,
    required this.onCreate,
  }) : super(const PosCustomerQuickCreateState());

  final PosRepository repository;
  final Future<PosCustomerCreateResult> Function(
    PosQuickCreateCustomerRequest request,
  )
  onCreate;

  int _groupsGeneration = 0;
  Future<PosCustomerCreateResult?>? _submitRequest;

  Future<void> loadGroups() async {
    final int generation = ++_groupsGeneration;
    emit(
      state.copyWith(
        groupStatus: PosCustomerGroupStatus.loading,
        clearGroupFailure: true,
      ),
    );
    try {
      final groups = await repository.getCustomerGroups();
      if (isClosed || generation != _groupsGeneration) return;
      emit(
        state.copyWith(
          groups: groups,
          groupStatus: groups.isEmpty
              ? PosCustomerGroupStatus.empty
              : PosCustomerGroupStatus.ready,
          clearGroupFailure: true,
        ),
      );
    } catch (error) {
      if (isClosed || generation != _groupsGeneration) return;
      emit(
        state.copyWith(
          groupStatus: PosCustomerGroupStatus.failure,
          groupFailure: _failureKind(error),
        ),
      );
    }
  }

  void updateName(String value) => _update(name: value);

  void updatePhone(String value) => _update(phone: value);

  void updateNotes(String value) => _update(notes: value);

  void toggleGroup(int groupId, bool selected) {
    final Set<int> groupIds = Set<int>.from(state.groupIds);
    if (selected) {
      groupIds.add(groupId);
    } else {
      groupIds.remove(groupId);
    }
    _update(groupIds: groupIds);
  }

  Future<PosCustomerCreateResult?> submit() {
    final Future<PosCustomerCreateResult?>? current = _submitRequest;
    if (current != null) return current;

    final Map<String, List<String>> fieldErrors = _validate();
    if (fieldErrors.isNotEmpty) {
      emit(
        state.copyWith(
          fieldErrors: fieldErrors,
          clearSubmitFailure: true,
          clearResult: true,
        ),
      );
      return Future<PosCustomerCreateResult?>.value();
    }

    final Future<PosCustomerCreateResult?> request = _submit();
    _submitRequest = request;
    return request.whenComplete(() {
      if (identical(_submitRequest, request)) _submitRequest = null;
    });
  }

  Future<PosCustomerCreateResult?> _submit() async {
    emit(
      state.copyWith(
        isSubmitting: true,
        fieldErrors: const <String, List<String>>{},
        clearSubmitFailure: true,
        clearResult: true,
      ),
    );
    try {
      final PosCustomerCreateResult result = await onCreate(
        PosQuickCreateCustomerRequest(
          name: state.name,
          phone: state.phone,
          notes: state.notes,
          groupIds: state.groupIds,
        ),
      );
      if (isClosed) return result;
      emit(
        state.copyWith(
          isSubmitting: false,
          result: result,
          isDirty: false,
          clearSubmitFailure: true,
        ),
      );
      return result;
    } catch (error) {
      if (isClosed) return null;
      emit(
        state.copyWith(
          isSubmitting: false,
          fieldErrors: error is ApiException
              ? error.validationErrors ?? const <String, List<String>>{}
              : const <String, List<String>>{},
          submitFailure: _failureKind(error),
        ),
      );
      return null;
    }
  }

  void _update({
    String? name,
    String? phone,
    String? notes,
    Set<int>? groupIds,
  }) {
    emit(
      state.copyWith(
        name: name,
        phone: phone,
        notes: notes,
        groupIds: groupIds,
        isDirty: true,
        fieldErrors: const <String, List<String>>{},
        clearSubmitFailure: true,
        clearResult: true,
      ),
    );
  }

  Map<String, List<String>> _validate() {
    final Map<String, List<String>> errors = <String, List<String>>{};
    if (state.name.trim().isEmpty) {
      errors['name'] = <String>['required'];
    }
    if (state.phone.trim().isEmpty) {
      errors['phone'] = <String>['required'];
    }
    return errors;
  }

  PosCustomerFailureKind _failureKind(Object error) {
    if (error is ApiException &&
        (error.type == ApiErrorType.forbidden || error.statusCode == 403)) {
      return PosCustomerFailureKind.forbidden;
    }
    return PosCustomerFailureKind.retryable;
  }

  @override
  Future<void> close() {
    _groupsGeneration++;
    return super.close();
  }
}

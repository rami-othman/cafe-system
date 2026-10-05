import 'package:equatable/equatable.dart';

import '../models/pos_customer_create_result.dart';
import '../models/pos_customer_group.dart';

enum PosCustomerGroupStatus { loading, ready, empty, failure }

enum PosCustomerFailureKind { forbidden, retryable }

class PosCustomerQuickCreateState extends Equatable {
  const PosCustomerQuickCreateState({
    this.name = '',
    this.phone = '',
    this.notes = '',
    this.groupIds = const <int>{},
    this.groups = const <PosCustomerGroup>[],
    this.groupStatus = PosCustomerGroupStatus.loading,
    this.groupFailure,
    this.isSubmitting = false,
    this.submitFailure,
    this.fieldErrors = const <String, List<String>>{},
    this.result,
    this.isDirty = false,
  });

  final String name;
  final String phone;
  final String notes;
  final Set<int> groupIds;
  final List<PosCustomerGroup> groups;
  final PosCustomerGroupStatus groupStatus;
  final PosCustomerFailureKind? groupFailure;
  final bool isSubmitting;
  final PosCustomerFailureKind? submitFailure;
  final Map<String, List<String>> fieldErrors;
  final PosCustomerCreateResult? result;
  final bool isDirty;

  PosCustomerQuickCreateState copyWith({
    String? name,
    String? phone,
    String? notes,
    Set<int>? groupIds,
    List<PosCustomerGroup>? groups,
    PosCustomerGroupStatus? groupStatus,
    PosCustomerFailureKind? groupFailure,
    bool? isSubmitting,
    PosCustomerFailureKind? submitFailure,
    Map<String, List<String>>? fieldErrors,
    PosCustomerCreateResult? result,
    bool? isDirty,
    bool clearGroupFailure = false,
    bool clearSubmitFailure = false,
    bool clearResult = false,
  }) => PosCustomerQuickCreateState(
    name: name ?? this.name,
    phone: phone ?? this.phone,
    notes: notes ?? this.notes,
    groupIds: groupIds ?? this.groupIds,
    groups: groups ?? this.groups,
    groupStatus: groupStatus ?? this.groupStatus,
    groupFailure: clearGroupFailure ? null : groupFailure ?? this.groupFailure,
    isSubmitting: isSubmitting ?? this.isSubmitting,
    submitFailure: clearSubmitFailure
        ? null
        : submitFailure ?? this.submitFailure,
    fieldErrors: fieldErrors ?? this.fieldErrors,
    result: clearResult ? null : result ?? this.result,
    isDirty: isDirty ?? this.isDirty,
  );

  @override
  List<Object?> get props => <Object?>[
    name,
    phone,
    notes,
    groupIds,
    groups,
    groupStatus,
    groupFailure,
    isSubmitting,
    submitFailure,
    fieldErrors,
    result,
    isDirty,
  ];
}

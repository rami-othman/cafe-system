import 'package:equatable/equatable.dart';

import '../models/customer_drafts.dart';
import '../models/customer_failure.dart';
import '../models/customer_group_models.dart';

enum CustomerGroupFormStatus {
  initial,
  loading,
  ready,
  submitting,
  success,
  failure,
}

class CustomerGroupFormState extends Equatable {
  const CustomerGroupFormState({
    this.status = CustomerGroupFormStatus.initial,
    this.groupId,
    this.draft = const GroupDraft(name: ''),
    this.baseline = const GroupDraft(name: ''),
    this.fieldErrors = const <String, List<String>>{},
    this.failure,
    this.savedGroup,
    this.loadedGroup,
    this.isDirty = false,
  });

  final CustomerGroupFormStatus status;
  final int? groupId;
  final GroupDraft draft;
  final GroupDraft baseline;
  final Map<String, List<String>> fieldErrors;
  final CustomerFailure? failure;
  final CustomerGroup? savedGroup;
  final CustomerGroup? loadedGroup;
  final bool isDirty;

  bool get isCreate => groupId == null;

  CustomerGroupFormState copyWith({
    CustomerGroupFormStatus? status,
    int? groupId,
    GroupDraft? draft,
    GroupDraft? baseline,
    Map<String, List<String>>? fieldErrors,
    CustomerFailure? failure,
    CustomerGroup? savedGroup,
    CustomerGroup? loadedGroup,
    bool? isDirty,
    bool clearErrors = false,
    bool clearFailure = false,
    bool clearSavedGroup = false,
  }) => CustomerGroupFormState(
    status: status ?? this.status,
    groupId: groupId ?? this.groupId,
    draft: draft ?? this.draft,
    baseline: baseline ?? this.baseline,
    fieldErrors: clearErrors
        ? const <String, List<String>>{}
        : fieldErrors ?? this.fieldErrors,
    failure: clearFailure ? null : failure ?? this.failure,
    savedGroup: clearSavedGroup ? null : savedGroup ?? this.savedGroup,
    loadedGroup: loadedGroup ?? this.loadedGroup,
    isDirty: isDirty ?? this.isDirty,
  );

  @override
  List<Object?> get props => <Object?>[
    status,
    groupId,
    draft,
    baseline,
    fieldErrors,
    failure,
    savedGroup,
    loadedGroup,
    isDirty,
  ];
}

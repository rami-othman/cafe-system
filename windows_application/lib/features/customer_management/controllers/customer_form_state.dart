import 'package:equatable/equatable.dart';

import '../models/customer_drafts.dart';
import '../models/customer_failure.dart';
import '../models/customer_group_models.dart';
import '../models/customer_models.dart';

enum CustomerFormStatus {
  initial,
  loading,
  ready,
  submitting,
  success,
  failure,
}

class CustomerFormState extends Equatable {
  const CustomerFormState({
    this.status = CustomerFormStatus.initial,
    this.customerId,
    this.customerNumber,
    this.draft = const CustomerDraft(name: ''),
    this.baseline = const CustomerDraft(name: ''),
    this.groupOptions = const <CustomerGroup>[],
    this.archivedGroupIds = const <int>{},
    this.archivedGroups = const <CustomerGroupSummary>[],
    this.fieldErrors = const <String, List<String>>{},
    this.failure,
    this.savedCustomer,
    this.loadedCustomer,
    this.isDirty = false,
  });

  final CustomerFormStatus status;
  final int? customerId;
  final String? customerNumber;
  final CustomerDraft draft;
  final CustomerDraft baseline;
  final List<CustomerGroup> groupOptions;
  final Set<int> archivedGroupIds;
  final List<CustomerGroupSummary> archivedGroups;
  final Map<String, List<String>> fieldErrors;
  final CustomerFailure? failure;
  final Customer? savedCustomer;
  final Customer? loadedCustomer;
  final bool isDirty;

  bool get isCreate => customerId == null;

  CustomerFormState copyWith({
    CustomerFormStatus? status,
    int? customerId,
    String? customerNumber,
    CustomerDraft? draft,
    CustomerDraft? baseline,
    List<CustomerGroup>? groupOptions,
    Set<int>? archivedGroupIds,
    List<CustomerGroupSummary>? archivedGroups,
    Map<String, List<String>>? fieldErrors,
    CustomerFailure? failure,
    Customer? savedCustomer,
    bool? isDirty,
    bool clearErrors = false,
    bool clearFailure = false,
    bool clearSavedCustomer = false,
    Customer? loadedCustomer,
  }) => CustomerFormState(
    status: status ?? this.status,
    customerId: customerId ?? this.customerId,
    customerNumber: customerNumber ?? this.customerNumber,
    draft: draft ?? this.draft,
    baseline: baseline ?? this.baseline,
    groupOptions: groupOptions ?? this.groupOptions,
    archivedGroupIds: archivedGroupIds ?? this.archivedGroupIds,
    archivedGroups: archivedGroups ?? this.archivedGroups,
    fieldErrors: clearErrors
        ? const <String, List<String>>{}
        : fieldErrors ?? this.fieldErrors,
    failure: clearFailure ? null : failure ?? this.failure,
    savedCustomer: clearSavedCustomer
        ? null
        : savedCustomer ?? this.savedCustomer,
    loadedCustomer: loadedCustomer ?? this.loadedCustomer,
    isDirty: isDirty ?? this.isDirty,
  );

  @override
  List<Object?> get props => <Object?>[
    status,
    customerId,
    customerNumber,
    draft,
    baseline,
    groupOptions,
    archivedGroupIds,
    archivedGroups,
    fieldErrors,
    failure,
    savedCustomer,
    loadedCustomer,
    isDirty,
  ];
}

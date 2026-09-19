import 'package:equatable/equatable.dart';

enum DiscountStatus { active, inactive, scheduled, expired }

class DiscountListItem extends Equatable {
  const DiscountListItem({
    required this.id,
    required this.name,
    required this.type,
    required this.status,
    required this.usageCount,
    required this.estimatedSavedValue,
    this.code,
    this.description,
    this.applicationMode = 'code',
    this.scope = 'order',
    this.value = 0,
    this.conditions,
    this.minimumOrderAmount = 0,
    this.maximumDiscountAmount,
    this.startDate,
    this.endDate,
    this.startsAt,
    this.endsAt,
    this.displayPeriodPrimary,
    this.displayPeriodSecondary,
    this.isActive = true,
    this.appliesToAllBranches = true,
    this.branchIds = const <int>[],
  });

  final String id;
  final String name;
  final String type;
  final DiscountStatus status;
  final int usageCount;
  final double estimatedSavedValue;
  final String? code;
  final String? description;
  final String? conditions;
  final String applicationMode;
  final String scope;
  final double value;
  final double minimumOrderAmount;
  final double? maximumDiscountAmount;

  /// Canonical branch-local policy dates. These must not be inferred from
  /// legacy timestamp fields, which describe an older display contract.
  final DateTime? startDate;
  final DateTime? endDate;
  final DateTime? startsAt;
  final DateTime? endsAt;
  final String? displayPeriodPrimary;
  final String? displayPeriodSecondary;
  final bool isActive;
  final bool appliesToAllBranches;
  final List<int> branchIds;

  @override
  List<Object?> get props => <Object?>[
    id,
    name,
    type,
    status,
    usageCount,
    estimatedSavedValue,
    code,
    description,
    conditions,
    applicationMode,
    scope,
    value,
    minimumOrderAmount,
    maximumDiscountAmount,
    startDate,
    endDate,
    startsAt,
    endsAt,
    displayPeriodPrimary,
    displayPeriodSecondary,
    isActive,
    appliesToAllBranches,
    branchIds,
  ];
}

class DiscountSummaryMetric {
  const DiscountSummaryMetric({required this.label, required this.value});

  final String label;
  final String value;
}

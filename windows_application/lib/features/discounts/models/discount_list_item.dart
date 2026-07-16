import 'package:equatable/equatable.dart';

enum DiscountStatus { active, inactive, scheduled, expired }

extension DiscountStatusLabel on DiscountStatus {
  String get label => switch (this) {
    DiscountStatus.active => 'ACTIVE',
    DiscountStatus.inactive => 'INACTIVE',
    DiscountStatus.scheduled => 'SCHEDULED',
    DiscountStatus.expired => 'EXPIRED',
  };
}

class DiscountListItem extends Equatable {
  const DiscountListItem({
    required this.id,
    required this.name,
    required this.secondaryLabel,
    required this.type,
    required this.displayValue,
    required this.conditions,
    required this.validPeriodPrimary,
    this.validPeriodSecondary,
    required this.status,
    required this.usageCount,
    required this.estimatedSavedValue,
    this.code,
    this.description,
    this.applicationMode = 'code',
    this.scope = 'order',
    this.value = 0,
    this.minimumOrderAmount = 0,
    this.maximumDiscountAmount,
    this.startsAt,
    this.endsAt,
    this.isActive = true,
    this.appliesToAllBranches = true,
    this.branchIds = const <int>[],
  });

  final String id;
  final String name;
  final String secondaryLabel;
  final String type;
  final String displayValue;
  final String conditions;
  final String validPeriodPrimary;
  final String? validPeriodSecondary;
  final DiscountStatus status;
  final int usageCount;
  final String estimatedSavedValue;
  final String? code;
  final String? description;
  final String applicationMode;
  final String scope;
  final double value;
  final double minimumOrderAmount;
  final double? maximumDiscountAmount;
  final DateTime? startsAt;
  final DateTime? endsAt;
  final bool isActive;
  final bool appliesToAllBranches;
  final List<int> branchIds;

  @override
  List<Object?> get props => <Object?>[
    id,
    name,
    secondaryLabel,
    type,
    displayValue,
    conditions,
    validPeriodPrimary,
    validPeriodSecondary,
    status,
    usageCount,
    estimatedSavedValue,
    code,
    description,
    applicationMode,
    scope,
    value,
    minimumOrderAmount,
    maximumDiscountAmount,
    startsAt,
    endsAt,
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

import 'package:equatable/equatable.dart';

enum DiscountStatus { active, scheduled, expired, draft }

extension DiscountStatusLabel on DiscountStatus {
  String get label => switch (this) {
    DiscountStatus.active => 'ACTIVE',
    DiscountStatus.scheduled => 'SCHEDULED',
    DiscountStatus.expired => 'EXPIRED',
    DiscountStatus.draft => 'DRAFT',
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
  ];
}

class DiscountSummaryMetric {
  const DiscountSummaryMetric({required this.label, required this.value});

  final String label;
  final String value;
}

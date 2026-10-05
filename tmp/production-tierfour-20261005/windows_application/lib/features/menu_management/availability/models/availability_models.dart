// ignore_for_file: curly_braces_in_flow_control_structures

import 'package:equatable/equatable.dart';

import '../../../pos/models/json_helpers.dart';

enum AvailabilityScope { global, branch, channel, branchChannel }

AvailabilityScope availabilityScopeOf({int? branchId, String? channel}) {
  if (branchId != null && channel != null)
    return AvailabilityScope.branchChannel;
  if (branchId != null) return AvailabilityScope.branch;
  if (channel != null) return AvailabilityScope.channel;
  return AvailabilityScope.global;
}

String availabilityScopeWire(AvailabilityScope scope) => switch (scope) {
  AvailabilityScope.global => 'global',
  AvailabilityScope.branch => 'branch',
  AvailabilityScope.channel => 'channel',
  AvailabilityScope.branchChannel => 'branch_channel',
};

String availabilityScopeLabel(AvailabilityScope scope) => switch (scope) {
  AvailabilityScope.global => 'Global',
  AvailabilityScope.branch => 'Branch',
  AvailabilityScope.channel => 'Channel',
  AvailabilityScope.branchChannel => 'Branch + Channel',
};

class AvailabilityRule extends Equatable {
  const AvailabilityRule({
    required this.id,
    required this.productVariantId,
    required this.branchId,
    required this.channel,
    required this.dayOfWeek,
    required this.startTime,
    required this.endTime,
    required this.startDate,
    required this.endDate,
    required this.priority,
    required this.isActive,
  });

  factory AvailabilityRule.fromJson(Map<String, dynamic> json) =>
      AvailabilityRule(
        id: readInt(json['id']) ?? 0,
        productVariantId: readInt(json['productVariantId']),
        branchId: readInt(json['branchId']),
        channel: _optional(json['channel']),
        dayOfWeek: readInt(json['dayOfWeek']),
        startTime: _optional(json['startTime']),
        endTime: _optional(json['endTime']),
        startDate: _optional(json['startDate']),
        endDate: _optional(json['endDate']),
        priority: readInt(json['priority']) ?? 0,
        isActive: readBool(json['isActive'], fallback: true),
      );

  final int id;
  final int? productVariantId;
  final int? branchId;
  final String? channel;
  final int? dayOfWeek;
  final String? startTime;
  final String? endTime;
  final String? startDate;
  final String? endDate;
  final int priority;
  final bool isActive;
  AvailabilityScope get scope =>
      availabilityScopeOf(branchId: branchId, channel: channel);
  bool get isOvernight =>
      startTime != null &&
      endTime != null &&
      startTime!.compareTo(endTime!) > 0;
  AvailabilityRuleDraft toDraft() => AvailabilityRuleDraft(
    productVariantId: productVariantId,
    branchId: branchId,
    channel: channel,
    dayOfWeek: dayOfWeek,
    startTime: startTime,
    endTime: endTime,
    startDate: startDate,
    endDate: endDate,
    priority: priority,
    isActive: isActive,
  );
  @override
  List<Object?> get props => <Object?>[
    id,
    productVariantId,
    branchId,
    channel,
    dayOfWeek,
    startTime,
    endTime,
    startDate,
    endDate,
    priority,
    isActive,
  ];
}

class AvailabilityRuleDraft extends Equatable {
  const AvailabilityRuleDraft({
    required this.productVariantId,
    required this.branchId,
    required this.channel,
    required this.dayOfWeek,
    required this.startTime,
    required this.endTime,
    required this.startDate,
    required this.endDate,
    required this.priority,
    required this.isActive,
  });
  final int? productVariantId;
  final int? branchId;
  final String? channel;
  final int? dayOfWeek;
  final String? startTime;
  final String? endTime;
  final String? startDate;
  final String? endDate;
  final int priority;
  final bool isActive;
  AvailabilityScope get scope =>
      availabilityScopeOf(branchId: branchId, channel: channel);
  bool get isOvernight =>
      startTime != null &&
      endTime != null &&
      startTime!.compareTo(endTime!) > 0;
  String get identity => <Object?>[
    productVariantId,
    branchId,
    channel,
    dayOfWeek,
    startTime,
    endTime,
    startDate,
    endDate,
  ].join('|');
  Map<String, dynamic> toJson() => <String, dynamic>{
    'productVariantId': productVariantId,
    'branchId': branchId,
    'channel': channel,
    'dayOfWeek': dayOfWeek,
    'startTime': startTime,
    'endTime': endTime,
    'startDate': startDate,
    'endDate': endDate,
    'priority': priority,
    'isActive': isActive,
  };
  @override
  List<Object?> get props => <Object?>[
    productVariantId,
    branchId,
    channel,
    dayOfWeek,
    startTime,
    endTime,
    startDate,
    endDate,
    priority,
    isActive,
  ];
}

class ProductAvailabilityRulesSnapshot extends Equatable {
  const ProductAvailabilityRulesSnapshot({
    required this.productId,
    required this.rules,
  });
  factory ProductAvailabilityRulesSnapshot.fromJson(Map<String, dynamic> json) {
    final dynamic rows = json['rules'];
    if (rows is! List)
      throw const FormatException('Invalid availability rule response.');
    return ProductAvailabilityRulesSnapshot(
      productId: readInt(json['productId']) ?? 0,
      rules: List.unmodifiable(
        rows.whereType<Map>().map(
          (row) => AvailabilityRule.fromJson(Map<String, dynamic>.from(row)),
        ),
      ),
    );
  }
  final int productId;
  final List<AvailabilityRule> rules;
  @override
  List<Object?> get props => <Object?>[productId, rules];
}

class AvailabilityPreview extends Equatable {
  const AvailabilityPreview({
    required this.isScheduledAvailable,
    required this.reason,
    required this.matchedRuleId,
    required this.matchedScope,
    required this.matchedLevel,
    required this.productVariantId,
    required this.branchId,
    required this.channel,
    required this.timezone,
  });
  factory AvailabilityPreview.fromJson(Map<String, dynamic> json) =>
      AvailabilityPreview(
        isScheduledAvailable: readBool(json['isScheduledAvailable']),
        reason: readString(json['reason']),
        matchedRuleId: readInt(json['matchedRuleId']),
        matchedScope: _optional(json['matchedScope']),
        matchedLevel: _optional(json['matchedLevel']),
        productVariantId: readInt(json['productVariantId']),
        branchId: readInt(json['branchId']),
        channel: _optional(json['channel']),
        timezone: readString(json['timezone']),
      );
  final bool isScheduledAvailable;
  final String reason;
  final int? matchedRuleId;
  final String? matchedScope;
  final String? matchedLevel;
  final int? productVariantId;
  final int? branchId;
  final String? channel;
  final String timezone;
  String get statusLabel => switch (reason) {
    'no_schedule_restriction' => 'Unrestricted',
    'outside_schedule' => 'Outside Schedule',
    _ => isScheduledAvailable ? 'Available' : 'Unavailable',
  };
  @override
  List<Object?> get props => <Object?>[
    isScheduledAvailable,
    reason,
    matchedRuleId,
    matchedScope,
    matchedLevel,
    productVariantId,
    branchId,
    channel,
    timezone,
  ];
}

String? _optional(dynamic value) {
  final String text = readString(value).trim();
  return text.isEmpty ? null : text;
}

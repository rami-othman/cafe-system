// ignore_for_file: use_null_aware_elements

import 'package:equatable/equatable.dart';

import '../../menus/models/menu_models.dart';

class MenuAssignment extends Equatable {
  const MenuAssignment({
    required this.id,
    required this.menuId,
    required this.branchId,
    required this.channel,
    required this.priority,
    required this.isActive,
    required this.createdAt,
    required this.updatedAt,
    this.menu,
  });

  factory MenuAssignment.fromJson(Map<String, dynamic> json) => MenuAssignment(
    id: _int(json['id']),
    menuId: _int(json['menuId']),
    branchId: _int(json['branchId']),
    channel: (json['channel'] ?? '').toString(),
    priority: _int(json['priority'], fallback: 0),
    isActive: json['isActive'] != false,
    createdAt: _date(json['createdAt']),
    updatedAt: _date(json['updatedAt']),
    menu: json['menu'] is Map
        ? MenuRecord.fromJson(Map<String, dynamic>.from(json['menu'] as Map))
        : null,
  );

  final int id, menuId, branchId, priority;
  final String channel;
  final bool isActive;
  final DateTime? createdAt, updatedAt;
  final MenuRecord? menu;

  MenuAssignment copyWith({int? priority, bool? isActive, MenuRecord? menu}) =>
      MenuAssignment(
        id: id,
        menuId: menuId,
        branchId: branchId,
        channel: channel,
        priority: priority ?? this.priority,
        isActive: isActive ?? this.isActive,
        createdAt: createdAt,
        updatedAt: updatedAt,
        menu: menu ?? this.menu,
      );

  @override
  List<Object?> get props => <Object?>[
    id,
    menuId,
    branchId,
    channel,
    priority,
    isActive,
    createdAt,
    updatedAt,
    menu,
  ];
}

class MenuAssignmentDraft {
  const MenuAssignmentDraft({
    required this.menuId,
    required this.priority,
    required this.isActive,
  });
  final int menuId, priority;
  final bool isActive;
  Map<String, dynamic> toJson() => <String, dynamic>{
    'menuId': menuId,
    'priority': priority,
    'isActive': isActive,
  };
}

class MenuScheduleRule extends Equatable {
  const MenuScheduleRule({
    required this.id,
    required this.branchId,
    required this.channel,
    required this.dayOfWeek,
    required this.startTime,
    required this.endTime,
    required this.startDate,
    required this.endDate,
    required this.priority,
    required this.isActive,
    required this.createdAt,
    required this.updatedAt,
  });

  factory MenuScheduleRule.fromJson(Map<String, dynamic> json) =>
      MenuScheduleRule(
        id: _int(json['id']),
        branchId: _nullableInt(json['branchId']),
        channel: _nullableString(json['channel']),
        dayOfWeek: _nullableInt(json['dayOfWeek']),
        startTime: _nullableString(json['startTime']),
        endTime: _nullableString(json['endTime']),
        startDate: _nullableString(json['startDate']),
        endDate: _nullableString(json['endDate']),
        priority: _int(json['priority'], fallback: 0),
        isActive: json['isActive'] != false,
        createdAt: _date(json['createdAt']),
        updatedAt: _date(json['updatedAt']),
      );

  final int id, priority;
  final int? branchId, dayOfWeek;
  final String? channel, startTime, endTime, startDate, endDate;
  final bool isActive;
  final DateTime? createdAt, updatedAt;
  bool get isOvernight =>
      startTime != null &&
      endTime != null &&
      endTime!.compareTo(startTime!) < 0;
  bool matchesExactScope(int branch, String salesChannel) =>
      branchId == branch && channel == salesChannel;
  MenuScheduleRuleDraft toDraft() => MenuScheduleRuleDraft(
    dayOfWeek: dayOfWeek,
    startTime: startTime ?? '',
    endTime: endTime ?? '',
    startDate: startDate ?? '',
    endDate: endDate ?? '',
    priority: '$priority',
    isActive: isActive,
  );
  Map<String, dynamic> toSyncJson() => MenuScheduleRuleDraft(
    dayOfWeek: dayOfWeek,
    startTime: startTime ?? '',
    endTime: endTime ?? '',
    startDate: startDate ?? '',
    endDate: endDate ?? '',
    priority: '$priority',
    isActive: isActive,
  ).toJson(branchId: branchId, channel: channel);

  @override
  List<Object?> get props => <Object?>[
    id,
    branchId,
    channel,
    dayOfWeek,
    startTime,
    endTime,
    startDate,
    endDate,
    priority,
    isActive,
    createdAt,
    updatedAt,
  ];
}

class MenuScheduleRuleDraft {
  const MenuScheduleRuleDraft({
    this.dayOfWeek,
    this.startTime = '',
    this.endTime = '',
    this.startDate = '',
    this.endDate = '',
    this.priority = '0',
    this.isActive = true,
  });
  final int? dayOfWeek;
  final String startTime, endTime, startDate, endDate, priority;
  final bool isActive;
  MenuScheduleRuleDraft copyWith({
    int? dayOfWeek,
    bool clearDay = false,
    String? startTime,
    String? endTime,
    String? startDate,
    String? endDate,
    String? priority,
    bool? isActive,
  }) => MenuScheduleRuleDraft(
    dayOfWeek: clearDay ? null : dayOfWeek ?? this.dayOfWeek,
    startTime: startTime ?? this.startTime,
    endTime: endTime ?? this.endTime,
    startDate: startDate ?? this.startDate,
    endDate: endDate ?? this.endDate,
    priority: priority ?? this.priority,
    isActive: isActive ?? this.isActive,
  );

  Map<String, dynamic> toJson({int? branchId, String? channel}) =>
      <String, dynamic>{
        if (branchId != null) 'branchId': branchId,
        if (channel != null) 'channel': channel,
        if (dayOfWeek != null) 'dayOfWeek': dayOfWeek,
        if (startTime.trim().isNotEmpty) 'startTime': startTime.trim(),
        if (endTime.trim().isNotEmpty) 'endTime': endTime.trim(),
        if (startDate.trim().isNotEmpty) 'startDate': startDate.trim(),
        if (endDate.trim().isNotEmpty) 'endDate': endDate.trim(),
        'priority': int.tryParse(priority.trim()) ?? 0,
        'isActive': isActive,
      };
}

int _int(dynamic value, {int fallback = 0}) =>
    value is int ? value : int.tryParse('${value ?? ''}') ?? fallback;
int? _nullableInt(dynamic value) => value == null ? null : _int(value);
String? _nullableString(dynamic value) => value == null ? null : '$value';
DateTime? _date(dynamic value) =>
    value == null ? null : DateTime.tryParse('$value')?.toLocal();

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

  factory MenuAssignment.fromJson(Map<String, dynamic> json) {
    final dynamic menu = json['menu'];
    if (menu is! Map) {
      throw const FormatException(
        'Menu assignment response is missing its embedded menu summary.',
      );
    }
    return MenuAssignment(
      id: _requiredInt(json, 'id'),
      menuId: _requiredInt(json, 'menuId'),
      branchId: _requiredInt(json, 'branchId'),
      channel: _requiredString(json, 'channel'),
      priority: _requiredInt(json, 'priority'),
      isActive: _requiredBool(json, 'isActive'),
      createdAt: _date(json['createdAt']),
      updatedAt: _date(json['updatedAt']),
      menu: MenuRecord.fromJson(Map<String, dynamic>.from(menu)),
    );
  }

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

  /// Complete-replacement sync must preserve the API's nullable contract.
  /// Send every supported field explicitly: omission is not used to express
  /// an unrestricted day, all-day availability, or an absent date limit.
  Map<String, dynamic> toSyncJson() => <String, dynamic>{
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
int _requiredInt(Map<String, dynamic> json, String key) {
  final int? value = int.tryParse('${json[key] ?? ''}');
  if (value == null) {
    throw FormatException('Menu assignment response is missing $key.');
  }
  return value;
}

String _requiredString(Map<String, dynamic> json, String key) {
  final String value = '${json[key] ?? ''}'.trim();
  if (value.isEmpty) {
    throw FormatException('Menu assignment response is missing $key.');
  }
  return value;
}

bool _requiredBool(Map<String, dynamic> json, String key) {
  final dynamic value = json[key];
  if (value is bool) return value;
  if (value is num) return value != 0;
  if (value is String) {
    return switch (value.toLowerCase()) {
      'true' || '1' => true,
      'false' || '0' => false,
      _ => throw FormatException('Menu assignment response has invalid $key.'),
    };
  }
  throw FormatException('Menu assignment response is missing $key.');
}

int? _nullableInt(dynamic value) => value == null ? null : _int(value);
String? _nullableString(dynamic value) => value == null ? null : '$value';
DateTime? _date(dynamic value) =>
    value == null ? null : DateTime.tryParse('$value')?.toLocal();

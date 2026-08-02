// ignore_for_file: curly_braces_in_flow_control_structures

import 'dart:ui';

import 'package:windows_application/core/utils/localized_entity_text.dart';

import '../../models/catalog_models.dart';
import '../../../pos/models/json_helpers.dart';

int _id(JsonMap json, String key) {
  final int? value = readInt(json[key]);
  if (value == null)
    throw FormatException('Modifier response is missing $key.');
  return value;
}

String _name(JsonMap json) {
  final String value = readString(json['name']).trim();
  if (value.isEmpty)
    throw const FormatException('Modifier response is missing name.');
  return value;
}

String? _nullable(dynamic value) {
  final String text = readString(value).trim();
  return text.isEmpty ? null : text;
}

DateTime? _date(dynamic value) =>
    DateTime.tryParse(readString(value))?.toLocal();

class ModifierOptionRecord {
  const ModifierOptionRecord({
    required this.id,
    this.modifierGroupId,
    required this.name,
    this.nameAr,
    this.nameEn,
    required this.priceDelta,
    required this.isDefault,
    required this.isActive,
    required this.isAvailable,
    required this.sortOrder,
    this.archivedAt,
  });
  factory ModifierOptionRecord.fromJson(JsonMap json) => ModifierOptionRecord(
    id: _id(json, 'id'),
    modifierGroupId: readInt(json['modifierGroupId']),
    name: _name(json),
    nameAr: _nullable(json['nameAr']),
    nameEn: _nullable(json['nameEn']),
    priceDelta: readDouble(json['priceDelta']),
    isDefault: readBool(json['isDefault']),
    isActive: readBool(json['isActive'], fallback: true),
    isAvailable: readBool(json['isAvailable'], fallback: true),
    sortOrder: readInt(json['sortOrder']) ?? 0,
    archivedAt: _date(json['archivedAt']),
  );
  final int id;
  final int? modifierGroupId;
  final String name;
  final String? nameAr;
  final String? nameEn;
  final double priceDelta;
  final bool isDefault;
  final bool isActive;
  final bool isAvailable;
  final int sortOrder;
  final DateTime? archivedAt;
  bool get isArchived => archivedAt != null;
  String get localizedName => nameEn ?? nameAr ?? name;
  String displayName(Locale locale) => LocalizedEntityText.resolve(
    locale: locale,
    defaultValue: name,
    arabicValue: nameAr,
    englishValue: nameEn,
  );
}

class ModifierGroupRecord {
  const ModifierGroupRecord({
    required this.id,
    required this.name,
    this.nameAr,
    this.nameEn,
    this.code,
    required this.groupType,
    required this.selectionType,
    required this.isRequired,
    required this.minSelections,
    required this.maxSelections,
    required this.allowQuantity,
    required this.isActive,
    required this.sortOrder,
    required this.optionCount,
    this.activeOptionCount,
    required this.options,
    this.archivedAt,
    this.createdAt,
    this.updatedAt,
  });
  factory ModifierGroupRecord.fromJson(JsonMap json) {
    final dynamic rawOptions = json['options'];
    return ModifierGroupRecord(
      id: _id(json, 'id'),
      name: _name(json),
      nameAr: _nullable(json['nameAr']),
      nameEn: _nullable(json['nameEn']),
      code: _nullable(json['code']),
      groupType: readString(json['groupType'], fallback: 'choice'),
      selectionType: readString(json['selectionType'], fallback: 'single'),
      isRequired: readBool(json['isRequired']),
      minSelections: readInt(json['minSelections']) ?? 0,
      maxSelections: readInt(json['maxSelections']) ?? 1,
      allowQuantity: readBool(json['allowQuantity']),
      isActive: readBool(json['isActive'], fallback: true),
      sortOrder: readInt(json['sortOrder']) ?? 0,
      optionCount: readInt(json['optionCount']) ?? 0,
      activeOptionCount: readInt(json['activeOptionCount']),
      options: rawOptions is List
          ? rawOptions
                .whereType<Map>()
                .map(
                  (e) => ModifierOptionRecord.fromJson(
                    Map<String, dynamic>.from(e),
                  ),
                )
                .toList(growable: false)
          : const <ModifierOptionRecord>[],
      archivedAt: _date(json['archivedAt']),
      createdAt: _date(json['createdAt']),
      updatedAt: _date(json['updatedAt']),
    );
  }
  final int id;
  final String name;
  final String? nameAr;
  final String? nameEn;
  final String? code;
  final String groupType;
  final String selectionType;
  final bool isRequired;
  final int minSelections;
  final int maxSelections;
  final bool allowQuantity;
  final bool isActive;
  final int sortOrder;
  final int optionCount;
  final int? activeOptionCount;
  final List<ModifierOptionRecord> options;
  final DateTime? archivedAt;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  bool get isArchived => archivedAt != null;
  String get localizedName => nameEn ?? nameAr ?? name;
  String displayName(Locale locale) => LocalizedEntityText.resolve(
    locale: locale,
    defaultValue: name,
    arabicValue: nameAr,
    englishValue: nameEn,
  );
}

class ModifierGroupFilter {
  const ModifierGroupFilter({
    this.search = '',
    this.status = 'active',
    this.groupType,
    this.selectionType,
  });
  final String search;
  final String status;
  final String? groupType;
  final String? selectionType;
  bool get hasActiveFilters =>
      search.trim().isNotEmpty ||
      status != 'active' ||
      groupType != null ||
      selectionType != null;
  ModifierGroupFilter copyWith({
    String? search,
    String? status,
    String? groupType,
    String? selectionType,
    bool clearGroupType = false,
    bool clearSelectionType = false,
  }) => ModifierGroupFilter(
    search: search ?? this.search,
    status: status ?? this.status,
    groupType: clearGroupType ? null : groupType ?? this.groupType,
    selectionType: clearSelectionType
        ? null
        : selectionType ?? this.selectionType,
  );
}

class ModifierReorderItem {
  const ModifierReorderItem(this.id, this.sortOrder);
  final int id;
  final int sortOrder;
  Map<String, dynamic> toJson() => <String, dynamic>{
    'id': id,
    'sortOrder': sortOrder,
  };
}

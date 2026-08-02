import 'dart:ui';

import 'package:windows_application/core/utils/localized_entity_text.dart';

import '../../../pos/models/json_helpers.dart';

typedef MenuJson = Map<String, dynamic>;

int _id(MenuJson json, String key) {
  final int? value = readInt(json[key]);
  if (value == null) throw FormatException('Menu response is missing $key.');
  return value;
}

String _name(MenuJson json) {
  final String value = readString(json['name']).trim();
  if (value.isEmpty)
    throw const FormatException('Menu response is missing name.');
  return value;
}

DateTime? _date(dynamic value) =>
    DateTime.tryParse(readString(value))?.toLocal();

class MenuRecord {
  const MenuRecord({
    required this.id,
    required this.name,
    required this.nameAr,
    required this.nameEn,
    required this.description,
    required this.descriptionAr,
    required this.descriptionEn,
    required this.coverImageUrl,
    required this.status,
    required this.priority,
    required this.sectionCount,
    required this.visibleProductCount,
    required this.archivedAt,
    required this.createdAt,
    required this.updatedAt,
    this.sections = const <MenuSectionRecord>[],
  });

  factory MenuRecord.fromJson(MenuJson json) => MenuRecord(
    id: _id(json, 'id'),
    name: _name(json),
    nameAr: readString(json['nameAr']),
    nameEn: readString(json['nameEn']),
    description: readString(json['description']),
    descriptionAr: readString(json['descriptionAr']),
    descriptionEn: readString(json['descriptionEn']),
    coverImageUrl: readString(json['coverImageUrl']),
    status: readString(json['status'], fallback: 'draft'),
    priority: readInt(json['priority']) ?? 0,
    sectionCount: readInt(json['sectionCount']) ?? 0,
    visibleProductCount: readInt(json['visibleProductCount']) ?? 0,
    archivedAt: _date(json['archivedAt']),
    createdAt: _date(json['createdAt']),
    updatedAt: _date(json['updatedAt']),
    sections: readMapList(
      json['sections'],
    ).map(MenuSectionRecord.fromJson).toList(growable: false),
  );

  final int id;
  final String name,
      nameAr,
      nameEn,
      description,
      descriptionAr,
      descriptionEn,
      coverImageUrl,
      status;
  final int priority, sectionCount, visibleProductCount;
  final DateTime? archivedAt, createdAt, updatedAt;
  final List<MenuSectionRecord> sections;
  bool get isArchived => archivedAt != null || status == 'archived';
  String get localizedName => nameEn.isNotEmpty ? nameEn : name;
  String displayName(Locale locale) => LocalizedEntityText.resolve(
    locale: locale,
    defaultValue: name,
    arabicValue: nameAr,
    englishValue: nameEn,
  );
}

class MenuSectionRecord {
  const MenuSectionRecord({
    required this.id,
    required this.menuId,
    required this.name,
    required this.nameAr,
    required this.nameEn,
    required this.description,
    required this.imageUrl,
    required this.isActive,
    required this.sortOrder,
    required this.placementCount,
    required this.archivedAt,
    required this.createdAt,
    required this.updatedAt,
  });

  factory MenuSectionRecord.fromJson(MenuJson json) => MenuSectionRecord(
    id: _id(json, 'id'),
    menuId: _id(json, 'menuId'),
    name: _name(json),
    nameAr: readString(json['nameAr']),
    nameEn: readString(json['nameEn']),
    description: readString(json['description']),
    imageUrl: readString(json['imageUrl']),
    isActive: readBool(json['isActive'], fallback: true),
    sortOrder: readInt(json['sortOrder']) ?? 0,
    placementCount: readInt(json['placementCount']) ?? 0,
    archivedAt: _date(json['archivedAt']),
    createdAt: _date(json['createdAt']),
    updatedAt: _date(json['updatedAt']),
  );

  final int id, menuId, sortOrder, placementCount;
  final String name, nameAr, nameEn, description, imageUrl;
  final bool isActive;
  final DateTime? archivedAt, createdAt, updatedAt;
  bool get isArchived => archivedAt != null;
  String get localizedName => nameEn.isNotEmpty ? nameEn : name;
  String displayName(Locale locale) => LocalizedEntityText.resolve(
    locale: locale,
    defaultValue: name,
    arabicValue: nameAr,
    englishValue: nameEn,
  );
}

class MenuSectionReorderItem {
  const MenuSectionReorderItem({required this.id, required this.sortOrder});
  final int id, sortOrder;
  Map<String, dynamic> toJson() => <String, dynamic>{
    'id': id,
    'sortOrder': sortOrder,
  };
}

// ignore_for_file: curly_braces_in_flow_control_structures

// ignore_for_file: curly_braces_in_flow_control_structures

import 'dart:ui';

import 'package:windows_application/core/utils/localized_entity_text.dart';

import '../../modifiers/models/modifier_models.dart';
import '../../models/catalog_models.dart';
import '../../../pos/models/json_helpers.dart';

int _assignmentId(JsonMap json, String key) {
  final int? value = readInt(json[key]);
  if (value == null)
    throw FormatException('Product modifier response is missing $key.');
  return value;
}

/// The product-assignment view of a central modifier group.  Defaults belong
/// to the library; nullable overrides belong only to this product.
class ProductModifierAssignment {
  const ProductModifierAssignment({
    required this.modifierGroupId,
    required this.name,
    this.nameAr,
    this.nameEn,
    required this.groupType,
    required this.selectionType,
    required this.isActive,
    this.archivedAt,
    required this.activeOptionCount,
    required this.libraryIsRequired,
    required this.libraryMinSelections,
    required this.libraryMaxSelections,
    required this.libraryAllowQuantity,
    required this.sortOrder,
    this.isRequiredOverride,
    this.minSelectionsOverride,
    this.maxSelectionsOverride,
    this.allowQuantityOverride,
  });

  factory ProductModifierAssignment.fromJson(JsonMap json) =>
      ProductModifierAssignment(
        modifierGroupId: _assignmentId(json, 'id'),
        name: readString(json['name']),
        nameAr: _text(json['nameAr']),
        nameEn: _text(json['nameEn']),
        groupType: readString(json['groupType'], fallback: 'choice'),
        selectionType: readString(json['selectionType'], fallback: 'single'),
        isActive: readBool(json['isActive'], fallback: true),
        archivedAt: _date(json['archivedAt']),
        activeOptionCount:
            readInt(json['activeOptionCount']) ??
            _activeOptions(json['options']),
        libraryIsRequired: readBool(json['isRequired']),
        libraryMinSelections: readInt(json['minSelections']) ?? 0,
        libraryMaxSelections: readInt(json['maxSelections']) ?? 0,
        libraryAllowQuantity: readBool(json['allowQuantity']),
        sortOrder: readInt(json['sortOrder']) ?? 0,
        isRequiredOverride: json['isRequiredOverride'] as bool?,
        minSelectionsOverride: readInt(json['minSelectionsOverride']),
        maxSelectionsOverride: readInt(json['maxSelectionsOverride']),
        allowQuantityOverride: json['allowQuantityOverride'] as bool?,
      );

  factory ProductModifierAssignment.fromLibrary(
    ModifierGroupRecord group, {
    required int sortOrder,
  }) => ProductModifierAssignment(
    modifierGroupId: group.id,
    name: group.name,
    nameAr: group.nameAr,
    nameEn: group.nameEn,
    groupType: group.groupType,
    selectionType: group.selectionType,
    isActive: group.isActive,
    archivedAt: group.archivedAt,
    activeOptionCount:
        group.activeOptionCount ??
        group.options.where((item) => item.isActive && !item.isArchived).length,
    libraryIsRequired: group.isRequired,
    libraryMinSelections: group.minSelections,
    libraryMaxSelections: group.maxSelections,
    libraryAllowQuantity: group.allowQuantity,
    sortOrder: sortOrder,
  );

  final int modifierGroupId;
  final String name;
  final String? nameAr;
  final String? nameEn;
  final String groupType;
  final String selectionType;
  final bool isActive;
  final DateTime? archivedAt;
  final int activeOptionCount;
  final bool libraryIsRequired;
  final int libraryMinSelections;
  final int libraryMaxSelections;
  final bool libraryAllowQuantity;
  final int sortOrder;
  final bool? isRequiredOverride;
  final int? minSelectionsOverride;
  final int? maxSelectionsOverride;
  final bool? allowQuantityOverride;

  bool get isArchived => archivedAt != null;
  bool get effectiveIsRequired => isRequiredOverride ?? libraryIsRequired;
  int get effectiveMinSelections =>
      minSelectionsOverride ?? libraryMinSelections;
  int get effectiveMaxSelections =>
      maxSelectionsOverride ?? libraryMaxSelections;
  bool get effectiveAllowQuantity =>
      allowQuantityOverride ?? libraryAllowQuantity;
  String get localizedName => nameEn ?? nameAr ?? name;
  String displayName(Locale locale) => LocalizedEntityText.resolve(
    locale: locale,
    defaultValue: name,
    arabicValue: nameAr,
    englishValue: nameEn,
  );

  ProductModifierAssignment copyWith({
    int? sortOrder,
    bool? isRequiredOverride,
    int? minSelectionsOverride,
    int? maxSelectionsOverride,
    bool? allowQuantityOverride,
    bool clearRequired = false,
    bool clearMinimum = false,
    bool clearMaximum = false,
    bool clearAllowQuantity = false,
  }) => ProductModifierAssignment(
    modifierGroupId: modifierGroupId,
    name: name,
    nameAr: nameAr,
    nameEn: nameEn,
    groupType: groupType,
    selectionType: selectionType,
    isActive: isActive,
    archivedAt: archivedAt,
    activeOptionCount: activeOptionCount,
    libraryIsRequired: libraryIsRequired,
    libraryMinSelections: libraryMinSelections,
    libraryMaxSelections: libraryMaxSelections,
    libraryAllowQuantity: libraryAllowQuantity,
    sortOrder: sortOrder ?? this.sortOrder,
    isRequiredOverride: clearRequired
        ? null
        : isRequiredOverride ?? this.isRequiredOverride,
    minSelectionsOverride: clearMinimum
        ? null
        : minSelectionsOverride ?? this.minSelectionsOverride,
    maxSelectionsOverride: clearMaximum
        ? null
        : maxSelectionsOverride ?? this.maxSelectionsOverride,
    allowQuantityOverride: clearAllowQuantity
        ? null
        : allowQuantityOverride ?? this.allowQuantityOverride,
  );

  Map<String, dynamic> toSyncJson() => <String, dynamic>{
    'modifierGroupId': modifierGroupId,
    'sortOrder': sortOrder,
    'isRequiredOverride': isRequiredOverride,
    'minSelectionsOverride': minSelectionsOverride,
    'maxSelectionsOverride': maxSelectionsOverride,
    'allowQuantityOverride': allowQuantityOverride,
  };
}

String? _text(dynamic value) {
  final String text = readString(value).trim();
  return text.isEmpty ? null : text;
}

DateTime? _date(dynamic value) =>
    DateTime.tryParse(readString(value))?.toLocal();
int _activeOptions(dynamic value) => value is List
    ? value
          .whereType<Map>()
          .where(
            (item) =>
                readBool(item['isActive'], fallback: true) &&
                item['archivedAt'] == null,
          )
          .length
    : 0;

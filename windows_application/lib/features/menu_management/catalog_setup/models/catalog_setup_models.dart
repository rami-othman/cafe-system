import 'dart:ui';

import 'package:equatable/equatable.dart';

import '../../../../core/utils/localized_entity_text.dart';
import '../../models/catalog_models.dart';
import '../../../pos/models/json_helpers.dart';

enum CatalogSetupKind { categories, reportingCategories, kitchenStations }

enum CatalogSetupStatus { active, archived, all }

const int catalogSetupPageSize = 5;

extension CatalogSetupKindPath on CatalogSetupKind {
  String get path => switch (this) {
    CatalogSetupKind.categories => 'categories',
    CatalogSetupKind.reportingCategories => 'reporting-categories',
    CatalogSetupKind.kitchenStations => 'kitchen-stations',
  };

  String get queryValue => switch (this) {
    CatalogSetupKind.categories => 'categories',
    CatalogSetupKind.reportingCategories => 'reporting-categories',
    CatalogSetupKind.kitchenStations => 'kitchen-stations',
  };

  static CatalogSetupKind fromQuery(String? value) => switch (value) {
    'reporting-categories' => CatalogSetupKind.reportingCategories,
    'kitchen-stations' => CatalogSetupKind.kitchenStations,
    _ => CatalogSetupKind.categories,
  };
}

extension CatalogSetupStatusValue on CatalogSetupStatus {
  String get value => name;
}

class CatalogSetupRecord extends Equatable {
  const CatalogSetupRecord({
    required this.id,
    required this.name,
    required this.nameAr,
    required this.nameEn,
    required this.description,
    required this.code,
    required this.printerName,
    required this.branchId,
    required this.isActive,
    required this.isArchived,
    required this.sortOrder,
    required this.productCount,
  });

  factory CatalogSetupRecord.fromJson(Map<String, dynamic> json) =>
      CatalogSetupRecord(
        id: readInt(json['id']) ?? 0,
        name: readString(json['name']),
        nameAr: readString(json['nameAr']),
        nameEn: readString(json['nameEn']),
        description: readString(json['description']),
        code: readString(json['code']),
        printerName: readString(json['printerName']),
        branchId: readInt(json['branchId']),
        isActive: readBool(json['isActive'], fallback: true),
        isArchived: readBool(json['isArchived']),
        sortOrder: readInt(json['sortOrder']) ?? 0,
        productCount: readInt(json['productCount']) ?? 0,
      );

  final int id;
  final String name;
  final String nameAr;
  final String nameEn;
  final String description;
  final String code;
  final String printerName;
  final int? branchId;
  final bool isActive;
  final bool isArchived;
  final int sortOrder;
  final int productCount;

  String displayName(Locale locale) => LocalizedEntityText.resolve(
    locale: locale,
    defaultValue: name,
    arabicValue: nameAr,
    englishValue: nameEn,
  );

  @override
  List<Object?> get props => <Object?>[
    id,
    name,
    nameAr,
    nameEn,
    description,
    code,
    printerName,
    branchId,
    isActive,
    isArchived,
    sortOrder,
    productCount,
  ];
}

class CatalogSetupDraft extends Equatable {
  const CatalogSetupDraft({
    this.name = '',
    this.nameAr = '',
    this.nameEn = '',
    this.description = '',
    this.code = '',
    this.printerName = '',
    this.branchId,
    this.isActive = true,
  });

  factory CatalogSetupDraft.fromRecord(CatalogSetupRecord record) =>
      CatalogSetupDraft(
        name: record.name,
        nameAr: record.nameAr,
        nameEn: record.nameEn,
        description: record.description,
        code: record.code,
        printerName: record.printerName,
        branchId: record.branchId,
        isActive: record.isActive,
      );

  final String name;
  final String nameAr;
  final String nameEn;
  final String description;
  final String code;
  final String printerName;
  final int? branchId;
  final bool isActive;

  Map<String, dynamic> toJson(CatalogSetupKind kind) => <String, dynamic>{
    'name': name.trim(),
    'nameAr': nameAr.trim().isEmpty ? null : nameAr.trim(),
    'nameEn': nameEn.trim().isEmpty ? null : nameEn.trim(),
    if (kind != CatalogSetupKind.categories) ...<String, dynamic>{
      'code': code.trim().isEmpty ? null : code.trim(),
    } else
      'description': description.trim().isEmpty ? null : description.trim(),
    if (kind == CatalogSetupKind.reportingCategories)
      'description': description.trim().isEmpty ? null : description.trim(),
    if (kind == CatalogSetupKind.kitchenStations) ...<String, dynamic>{
      if (branchId != null) 'branchId': branchId,
      'printerName': printerName.trim().isEmpty ? null : printerName.trim(),
    },
    'isActive': isActive,
  };

  @override
  List<Object?> get props => <Object?>[
    name,
    nameAr,
    nameEn,
    description,
    code,
    printerName,
    branchId,
    isActive,
  ];
}

class CatalogSetupPage extends Equatable {
  const CatalogSetupPage({required this.items, required this.meta});
  final List<CatalogSetupRecord> items;
  final CatalogPagination meta;
  @override
  List<Object?> get props => <Object?>[items, meta.currentPage, meta.total];
}

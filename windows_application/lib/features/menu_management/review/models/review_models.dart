import 'package:equatable/equatable.dart';

import '../../../pos/models/json_helpers.dart';

/// The only client context accepted by the validation and preview endpoints.
class ReviewContext extends Equatable {
  const ReviewContext({
    required this.branchId,
    required this.channel,
    this.menuId,
    this.evaluationAt,
    this.language = 'default',
    this.includeHidden = false,
    this.includeUnavailable = true,
  });

  final int branchId;
  final String channel;
  final int? menuId;
  final DateTime? evaluationAt;
  final String language;
  final bool includeHidden;
  final bool includeUnavailable;

  bool get isCollection => menuId == null;

  Map<String, dynamic> validationJson() => <String, dynamic>{
    'branchId': branchId,
    'channel': channel,
    if (evaluationAt != null) 'at': evaluationAt!.toIso8601String(),
  };

  Map<String, dynamic> previewJson() => <String, dynamic>{
    'branchId': branchId,
    'channel': channel,
    'language': language,
    'includeHidden': includeHidden,
    'includeUnavailable': includeUnavailable,
    if (evaluationAt != null) 'at': evaluationAt!.toIso8601String(),
  };

  @override
  List<Object?> get props => <Object?>[
    branchId,
    channel,
    menuId,
    evaluationAt,
    language,
    includeHidden,
    includeUnavailable,
  ];
}

enum ValidationSeverity { error, warning, information, unknown }

ValidationSeverity validationSeverity(String value) => switch (value) {
  'error' => ValidationSeverity.error,
  'warning' => ValidationSeverity.warning,
  'information' => ValidationSeverity.information,
  _ => ValidationSeverity.unknown,
};

class ValidationIssue extends Equatable {
  const ValidationIssue({
    required this.code,
    required this.severity,
    required this.message,
    required this.entityType,
    this.entityId,
    required this.menuId,
    this.sectionId,
    this.placementId,
    this.metadata = const <String, dynamic>{},
  });

  factory ValidationIssue.fromJson(Map<String, dynamic> json) =>
      ValidationIssue(
        code: readString(json['code'], fallback: 'unknown'),
        severity: readString(json['severity'], fallback: 'information'),
        message: readString(json['message'], fallback: 'No details provided.'),
        entityType: readString(json['entityType'], fallback: 'unknown'),
        entityId: readInt(json['entityId']),
        menuId: readInt(json['menuId']) ?? 0,
        sectionId: readInt(json['sectionId']),
        placementId: readInt(json['placementId']),
        metadata: json['metadata'] is Map
            ? Map<String, dynamic>.from(json['metadata'] as Map)
            : const <String, dynamic>{},
      );

  final String code;
  final String severity;
  final String message;
  final String entityType;
  final int? entityId;
  final int menuId;
  final int? sectionId;
  final int? placementId;
  final Map<String, dynamic> metadata;

  ValidationSeverity get severityValue => validationSeverity(severity);

  @override
  List<Object?> get props => <Object?>[
    code,
    severity,
    message,
    entityType,
    entityId,
    menuId,
    sectionId,
    placementId,
    metadata,
  ];
}

class MenuValidationResult extends Equatable {
  const MenuValidationResult({
    required this.isValid,
    required this.errorCount,
    required this.warningCount,
    required this.informationCount,
    required this.errors,
    required this.warnings,
    required this.information,
  });

  factory MenuValidationResult.fromJson(Map<String, dynamic> json) =>
      MenuValidationResult(
        isValid: readBool(json['isValid']),
        errorCount: readInt(json['errorCount']) ?? 0,
        warningCount: readInt(json['warningCount']) ?? 0,
        informationCount: readInt(json['informationCount']) ?? 0,
        errors: _issues(json['errors']),
        warnings: _issues(json['warnings']),
        information: _issues(json['information']),
      );

  final bool isValid;
  final int errorCount;
  final int warningCount;
  final int informationCount;
  final List<ValidationIssue> errors;
  final List<ValidationIssue> warnings;
  final List<ValidationIssue> information;

  /// Laravel returns `isValid`; it is its authoritative publishability result.
  bool get canPublish => isValid;
  List<ValidationIssue> get issues => <ValidationIssue>[
    ...errors,
    ...warnings,
    ...information,
  ];

  @override
  List<Object?> get props => <Object?>[
    isValid,
    errorCount,
    warningCount,
    informationCount,
    errors,
    warnings,
    information,
  ];
}

List<ValidationIssue> _issues(dynamic value) => (value as List? ?? const [])
    .whereType<Map>()
    .map(
      (Map item) => ValidationIssue.fromJson(Map<String, dynamic>.from(item)),
    )
    .toList(growable: false);

class ResolvedPreview extends Equatable {
  const ResolvedPreview({
    required this.canPublish,
    required this.timezone,
    required this.evaluatedAt,
    required this.menus,
  });

  factory ResolvedPreview.fromJson(Map<String, dynamic> json) {
    final Map? context = json['context'] as Map?;
    final dynamic menus = json['menus'];
    if (context == null || menus is! List) {
      throw const FormatException('Invalid menu collection preview response.');
    }
    return ResolvedPreview(
      canPublish: readBool(json['canPublish']),
      timezone: readString(context['timezone']),
      evaluatedAt: readString(context['evaluatedAt']),
      menus: menus
          .whereType<Map>()
          .map(
            (Map item) =>
                ResolvedMenu.fromJson(Map<String, dynamic>.from(item)),
          )
          .toList(growable: false),
    );
  }

  final bool canPublish;
  final String timezone;
  final String evaluatedAt;
  final List<ResolvedMenu> menus;

  @override
  List<Object?> get props => <Object?>[
    canPublish,
    timezone,
    evaluatedAt,
    menus,
  ];
}

/// A deliberately small projection of the single-menu preview contract used
/// by the Menu Schedule drawer. Product, variant, and modifier diagnostics do
/// not participate in this manager-facing schedule check.
class MenuScheduleCheck extends Equatable {
  const MenuScheduleCheck({
    required this.isScheduledAvailable,
    required this.scheduleReason,
  });

  final bool isScheduledAvailable;
  final String scheduleReason;

  @override
  List<Object?> get props => <Object?>[isScheduledAvailable, scheduleReason];
}

/// Metadata returned for the immutable version currently published for a
/// Branch/Channel scope.  The publishing endpoints deliberately do not expose
/// the snapshot payload to this administration workflow.
class PublishedMenuVersion extends Equatable {
  const PublishedMenuVersion({
    required this.id,
    required this.versionNumber,
    required this.checksum,
    required this.status,
    required this.branchId,
    required this.channel,
    required this.publishedAt,
    required this.publicationId,
  });

  factory PublishedMenuVersion.fromJson(Map<String, dynamic> json) =>
      PublishedMenuVersion(
        id: readInt(json['id']) ?? 0,
        versionNumber: readInt(json['versionNumber']) ?? 0,
        checksum: readString(json['checksum']),
        // Keep backend additions safe to render instead of assuming an enum.
        status: readString(json['status'], fallback: 'unknown'),
        branchId: readInt(json['branchId']) ?? 0,
        channel: readString(json['channel'], fallback: 'unknown'),
        publishedAt: readString(json['publishedAt']),
        publicationId: readInt(json['publicationId']),
      );

  final int id;
  final int versionNumber;
  final String checksum;
  final String status;
  final int branchId;
  final String channel;
  final String publishedAt;
  final int? publicationId;

  @override
  List<Object?> get props => <Object?>[
    id,
    versionNumber,
    checksum,
    status,
    branchId,
    channel,
    publishedAt,
    publicationId,
  ];
}

/// The result of a publish attempt.  Version values are server produced: the
/// desktop client never calculates checksums, version numbers, or no-change
/// state.
class MenuPublicationResult extends Equatable {
  const MenuPublicationResult({
    required this.published,
    required this.noChanges,
    required this.publicationId,
    required this.version,
    required this.validation,
  });

  factory MenuPublicationResult.fromJson(Map<String, dynamic> json) {
    final dynamic version = json['version'];
    final dynamic validation = json['validation'];
    if (version is! Map || validation is! Map) {
      throw const FormatException('Invalid menu publication response.');
    }
    return MenuPublicationResult(
      published: readBool(json['published']),
      noChanges: readBool(json['noChanges']),
      publicationId: readInt(json['publicationId']),
      version: PublishedMenuVersion.fromJson(
        Map<String, dynamic>.from(version),
      ),
      validation: MenuValidationResult.fromJson(
        Map<String, dynamic>.from(validation),
      ),
    );
  }

  final bool published;
  final bool noChanges;
  final int? publicationId;
  final PublishedMenuVersion version;
  final MenuValidationResult validation;

  @override
  List<Object?> get props => <Object?>[
    published,
    noChanges,
    publicationId,
    version,
    validation,
  ];
}

class ResolvedMenu extends Equatable {
  const ResolvedMenu({
    required this.id,
    required this.name,
    required this.priority,
    required this.isAssigned,
    required this.isScheduledAvailable,
    required this.scheduleReason,
    required this.sections,
  });

  factory ResolvedMenu.fromJson(Map<String, dynamic> json) => ResolvedMenu(
    id: _requiredPreviewInt(json, 'id'),
    name: readString(json['name'], fallback: 'Unnamed menu'),
    priority: _requiredPreviewInt(json, 'priority'),
    isAssigned: _requiredPreviewBool(json, 'isAssigned'),
    isScheduledAvailable: _requiredPreviewBool(json, 'isScheduledAvailable'),
    scheduleReason: _requiredPreviewString(json, 'scheduleReason'),
    sections: (json['sections'] as List? ?? const [])
        .whereType<Map>()
        .map(
          (Map item) =>
              ResolvedSection.fromJson(Map<String, dynamic>.from(item)),
        )
        .toList(growable: false),
  );

  final int id;
  final String name;
  final int priority;
  final bool isAssigned;
  final bool isScheduledAvailable;
  final String scheduleReason;
  final List<ResolvedSection> sections;

  @override
  List<Object?> get props => <Object?>[
    id,
    name,
    priority,
    isAssigned,
    isScheduledAvailable,
    scheduleReason,
    sections,
  ];
}

class ResolvedSection extends Equatable {
  const ResolvedSection({
    required this.name,
    required this.sortOrder,
    required this.products,
  });
  factory ResolvedSection.fromJson(Map<String, dynamic> json) =>
      ResolvedSection(
        name: readString(json['name'], fallback: 'Unnamed section'),
        sortOrder: readInt(json['sortOrder']) ?? 0,
        products: (json['products'] as List? ?? const [])
            .whereType<Map>()
            .map(
              (Map item) =>
                  ResolvedProduct.fromJson(Map<String, dynamic>.from(item)),
            )
            .toList(growable: false),
      );
  final String name;
  final int sortOrder;
  final List<ResolvedProduct> products;
  @override
  List<Object?> get props => <Object?>[name, sortOrder, products];
}

class ResolvedProduct extends Equatable {
  const ResolvedProduct({
    required this.id,
    required this.name,
    required this.isVisible,
    required this.isScheduledAvailable,
    required this.isOperationallyAvailable,
    required this.isSellable,
    required this.reasons,
    required this.variants,
    required this.modifiers,
  });
  factory ResolvedProduct.fromJson(
    Map<String, dynamic> json,
  ) => ResolvedProduct(
    id: readInt(json['productId']) ?? 0,
    name: readString(json['name'], fallback: 'Unnamed product'),
    isVisible: readBool(json['isVisible']),
    isScheduledAvailable: readBool(json['isScheduledAvailable']),
    isOperationallyAvailable: readBool(json['isOperationallyAvailable']),
    isSellable: readBool(json['isSellable']),
    reasons: _strings(json['unavailabilityReasons']),
    variants: (json['variants'] as List? ?? const [])
        .whereType<Map>()
        .map(
          (Map item) =>
              ResolvedVariant.fromJson(Map<String, dynamic>.from(item)),
        )
        .toList(growable: false),
    modifiers: (json['modifierGroups'] as List? ?? const [])
        .whereType<Map>()
        .map(
          (Map item) =>
              ResolvedModifierGroup.fromJson(Map<String, dynamic>.from(item)),
        )
        .toList(growable: false),
  );
  final int id;
  final String name;
  final bool isVisible;
  final bool isScheduledAvailable;
  final bool isOperationallyAvailable;
  final bool isSellable;
  final List<String> reasons;
  final List<ResolvedVariant> variants;
  final List<ResolvedModifierGroup> modifiers;
  @override
  List<Object?> get props => <Object?>[
    id,
    name,
    isVisible,
    isScheduledAvailable,
    isOperationallyAvailable,
    isSellable,
    reasons,
    variants,
    modifiers,
  ];
}

class ResolvedVariant extends Equatable {
  const ResolvedVariant({
    required this.name,
    required this.effectivePrice,
    required this.priceScope,
    required this.isDefault,
    required this.isScheduledAvailable,
    required this.isOperationallyAvailable,
    required this.isSellable,
    required this.reasons,
  });
  factory ResolvedVariant.fromJson(Map<String, dynamic> json) =>
      ResolvedVariant(
        name: readString(json['name'], fallback: 'Unnamed variant'),
        effectivePrice: readDouble(json['effectivePrice']),
        priceScope: readString(json['matchedPriceScope']),
        isDefault: readBool(json['isDefault']),
        isScheduledAvailable: readBool(json['isScheduledAvailable']),
        isOperationallyAvailable: readBool(json['isOperationallyAvailable']),
        isSellable: readBool(json['isSellable']),
        reasons: _strings(json['unavailabilityReasons']),
      );
  final String name;
  final double effectivePrice;
  final String priceScope;
  final bool isDefault;
  final bool isScheduledAvailable;
  final bool isOperationallyAvailable;
  final bool isSellable;
  final List<String> reasons;
  @override
  List<Object?> get props => <Object?>[
    name,
    effectivePrice,
    priceScope,
    isDefault,
    isScheduledAvailable,
    isOperationallyAvailable,
    isSellable,
    reasons,
  ];
}

class ResolvedModifierGroup extends Equatable {
  const ResolvedModifierGroup({
    required this.name,
    required this.isRequired,
    required this.minSelections,
    required this.maxSelections,
    required this.allowQuantity,
    required this.options,
  });
  factory ResolvedModifierGroup.fromJson(Map<String, dynamic> json) =>
      ResolvedModifierGroup(
        name: readString(json['name'], fallback: 'Unnamed modifier group'),
        isRequired: readBool(json['isRequired']),
        minSelections: readInt(json['minSelections']) ?? 0,
        maxSelections: readInt(json['maxSelections']) ?? 0,
        allowQuantity: readBool(json['allowQuantity']),
        options: (json['options'] as List? ?? const [])
            .whereType<Map>()
            .map(
              (Map item) => ResolvedModifierOption.fromJson(
                Map<String, dynamic>.from(item),
              ),
            )
            .toList(growable: false),
      );
  final String name;
  final bool isRequired;
  final int minSelections;
  final int maxSelections;
  final bool allowQuantity;
  final List<ResolvedModifierOption> options;
  @override
  List<Object?> get props => <Object?>[
    name,
    isRequired,
    minSelections,
    maxSelections,
    allowQuantity,
    options,
  ];
}

class ResolvedModifierOption extends Equatable {
  const ResolvedModifierOption({
    required this.name,
    required this.priceDelta,
    required this.isAvailable,
  });
  factory ResolvedModifierOption.fromJson(Map<String, dynamic> json) =>
      ResolvedModifierOption(
        name: readString(json['name'], fallback: 'Unnamed option'),
        priceDelta: readDouble(json['priceDelta']),
        isAvailable: readBool(json['isAvailable']),
      );
  final String name;
  final double priceDelta;
  final bool isAvailable;
  @override
  List<Object?> get props => <Object?>[name, priceDelta, isAvailable];
}

List<String> _strings(dynamic value) => (value as List? ?? const [])
    .map((dynamic item) => readString(item))
    .where((String item) => item.isNotEmpty)
    .toList(growable: false);

int _requiredPreviewInt(Map<String, dynamic> json, String key) {
  final int? value = readInt(json[key]);
  if (value == null) {
    throw FormatException('Menu collection preview is missing $key.');
  }
  return value;
}

String _requiredPreviewString(Map<String, dynamic> json, String key) {
  final String value = readString(json[key]).trim();
  if (value.isEmpty) {
    throw FormatException('Menu collection preview is missing $key.');
  }
  return value;
}

bool _requiredPreviewBool(Map<String, dynamic> json, String key) {
  final dynamic value = json[key];
  if (value is bool) return value;
  if (value is num) return value != 0;
  if (value is String) {
    return switch (value.toLowerCase()) {
      'true' || '1' => true,
      'false' || '0' => false,
      _ => throw FormatException('Menu collection preview has invalid $key.'),
    };
  }
  throw FormatException('Menu collection preview is missing $key.');
}

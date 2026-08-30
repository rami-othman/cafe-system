import 'json_helpers.dart';

/// The Flutter consumer deliberately supports only the backend POS runtime
/// contract v1. Published snapshot schema versions remain a backend concern.
const int supportedPosRuntimeContractVersion = 1;

class PosMenuContractException implements Exception {
  const PosMenuContractException(this.message);

  final String message;

  @override
  String toString() => message;
}

class PosLocalizedText {
  const PosLocalizedText({this.defaultValue, this.ar, this.en});

  final String? defaultValue;
  final String? ar;
  final String? en;

  factory PosLocalizedText.fromJson(Object? value) {
    final Map<String, dynamic> json = _map(value, 'localized text');
    return PosLocalizedText(
      defaultValue: _nullableString(json['default']),
      ar: _nullableString(json['ar']),
      en: _nullableString(json['en']),
    );
  }

  String resolve(String languageCode) {
    return switch (languageCode.toLowerCase()) {
      'ar' => ar ?? defaultValue ?? en ?? '',
      'en' => en ?? defaultValue ?? ar ?? '',
      _ => defaultValue ?? en ?? ar ?? '',
    };
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
    'default': defaultValue,
    'ar': ar,
    'en': en,
  };
}

class PosMenuContext {
  const PosMenuContext({
    required this.branchId,
    required this.channel,
    required this.timezone,
    required this.currency,
  });

  final int branchId;
  final String channel;
  final String timezone;
  final String currency;

  factory PosMenuContext.fromJson(Object? value) {
    final Map<String, dynamic> json = _map(value, 'context');
    final PosMenuContext context = PosMenuContext(
      branchId: _id(json['branchId'], 'context.branchId'),
      channel: _requiredString(json['channel'], 'context.channel'),
      timezone: _requiredString(json['timezone'], 'context.timezone'),
      currency: _requiredString(json['currency'], 'context.currency'),
    );
    if (context.channel != 'pos') {
      throw PosMenuContractException('Expected POS channel.');
    }
    return context;
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
    'branchId': branchId,
    'channel': channel,
    'timezone': timezone,
    'currency': currency,
  };
}

class PosPublishedMenuVersion {
  const PosPublishedMenuVersion({
    required this.id,
    required this.versionNumber,
    required this.publishedAt,
    required this.sourceSchemaVersion,
    required this.runtimeContractVersion,
  });

  final int id;
  final int versionNumber;
  final DateTime? publishedAt;
  final int sourceSchemaVersion;
  final int runtimeContractVersion;

  factory PosPublishedMenuVersion.fromJson(Object? value) {
    final Map<String, dynamic> json = _map(value, 'version');
    final PosPublishedMenuVersion version = PosPublishedMenuVersion(
      id: _id(json['id'], 'version.id'),
      versionNumber: _id(json['versionNumber'], 'version.versionNumber'),
      publishedAt: _date(json['publishedAt'], 'version.publishedAt'),
      sourceSchemaVersion: _id(
        json['sourceSchemaVersion'],
        'version.sourceSchemaVersion',
      ),
      runtimeContractVersion: _id(
        json['runtimeContractVersion'],
        'version.runtimeContractVersion',
      ),
    );
    if (version.runtimeContractVersion != supportedPosRuntimeContractVersion) {
      throw PosMenuContractException(
        'Unsupported POS runtime contract version ${version.runtimeContractVersion}.',
      );
    }
    return version;
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
    'id': id,
    'versionNumber': versionNumber,
    'publishedAt': publishedAt?.toIso8601String(),
    'sourceSchemaVersion': sourceSchemaVersion,
    'runtimeContractVersion': runtimeContractVersion,
  };
}

class PosStaticMenu {
  const PosStaticMenu({
    required this.id,
    required this.scopeOrder,
    required this.name,
    required this.description,
    required this.coverImageUrl,
    required this.sections,
  });

  final int id;
  final int scopeOrder;
  final PosLocalizedText name;
  final PosLocalizedText description;
  final String? coverImageUrl;
  final List<PosStaticSection> sections;

  factory PosStaticMenu.fromJson(Object? value) {
    final Map<String, dynamic> json = _map(value, 'menu');
    return PosStaticMenu(
      id: _id(json['id'], 'menu.id'),
      scopeOrder: _integer(json['scopeOrder'], 'menu.scopeOrder'),
      name: PosLocalizedText.fromJson(json['name']),
      description: PosLocalizedText.fromJson(json['description']),
      coverImageUrl: _nullableString(json['coverImageUrl']),
      sections: _list(
        json['sections'],
        'menu.sections',
      ).map(PosStaticSection.fromJson).toList(growable: false),
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
    'id': id,
    'scopeOrder': scopeOrder,
    'name': name.toJson(),
    'description': description.toJson(),
    'coverImageUrl': coverImageUrl,
    'sections': sections.map((PosStaticSection item) => item.toJson()).toList(),
  };
}

class PosStaticSection {
  const PosStaticSection({
    required this.id,
    required this.name,
    required this.description,
    required this.imageUrl,
    required this.sortOrder,
    required this.products,
  });

  final int id;
  final PosLocalizedText name;
  final PosLocalizedText description;
  final String? imageUrl;
  final int sortOrder;
  final List<PosProductPlacement> products;

  factory PosStaticSection.fromJson(Object? value) {
    final Map<String, dynamic> json = _map(value, 'section');
    return PosStaticSection(
      id: _id(json['id'], 'section.id'),
      name: PosLocalizedText.fromJson(json['name']),
      description: PosLocalizedText.fromJson(json['description']),
      imageUrl: _nullableString(json['imageUrl']),
      sortOrder: _integer(json['sortOrder'], 'section.sortOrder'),
      products: _list(
        json['products'],
        'section.products',
      ).map(PosProductPlacement.fromJson).toList(growable: false),
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
    'id': id,
    'name': name.toJson(),
    'description': description.toJson(),
    'imageUrl': imageUrl,
    'sortOrder': sortOrder,
    'products': products
        .map((PosProductPlacement item) => item.toJson())
        .toList(),
  };
}

class PosProductPlacement {
  const PosProductPlacement({
    required this.placementId,
    required this.productId,
    required this.name,
    required this.description,
    required this.imageUrl,
    required this.sortOrder,
    required this.isFeatured,
    required this.isVisible,
    required this.variants,
    required this.modifierGroups,
  });

  final int placementId;
  final int productId;
  final PosLocalizedText name;
  final PosLocalizedText description;
  final String? imageUrl;
  final int sortOrder;
  final bool isFeatured;
  final bool isVisible;
  final List<PosPublishedVariant> variants;
  final List<PosModifierGroup> modifierGroups;

  factory PosProductPlacement.fromJson(Object? value) {
    final Map<String, dynamic> json = _map(value, 'placement');
    return PosProductPlacement(
      placementId: _id(json['placementId'], 'placement.placementId'),
      productId: _id(json['productId'], 'placement.productId'),
      name: PosLocalizedText.fromJson(json['name']),
      description: PosLocalizedText.fromJson(json['description']),
      imageUrl: _nullableString(json['imageUrl']),
      sortOrder: _integer(json['sortOrder'], 'placement.sortOrder'),
      isFeatured: _bool(json['isFeatured'], 'placement.isFeatured'),
      isVisible: _bool(json['isVisible'], 'placement.isVisible'),
      variants: _list(
        json['variants'],
        'placement.variants',
      ).map(PosPublishedVariant.fromJson).toList(growable: false),
      modifierGroups: _list(
        json['modifierGroups'],
        'placement.modifierGroups',
      ).map(PosModifierGroup.fromJson).toList(growable: false),
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
    'placementId': placementId,
    'productId': productId,
    'name': name.toJson(),
    'description': description.toJson(),
    'imageUrl': imageUrl,
    'sortOrder': sortOrder,
    'isFeatured': isFeatured,
    'isVisible': isVisible,
    'variants': variants
        .map((PosPublishedVariant item) => item.toJson())
        .toList(),
    'modifierGroups': modifierGroups
        .map((PosModifierGroup item) => item.toJson())
        .toList(),
  };
}

class PosPublishedVariant {
  const PosPublishedVariant({
    required this.id,
    required this.name,
    required this.sku,
    required this.barcode,
    required this.sortOrder,
    required this.isDefault,
    required this.basePrice,
    required this.effectivePrice,
  });

  final int id;
  final PosLocalizedText name;
  final String? sku;
  final String? barcode;
  final int sortOrder;
  final bool isDefault;
  final double? basePrice;
  final double? effectivePrice;

  factory PosPublishedVariant.fromJson(Object? value) {
    final Map<String, dynamic> json = _map(value, 'variant');
    return PosPublishedVariant(
      id: _id(json['id'], 'variant.id'),
      name: PosLocalizedText.fromJson(json['name']),
      sku: _nullableString(json['sku']),
      barcode: _nullableString(json['barcode']),
      sortOrder: _integer(json['sortOrder'], 'variant.sortOrder'),
      isDefault: _bool(json['isDefault'], 'variant.isDefault'),
      basePrice: _money(json['basePrice'], 'variant.basePrice'),
      effectivePrice: _money(json['effectivePrice'], 'variant.effectivePrice'),
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
    'id': id,
    'name': name.toJson(),
    'sku': sku,
    'barcode': barcode,
    'sortOrder': sortOrder,
    'isDefault': isDefault,
    'basePrice': basePrice,
    'effectivePrice': effectivePrice,
  };
}

class PosModifierGroup {
  const PosModifierGroup({
    required this.id,
    required this.name,
    required this.selectionType,
    required this.isRequired,
    required this.minSelections,
    required this.maxSelections,
    required this.allowQuantity,
    required this.sortOrder,
    required this.options,
  });

  final int id;
  final PosLocalizedText name;
  final String? selectionType;
  final bool isRequired;
  final int? minSelections;
  final int? maxSelections;
  final bool allowQuantity;
  final int sortOrder;
  final List<PosModifierOption> options;

  factory PosModifierGroup.fromJson(Object? value) {
    final Map<String, dynamic> json = _map(value, 'modifier group');
    return PosModifierGroup(
      id: _id(json['id'], 'modifierGroup.id'),
      name: PosLocalizedText.fromJson(json['name']),
      selectionType: _nullableString(json['selectionType']),
      isRequired: _bool(json['isRequired'], 'modifierGroup.isRequired'),
      minSelections: _nullableInteger(
        json['minSelections'],
        'modifierGroup.minSelections',
      ),
      maxSelections: _nullableInteger(
        json['maxSelections'],
        'modifierGroup.maxSelections',
      ),
      allowQuantity: _bool(
        json['allowQuantity'],
        'modifierGroup.allowQuantity',
      ),
      sortOrder: _integer(json['sortOrder'], 'modifierGroup.sortOrder'),
      options: _list(
        json['options'],
        'modifierGroup.options',
      ).map(PosModifierOption.fromJson).toList(growable: false),
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
    'id': id,
    'name': name.toJson(),
    'selectionType': selectionType,
    'isRequired': isRequired,
    'minSelections': minSelections,
    'maxSelections': maxSelections,
    'allowQuantity': allowQuantity,
    'sortOrder': sortOrder,
    'options': options.map((PosModifierOption item) => item.toJson()).toList(),
  };
}

class PosModifierOption {
  const PosModifierOption({
    required this.id,
    required this.name,
    required this.priceDelta,
    required this.isDefault,
    required this.isAvailable,
    required this.sortOrder,
  });

  final int id;
  final PosLocalizedText name;
  final double? priceDelta;
  final bool isDefault;
  final bool isAvailable;
  final int sortOrder;

  factory PosModifierOption.fromJson(Object? value) {
    final Map<String, dynamic> json = _map(value, 'modifier option');
    return PosModifierOption(
      id: _id(json['id'], 'modifierOption.id'),
      name: PosLocalizedText.fromJson(json['name']),
      priceDelta: _money(json['priceDelta'], 'modifierOption.priceDelta'),
      isDefault: _bool(json['isDefault'], 'modifierOption.isDefault'),
      isAvailable: _bool(json['isAvailable'], 'modifierOption.isAvailable'),
      sortOrder: _integer(json['sortOrder'], 'modifierOption.sortOrder'),
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
    'id': id,
    'name': name.toJson(),
    'priceDelta': priceDelta,
    'isDefault': isDefault,
    'isAvailable': isAvailable,
    'sortOrder': sortOrder,
  };
}

class PosStaticMenuProjection {
  const PosStaticMenuProjection({required this.menus});

  final List<PosStaticMenu> menus;

  factory PosStaticMenuProjection.fromJson(Object? value) {
    final Map<String, dynamic> json = _map(value, 'menu');
    return PosStaticMenuProjection(
      menus: _list(
        json['menus'],
        'menu.menus',
      ).map(PosStaticMenu.fromJson).toList(growable: false),
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
    'menus': menus.map((PosStaticMenu item) => item.toJson()).toList(),
  };
}

class PosRuntimeMenuState {
  const PosRuntimeMenuState({
    required this.menuId,
    required this.isScheduledAvailable,
    required this.reason,
  });

  final int menuId;
  final bool isScheduledAvailable;
  final String? reason;

  factory PosRuntimeMenuState.fromJson(Object? value) {
    final Map<String, dynamic> json = _map(value, 'runtime menu');
    return PosRuntimeMenuState(
      menuId: _id(json['menuId'], 'runtime.menuId'),
      isScheduledAvailable: _bool(
        json['isScheduledAvailable'],
        'runtime.isScheduledAvailable',
      ),
      reason: _nullableString(json['reason']),
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
    'menuId': menuId,
    'isScheduledAvailable': isScheduledAvailable,
    'reason': reason,
  };
}

class PosRuntimePlacementState {
  const PosRuntimePlacementState({
    required this.placementId,
    required this.productId,
    required this.isScheduledAvailable,
    required this.isOperationallyAvailable,
    required this.isSellable,
    required this.reason,
  });

  final int placementId;
  final int productId;
  final bool isScheduledAvailable;
  final bool isOperationallyAvailable;
  final bool isSellable;
  final String? reason;

  factory PosRuntimePlacementState.fromJson(Object? value) {
    final Map<String, dynamic> json = _map(value, 'runtime placement');
    return PosRuntimePlacementState(
      placementId: _id(json['placementId'], 'runtime.placementId'),
      productId: _id(json['productId'], 'runtime.productId'),
      isScheduledAvailable: _bool(
        json['isScheduledAvailable'],
        'runtime.isScheduledAvailable',
      ),
      isOperationallyAvailable: _bool(
        json['isOperationallyAvailable'],
        'runtime.isOperationallyAvailable',
      ),
      isSellable: _bool(json['isSellable'], 'runtime.isSellable'),
      reason: _nullableString(json['reason']),
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
    'placementId': placementId,
    'productId': productId,
    'isScheduledAvailable': isScheduledAvailable,
    'isOperationallyAvailable': isOperationallyAvailable,
    'isSellable': isSellable,
    'reason': reason,
  };
}

class PosRuntimeVariantState {
  const PosRuntimeVariantState({
    required this.placementId,
    required this.productId,
    required this.variantId,
    required this.isScheduledAvailable,
    required this.isOperationallyAvailable,
    required this.isSellable,
    required this.reason,
    required this.operationalStatus,
    required this.remainingQuantity,
    required this.unavailableUntil,
  });

  final int placementId;
  final int productId;
  final int variantId;
  final bool isScheduledAvailable;
  final bool isOperationallyAvailable;
  final bool isSellable;
  final String? reason;
  final String? operationalStatus;
  final double? remainingQuantity;
  final DateTime? unavailableUntil;

  factory PosRuntimeVariantState.fromJson(Object? value) {
    final Map<String, dynamic> json = _map(value, 'runtime variant');
    return PosRuntimeVariantState(
      placementId: _id(json['placementId'], 'runtime.placementId'),
      productId: _id(json['productId'], 'runtime.productId'),
      variantId: _id(json['variantId'], 'runtime.variantId'),
      isScheduledAvailable: _bool(
        json['isScheduledAvailable'],
        'runtime.isScheduledAvailable',
      ),
      isOperationallyAvailable: _bool(
        json['isOperationallyAvailable'],
        'runtime.isOperationallyAvailable',
      ),
      isSellable: _bool(json['isSellable'], 'runtime.isSellable'),
      reason: _nullableString(json['reason']),
      operationalStatus: _nullableString(json['operationalStatus']),
      remainingQuantity: _money(
        json['remainingQuantity'],
        'runtime.remainingQuantity',
      ),
      unavailableUntil: _date(
        json['unavailableUntil'],
        'runtime.unavailableUntil',
      ),
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
    'placementId': placementId,
    'productId': productId,
    'variantId': variantId,
    'isScheduledAvailable': isScheduledAvailable,
    'isOperationallyAvailable': isOperationallyAvailable,
    'isSellable': isSellable,
    'reason': reason,
    'operationalStatus': operationalStatus,
    'remainingQuantity': remainingQuantity,
    'unavailableUntil': unavailableUntil?.toIso8601String(),
  };
}

class PosRuntimeOverlay {
  const PosRuntimeOverlay({
    required this.evaluatedAt,
    required this.menus,
    required this.placements,
    required this.variants,
  });

  final DateTime evaluatedAt;
  final List<PosRuntimeMenuState> menus;
  final List<PosRuntimePlacementState> placements;
  final List<PosRuntimeVariantState> variants;

  factory PosRuntimeOverlay.fromJson(Object? value) {
    final Map<String, dynamic> json = _map(value, 'runtime');
    final DateTime? evaluatedAt = _date(
      json['evaluatedAt'],
      'runtime.evaluatedAt',
    );
    if (evaluatedAt == null) {
      throw const PosMenuContractException('runtime.evaluatedAt is required.');
    }
    return PosRuntimeOverlay(
      evaluatedAt: evaluatedAt,
      menus: _list(
        json['menus'],
        'runtime.menus',
      ).map(PosRuntimeMenuState.fromJson).toList(growable: false),
      placements: _list(
        json['placements'],
        'runtime.placements',
      ).map(PosRuntimePlacementState.fromJson).toList(growable: false),
      variants: _list(
        json['variants'],
        'runtime.variants',
      ).map(PosRuntimeVariantState.fromJson).toList(growable: false),
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
    'evaluatedAt': evaluatedAt.toIso8601String(),
    'menus': menus.map((PosRuntimeMenuState item) => item.toJson()).toList(),
    'placements': placements
        .map((PosRuntimePlacementState item) => item.toJson())
        .toList(),
    'variants': variants
        .map((PosRuntimeVariantState item) => item.toJson())
        .toList(),
  };
}

class PosPublishedRuntimeMenu {
  const PosPublishedRuntimeMenu({
    required this.context,
    required this.version,
    required this.menu,
    this.runtime,
  });

  final PosMenuContext context;
  final PosPublishedMenuVersion version;
  final PosStaticMenuProjection menu;
  final PosRuntimeOverlay? runtime;

  PosRuntimePlacementState? runtimeForPlacement(int placementId) {
    for (final PosRuntimePlacementState state
        in runtime?.placements ?? const <PosRuntimePlacementState>[]) {
      if (state.placementId == placementId) return state;
    }
    return null;
  }

  PosRuntimeVariantState? runtimeForVariant({
    required int placementId,
    required int variantId,
  }) {
    for (final PosRuntimeVariantState state
        in runtime?.variants ?? const <PosRuntimeVariantState>[]) {
      if (state.placementId == placementId && state.variantId == variantId) {
        return state;
      }
    }
    return null;
  }
}

class PosMenuSyncResponse {
  const PosMenuSyncResponse({
    required this.context,
    required this.upToDate,
    required this.version,
    required this.menu,
    required this.runtime,
  });

  final PosMenuContext context;
  final bool upToDate;
  final PosPublishedMenuVersion? version;
  final PosStaticMenuProjection? menu;
  final PosRuntimeOverlay? runtime;

  factory PosMenuSyncResponse.fromJson(Object? value) {
    final Map<String, dynamic> json = _map(value, 'sync response');
    final PosMenuSyncResponse response = PosMenuSyncResponse(
      context: PosMenuContext.fromJson(json['context']),
      upToDate: _bool(json['upToDate'], 'upToDate'),
      version: json['version'] == null
          ? null
          : PosPublishedMenuVersion.fromJson(json['version']),
      menu: json['menu'] == null
          ? null
          : PosStaticMenuProjection.fromJson(json['menu']),
      runtime: json['runtime'] == null
          ? null
          : PosRuntimeOverlay.fromJson(json['runtime']),
    );
    if (response.version == null) {
      if (response.upToDate ||
          response.menu != null ||
          response.runtime != null) {
        throw const PosMenuContractException(
          'Invalid no-publication response.',
        );
      }
    } else if (response.runtime == null ||
        (response.upToDate && response.menu != null) ||
        (!response.upToDate && response.menu == null)) {
      throw const PosMenuContractException(
        'Invalid published-menu sync response.',
      );
    }
    return response;
  }
}

Map<String, dynamic> _map(Object? value, String field) {
  if (value is Map) return Map<String, dynamic>.from(value);
  throw PosMenuContractException('$field must be an object.');
}

List<Object?> _list(Object? value, String field) {
  if (value is List) return List<Object?>.from(value);
  throw PosMenuContractException('$field must be an array.');
}

int _id(Object? value, String field) {
  final int result = _integer(value, field);
  if (result <= 0) throw PosMenuContractException('$field must be positive.');
  return result;
}

int _integer(Object? value, String field) {
  final int? result = readInt(value);
  if (result == null) {
    throw PosMenuContractException('$field must be an integer.');
  }
  return result;
}

int? _nullableInteger(Object? value, String field) =>
    value == null ? null : _integer(value, field);

bool _bool(Object? value, String field) {
  if (value is bool) return value;
  throw PosMenuContractException('$field must be a boolean.');
}

String _requiredString(Object? value, String field) {
  final String? result = _nullableString(value);
  if (result == null || result.trim().isEmpty) {
    throw PosMenuContractException('$field must be a string.');
  }
  return result;
}

String? _nullableString(Object? value) => value?.toString();

double? _money(Object? value, String field) {
  if (value == null) return null;
  final double? result = value is num
      ? value.toDouble()
      : double.tryParse(value.toString());
  if (result?.isFinite != true) {
    throw PosMenuContractException('$field must be a finite numeric value.');
  }
  return result;
}

DateTime? _date(Object? value, String field) {
  if (value == null) return null;
  final DateTime? result = DateTime.tryParse(value.toString());
  if (result == null) {
    throw PosMenuContractException('$field must be ISO-8601.');
  }
  return result;
}

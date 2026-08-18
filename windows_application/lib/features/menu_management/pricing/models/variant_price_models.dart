import 'package:equatable/equatable.dart';

import '../../../pos/models/json_helpers.dart';

/// A two-decimal monetary amount held as minor units.  This avoids using a
/// binary floating point value for price comparisons and PUT payloads.
class PriceAmount extends Equatable {
  const PriceAmount._(this.minorUnits);

  factory PriceAmount.parse(dynamic value) {
    final String text = value.toString().trim();
    final Match? match = RegExp(r'^(\d+)(?:\.(\d{1,2}))?$').firstMatch(text);
    if (match == null) throw FormatException('Invalid decimal price.');
    final int whole = int.parse(match.group(1)!);
    final String fraction = (match.group(2) ?? '').padRight(2, '0');
    return PriceAmount._(whole * 100 + int.parse(fraction));
  }

  final int minorUnits;
  String get wireValue =>
      '${minorUnits ~/ 100}.${(minorUnits % 100).toString().padLeft(2, '0')}';
  String get displayValue => wireValue;
  PriceAmount operator -(PriceAmount other) =>
      PriceAmount._(minorUnits - other.minorUnits);
  @override
  List<Object?> get props => <Object?>[minorUnits];
}

enum PriceOverrideScope { branch, channel, branchChannel }

PriceOverrideScope scopeFromWire(String value) => switch (value) {
  'branch' => PriceOverrideScope.branch,
  'channel' => PriceOverrideScope.channel,
  'branch_channel' => PriceOverrideScope.branchChannel,
  _ => throw FormatException('Unknown price override scope.'),
};

String scopeToWire(PriceOverrideScope value) => switch (value) {
  PriceOverrideScope.branch => 'branch',
  PriceOverrideScope.channel => 'channel',
  PriceOverrideScope.branchChannel => 'branch_channel',
};

String scopeLabel(PriceOverrideScope value) => switch (value) {
  PriceOverrideScope.branch => 'Branch',
  PriceOverrideScope.channel => 'Channel',
  PriceOverrideScope.branchChannel => 'Branch + Channel',
};

class VariantPriceOverride extends Equatable {
  const VariantPriceOverride({
    required this.id,
    required this.scope,
    required this.branchId,
    required this.channel,
    required this.price,
    required this.isActive,
    this.branchName,
    this.createdAt,
    this.updatedAt,
  });

  factory VariantPriceOverride.fromJson(Map<String, dynamic> json) =>
      VariantPriceOverride(
        id: readInt(json['id']) ?? 0,
        scope: scopeFromWire(readString(json['scopeType'])),
        branchId: readInt(json['branchId']),
        channel: _nullableString(json['channel']),
        price: PriceAmount.parse(json['overridePrice']),
        isActive: readBool(json['isActive'], fallback: true),
        branchName: _nullableString(json['branchName']),
        createdAt: DateTime.tryParse(readString(json['createdAt'])),
        updatedAt: DateTime.tryParse(readString(json['updatedAt'])),
      );

  final int id;
  final PriceOverrideScope scope;
  final int? branchId;
  final String? channel;
  final PriceAmount price;
  final bool isActive;
  final String? branchName;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  String get scopeKey => 'branch:${branchId ?? '*'}|channel:${channel ?? '*'}';
  @override
  List<Object?> get props => <Object?>[
    id,
    scope,
    branchId,
    channel,
    price,
    isActive,
    branchName,
    createdAt,
    updatedAt,
  ];
}

class VariantPriceOverrideDraft extends Equatable {
  const VariantPriceOverrideDraft({
    required this.scope,
    required this.branchId,
    required this.channel,
    required this.price,
    this.isActive = true,
  });

  factory VariantPriceOverrideDraft.fromOverride(VariantPriceOverride item) =>
      VariantPriceOverrideDraft(
        scope: item.scope,
        branchId: item.branchId,
        channel: item.channel,
        price: item.price,
        isActive: item.isActive,
      );
  final PriceOverrideScope scope;
  final int? branchId;
  final String? channel;
  final PriceAmount price;

  /// New overrides default active; edits carry the persisted lifecycle state.
  final bool isActive;
  String get scopeKey => 'branch:${branchId ?? '*'}|channel:${channel ?? '*'}';
  Map<String, dynamic> toJson() => <String, dynamic>{
    'scopeType': scopeToWire(scope),
    'branchId': branchId,
    'channel': channel,
    'overridePrice': price.wireValue,
    'isActive': isActive,
  };
  @override
  List<Object?> get props => <Object?>[
    scope,
    branchId,
    channel,
    price,
    isActive,
  ];
}

class VariantPriceOverridesSnapshot extends Equatable {
  const VariantPriceOverridesSnapshot({
    required this.variantId,
    required this.basePrice,
    required this.overrides,
  });
  factory VariantPriceOverridesSnapshot.fromJson(Map<String, dynamic> json) {
    final dynamic rows = json['overrides'];
    if (rows is! List) {
      throw FormatException('Invalid price override response.');
    }
    return VariantPriceOverridesSnapshot(
      variantId: readInt(json['variantId']) ?? 0,
      basePrice: PriceAmount.parse(json['basePrice']),
      overrides: List.unmodifiable(
        rows.whereType<Map>().map(
          (row) =>
              VariantPriceOverride.fromJson(Map<String, dynamic>.from(row)),
        ),
      ),
    );
  }
  final int variantId;
  final PriceAmount basePrice;
  final List<VariantPriceOverride> overrides;
  @override
  List<Object?> get props => <Object?>[variantId, basePrice, overrides];
}

class EffectiveVariantPrice extends Equatable {
  const EffectiveVariantPrice({
    required this.variantId,
    required this.basePrice,
    required this.effectivePrice,
    required this.matchedScope,
    required this.matchedOverrideId,
    required this.branchId,
    required this.channel,
  });
  factory EffectiveVariantPrice.fromJson(Map<String, dynamic> json) =>
      EffectiveVariantPrice(
        variantId: readInt(json['variantId']) ?? 0,
        basePrice: PriceAmount.parse(json['basePrice']),
        effectivePrice: PriceAmount.parse(json['effectivePrice']),
        matchedScope: readString(json['matchedScope'], fallback: 'base'),
        matchedOverrideId: readInt(json['matchedOverrideId']),
        branchId: readInt(json['branchId']),
        channel: _nullableString(json['channel']),
      );
  final int variantId;
  final PriceAmount basePrice;
  final PriceAmount effectivePrice;
  final String matchedScope;
  final int? matchedOverrideId;
  final int? branchId;
  final String? channel;
  String get sourceLabel => switch (matchedScope) {
    'branch_channel' => 'Branch + Channel Override',
    'branch' => 'Branch Override',
    'channel' => 'Channel Override',
    _ => 'Variant Base Price',
  };
  @override
  List<Object?> get props => <Object?>[
    variantId,
    basePrice,
    effectivePrice,
    matchedScope,
    matchedOverrideId,
    branchId,
    channel,
  ];
}

String? _nullableString(dynamic value) {
  final String text = readString(value).trim();
  return text.isEmpty ? null : text;
}

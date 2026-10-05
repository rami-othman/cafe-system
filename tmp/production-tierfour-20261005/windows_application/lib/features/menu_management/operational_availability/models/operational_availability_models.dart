import 'package:equatable/equatable.dart';

import '../../../pos/models/json_helpers.dart';

enum OperationalAvailabilityLevel { product, variant }

enum OperationalAvailabilityStatus {
  available,
  soldOut,
  temporarilyUnavailable,
}

const Set<String> operationalAvailabilityChannels = <String>{
  'all',
  'pos',
  'waiter_app',
  'kiosk',
  'qr_ordering',
  'delivery',
  'online_ordering',
};

bool isOperationalAvailabilityChannel(String value) =>
    operationalAvailabilityChannels.contains(value);

OperationalAvailabilityStatus operationalStatusFromWire(String value) =>
    switch (value) {
      'available' => OperationalAvailabilityStatus.available,
      'sold_out' => OperationalAvailabilityStatus.soldOut,
      'temporarily_unavailable' =>
        OperationalAvailabilityStatus.temporarilyUnavailable,
      _ => throw FormatException('Unknown operational availability status.'),
    };

String operationalStatusWire(OperationalAvailabilityStatus value) =>
    switch (value) {
      OperationalAvailabilityStatus.available => 'available',
      OperationalAvailabilityStatus.soldOut => 'sold_out',
      OperationalAvailabilityStatus.temporarilyUnavailable =>
        'temporarily_unavailable',
    };

String operationalStatusLabel(OperationalAvailabilityStatus value) =>
    switch (value) {
      OperationalAvailabilityStatus.available => 'Available',
      OperationalAvailabilityStatus.soldOut => 'Sold Out',
      OperationalAvailabilityStatus.temporarilyUnavailable =>
        'Temporarily Unavailable',
    };

/// The backend's authoritative operational-resolution response.
///
/// This deliberately models the preview response only; it does not infer
/// scheduled availability, inventory, publishing, or sellability.
class OperationalAvailabilityPreview extends Equatable {
  const OperationalAvailabilityPreview({
    required this.productId,
    required this.productVariantId,
    required this.branchId,
    required this.channel,
    required this.isOperationallyAvailable,
    required this.status,
    required this.matchedLevel,
    required this.matchedScope,
    required this.matchedRecordId,
    required this.remainingQuantity,
    required this.unavailableUntil,
    required this.reason,
  });

  factory OperationalAvailabilityPreview.fromJson(Map<String, dynamic> json) {
    final String status = readString(json['status']);
    final String? level = _nullable(json['matchedLevel']);
    final String? scope = _nullable(json['matchedScope']);
    if (readInt(json['productId']) == null ||
        readInt(json['branchId']) == null ||
        channelIsRuntime(readString(json['channel'])) == false ||
        json['isOperationallyAvailable'] is! bool ||
        status.isEmpty ||
        (level != null && level != 'product' && level != 'variant') ||
        (scope != null &&
            scope != 'exact_channel' &&
            scope != 'all_channels')) {
      throw const FormatException('Invalid operational resolution response.');
    }
    return OperationalAvailabilityPreview(
      productId: readInt(json['productId'])!,
      productVariantId: readInt(json['productVariantId']),
      branchId: readInt(json['branchId'])!,
      channel: readString(json['channel']),
      isOperationallyAvailable: readBool(json['isOperationallyAvailable']),
      status: operationalStatusFromWire(status),
      matchedLevel: level == null
          ? null
          : level == 'variant'
          ? OperationalAvailabilityLevel.variant
          : OperationalAvailabilityLevel.product,
      matchedScope: scope,
      matchedRecordId: readInt(json['matchedRecordId']),
      remainingQuantity: json['remainingQuantity'] == null
          ? null
          : readDouble(json['remainingQuantity']),
      unavailableUntil: _branchLocalDateTime(json['unavailableUntil']),
      reason: _nullable(json['reason']),
    );
  }

  final int productId;
  final int? productVariantId;
  final int branchId;
  final String channel;
  final bool isOperationallyAvailable;
  final OperationalAvailabilityStatus status;
  final OperationalAvailabilityLevel? matchedLevel;
  final String? matchedScope;
  final int? matchedRecordId;
  final double? remainingQuantity;
  final DateTime? unavailableUntil;
  final String? reason;

  bool get isFallback => matchedRecordId == null;
  bool get isExplicitAvailable =>
      !isFallback && status == OperationalAvailabilityStatus.available;
  bool get isTemporary =>
      status == OperationalAvailabilityStatus.temporarilyUnavailable;

  @override
  List<Object?> get props => <Object?>[
    productId,
    productVariantId,
    branchId,
    channel,
    isOperationallyAvailable,
    status,
    matchedLevel,
    matchedScope,
    matchedRecordId,
    remainingQuantity,
    unavailableUntil,
    reason,
  ];
}

bool channelIsRuntime(String value) =>
    value != 'all' && operationalAvailabilityChannels.contains(value);

class OperationalAvailabilityOverride extends Equatable {
  const OperationalAvailabilityOverride({
    required this.id,
    required this.level,
    required this.productId,
    required this.productVariantId,
    required this.branchId,
    required this.branchName,
    required this.branchTimezone,
    required this.channel,
    required this.status,
    required this.remainingQuantity,
    required this.unavailableUntil,
    required this.reason,
    required this.isExpired,
    required this.createdAt,
    required this.updatedAt,
  });

  factory OperationalAvailabilityOverride.fromJson(Map<String, dynamic> json) {
    final Map<dynamic, dynamic>? branch =
        json['branch'] as Map<dynamic, dynamic>?;
    return OperationalAvailabilityOverride(
      id: readInt(json['id']) ?? 0,
      level: readString(json['level']) == 'variant'
          ? OperationalAvailabilityLevel.variant
          : OperationalAvailabilityLevel.product,
      productId: readInt(json['productId']) ?? 0,
      productVariantId: readInt(json['productVariantId']),
      branchId: readInt(branch?['id']) ?? readInt(json['branchId']) ?? 0,
      branchName: readString(branch?['name'], fallback: 'Unknown branch'),
      branchTimezone: readString(branch?['timezone']),
      channel: readString(json['channel'], fallback: 'all'),
      status: operationalStatusFromWire(readString(json['status'])),
      remainingQuantity: json['remainingQuantity'] == null
          ? null
          : readDouble(json['remainingQuantity']),
      unavailableUntil: _branchLocalDateTime(json['unavailableUntil']),
      reason: _nullable(json['reason']),
      isExpired: readBool(json['isExpired']),
      createdAt: DateTime.tryParse(readString(json['createdAt'])),
      updatedAt: DateTime.tryParse(readString(json['updatedAt'])),
    );
  }

  final int id;
  final OperationalAvailabilityLevel level;
  final int productId;
  final int? productVariantId;
  final int branchId;
  final String branchName;
  final String branchTimezone;
  final String channel;
  final OperationalAvailabilityStatus status;
  final double? remainingQuantity;
  final DateTime? unavailableUntil;
  final String? reason;
  final bool isExpired;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  bool get isTemporary =>
      status == OperationalAvailabilityStatus.temporarilyUnavailable;
  String get scopeKey => 'branch:$branchId|channel:$channel';

  OperationalAvailabilityDraft toDraft() => OperationalAvailabilityDraft(
    branchId: branchId,
    channel: channel,
    status: status,
    remainingQuantity: remainingQuantity,
    unavailableUntil: unavailableUntil,
    reason: reason,
  );

  @override
  List<Object?> get props => <Object?>[
    id,
    level,
    productId,
    productVariantId,
    branchId,
    branchName,
    branchTimezone,
    channel,
    status,
    remainingQuantity,
    unavailableUntil,
    reason,
    isExpired,
    createdAt,
    updatedAt,
  ];
}

class OperationalAvailabilityDraft extends Equatable {
  const OperationalAvailabilityDraft({
    required this.branchId,
    required this.channel,
    required this.status,
    this.remainingQuantity,
    this.unavailableUntil,
    this.reason,
  });

  final int? branchId;

  /// `all` is the backend's all-channels scope for the required Branch.
  final String channel;
  final OperationalAvailabilityStatus status;
  final double? remainingQuantity;
  final DateTime? unavailableUntil;
  final String? reason;
  bool get isTemporary =>
      status == OperationalAvailabilityStatus.temporarilyUnavailable;
  String get scopeKey => 'branch:${branchId ?? '*'}|channel:$channel';

  Map<String, dynamic> toJson() {
    if (branchId == null || branchId! <= 0) {
      throw const FormatException(
        'Operational availability requires a Branch.',
      );
    }
    if (!isOperationalAvailabilityChannel(channel)) {
      throw const FormatException(
        'Unsupported operational availability channel.',
      );
    }
    return <String, dynamic>{
      'branchId': branchId,
      'channel': channel,
      'status': operationalStatusWire(status),
      if (remainingQuantity != null) 'remainingQuantity': remainingQuantity,
      if (isTemporary && unavailableUntil != null)
        // This is deliberately a branch-local wall-clock timestamp, not the
        // workstation instant. The API interprets offset-less values in the
        // authoritative Branch timezone.
        'unavailableUntil': _branchLocalTimestamp(unavailableUntil!),
      if (status != OperationalAvailabilityStatus.available &&
          reason != null &&
          reason!.trim().isNotEmpty)
        'reason': reason!.trim(),
    };
  }

  @override
  List<Object?> get props => <Object?>[
    branchId,
    channel,
    status,
    remainingQuantity,
    unavailableUntil,
    reason,
  ];
}

String _branchLocalTimestamp(DateTime value) =>
    '${value.year.toString().padLeft(4, '0')}-${value.month.toString().padLeft(2, '0')}-${value.day.toString().padLeft(2, '0')}T${value.hour.toString().padLeft(2, '0')}:${value.minute.toString().padLeft(2, '0')}:${value.second.toString().padLeft(2, '0')}';

/// API responses are serialized in the Branch timezone. Keep their wall-clock
/// fields rather than converting them to the workstation timezone.
DateTime? _branchLocalDateTime(dynamic value) {
  final String wire = readString(value);
  if (wire.length < 19) return DateTime.tryParse(wire);
  return DateTime.tryParse(wire.substring(0, 19));
}

String? _nullable(dynamic value) {
  final String result = readString(value).trim();
  return result.isEmpty ? null : result;
}

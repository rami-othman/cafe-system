import 'package:equatable/equatable.dart';

import '../../pos/models/json_helpers.dart';

/// One line of the cashier's own shift bar check: a single item to count.
class BarCheckLine extends Equatable {
  const BarCheckLine({
    required this.itemId,
    required this.itemName,
    required this.unit,
    required this.isRequired,
    required this.isCounted,
    required this.expectedQuantity,
    required this.countedQuantity,
    required this.varianceStatus,
  });

  factory BarCheckLine.fromJson(Map<String, dynamic> json) => BarCheckLine(
    itemId: readInt(json['itemId']) ?? 0,
    itemName: readString(
      json['itemNameAr'],
      fallback: readString(json['itemNameEn']),
    ),
    unit: readString(json['countUnit'], fallback: readString(json['unit'])),
    isRequired: readBool(json['isRequired'], fallback: true),
    isCounted: readBool(json['isCounted']),
    expectedQuantity: readString(json['expectedQuantity'], fallback: '0'),
    countedQuantity: readString(json['countedQuantity'], fallback: '0'),
    varianceStatus: json['varianceStatus'] as String?,
  );

  final int itemId;
  final String itemName;
  final String unit;
  final bool isRequired;
  final bool isCounted;
  final String expectedQuantity;
  final String countedQuantity;

  /// One of within_tolerance / needs_reason / needs_manager_review, or null
  /// before the line has been counted.
  final String? varianceStatus;

  bool get needsManagerReview => varianceStatus == 'needs_manager_review';

  @override
  List<Object?> get props => <Object?>[
    itemId,
    itemName,
    unit,
    isRequired,
    isCounted,
    expectedQuantity,
    countedQuantity,
    varianceStatus,
  ];
}

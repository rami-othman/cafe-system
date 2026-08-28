import 'dart:math' as math;

import 'package:equatable/equatable.dart';

import '../../../core/utils/currency_formatter.dart';

enum AppliedDiscountType { percentage, fixedAmount }

class AppliedDiscount extends Equatable {
  const AppliedDiscount({
    required this.id,
    required this.title,
    required this.type,
    required this.value,
    this.backendId,
    this.code,
  });

  final String id;
  final int? backendId;
  final String title;
  final AppliedDiscountType type;
  final double value;
  final String? code;

  double calculateAmount(double subtotal) {
    final double amount = switch (type) {
      AppliedDiscountType.percentage => subtotal * value / 100,
      AppliedDiscountType.fixedAmount => value,
    };

    return amount.clamp(0, math.max(subtotal, 0)).toDouble();
  }

  String get displayLabel {
    return switch (type) {
      AppliedDiscountType.percentage => '${value.toStringAsFixed(0)}% off',
      AppliedDiscountType.fixedAmount => '-${CurrencyFormatter.format(value)}',
    };
  }

  @override
  List<Object?> get props => <Object?>[id, backendId, title, type, value, code];
}

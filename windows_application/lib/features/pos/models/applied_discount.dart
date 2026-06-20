import 'dart:math' as math;

import 'package:equatable/equatable.dart';

enum AppliedDiscountType { percentage, fixedAmount }

class AppliedDiscount extends Equatable {
  const AppliedDiscount({
    required this.id,
    required this.title,
    required this.type,
    required this.value,
    this.code,
  });

  final String id;
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
      AppliedDiscountType.fixedAmount => '-\$${value.toStringAsFixed(2)}',
    };
  }

  @override
  List<Object?> get props => <Object?>[id, title, type, value, code];
}

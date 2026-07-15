import 'package:equatable/equatable.dart';

enum AvailableDiscountType { percentage, fixedAmount, bogo }

class AvailableDiscount extends Equatable {
  const AvailableDiscount({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.badgeLabel,
    required this.type,
    required this.value,
    this.backendId,
    this.minimumSubtotal = 0,
    this.couponCode,
    this.isEligible = true,
    this.message,
  });

  final String id;
  final int? backendId;
  final String title;
  final String subtitle;
  final String badgeLabel;
  final AvailableDiscountType type;
  final double value;
  final double minimumSubtotal;
  final String? couponCode;
  final bool isEligible;
  final String? message;

  @override
  List<Object?> get props => <Object?>[
    id,
    backendId,
    title,
    subtitle,
    badgeLabel,
    type,
    value,
    minimumSubtotal,
    couponCode,
    isEligible,
    message,
  ];
}

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
    this.minimumSubtotal = 0,
    this.couponCode,
  });

  final String id;
  final String title;
  final String subtitle;
  final String badgeLabel;
  final AvailableDiscountType type;
  final double value;
  final double minimumSubtotal;
  final String? couponCode;

  @override
  List<Object?> get props => <Object?>[
    id,
    title,
    subtitle,
    badgeLabel,
    type,
    value,
    minimumSubtotal,
    couponCode,
  ];
}

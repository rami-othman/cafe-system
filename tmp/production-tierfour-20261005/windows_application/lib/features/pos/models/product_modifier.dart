import 'package:equatable/equatable.dart';

class ProductModifierOption extends Equatable {
  const ProductModifierOption({
    required this.id,
    required this.label,
    this.priceDelta = 0,
    this.helperLabel,
  });

  final String id;
  final String label;
  final double priceDelta;
  final String? helperLabel;

  @override
  List<Object?> get props => <Object?>[id, label, priceDelta, helperLabel];
}

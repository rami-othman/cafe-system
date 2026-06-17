import 'package:equatable/equatable.dart';

class ReceiptLineItem extends Equatable {
  const ReceiptLineItem({
    required this.name,
    required this.quantity,
    required this.unitPrice,
    required this.lineTotal,
    this.modifiers = const <String>[],
    this.specialInstructions,
  });

  final String name;
  final int quantity;
  final double unitPrice;
  final double lineTotal;
  final List<String> modifiers;
  final String? specialInstructions;

  @override
  List<Object?> get props => <Object?>[
    name,
    quantity,
    unitPrice,
    lineTotal,
    modifiers,
    specialInstructions,
  ];
}

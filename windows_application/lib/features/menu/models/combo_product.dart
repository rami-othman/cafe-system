import 'package:equatable/equatable.dart';

import 'combo_slot.dart';

class ComboProduct extends Equatable {
  const ComboProduct({
    required this.id,
    required this.productId,
    required this.name,
    required this.price,
    required this.slots,
    this.upgrades = const <String>[],
  });

  final String id;
  final String productId;
  final String name;
  final double price;
  final List<ComboSlot> slots;
  final List<String> upgrades;

  @override
  List<Object?> get props => <Object?>[
    id,
    productId,
    name,
    price,
    slots,
    upgrades,
  ];
}

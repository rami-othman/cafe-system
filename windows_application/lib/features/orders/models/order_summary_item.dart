import 'package:equatable/equatable.dart';

class OrderSummaryItem extends Equatable {
  const OrderSummaryItem({
    required this.quantity,
    required this.name,
    required this.total,
  });

  final int quantity;
  final String name;
  final double total;

  @override
  List<Object?> get props => <Object?>[quantity, name, total];
}

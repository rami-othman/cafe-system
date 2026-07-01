import 'package:equatable/equatable.dart';

import 'menu_enums.dart';

class ProductVariant extends Equatable {
  const ProductVariant({
    required this.id,
    required this.productId,
    required this.name,
    required this.sku,
    required this.price,
    required this.cost,
    required this.isDefault,
    required this.status,
  });

  final String id;
  final String productId;
  final String name;
  final String sku;
  final double price;
  final double cost;
  final bool isDefault;
  final ProductStatus status;

  @override
  List<Object?> get props => <Object?>[
    id,
    productId,
    name,
    sku,
    price,
    cost,
    isDefault,
    status,
  ];
}

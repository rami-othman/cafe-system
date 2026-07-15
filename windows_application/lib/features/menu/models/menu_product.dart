import 'package:equatable/equatable.dart';

import 'menu_enums.dart';
import 'product_variant.dart';

class MenuProduct extends Equatable {
  const MenuProduct({
    required this.id,
    required this.name,
    required this.description,
    required this.sku,
    required this.categoryId,
    required this.categoryName,
    required this.type,
    required this.status,
    required this.basePrice,
    required this.isTaxable,
    required this.availableChannels,
    required this.branchIds,
    required this.variants,
    required this.modifierGroupIds,
    this.arabicName,
    this.cost,
    this.imageUrl,
    this.listSubtitle,
  });

  final String id;
  final String name;
  final String? arabicName;
  final String description;
  final String sku;
  final String categoryId;
  final String categoryName;
  final ProductType type;
  final ProductStatus status;
  final double basePrice;
  final double? cost;
  final String? imageUrl;
  final String? listSubtitle;
  final bool isTaxable;
  final List<ChannelType> availableChannels;
  final List<String> branchIds;
  final List<ProductVariant> variants;
  final List<String> modifierGroupIds;

  @override
  List<Object?> get props => <Object?>[
    id,
    name,
    arabicName,
    description,
    sku,
    categoryId,
    categoryName,
    type,
    status,
    basePrice,
    cost,
    imageUrl,
    listSubtitle,
    isTaxable,
    availableChannels,
    branchIds,
    variants,
    modifierGroupIds,
  ];
}

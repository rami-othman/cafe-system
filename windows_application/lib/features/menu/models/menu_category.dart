import 'package:equatable/equatable.dart';

class MenuCategory extends Equatable {
  const MenuCategory({
    required this.id,
    required this.name,
    required this.description,
    required this.sortOrder,
    required this.isActive,
    required this.branchIds,
    required this.productCount,
    this.imageUrl,
  });

  final String id;
  final String name;
  final String description;
  final String? imageUrl;
  final int sortOrder;
  final bool isActive;
  final List<String> branchIds;
  final int productCount;

  @override
  List<Object?> get props => <Object?>[
    id,
    name,
    description,
    imageUrl,
    sortOrder,
    isActive,
    branchIds,
    productCount,
  ];
}

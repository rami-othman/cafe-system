import 'package:equatable/equatable.dart';

class MenuKpis extends Equatable {
  const MenuKpis({
    required this.totalCategories,
    required this.totalProducts,
    required this.activeProducts,
    required this.inactiveProducts,
    required this.modifierGroups,
  });

  final int totalCategories;
  final int totalProducts;
  final int activeProducts;
  final int inactiveProducts;
  final int modifierGroups;

  @override
  List<Object> get props => <Object>[
    totalCategories,
    totalProducts,
    activeProducts,
    inactiveProducts,
    modifierGroups,
  ];
}

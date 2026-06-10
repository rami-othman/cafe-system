import 'package:equatable/equatable.dart';

import '../models/cart_item.dart';
import '../models/order_type.dart';
import '../models/pos_product.dart';

class PosState extends Equatable {
  const PosState({
    this.products = const <PosProduct>[],
    this.categories = const <String>[],
    this.selectedCategory = '',
    this.searchQuery = '',
    this.cartItems = const <CartItem>[],
    this.orderType = OrderType.dineIn,
    this.isLoading = false,
    this.errorMessage,
  });

  static const double taxRate = 0.08;

  final List<PosProduct> products;
  final List<String> categories;
  final String selectedCategory;
  final String searchQuery;
  final List<CartItem> cartItems;
  final OrderType orderType;
  final bool isLoading;
  final String? errorMessage;

  List<PosProduct> get filteredProducts {
    final String normalizedQuery = searchQuery.trim().toLowerCase();

    return products
        .where((PosProduct product) {
          final bool matchesCategory = selectedCategory.isEmpty
              ? true
              : product.category == selectedCategory;
          final bool matchesSearch = normalizedQuery.isEmpty
              ? true
              : product.name.toLowerCase().contains(normalizedQuery);

          return matchesCategory && matchesSearch;
        })
        .toList(growable: false);
  }

  double get subtotal {
    return cartItems.fold<double>(
      0,
      (double total, CartItem item) => total + item.lineTotal,
    );
  }

  double get discountTotal => 0;

  double get tax => subtotal * taxRate;

  double get total => subtotal - discountTotal + tax;

  int get totalItems {
    return cartItems.fold<int>(
      0,
      (int total, CartItem item) => total + item.quantity,
    );
  }

  bool get hasCartItems => cartItems.isNotEmpty;

  PosState copyWith({
    List<PosProduct>? products,
    List<String>? categories,
    String? selectedCategory,
    String? searchQuery,
    List<CartItem>? cartItems,
    OrderType? orderType,
    bool? isLoading,
    String? errorMessage,
    bool clearErrorMessage = false,
  }) {
    return PosState(
      products: products ?? this.products,
      categories: categories ?? this.categories,
      selectedCategory: selectedCategory ?? this.selectedCategory,
      searchQuery: searchQuery ?? this.searchQuery,
      cartItems: cartItems ?? this.cartItems,
      orderType: orderType ?? this.orderType,
      isLoading: isLoading ?? this.isLoading,
      errorMessage: clearErrorMessage
          ? null
          : errorMessage ?? this.errorMessage,
    );
  }

  @override
  List<Object?> get props => <Object?>[
    products,
    categories,
    selectedCategory,
    searchQuery,
    cartItems,
    orderType,
    isLoading,
    errorMessage,
  ];
}

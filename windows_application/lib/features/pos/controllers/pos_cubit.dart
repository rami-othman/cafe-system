import 'package:flutter_bloc/flutter_bloc.dart';

import '../models/cart_item.dart';
import '../models/order_type.dart';
import '../models/pos_product.dart';
import '../repositories/pos_repository.dart';
import 'pos_state.dart';

class PosCubit extends Cubit<PosState> {
  PosCubit({required this.repository}) : super(const PosState());

  final PosRepository repository;

  Future<void> loadInitialData() async {
    emit(state.copyWith(isLoading: true, clearErrorMessage: true));

    try {
      final List<String> categories = repository.getCategories();
      final List<PosProduct> products = repository.getProducts();

      emit(
        state.copyWith(
          products: products,
          categories: categories,
          selectedCategory: categories.isEmpty ? '' : categories.first,
          isLoading: false,
          clearErrorMessage: true,
        ),
      );
    } catch (error) {
      emit(state.copyWith(isLoading: false, errorMessage: error.toString()));
    }
  }

  void selectCategory(String category) {
    emit(state.copyWith(selectedCategory: category, searchQuery: ''));
  }

  void updateSearchQuery(String query) {
    emit(state.copyWith(searchQuery: query));
  }

  void addProductToCart(PosProduct product) {
    if (!product.isAvailable) {
      return;
    }

    final int existingIndex = state.cartItems.indexWhere(
      (CartItem item) => item.product.id == product.id,
    );

    if (existingIndex == -1) {
      emit(
        state.copyWith(
          cartItems: <CartItem>[
            ...state.cartItems,
            CartItem(
              product: product,
              quantity: 1,
              modifiers: _defaultModifiersFor(product),
            ),
          ],
        ),
      );
      return;
    }

    final List<CartItem> updatedItems = List<CartItem>.of(state.cartItems);
    final CartItem existingItem = updatedItems[existingIndex];
    updatedItems[existingIndex] = existingItem.copyWith(
      quantity: existingItem.quantity + 1,
    );

    emit(state.copyWith(cartItems: updatedItems));
  }

  void increaseQuantity(String productId) {
    final List<CartItem> updatedItems = state.cartItems
        .map((CartItem item) {
          if (item.product.id != productId) {
            return item;
          }

          return item.copyWith(quantity: item.quantity + 1);
        })
        .toList(growable: false);

    emit(state.copyWith(cartItems: updatedItems));
  }

  void decreaseQuantity(String productId) {
    final List<CartItem> updatedItems = <CartItem>[];

    for (final CartItem item in state.cartItems) {
      if (item.product.id != productId) {
        updatedItems.add(item);
        continue;
      }

      final int nextQuantity = item.quantity - 1;
      if (nextQuantity > 0) {
        updatedItems.add(item.copyWith(quantity: nextQuantity));
      }
    }

    emit(state.copyWith(cartItems: updatedItems));
  }

  void removeCartItem(String productId) {
    emit(
      state.copyWith(
        cartItems: state.cartItems
            .where((CartItem item) => item.product.id != productId)
            .toList(growable: false),
      ),
    );
  }

  void changeOrderType(OrderType orderType) {
    emit(state.copyWith(orderType: orderType));
  }

  void clearCart() {
    emit(state.copyWith(cartItems: const <CartItem>[]));
  }

  List<String> _defaultModifiersFor(PosProduct product) {
    return switch (product.id) {
      'cappuccino' => const <String>['Oat Milk', 'Extra Shot'],
      'almond-croissant' => const <String>['Warmed'],
      _ => const <String>[],
    };
  }
}

import 'package:flutter_bloc/flutter_bloc.dart';

import '../models/applied_discount.dart';
import '../models/cart_item.dart';
import '../models/customer.dart';
import '../models/order_type.dart';
import '../models/order_receipt.dart';
import '../models/payment_result.dart';
import '../models/pos_product.dart';
import '../models/product_customization.dart';
import '../models/receipt_line_item.dart';
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
      final List<Customer> customers = repository.getCustomers();

      emit(
        state.copyWith(
          products: products,
          categories: categories,
          customers: customers,
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
              id: product.id,
              product: product,
              quantity: 1,
              unitPrice: product.price,
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

  void addCustomizedProductToCart(ProductCustomization customization) {
    if (!customization.product.isAvailable) {
      return;
    }

    final String cartItemId = customization.configurationKey;
    final int existingIndex = state.cartItems.indexWhere(
      (CartItem item) => item.id == cartItemId,
    );

    if (existingIndex == -1) {
      emit(
        state.copyWith(
          cartItems: <CartItem>[
            ...state.cartItems,
            CartItem(
              id: cartItemId,
              product: customization.product,
              quantity: customization.quantity,
              unitPrice: customization.unitPrice,
              modifiers: customization.modifierLabels,
              specialInstructions: customization.specialInstructions.trim(),
            ),
          ],
        ),
      );
      return;
    }

    final List<CartItem> updatedItems = List<CartItem>.of(state.cartItems);
    final CartItem existingItem = updatedItems[existingIndex];
    updatedItems[existingIndex] = existingItem.copyWith(
      quantity: existingItem.quantity + customization.quantity,
    );

    emit(state.copyWith(cartItems: updatedItems));
  }

  void increaseQuantity(String cartItemId) {
    final List<CartItem> updatedItems = state.cartItems
        .map((CartItem item) {
          if (item.id != cartItemId) {
            return item;
          }

          return item.copyWith(quantity: item.quantity + 1);
        })
        .toList(growable: false);

    emit(state.copyWith(cartItems: updatedItems));
  }

  void decreaseQuantity(String cartItemId) {
    final List<CartItem> updatedItems = <CartItem>[];

    for (final CartItem item in state.cartItems) {
      if (item.id != cartItemId) {
        updatedItems.add(item);
        continue;
      }

      final int nextQuantity = item.quantity - 1;
      if (nextQuantity > 0) {
        updatedItems.add(item.copyWith(quantity: nextQuantity));
      }
    }

    _emitCartItems(updatedItems);
  }

  void removeCartItem(String cartItemId) {
    _emitCartItems(
      state.cartItems
          .where((CartItem item) => item.id != cartItemId)
          .toList(growable: false),
    );
  }

  void changeOrderType(OrderType orderType) {
    emit(state.copyWith(orderType: orderType));
  }

  void selectCustomer(Customer customer) {
    emit(state.copyWith(selectedCustomer: customer));
  }

  void clearSelectedCustomer() {
    emit(state.copyWith(clearSelectedCustomer: true));
  }

  void applyDiscount(AppliedDiscount discount) {
    if (!state.hasCartItems) {
      return;
    }

    emit(state.copyWith(appliedDiscount: discount));
  }

  void removeDiscount() {
    emit(state.copyWith(clearAppliedDiscount: true));
  }

  void clearCart() {
    emit(
      state.copyWith(cartItems: const <CartItem>[], clearAppliedDiscount: true),
    );
  }

  void completeLocalPayment(PaymentResult result) {
    if (!state.hasCartItems || result.totalDue <= 0) {
      return;
    }

    final OrderReceipt receipt = _buildReceiptSnapshot(result);

    emit(
      state.copyWith(
        cartItems: const <CartItem>[],
        lastReceipt: receipt,
        clearSelectedCustomer: true,
        clearAppliedDiscount: true,
      ),
    );
  }

  void clearLastReceipt() {
    emit(state.copyWith(clearLastReceipt: true));
  }

  void _emitCartItems(List<CartItem> cartItems) {
    emit(
      state.copyWith(
        cartItems: cartItems,
        clearAppliedDiscount: cartItems.isEmpty,
      ),
    );
  }

  List<String> _defaultModifiersFor(PosProduct product) {
    return switch (product.id) {
      'cappuccino' => const <String>['Oat Milk', 'Extra Shot'],
      'almond-croissant' => const <String>['Warmed'],
      _ => const <String>[],
    };
  }

  OrderReceipt _buildReceiptSnapshot(PaymentResult payment) {
    final DateTime completedAt = DateTime.now();

    return OrderReceipt(
      orderNumber: _orderNumberFor(completedAt),
      branchName: 'DOWNTOWN BRANCH',
      cashierName: 'ALEX M.',
      completedAt: completedAt,
      items: state.cartItems
          .map(
            (CartItem item) => ReceiptLineItem(
              name: item.product.name,
              quantity: item.quantity,
              unitPrice: item.unitPrice,
              lineTotal: item.lineTotal,
              modifiers: item.modifiers,
              specialInstructions: item.specialInstructions.trim().isEmpty
                  ? null
                  : item.specialInstructions.trim(),
            ),
          )
          .toList(growable: false),
      subtotal: state.subtotal,
      discountTotal: state.discountTotal,
      discountLabel: state.appliedDiscount?.title,
      tax: state.tax,
      total: state.total,
      payment: payment,
      customerName: state.selectedCustomer?.name,
    );
  }

  String _orderNumberFor(DateTime completedAt) {
    final int suffix = completedAt.millisecondsSinceEpoch % 10000;
    return '#618-${suffix.toString().padLeft(4, '0')}';
  }
}

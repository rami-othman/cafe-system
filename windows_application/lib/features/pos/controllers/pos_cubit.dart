import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/network/api_exception.dart';
import '../models/applied_discount.dart';
import '../models/backend_order.dart';
import '../models/backend_order_item.dart';
import '../models/backend_product_detail.dart';
import '../models/cart_item.dart';
import '../models/create_order_request.dart';
import '../models/customer.dart';
import '../models/order_type.dart';
import '../models/order_receipt.dart';
import '../models/payment_method.dart';
import '../models/payment_result.dart';
import '../models/pos_product.dart';
import '../models/product_customization.dart';
import '../models/receipt_line_item.dart';
import '../models/update_order_item_request.dart';
import '../repositories/pos_repository.dart';
import 'pos_state.dart';

class PosCubit extends Cubit<PosState> {
  PosCubit({required this.repository}) : super(const PosState());

  final PosRepository repository;
  Future<void> _cartMutationQueue = Future<void>.value();
  int _queuedCartMutations = 0;

  Future<void> loadInitialData() async {
    emit(state.copyWith(isLoading: true, clearErrorMessage: true));

    try {
      final branches = await repository.getBranches();
      final int branchId = branches.isEmpty ? 1 : branches.first.id;
      final shift = await repository.getCurrentShift(branchId: branchId);
      final List<String> categories = await repository.getCategories(
        branchId: branchId,
      );
      final List<PosProduct> products = await repository.getProducts(
        branchId: branchId,
      );
      final List<Customer> customers = await repository.getCustomers();
      final tables = await repository.getTables(branchId: branchId);
      await repository.getPosState(branchId: branchId);

      emit(
        state.copyWith(
          branchId: branchId,
          shiftId: shift?.id,
          isBackendMode: repository.usesBackend,
          products: products,
          categories: categories,
          customers: customers,
          tables: tables,
          selectedCategory: categories.isEmpty ? '' : categories.first,
          isLoading: false,
          clearErrorMessage: true,
          clearApiErrorMessage: true,
        ),
      );
    } catch (error) {
      final String message = _messageFor(error);
      emit(
        state.copyWith(
          isLoading: false,
          errorMessage: message,
          apiErrorMessage: message,
        ),
      );
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

  Future<BackendProductDetail?> loadProductDetail(PosProduct product) async {
    final int? productId = product.backendId;
    if (!repository.usesBackend || productId == null) {
      return null;
    }

    try {
      emit(state.copyWith(isSyncingOrder: true, clearApiErrorMessage: true));
      final BackendProductDetail detail = await repository.getProductDetail(
        productId: productId,
        branchId: state.branchId,
      );
      return detail;
    } catch (error) {
      if (!isClosed) {
        emit(state.copyWith(apiErrorMessage: _messageFor(error)));
      }
      return null;
    } finally {
      if (!isClosed) {
        emit(state.copyWith(isSyncingOrder: false));
      }
    }
  }

  Future<bool> addCustomizedProductToCart(
    ProductCustomization customization,
  ) async {
    if (!customization.product.isAvailable) {
      return false;
    }

    if (repository.usesBackend && customization.product.backendId != null) {
      return _enqueueCartMutation(
        fallbackMessage: 'Could not add item. Please try again.',
        action: () => _addCustomizedProductToBackendOrder(customization),
      );
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
      return true;
    }

    final List<CartItem> updatedItems = List<CartItem>.of(state.cartItems);
    final CartItem existingItem = updatedItems[existingIndex];
    updatedItems[existingIndex] = existingItem.copyWith(
      quantity: existingItem.quantity + customization.quantity,
    );

    emit(state.copyWith(cartItems: updatedItems));
    return true;
  }

  Future<void> increaseQuantity(String cartItemId) async {
    final CartItem? item = _cartItemById(cartItemId);
    if (item == null) {
      return;
    }

    if (state.currentOrderId != null && item.backendItemId != null) {
      await _syncOrder(
        () => repository.updateOrderItem(
          orderId: state.currentOrderId!,
          itemId: item.backendItemId!,
          request: UpdateOrderItemRequest(quantity: item.quantity + 1),
        ),
      );
      return;
    }

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

  Future<void> decreaseQuantity(String cartItemId) async {
    final CartItem? item = _cartItemById(cartItemId);
    if (item == null) {
      return;
    }

    if (state.currentOrderId != null && item.backendItemId != null) {
      if (item.quantity <= 1) {
        await _syncOrder(
          () => repository.removeOrderItem(
            orderId: state.currentOrderId!,
            itemId: item.backendItemId!,
          ),
        );
      } else {
        await _syncOrder(
          () => repository.updateOrderItem(
            orderId: state.currentOrderId!,
            itemId: item.backendItemId!,
            request: UpdateOrderItemRequest(quantity: item.quantity - 1),
          ),
        );
      }
      return;
    }

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

  Future<void> removeCartItem(String cartItemId) async {
    final CartItem? item = _cartItemById(cartItemId);
    if (item == null) {
      return;
    }

    if (state.currentOrderId != null && item.backendItemId != null) {
      await _syncOrder(
        () => repository.removeOrderItem(
          orderId: state.currentOrderId!,
          itemId: item.backendItemId!,
        ),
      );
      return;
    }

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

  Future<void> applyDiscount(AppliedDiscount discount) async {
    if (!state.hasCartItems) {
      return;
    }

    if (state.currentOrderId != null) {
      await _syncOrder(
        () => repository.applyDiscount(
          orderId: state.currentOrderId!,
          code: discount.code,
          discountId: discount.backendId,
        ),
      );
      return;
    }

    emit(state.copyWith(appliedDiscount: discount));
  }

  Future<void> removeDiscount() async {
    if (state.currentOrderId != null) {
      await _syncOrder(() => repository.removeDiscount(state.currentOrderId!));
      return;
    }

    emit(state.copyWith(clearAppliedDiscount: true));
  }

  Future<void> clearCart() async {
    if (state.currentOrderId != null) {
      await _enqueueCartMutation(
        fallbackMessage: 'Could not cancel order. Please try again.',
        action: () async {
          await repository.cancelOrder(state.currentOrderId!);
          _clearCurrentOrderState();
        },
      );
      return;
    }

    _clearCurrentOrderState();
  }

  Future<void> holdCurrentOrder() async {
    if (state.currentOrderId == null) {
      return;
    }

    await _enqueueCartMutation(
      fallbackMessage: 'Could not hold order. Please try again.',
      action: () async {
        await repository.holdOrder(state.currentOrderId!);
        _clearCurrentOrderState();
      },
    );
  }

  void _clearCurrentOrderState() {
    emit(
      state.copyWith(
        cartItems: const <CartItem>[],
        clearAppliedDiscount: true,
        clearCurrentOrderId: true,
        clearBackendTotals: true,
      ),
    );
  }

  Future<void> completeLocalPayment(PaymentResult result) async {
    if (!state.hasCartItems || result.totalDue <= 0) {
      return;
    }
    if (state.isCartMutationInProgress) {
      emit(
        state.copyWith(
          cartMutationError: 'Please wait for the current cart update.',
        ),
      );
      return;
    }

    if (state.currentOrderId != null) {
      await _completeBackendPayment(result);
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

  Future<void> _addCustomizedProductToBackendOrder(
    ProductCustomization customization,
  ) async {
    final int? productId = customization.product.backendId;
    if (productId == null) {
      throw const ApiException(message: 'Product is missing backend id.');
    }

    final AddOrderItemRequest itemRequest = AddOrderItemRequest(
      productId: productId,
      quantity: customization.quantity,
      modifiers: customization.selectedModifiers,
      note: customization.specialInstructions,
    );

    if (state.currentOrderId == null) {
      if (state.shiftId == null) {
        throw const ApiException(
          message:
              'No open shift found. Open a shift before creating an order.',
        );
      }

      final BackendOrder order = await repository.createOrder(
        CreateOrderRequest(
          branchId: state.branchId,
          shiftId: state.shiftId,
          orderType: state.orderType,
          tableId: state.tables.isEmpty ? null : state.tables.first.id,
          customerId: state.selectedCustomer?.backendId,
          items: <AddOrderItemRequest>[itemRequest],
        ),
      );
      _emitBackendOrder(order);
      return;
    }

    final String? configurationKey = customization.backendConfigurationKey;
    final CartItem? existing = configurationKey == null
        ? null
        : state.cartItems.cast<CartItem?>().firstWhere(
            (CartItem? item) =>
                item?.backendItemId != null &&
                item?.hasCompleteBackendConfiguration == true &&
                item?.backendConfigurationKey == configurationKey,
            orElse: () => null,
          );
    final BackendOrder order;
    if (existing != null) {
      order = await repository.updateOrderItem(
        orderId: state.currentOrderId!,
        itemId: existing.backendItemId!,
        request: UpdateOrderItemRequest(
          quantity: existing.quantity + customization.quantity,
        ),
      );
    } else {
      order = await repository.addOrderItem(
        orderId: state.currentOrderId!,
        request: itemRequest,
      );
    }
    _emitBackendOrder(order);
  }

  Future<void> _syncOrder(Future<BackendOrder> Function() action) async {
    await _enqueueCartMutation(
      fallbackMessage: 'Could not update order. Please try again.',
      action: () async => _emitBackendOrder(await action()),
    );
  }

  Future<bool> _enqueueCartMutation({
    required String fallbackMessage,
    required Future<void> Function() action,
  }) {
    _queuedCartMutations += 1;
    if (!isClosed && !state.isCartMutationInProgress) {
      emit(
        state.copyWith(
          isCartMutationInProgress: true,
          isSyncingOrder: true,
          clearCartMutationError: true,
        ),
      );
    }

    bool succeeded = false;
    final Future<void> scheduled = _cartMutationQueue.then((_) async {
      if (isClosed) {
        return;
      }
      try {
        await action();
        succeeded = true;
      } catch (error) {
        if (!isClosed) {
          emit(
            state.copyWith(
              cartMutationError: error is ApiException
                  ? _messageFor(error)
                  : fallbackMessage,
            ),
          );
        }
      } finally {
        _queuedCartMutations -= 1;
        if (!isClosed && _queuedCartMutations == 0) {
          emit(
            state.copyWith(
              isCartMutationInProgress: false,
              isSyncingOrder: false,
            ),
          );
        }
      }
    });
    _cartMutationQueue = scheduled.catchError((Object _) {});
    return scheduled.then((_) => succeeded);
  }

  void _emitBackendOrder(BackendOrder order) {
    final List<CartItem> cartItems = order.items
        .map(_cartItemFromBackend)
        .toList(growable: false);

    emit(
      state.copyWith(
        cartItems: cartItems,
        currentOrderId: order.id,
        branchId: order.branchId,
        shiftId: order.shiftId,
        orderType: orderTypeFromApi(order.orderType),
        appliedDiscount: _discountFromBackend(order),
        backendSubtotal: order.totals.subtotal,
        backendDiscountTotal: order.totals.discountTotal,
        backendTax: order.totals.taxTotal,
        backendTotal: order.totals.total,
        clearAppliedDiscount: order.discountAmount == null,
      ),
    );
  }

  CartItem _cartItemFromBackend(BackendOrderItem item) {
    final PosProduct product = state.products.firstWhere(
      (PosProduct product) => product.backendId == item.productId,
      orElse: () => PosProduct(
        id: item.productId.toString(),
        backendId: item.productId,
        name: item.name,
        category: 'MENU',
        size: '1 item',
        price: item.unitPrice,
        isAvailable: true,
      ),
    );

    return CartItem(
      id: item.id.toString(),
      backendItemId: item.id,
      backendProductId: item.productId,
      product: product,
      quantity: item.quantity,
      unitPrice: item.unitPrice,
      modifiers: item.modifierLabels,
      selectedModifiers: item.selectedModifiers,
      specialInstructions: item.note ?? '',
    );
  }

  AppliedDiscount? _discountFromBackend(BackendOrder order) {
    final double? amount = order.discountAmount;
    if (amount == null || amount <= 0) {
      return null;
    }

    return AppliedDiscount(
      id: 'backend-${order.id}',
      title: order.discountName ?? 'Discount',
      type: order.discountType == 'percentage'
          ? AppliedDiscountType.percentage
          : AppliedDiscountType.fixedAmount,
      value: order.discountValue ?? amount,
    );
  }

  CartItem? _cartItemById(String cartItemId) {
    for (final CartItem item in state.cartItems) {
      if (item.id == cartItemId) {
        return item;
      }
    }

    return null;
  }

  Future<void> _completeBackendPayment(PaymentResult result) async {
    final int orderId = state.currentOrderId!;
    try {
      emit(state.copyWith(isSyncingOrder: true, clearApiErrorMessage: true));
      await repository.payOrder(
        orderId: orderId,
        method: result.method.apiValue,
        amount: result.amountReceived,
        totalDue: state.total,
      );
      final OrderReceipt receipt = await repository.getReceipt(orderId);
      emit(
        state.copyWith(
          cartItems: const <CartItem>[],
          lastReceipt: receipt,
          clearSelectedCustomer: true,
          clearAppliedDiscount: true,
          clearCurrentOrderId: true,
          clearBackendTotals: true,
        ),
      );
    } catch (error) {
      emit(state.copyWith(apiErrorMessage: _messageFor(error)));
    } finally {
      emit(state.copyWith(isSyncingOrder: false));
    }
  }

  String _messageFor(Object error) {
    if (error is ApiException) {
      if (error.validationErrors?.isNotEmpty ?? false) {
        return error.validationErrors!.values.first.first;
      }
      return error.message;
    }

    return error.toString();
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

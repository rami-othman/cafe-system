import 'dart:math';

import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/network/api_exception.dart';
import '../models/applied_discount.dart';
import '../models/backend_order.dart';
import '../models/backend_order_item.dart';
import '../models/backend_product_detail.dart';
import '../models/branch.dart';
import '../models/cart_item.dart';
import '../models/create_order_request.dart';
import '../models/customer.dart';
import '../models/order_type.dart';
import '../models/order_receipt.dart';
import '../models/payment_method.dart';
import '../models/payment_result.dart';
import '../models/pos_product.dart';
import '../models/product_customization.dart';
import '../models/product_detail_load_result.dart';
import '../models/receipt_line_item.dart';
import '../models/selected_modifier.dart';
import '../models/update_order_item_request.dart';
import '../repositories/pos_repository.dart';
import 'pos_state.dart';

enum PaymentCompletionStatus { completed, retryableFailure, uncertain }

class PosCubit extends Cubit<PosState> {
  PosCubit({required this.repository})
    : super(
        PosState(
          isBackendMode: repository.usesBackend,
          // Until the POS sync flow is mounted, retain legacy direct-cubit
          // behavior. PosScreen immediately replaces this with API-derived
          // reachability for real backend sessions.
          isBackendReachable: true,
        ),
      );

  final PosRepository repository;
  Future<void> _cartMutationQueue = Future<void>.value();
  int _queuedCartMutations = 0;
  int _receiptRequestGeneration = 0;
  int _productDetailRequestVersion = 0;
  int _branchLoadGeneration = 0;

  static const String connectionRequiredMessage =
      'pos.connectionRequiredToCompleteOrder';
  static const String menuChangedReviewMessage = 'pos.menuChangedReviewOrder';

  Future<void> loadInitialData() async {
    emit(
      state.copyWith(
        isLoading: true,
        isBackendMode: repository.usesBackend,
        clearErrorMessage: true,
      ),
    );

    try {
      final branches = await repository.getBranches();
      final List<Customer> customers = await repository.getCustomers();
      final Branch branch = branches.isEmpty
          ? const Branch(
              id: 1,
              name: 'Default Branch',
              currency: 'SYP',
              timezone: 'Asia/Damascus',
              isActive: true,
            )
          : branches.firstWhere(
              (Branch item) => item.id == state.branchId,
              orElse: () => branches.first,
            );
      emit(state.copyWith(branches: branches, customers: customers));
      await _activateBranch(branch, reloadCustomers: false);
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

  /// Changes the one POS selling context.  An order/draft is branch-bound, so
  /// callers must leave the existing cart intact before switching branches.
  Future<bool> selectBranch(int branchId) async {
    if (branchId == state.branchId) return true;
    if (state.hasCartItems || state.currentOrderId != null) return false;
    final Branch? branch = state.branches.cast<Branch?>().firstWhere(
      (Branch? item) => item?.id == branchId && item!.isActive,
      orElse: () => null,
    );
    if (branch == null) return false;
    await _activateBranch(branch);
    return true;
  }

  Future<void> _activateBranch(
    Branch branch, {
    bool reloadCustomers = false,
  }) async {
    final int request = ++_branchLoadGeneration;
    // This emits the authoritative context before any branch-scoped work.
    // PosScreen clears the old published presentation immediately when it
    // observes this branchId change.
    emit(
      state.copyWith(
        branchId: branch.id,
        taxRate: branch.taxRate,
        isLoading: true,
        clearShiftId: true,
        clearErrorMessage: true,
        clearApiErrorMessage: true,
        requiresMenuRefresh: false,
      ),
    );

    try {
      final shift = await repository.getCurrentShift(branchId: branch.id);
      final List<String> categories = repository.usesBackend
          ? const <String>[]
          : await repository.getCategories(branchId: branch.id);
      final List<PosProduct> products = repository.usesBackend
          ? const <PosProduct>[]
          : await repository.getProducts(branchId: branch.id);
      final List<Customer>? customers = reloadCustomers
          ? await repository.getCustomers()
          : null;
      await repository.getPosState(branchId: branch.id);
      if (isClosed || request != _branchLoadGeneration) return;
      emit(
        state.copyWith(
          branchId: branch.id,
          taxRate: branch.taxRate,
          shiftId: shift?.id,
          isBackendMode: repository.usesBackend,
          customers: customers,
          products: products,
          categories: categories,
          selectedCategory: categories.isEmpty ? '' : categories.first,
          searchQuery: '',
          isLoading: false,
          clearErrorMessage: true,
          clearApiErrorMessage: true,
          requiresMenuRefresh: false,
        ),
      );
    } catch (error) {
      if (isClosed || request != _branchLoadGeneration) return;
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

  /// Menu-sync request results, rather than an OS interface flag, determine
  /// whether backend mutations may be attempted.
  void setBackendReachability(bool reachable) {
    if (state.isBackendReachable == reachable) return;
    emit(state.copyWith(isBackendReachable: reachable));
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

  Future<ProductDetailLoadResult> loadProductDetail(PosProduct product) async {
    final int? productId = product.backendId;
    // Published runtime cards already contain the complete variant and
    // modifier contract. This guard makes the no-legacy-detail-request rule
    // hold even if a future caller bypasses PosScreen's published-card path.
    if (product.isPublishedRuntime ||
        !repository.usesBackend ||
        productId == null) {
      return const ProductDetailNotRequired();
    }

    if (state.isProductDetailLoading && state.loadingProductId == productId) {
      return const ProductDetailLoadStale();
    }

    final int requestVersion = ++_productDetailRequestVersion;
    emit(
      state.copyWith(
        loadingProductId: productId,
        isProductDetailLoading: true,
        clearProductDetailError: true,
      ),
    );

    try {
      final BackendProductDetail detail = await repository.getProductDetail(
        productId: productId,
        branchId: state.branchId,
      );
      if (isClosed || requestVersion != _productDetailRequestVersion) {
        return const ProductDetailLoadStale();
      }
      emit(
        state.copyWith(
          isProductDetailLoading: false,
          clearLoadingProductId: true,
          clearProductDetailError: true,
        ),
      );
      return ProductDetailLoaded(detail);
    } catch (error) {
      if (isClosed || requestVersion != _productDetailRequestVersion) {
        return const ProductDetailLoadStale();
      }
      const String message =
          'Could not load product options. Please try again.';
      emit(
        state.copyWith(
          isProductDetailLoading: false,
          clearLoadingProductId: true,
          productDetailError: message,
        ),
      );
      return const ProductDetailLoadFailed(message);
    }
  }

  Future<bool> addCustomizedProductToCart(
    ProductCustomization customization,
  ) async {
    if (!customization.product.isAvailable) {
      return false;
    }

    if (customization.isPublishedRuntime) {
      if (state.currentOrderId != null) {
        return _enqueueCartMutation(
          fallbackMessage: 'Could not add item. Please try again.',
          action: () => _addPublishedProductToBackendOrder(customization),
        );
      }
      return _addPublishedProductToLocalCart(customization);
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

  Future<bool> changeOrderType(OrderType orderType) {
    if (state.orderType == orderType) {
      return Future<bool>.value(true);
    }
    if (state.currentOrderId == null) {
      emit(state.copyWith(orderType: orderType, clearCartMutationError: true));
      return Future<bool>.value(true);
    }
    final int orderId = state.currentOrderId!;
    return _enqueueCartMutation(
      fallbackMessage: 'Could not update order type. Please try again.',
      action: () async {
        final BackendOrder order = await repository.updateOrderContext(
          orderId: orderId,
          orderType: orderType.apiValue,
          clearTable: true,
        );
        _emitBackendOrder(order);
      },
    );
  }

  Future<bool> selectCustomer(Customer? customer) {
    if (state.selectedCustomer == customer) {
      return Future<bool>.value(true);
    }
    if (state.currentOrderId == null) {
      emit(
        state.copyWith(
          selectedCustomer: customer,
          clearSelectedCustomer: customer == null,
          clearCartMutationError: true,
        ),
      );
      return Future<bool>.value(true);
    }

    final int orderId = state.currentOrderId!;
    return _enqueueCartMutation(
      fallbackMessage: 'Could not update customer. Please try again.',
      action: () async {
        final BackendOrder order = await repository.updateOrderContext(
          orderId: orderId,
          customerId: customer?.backendId,
          clearCustomer: customer == null,
        );
        _emitBackendOrder(order);
      },
    );
  }

  Future<bool> clearSelectedCustomer() {
    return selectCustomer(null);
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
        orderType: OrderType.dineIn,
        clearAppliedDiscount: true,
        clearSelectedCustomer: true,
        clearCurrentOrderId: true,
        clearBackendTotals: true,
      ),
    );
  }

  Future<PaymentCompletionStatus> completeLocalPayment(
    PaymentResult result,
  ) async {
    if (!state.hasCartItems || result.totalDue <= 0) {
      return PaymentCompletionStatus.retryableFailure;
    }
    if (state.isCartMutationInProgress) {
      emit(
        state.copyWith(
          cartMutationError: 'Please wait for the current cart update.',
        ),
      );
      return PaymentCompletionStatus.retryableFailure;
    }

    if (state.currentOrderId != null) {
      return completeBackendPayment(result);
    }

    if (state.isBackendMode) {
      if (!state.isBackendReachable) {
        emit(state.copyWith(paymentErrorMessage: connectionRequiredMessage));
        return PaymentCompletionStatus.retryableFailure;
      }
      return _createPublishedOrderAndPay(result);
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
    return PaymentCompletionStatus.completed;
  }

  Future<PaymentCompletionStatus> completeBackendPayment(
    PaymentResult requestedPayment,
  ) => _completeBackendPayment(requestedPayment);

  Future<PaymentCompletionStatus> _completeBackendPayment(
    PaymentResult requestedPayment, {
    bool paymentSubmissionAlreadyStarted = false,
  }) async {
    if ((!paymentSubmissionAlreadyStarted && state.isPaymentSubmitting) ||
        state.uncertainPaymentOrderId != null) {
      return PaymentCompletionStatus.uncertain;
    }
    if (!state.isBackendReachable) {
      emit(state.copyWith(paymentErrorMessage: connectionRequiredMessage));
      return PaymentCompletionStatus.retryableFailure;
    }

    final int? orderId = state.currentOrderId;
    final double totalDue = state.total;
    if (orderId == null || totalDue <= 0 || !state.hasCartItems) {
      return PaymentCompletionStatus.retryableFailure;
    }

    if (!paymentSubmissionAlreadyStarted) {
      emit(
        state.copyWith(
          isPaymentSubmitting: true,
          clearPaymentErrorMessage: true,
          clearApiErrorMessage: true,
        ),
      );
    }

    try {
      final PaymentResult payment = await repository.payOrder(
        orderId: orderId,
        method: requestedPayment.method.apiValue,
        amount: requestedPayment.amountReceived,
        idempotencyKey: _operationKey('payment'),
        totalDue: totalDue,
      );
      if (isClosed) {
        return PaymentCompletionStatus.uncertain;
      }

      await _confirmBackendPayment(orderId: orderId, payment: payment);
      return PaymentCompletionStatus.completed;
    } catch (error) {
      if (isClosed) {
        return PaymentCompletionStatus.uncertain;
      }
      if (_isPotentiallyUncertainPaymentFailure(error)) {
        return _verifyUncertainPayment(
          orderId: orderId,
          requestedPayment: requestedPayment,
        );
      }

      emit(
        state.copyWith(
          isPaymentSubmitting: false,
          paymentErrorMessage: _messageFor(error),
        ),
      );
      return PaymentCompletionStatus.retryableFailure;
    }
  }

  Future<void> retryPendingReceipt() async {
    final int? orderId = state.pendingReceiptOrderId;
    if (orderId == null || state.isReceiptLoading) {
      return;
    }

    await _loadReceipt(orderId);
  }

  Future<void> checkUncertainPaymentStatus() async {
    final int? orderId = state.uncertainPaymentOrderId;
    if (orderId == null || state.isPaymentSubmitting) {
      return;
    }

    emit(
      state.copyWith(isPaymentSubmitting: true, clearPaymentErrorMessage: true),
    );
    await _verifyUncertainPayment(orderId: orderId, requestedPayment: null);
  }

  void clearLastReceipt([OrderReceipt? expectedReceipt]) {
    if (expectedReceipt != null && state.lastReceipt != expectedReceipt) {
      return;
    }
    emit(state.copyWith(clearLastReceipt: true));
  }

  void _emitCartItems(List<CartItem> cartItems) {
    emit(
      state.copyWith(
        cartItems: cartItems,
        clearAppliedDiscount: cartItems.isEmpty,
        clearCurrentOrderId: cartItems.isEmpty && state.currentOrderId == null,
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
          tableId: null,
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

  Future<void> _addPublishedProductToBackendOrder(
    ProductCustomization customization,
  ) async {
    final PosProduct product = customization.product;
    final int? versionId = product.publishedMenuVersionId;
    final int? productId = product.backendId;
    final int? placementId = product.placementId;
    final int? variantId = customization.publishedVariantId;
    if (versionId == null ||
        productId == null ||
        placementId == null ||
        variantId == null) {
      throw const ApiException(message: 'Published menu item is incomplete.');
    }
    if ((state.currentOrderId != null &&
            state.publishedMenuVersionId != versionId) ||
        (state.publishedMenuVersionId != null &&
            state.publishedMenuVersionId != versionId)) {
      throw const ApiException(
        message:
            'MENU_VERSION_STALE: refresh the POS menu before adding items.',
      );
    }

    final AddOrderItemRequest itemRequest = AddOrderItemRequest(
      productId: productId,
      placementId: placementId,
      variantId: variantId,
      modifierOptionIds: customization.publishedModifierOptionIds,
      quantity: customization.quantity,
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
          tableId: null,
          customerId: state.selectedCustomer?.backendId,
          publishedMenuVersionId: versionId,
          items: <AddOrderItemRequest>[itemRequest],
        ),
      );
      _emitBackendOrder(order);
      return;
    }

    final BackendOrder order = await repository.addOrderItem(
      orderId: state.currentOrderId!,
      request: itemRequest,
    );
    _emitBackendOrder(order);
  }

  Future<bool> _addPublishedProductToLocalCart(
    ProductCustomization customization,
  ) async {
    final PosProduct product = customization.product;
    final int? versionId = product.publishedMenuVersionId;
    final int? productId = product.backendId;
    final int? placementId = product.placementId;
    final int? variantId = customization.publishedVariantId;
    if (versionId == null ||
        productId == null ||
        placementId == null ||
        variantId == null) {
      emit(
        state.copyWith(
          cartMutationError: 'Could not add this published menu item.',
        ),
      );
      return false;
    }
    if (state.publishedMenuVersionId != null &&
        state.publishedMenuVersionId != versionId) {
      emit(
        state.copyWith(
          cartMutationError: menuChangedReviewMessage,
          requiresMenuRefresh: true,
        ),
      );
      return false;
    }

    final String key = customization.configurationKey;
    final int index = state.cartItems.indexWhere(
      (CartItem item) => item.id == key,
    );
    final CartItem next = CartItem(
      id: key,
      backendProductId: productId,
      publishedMenuVersionId: versionId,
      placementId: placementId,
      variantId: variantId,
      modifierOptionIds: customization.publishedModifierOptionIds,
      product: product,
      quantity: customization.quantity,
      unitPrice: customization.unitPrice,
      modifiers: customization.modifierLabels,
      specialInstructions: customization.specialInstructions.trim(),
    );
    if (index < 0) {
      emit(
        state.copyWith(
          cartItems: <CartItem>[...state.cartItems, next],
          publishedMenuVersionId: versionId,
        ),
      );
    } else {
      final List<CartItem> items = List<CartItem>.of(state.cartItems);
      items[index] = items[index].copyWith(
        quantity: items[index].quantity + customization.quantity,
      );
      emit(state.copyWith(cartItems: items, publishedMenuVersionId: versionId));
    }
    return true;
  }

  Future<PaymentCompletionStatus> _createPublishedOrderAndPay(
    PaymentResult requestedPayment,
  ) async {
    int? versionId;
    for (final CartItem item in state.cartItems) {
      if (item.publishedMenuVersionId != null) {
        versionId = item.publishedMenuVersionId;
        break;
      }
    }
    if (versionId == null ||
        state.cartItems.any(
          (CartItem item) =>
              item.publishedMenuVersionId != versionId ||
              item.backendProductId == null ||
              item.placementId == null ||
              item.variantId == null,
        )) {
      emit(
        state.copyWith(
          paymentErrorMessage: menuChangedReviewMessage,
          requiresMenuRefresh: true,
        ),
      );
      return PaymentCompletionStatus.retryableFailure;
    }
    if (state.shiftId == null) {
      emit(
        state.copyWith(
          paymentErrorMessage:
              'No open shift found. Open a shift before paying.',
        ),
      );
      return PaymentCompletionStatus.retryableFailure;
    }

    emit(
      state.copyWith(isPaymentSubmitting: true, clearPaymentErrorMessage: true),
    );
    try {
      final BackendOrder order = await repository.createOrder(
        CreateOrderRequest(
          branchId: state.branchId,
          shiftId: state.shiftId,
          orderType: state.orderType,
          customerId: state.selectedCustomer?.backendId,
          publishedMenuVersionId: versionId,
          items: state.cartItems
              .map(
                (CartItem item) => AddOrderItemRequest(
                  productId: item.backendProductId!,
                  placementId: item.placementId,
                  variantId: item.variantId,
                  modifierOptionIds: item.modifierOptionIds,
                  quantity: item.quantity,
                  note: item.specialInstructions,
                ),
              )
              .toList(growable: false),
        ),
      );
      if (isClosed) return PaymentCompletionStatus.uncertain;
      _emitBackendOrder(order);
      // Creating a snapshot-aware order is the first half of the same payment
      // action. Keep the UI locked, but let the owned hand-off submit /pay.
      return _completeBackendPayment(
        requestedPayment,
        paymentSubmissionAlreadyStarted: true,
      );
    } catch (error) {
      if (!isClosed) {
        emit(
          state.copyWith(
            isPaymentSubmitting: false,
            paymentErrorMessage: _messageFor(error),
            requiresMenuRefresh: _isMenuVersionStale(error),
          ),
        );
      }
      return PaymentCompletionStatus.retryableFailure;
    }
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
    if (repository.usesBackend && !state.isBackendReachable) {
      emit(state.copyWith(cartMutationError: connectionRequiredMessage));
      return Future<bool>.value(false);
    }
    _queuedCartMutations += 1;
    if (!isClosed && !state.isCartMutationInProgress) {
      emit(
        state.copyWith(
          isCartMutationInProgress: true,
          isSyncingOrder: true,
          clearCartMutationError: true,
          requiresMenuRefresh: false,
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
              requiresMenuRefresh: _isMenuVersionStale(error),
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
        taxRate: order.totals.taxRate,
        shiftId: order.shiftId,
        publishedMenuVersionId: order.publishedMenuVersionId,
        orderType: orderTypeFromApi(order.orderType),
        selectedCustomer: _customerFromBackendOrder(order),
        clearSelectedCustomer: order.customerId == null,
        appliedDiscount: _discountFromBackend(order),
        backendSubtotal: order.totals.subtotal,
        backendDiscountTotal: order.totals.discountTotal,
        backendTax: order.totals.taxTotal,
        backendTotal: order.totals.total,
        clearAppliedDiscount: order.discountAmount == null,
      ),
    );
  }

  Customer? _customerFromBackendOrder(BackendOrder order) {
    final int? customerId = order.customerId;
    if (customerId == null) {
      return null;
    }
    for (final Customer customer in state.customers) {
      if (customer.backendId == customerId) {
        return customer;
      }
    }
    return Customer(
      id: customerId.toString(),
      backendId: customerId,
      name: order.customerName ?? 'Customer $customerId',
      phone: order.customerPhone ?? '',
      tier: 'CUSTOMER',
      points: 0,
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
      publishedMenuVersionId: state.publishedMenuVersionId,
      placementId: item.placementId,
      variantId: item.variantId,
      modifierOptionIds: item.selectedModifiers
          .map((SelectedModifier modifier) => modifier.optionId)
          .toList(growable: false),
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

  Future<void> _confirmBackendPayment({
    required int orderId,
    required PaymentResult payment,
  }) async {
    if (isClosed) {
      return;
    }
    _completeConfirmedOrder(orderId: orderId, payment: payment);
    await _loadReceipt(orderId);
  }

  void _completeConfirmedOrder({
    required int orderId,
    required PaymentResult payment,
  }) {
    if (isClosed) {
      return;
    }
    emit(
      state.copyWith(
        cartItems: const <CartItem>[],
        orderType: OrderType.dineIn,
        lastPaidOrderId: orderId,
        lastPaymentResult: payment,
        pendingReceiptOrderId: orderId,
        isPaymentSubmitting: false,
        clearSelectedCustomer: true,
        clearAppliedDiscount: true,
        clearCurrentOrderId: true,
        clearBackendTotals: true,
        clearPaymentErrorMessage: true,
        clearUncertainPayment: true,
        clearReceiptErrorMessage: true,
      ),
    );
  }

  Future<void> _loadReceipt(int orderId) async {
    if (isClosed || state.pendingReceiptOrderId != orderId) {
      return;
    }
    final int requestId = ++_receiptRequestGeneration;
    emit(
      state.copyWith(isReceiptLoading: true, clearReceiptErrorMessage: true),
    );
    try {
      final OrderReceipt receipt = await repository.getReceipt(orderId);
      if (isClosed ||
          requestId != _receiptRequestGeneration ||
          state.pendingReceiptOrderId != orderId) {
        return;
      }
      emit(
        state.copyWith(
          lastReceipt: receipt,
          isReceiptLoading: false,
          clearPendingReceiptOrderId: true,
          clearReceiptErrorMessage: true,
        ),
      );
    } catch (error) {
      if (isClosed ||
          requestId != _receiptRequestGeneration ||
          state.pendingReceiptOrderId != orderId) {
        return;
      }
      emit(
        state.copyWith(
          isReceiptLoading: false,
          receiptErrorMessage:
              'Payment completed, but the receipt could not be loaded.',
        ),
      );
    }
  }

  Future<PaymentCompletionStatus> _verifyUncertainPayment({
    required int orderId,
    required PaymentResult? requestedPayment,
  }) async {
    try {
      final BackendOrder order = await repository.getOrder(orderId);
      if (isClosed) {
        return PaymentCompletionStatus.uncertain;
      }
      if (_isConfirmedPaid(order)) {
        final PaymentResult payment =
            requestedPayment ??
            PaymentResult(
              method: PaymentMethod.cash,
              totalDue: order.totals.total,
              amountReceived: order.totals.total,
              changeDue: 0,
              status: order.paymentStatus,
            );
        await _confirmBackendPayment(orderId: orderId, payment: payment);
        return PaymentCompletionStatus.completed;
      }

      emit(
        state.copyWith(
          isPaymentSubmitting: false,
          paymentErrorMessage: 'Payment was not completed. Please try again.',
          clearUncertainPayment: true,
        ),
      );
      return PaymentCompletionStatus.retryableFailure;
    } catch (_) {
      if (!isClosed) {
        emit(
          state.copyWith(
            isPaymentSubmitting: false,
            uncertainPaymentOrderId: orderId,
            uncertainPaymentMessage:
                'Payment status could not be confirmed. Check the Orders screen before retrying.',
          ),
        );
      }
      return PaymentCompletionStatus.uncertain;
    }
  }

  bool _isPotentiallyUncertainPaymentFailure(Object error) {
    return error is! ApiException || error.statusCode == null;
  }

  String _operationKey(String operation) {
    final int random = Random.secure().nextInt(1 << 32);
    return '$operation-${DateTime.now().microsecondsSinceEpoch}-${random.toRadixString(16)}';
  }

  bool _isConfirmedPaid(BackendOrder order) {
    const Set<String> paidValues = <String>{'paid', 'completed', 'complete'};
    return paidValues.contains(order.status.toLowerCase()) ||
        paidValues.contains(order.paymentStatus.toLowerCase());
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

  bool _isMenuVersionStale(Object error) =>
      error is ApiException && error.message.contains('MENU_VERSION_STALE');

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
      taxRate: state.taxRate,
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

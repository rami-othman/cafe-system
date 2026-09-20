import 'package:equatable/equatable.dart';

import '../../../core/config/tax_config.dart';
import '../models/applied_discount.dart';
import '../models/branch.dart';
import '../models/cart_item.dart';
import '../models/customer.dart';
import '../models/order_type.dart';
import '../models/order_receipt.dart';
import '../models/payment_result.dart';
import '../models/pos_product.dart';

class PosState extends Equatable {
  const PosState({
    this.branches = const <Branch>[],
    this.products = const <PosProduct>[],
    this.categories = const <String>[],
    this.selectedCategory = '',
    this.searchQuery = '',
    this.cartItems = const <CartItem>[],
    this.customers = const <Customer>[],
    this.selectedCustomer,
    this.loadingProductId,
    this.isProductDetailLoading = false,
    this.productDetailError,
    this.appliedDiscount,
    this.lastReceipt,
    this.isPaymentSubmitting = false,
    this.paymentErrorMessage,
    this.lastPaidOrderId,
    this.lastPaymentResult,
    this.pendingReceiptOrderId,
    this.isReceiptLoading = false,
    this.receiptErrorMessage,
    this.uncertainPaymentOrderId,
    this.uncertainPaymentMessage,
    this.orderType = OrderType.dineIn,
    this.branchId = 1,
    this.taxRate = TaxConfig.defaultTaxRate,
    this.shiftId,
    this.currentOrderId,
    this.currentOrderStatus,
    this.currentOrderPaymentStatus,
    this.tableId,
    this.tableName,
    this.tableCode,
    this.orderNote,
    this.publishedMenuVersionId,
    this.isBackendMode = false,
    this.isBackendReachable = true,
    this.isSyncingOrder = false,
    this.isCartMutationInProgress = false,
    this.cartMutationError,
    this.apiErrorMessage,
    this.backendSubtotal,
    this.backendDiscountTotal,
    this.backendTax,
    this.backendTotal,
    this.isLoading = false,
    this.errorMessage,
    this.requiresMenuRefresh = false,
    this.holdSuccessMessage,
    this.uncertainHoldMessage,
  });

  /// The POS-owned selling context.  The shell branch tabs must use this
  /// collection and [branchId], never an independently selected branch.
  final List<Branch> branches;
  final List<PosProduct> products;
  final List<String> categories;
  final String selectedCategory;
  final String searchQuery;
  final List<CartItem> cartItems;
  final List<Customer> customers;
  final Customer? selectedCustomer;
  final int? loadingProductId;
  final bool isProductDetailLoading;
  final String? productDetailError;
  final AppliedDiscount? appliedDiscount;
  final OrderReceipt? lastReceipt;
  final bool isPaymentSubmitting;
  final String? paymentErrorMessage;
  final int? lastPaidOrderId;
  final PaymentResult? lastPaymentResult;
  final int? pendingReceiptOrderId;
  final bool isReceiptLoading;
  final String? receiptErrorMessage;
  final int? uncertainPaymentOrderId;
  final String? uncertainPaymentMessage;
  final OrderType orderType;
  final int branchId;
  final double taxRate;
  final int? shiftId;
  final int? currentOrderId;
  final String? currentOrderStatus;
  final String? currentOrderPaymentStatus;
  final int? tableId;
  final String? tableName;
  final String? tableCode;
  final String? orderNote;

  /// Remains null for every legacy Catalog session. 12E will pin this from a
  /// published runtime menu before creating snapshot-aware orders.
  final int? publishedMenuVersionId;
  final bool isBackendMode;

  /// A successful menu sync is the reachability authority; interface state is
  /// deliberately not inferred from Wi-Fi/Ethernet availability.
  final bool isBackendReachable;
  final bool isSyncingOrder;
  final bool isCartMutationInProgress;
  final String? cartMutationError;
  final String? apiErrorMessage;
  final double? backendSubtotal;
  final double? backendDiscountTotal;
  final double? backendTax;
  final double? backendTotal;
  final bool isLoading;
  final String? errorMessage;
  final bool requiresMenuRefresh;
  final String? holdSuccessMessage;
  final String? uncertainHoldMessage;

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
    if (currentOrderId != null) {
      return backendSubtotal ?? 0;
    }

    return cartItems.fold<double>(
      0,
      (double total, CartItem item) => total + item.lineTotal,
    );
  }

  double get discountTotal {
    if (currentOrderId != null) {
      return backendDiscountTotal ?? 0;
    }

    return appliedDiscount?.calculateAmount(subtotal) ?? 0;
  }

  double get taxableAmount {
    return (subtotal - discountTotal).clamp(0, double.infinity).toDouble();
  }

  double get tax {
    if (currentOrderId != null) {
      return backendTax ?? 0;
    }

    return taxableAmount * taxRate;
  }

  double get total {
    if (currentOrderId != null) {
      return backendTotal ?? 0;
    }

    return taxableAmount + tax;
  }

  int get totalItems {
    return cartItems.fold<int>(
      0,
      (int total, CartItem item) => total + item.quantity,
    );
  }

  bool get hasCartItems => cartItems.isNotEmpty;

  bool get canHoldCurrentOrder {
    if (!hasCartItems || isCartMutationInProgress || isPaymentSubmitting) {
      return false;
    }
    if (currentOrderId == null) return true;
    return currentOrderStatus?.toLowerCase() == 'draft' &&
        currentOrderPaymentStatus?.toLowerCase() == 'unpaid';
  }

  String get customerDisplayName {
    return selectedCustomer?.name ?? 'Walk-in Customer';
  }

  PosState copyWith({
    List<Branch>? branches,
    List<PosProduct>? products,
    List<String>? categories,
    String? selectedCategory,
    String? searchQuery,
    List<CartItem>? cartItems,
    List<Customer>? customers,
    Customer? selectedCustomer,
    int? loadingProductId,
    bool? isProductDetailLoading,
    String? productDetailError,
    AppliedDiscount? appliedDiscount,
    OrderReceipt? lastReceipt,
    bool? isPaymentSubmitting,
    String? paymentErrorMessage,
    int? lastPaidOrderId,
    PaymentResult? lastPaymentResult,
    int? pendingReceiptOrderId,
    bool? isReceiptLoading,
    String? receiptErrorMessage,
    int? uncertainPaymentOrderId,
    String? uncertainPaymentMessage,
    OrderType? orderType,
    int? branchId,
    double? taxRate,
    int? shiftId,
    int? currentOrderId,
    String? currentOrderStatus,
    String? currentOrderPaymentStatus,
    int? tableId,
    String? tableName,
    String? tableCode,
    String? orderNote,
    int? publishedMenuVersionId,
    bool? isBackendMode,
    bool? isBackendReachable,
    bool? isSyncingOrder,
    bool? isCartMutationInProgress,
    String? cartMutationError,
    String? apiErrorMessage,
    double? backendSubtotal,
    double? backendDiscountTotal,
    double? backendTax,
    double? backendTotal,
    bool? isLoading,
    String? errorMessage,
    bool? requiresMenuRefresh,
    String? holdSuccessMessage,
    String? uncertainHoldMessage,
    bool clearErrorMessage = false,
    bool clearApiErrorMessage = false,
    bool clearCartMutationError = false,
    bool clearSelectedCustomer = false,
    bool clearLoadingProductId = false,
    bool clearProductDetailError = false,
    bool clearAppliedDiscount = false,
    bool clearLastReceipt = false,
    bool clearPaymentErrorMessage = false,
    bool clearPendingReceiptOrderId = false,
    bool clearReceiptErrorMessage = false,
    bool clearUncertainPayment = false,
    bool clearShiftId = false,
    bool clearCurrentOrderId = false,
    bool clearBackendTotals = false,
    bool clearTable = false,
    bool clearOrderNote = false,
    bool clearHoldSuccessMessage = false,
    bool clearUncertainHoldMessage = false,
  }) {
    return PosState(
      branches: branches ?? this.branches,
      products: products ?? this.products,
      categories: categories ?? this.categories,
      selectedCategory: selectedCategory ?? this.selectedCategory,
      searchQuery: searchQuery ?? this.searchQuery,
      cartItems: cartItems ?? this.cartItems,
      customers: customers ?? this.customers,
      selectedCustomer: clearSelectedCustomer
          ? null
          : selectedCustomer ?? this.selectedCustomer,
      loadingProductId: clearLoadingProductId
          ? null
          : loadingProductId ?? this.loadingProductId,
      isProductDetailLoading:
          isProductDetailLoading ?? this.isProductDetailLoading,
      productDetailError: clearProductDetailError
          ? null
          : productDetailError ?? this.productDetailError,
      appliedDiscount: clearAppliedDiscount
          ? null
          : appliedDiscount ?? this.appliedDiscount,
      lastReceipt: clearLastReceipt ? null : lastReceipt ?? this.lastReceipt,
      isPaymentSubmitting: isPaymentSubmitting ?? this.isPaymentSubmitting,
      paymentErrorMessage: clearPaymentErrorMessage
          ? null
          : paymentErrorMessage ?? this.paymentErrorMessage,
      lastPaidOrderId: lastPaidOrderId ?? this.lastPaidOrderId,
      lastPaymentResult: lastPaymentResult ?? this.lastPaymentResult,
      pendingReceiptOrderId: clearPendingReceiptOrderId
          ? null
          : pendingReceiptOrderId ?? this.pendingReceiptOrderId,
      isReceiptLoading: isReceiptLoading ?? this.isReceiptLoading,
      receiptErrorMessage: clearReceiptErrorMessage
          ? null
          : receiptErrorMessage ?? this.receiptErrorMessage,
      uncertainPaymentOrderId: clearUncertainPayment
          ? null
          : uncertainPaymentOrderId ?? this.uncertainPaymentOrderId,
      uncertainPaymentMessage: clearUncertainPayment
          ? null
          : uncertainPaymentMessage ?? this.uncertainPaymentMessage,
      orderType: orderType ?? this.orderType,
      branchId: branchId ?? this.branchId,
      taxRate: taxRate ?? this.taxRate,
      shiftId: clearShiftId ? null : shiftId ?? this.shiftId,
      currentOrderId: clearCurrentOrderId
          ? null
          : currentOrderId ?? this.currentOrderId,
      currentOrderStatus: clearCurrentOrderId
          ? null
          : currentOrderStatus ?? this.currentOrderStatus,
      currentOrderPaymentStatus: clearCurrentOrderId
          ? null
          : currentOrderPaymentStatus ?? this.currentOrderPaymentStatus,
      tableId: clearTable || clearCurrentOrderId
          ? null
          : tableId ?? this.tableId,
      tableName: clearTable || clearCurrentOrderId
          ? null
          : tableName ?? this.tableName,
      tableCode: clearTable || clearCurrentOrderId
          ? null
          : tableCode ?? this.tableCode,
      orderNote: clearOrderNote || clearCurrentOrderId
          ? null
          : orderNote ?? this.orderNote,
      publishedMenuVersionId: clearCurrentOrderId
          ? null
          : publishedMenuVersionId ?? this.publishedMenuVersionId,
      isBackendMode: isBackendMode ?? this.isBackendMode,
      isBackendReachable: isBackendReachable ?? this.isBackendReachable,
      isSyncingOrder: isSyncingOrder ?? this.isSyncingOrder,
      isCartMutationInProgress:
          isCartMutationInProgress ?? this.isCartMutationInProgress,
      cartMutationError: clearCartMutationError
          ? null
          : cartMutationError ?? this.cartMutationError,
      apiErrorMessage: clearApiErrorMessage
          ? null
          : apiErrorMessage ?? this.apiErrorMessage,
      backendSubtotal: clearBackendTotals
          ? null
          : backendSubtotal ?? this.backendSubtotal,
      backendDiscountTotal: clearBackendTotals
          ? null
          : backendDiscountTotal ?? this.backendDiscountTotal,
      backendTax: clearBackendTotals ? null : backendTax ?? this.backendTax,
      backendTotal: clearBackendTotals
          ? null
          : backendTotal ?? this.backendTotal,
      isLoading: isLoading ?? this.isLoading,
      errorMessage: clearErrorMessage
          ? null
          : errorMessage ?? this.errorMessage,
      requiresMenuRefresh: requiresMenuRefresh ?? this.requiresMenuRefresh,
      holdSuccessMessage: clearHoldSuccessMessage
          ? null
          : holdSuccessMessage ?? this.holdSuccessMessage,
      uncertainHoldMessage: clearUncertainHoldMessage
          ? null
          : uncertainHoldMessage ?? this.uncertainHoldMessage,
    );
  }

  @override
  List<Object?> get props => <Object?>[
    branches,
    products,
    categories,
    selectedCategory,
    searchQuery,
    cartItems,
    customers,
    selectedCustomer,
    loadingProductId,
    isProductDetailLoading,
    productDetailError,
    appliedDiscount,
    lastReceipt,
    isPaymentSubmitting,
    paymentErrorMessage,
    lastPaidOrderId,
    lastPaymentResult,
    pendingReceiptOrderId,
    isReceiptLoading,
    receiptErrorMessage,
    uncertainPaymentOrderId,
    uncertainPaymentMessage,
    orderType,
    branchId,
    taxRate,
    shiftId,
    currentOrderId,
    currentOrderStatus,
    currentOrderPaymentStatus,
    tableId,
    tableName,
    tableCode,
    orderNote,
    publishedMenuVersionId,
    isBackendMode,
    isBackendReachable,
    isSyncingOrder,
    isCartMutationInProgress,
    cartMutationError,
    apiErrorMessage,
    backendSubtotal,
    backendDiscountTotal,
    backendTax,
    backendTotal,
    isLoading,
    errorMessage,
    requiresMenuRefresh,
    holdSuccessMessage,
    uncertainHoldMessage,
  ];
}

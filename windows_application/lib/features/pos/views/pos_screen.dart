import 'dart:async';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/theme/app_colors.dart';
import '../../../shared/layouts/desktop_page_layout.dart';
import '../controllers/pos_cubit.dart';
import '../controllers/pos_state.dart';
import '../models/backend_product_detail.dart';
import '../models/order_receipt.dart';
import '../models/pos_product.dart';
import '../models/product_detail_load_result.dart';
import '../models/product_customization.dart';
import '../widgets/product_customization_dialog.dart';
import '../widgets/pos_product_area.dart';
import '../widgets/receipt_preview_dialog.dart';

class PosScreen extends StatefulWidget {
  const PosScreen({super.key});

  @override
  State<PosScreen> createState() => _PosScreenState();
}

class _PosScreenState extends State<PosScreen> {
  bool _isReceiptDialogOpen = false;
  bool _isCustomizationDialogOpen = false;

  @override
  Widget build(BuildContext context) {
    return BlocListener<PosCubit, PosState>(
      listenWhen: (PosState previous, PosState current) {
        return (previous.lastReceipt != current.lastReceipt &&
                current.lastReceipt != null) ||
            previous.apiErrorMessage != current.apiErrorMessage ||
            previous.cartMutationError != current.cartMutationError ||
            previous.paymentErrorMessage != current.paymentErrorMessage ||
            previous.receiptErrorMessage != current.receiptErrorMessage ||
            previous.uncertainPaymentMessage != current.uncertainPaymentMessage;
      },
      listener: (BuildContext context, PosState state) {
        final String? errorMessage =
            state.cartMutationError ??
            state.paymentErrorMessage ??
            state.apiErrorMessage;
        if (errorMessage != null) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text(errorMessage)));
        }

        if (state.receiptErrorMessage != null) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(state.receiptErrorMessage!),
              action: SnackBarAction(
                label: 'Retry Receipt',
                onPressed: () => context.read<PosCubit>().retryPendingReceipt(),
              ),
            ),
          );
        }

        if (state.uncertainPaymentMessage != null) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(state.uncertainPaymentMessage!),
              action: SnackBarAction(
                label: 'Check Payment Status',
                onPressed: () =>
                    context.read<PosCubit>().checkUncertainPaymentStatus(),
              ),
            ),
          );
        }

        if (state.lastReceipt != null && !_isReceiptDialogOpen) {
          final OrderReceipt receipt = state.lastReceipt!;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!mounted || _isReceiptDialogOpen) {
              return;
            }
            unawaited(_showReceiptDialog(context, receipt));
          });
        }
      },
      child: BlocBuilder<PosCubit, PosState>(
        builder: (BuildContext context, PosState state) {
          final PosCubit cubit = context.read<PosCubit>();

          return DesktopPageLayout(
            child: PosProductArea(
              products: state.filteredProducts,
              categories: state.categories,
              selectedCategory: state.selectedCategory,
              searchQuery: state.searchQuery,
              isLoading: state.isLoading,
              onSearchChanged: cubit.updateSearchQuery,
              onCategorySelected: cubit.selectCategory,
              onProductTap: state.isCartMutationInProgress
                  ? (_) {}
                  : (PosProduct product) =>
                        _showCustomizationDialog(context, cubit, product),
            ),
          );
        },
      ),
    );
  }

  Future<void> _showCustomizationDialog(
    BuildContext context,
    PosCubit cubit,
    PosProduct product,
  ) async {
    if (!product.isAvailable) {
      return;
    }

    final ProductDetailLoadResult result = await cubit.loadProductDetail(
      product,
    );

    if (!context.mounted) {
      return;
    }

    switch (result) {
      case ProductDetailLoadStale():
        return;
      case ProductDetailLoadFailed(:final String message):
        await _showProductDetailFailure(context, cubit, product, message);
        return;
      case ProductDetailNotRequired():
        await _openCustomizationDialog(context, cubit, product);
        return;
      case ProductDetailLoaded(:final detail):
        await _openCustomizationDialog(
          context,
          cubit,
          product,
          productDetail: detail,
        );
        return;
    }
  }

  Future<void> _openCustomizationDialog(
    BuildContext context,
    PosCubit cubit,
    PosProduct product, {
    BackendProductDetail? productDetail,
  }) async {
    if (!context.mounted || _isCustomizationDialogOpen) {
      return;
    }
    _isCustomizationDialogOpen = true;

    try {
      await showGeneralDialog<ProductCustomization>(
        context: context,
        barrierDismissible: true,
        barrierLabel: 'Close customization dialog',
        barrierColor: AppColors.black.withValues(alpha: 0.4),
        transitionDuration: const Duration(milliseconds: 160),
        pageBuilder:
            (
              BuildContext context,
              Animation<double> animation,
              Animation<double> secondaryAnimation,
            ) {
              return BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 3, sigmaY: 3),
                child: ProductCustomizationDialog(
                  product: product,
                  productDetail: productDetail,
                  onSubmit: cubit.addCustomizedProductToCart,
                ),
              );
            },
      );
    } finally {
      _isCustomizationDialogOpen = false;
    }
  }

  Future<void> _showProductDetailFailure(
    BuildContext context,
    PosCubit cubit,
    PosProduct product,
    String message,
  ) async {
    final bool? retry = await showDialog<bool>(
      context: context,
      barrierDismissible: true,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Product options unavailable'),
          content: Text(message),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Retry'),
            ),
          ],
        );
      },
    );

    if (retry == true && context.mounted) {
      await _showCustomizationDialog(context, cubit, product);
    }
  }

  Future<void> _showReceiptDialog(
    BuildContext context,
    OrderReceipt receipt,
  ) async {
    if (_isReceiptDialogOpen || !context.mounted) {
      return;
    }
    _isReceiptDialogOpen = true;
    await showDialog<void>(
      context: context,
      barrierDismissible: true,
      barrierColor: AppColors.black.withValues(alpha: 0.42),
      builder: (BuildContext context) {
        return ReceiptPreviewDialog(receipt: receipt);
      },
    );

    _isReceiptDialogOpen = false;
    if (!context.mounted) {
      return;
    }

    final PosCubit cubit = context.read<PosCubit>();
    cubit.clearLastReceipt(receipt);
    final OrderReceipt? nextReceipt = cubit.state.lastReceipt;
    if (nextReceipt != null && nextReceipt != receipt) {
      unawaited(_showReceiptDialog(context, nextReceipt));
    }
  }
}

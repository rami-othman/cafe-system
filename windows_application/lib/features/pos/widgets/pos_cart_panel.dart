import 'dart:ui' show PathMetric;

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/constants/app_sizes.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_radius.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_text_styles.dart';
import '../controllers/pos_cubit.dart';
import '../controllers/pos_state.dart';
import '../models/applied_discount.dart';
import '../models/cart_item.dart';
import '../models/customer.dart';
import '../models/order_type.dart';
import '../models/payment_result.dart';
import 'cart_customer_selector.dart';
import 'cart_item_tile.dart';
import 'discount_dialog.dart';
import 'order_totals_panel.dart';
import 'payment_dialog.dart';
import 'order_type_selector.dart';
import 'pos_action_buttons.dart';
import 'select_customer_dialog.dart';

class PosCartPanel extends StatelessWidget {
  const PosCartPanel({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<PosCubit, PosState>(
      builder: (BuildContext context, PosState state) {
        final PosCubit cubit = context.read<PosCubit>();

        return DecoratedBox(
          decoration: const BoxDecoration(
            color: AppColors.white,
            border: Border(left: BorderSide(color: AppColors.shellBorder)),
            boxShadow: <BoxShadow>[
              BoxShadow(
                color: Color(0x12000000),
                offset: Offset(-2, 0),
                blurRadius: 10,
              ),
            ],
          ),
          child: Column(
            children: <Widget>[
              _OrderControls(
                orderType: state.orderType,
                selectedCustomer: state.selectedCustomer,
                onOrderTypeChanged: cubit.changeOrderType,
                onCustomerSelectorPressed: () =>
                    _showCustomerDialog(context, state, cubit),
              ),
              Expanded(
                child: ListView.separated(
                  padding: AppSpacing.allLg,
                  itemCount: state.cartItems.length + 1,
                  separatorBuilder: (BuildContext context, int index) {
                    return const SizedBox(height: AppSpacing.md);
                  },
                  itemBuilder: (BuildContext context, int index) {
                    if (index == state.cartItems.length) {
                      return _AddDiscountButton(
                        isEnabled: state.hasCartItems,
                        onPressed: state.hasCartItems
                            ? () => _showDiscountDialog(context, state, cubit)
                            : null,
                      );
                    }

                    final CartItem item = state.cartItems[index];

                    return CartItemTile(
                      item: item,
                      onIncreaseQuantity: () => cubit.increaseQuantity(item.id),
                      onDecreaseQuantity: () => cubit.decreaseQuantity(item.id),
                      onRemoveItem: () => cubit.removeCartItem(item.id),
                    );
                  },
                ),
              ),
              _CartFooter(
                subtotal: state.subtotal,
                discountTotal: state.discountTotal,
                tax: state.tax,
                total: state.total,
                itemCount: state.totalItems,
                hasCartItems: state.hasCartItems,
                appliedDiscount: state.appliedDiscount,
                onRemoveDiscount: cubit.removeDiscount,
                onClearCart: cubit.clearCart,
                onPay: () => _showPaymentDialog(context, state, cubit),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _showDiscountDialog(
    BuildContext context,
    PosState state,
    PosCubit cubit,
  ) async {
    final AppliedDiscount? discount = await showDialog<AppliedDiscount>(
      context: context,
      barrierDismissible: true,
      barrierColor: AppColors.black.withValues(alpha: 0.4),
      builder: (BuildContext context) {
        return DiscountDialog(subtotal: state.subtotal);
      },
    );

    if (!context.mounted || discount == null) {
      return;
    }

    cubit.applyDiscount(discount);
  }

  Future<void> _showCustomerDialog(
    BuildContext context,
    PosState state,
    PosCubit cubit,
  ) async {
    final Customer? selected = await showDialog<Customer>(
      context: context,
      barrierDismissible: true,
      barrierColor: AppColors.black.withValues(alpha: 0.4),
      builder: (BuildContext context) {
        return SelectCustomerDialog(
          customers: state.customers,
          selectedCustomer: state.selectedCustomer,
        );
      },
    );

    if (!context.mounted || selected == null) {
      return;
    }

    cubit.selectCustomer(selected);
  }

  Future<void> _showPaymentDialog(
    BuildContext context,
    PosState state,
    PosCubit cubit,
  ) async {
    if (!state.hasCartItems || state.total <= 0) {
      return;
    }

    final PaymentResult? result = await showDialog<PaymentResult>(
      context: context,
      barrierDismissible: true,
      barrierColor: AppColors.black.withValues(alpha: 0.4),
      builder: (BuildContext context) {
        return PaymentDialog(
          totalDue: state.total,
          itemCount: state.totalItems,
        );
      },
    );

    if (!context.mounted || result == null) {
      return;
    }

    cubit.completeLocalPayment(result);
  }
}

class _OrderControls extends StatelessWidget {
  const _OrderControls({
    required this.orderType,
    required this.selectedCustomer,
    required this.onOrderTypeChanged,
    required this.onCustomerSelectorPressed,
  });

  final OrderType orderType;
  final Customer? selectedCustomer;
  final ValueChanged<OrderType> onOrderTypeChanged;
  final VoidCallback onCustomerSelectorPressed;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: AppSpacing.allMd,
      child: Column(
        children: <Widget>[
          OrderTypeSelector(
            selectedOrderType: orderType,
            onOrderTypeSelected: onOrderTypeChanged,
          ),
          const SizedBox(height: AppSpacing.md),
          _TableCustomerRow(
            selectedCustomer: selectedCustomer,
            onCustomerSelectorPressed: onCustomerSelectorPressed,
          ),
        ],
      ),
    );
  }
}

class _TableCustomerRow extends StatelessWidget {
  const _TableCustomerRow({
    required this.selectedCustomer,
    required this.onCustomerSelectorPressed,
  });

  final Customer? selectedCustomer;
  final VoidCallback onCustomerSelectorPressed;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        if (constraints.maxWidth < AppSizes.cartControlsStackBreakpoint) {
          return Column(
            children: <Widget>[
              const SizedBox(width: double.infinity, child: _TableInput()),
              const SizedBox(height: AppSpacing.sm),
              CartCustomerSelector(
                customer: selectedCustomer,
                onTap: onCustomerSelectorPressed,
              ),
            ],
          );
        }

        return Row(
          children: <Widget>[
            const SizedBox(
              width: AppSizes.tableInputWidth,
              child: _TableInput(),
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: CartCustomerSelector(
                customer: selectedCustomer,
                onTap: onCustomerSelectorPressed,
              ),
            ),
          ],
        );
      },
    );
  }
}

class _TableInput extends StatelessWidget {
  const _TableInput();

  @override
  Widget build(BuildContext context) {
    return Container(
      height: AppSizes.cartControlHeight,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border.all(color: AppColors.border),
        borderRadius: AppRadius.control,
      ),
      child: Text(
        '12',
        style: AppTextStyles.bodySmall.copyWith(color: AppColors.textDark),
      ),
    );
  }
}

class _AddDiscountButton extends StatelessWidget {
  const _AddDiscountButton({required this.isEnabled, required this.onPressed});

  final bool isEnabled;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final Color contentColor = isEnabled
        ? AppColors.tertiary
        : AppColors.textMuted;
    final Color borderColor = isEnabled
        ? AppColors.dashedBorder
        : AppColors.border;

    return MouseRegion(
      cursor: isEnabled ? SystemMouseCursors.click : MouseCursor.defer,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onPressed,
        child: Opacity(
          opacity: isEnabled ? 1 : 0.55,
          child: CustomPaint(
            painter: _DashedBorderPainter(
              color: borderColor,
              radius: AppRadius.sm,
            ),
            child: SizedBox(
              height: AppSizes.cartControlHeight,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: <Widget>[
                  Icon(
                    Icons.local_offer_outlined,
                    color: contentColor,
                    size: 14,
                  ),
                  const SizedBox(width: AppSpacing.xs),
                  Text(
                    'ADD DISCOUNT',
                    style: AppTextStyles.labelSmall.copyWith(
                      color: contentColor,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.6,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _CartFooter extends StatelessWidget {
  const _CartFooter({
    required this.subtotal,
    required this.discountTotal,
    required this.tax,
    required this.total,
    required this.itemCount,
    required this.hasCartItems,
    required this.appliedDiscount,
    required this.onRemoveDiscount,
    required this.onClearCart,
    required this.onPay,
  });

  final double subtotal;
  final double discountTotal;
  final double tax;
  final double total;
  final int itemCount;
  final bool hasCartItems;
  final AppliedDiscount? appliedDiscount;
  final VoidCallback onRemoveDiscount;
  final VoidCallback onClearCart;
  final VoidCallback onPay;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        color: AppColors.shellBackground,
        border: Border(top: BorderSide(color: AppColors.shellBorder)),
      ),
      child: Padding(
        padding: AppSpacing.allLg,
        child: Column(
          children: <Widget>[
            OrderTotalsPanel(
              subtotal: subtotal,
              discountTotal: discountTotal,
              tax: tax,
              total: total,
              appliedDiscount: appliedDiscount,
              onRemoveDiscount: onRemoveDiscount,
            ),
            const SizedBox(height: AppSpacing.lg),
            PosActionButtons(
              total: total,
              onCancel: onClearCart,
              onPay: onPay,
              isPaymentEnabled: hasCartItems && total > 0 && itemCount > 0,
            ),
          ],
        ),
      ),
    );
  }
}

class _DashedBorderPainter extends CustomPainter {
  const _DashedBorderPainter({required this.color, required this.radius});

  final Color color;
  final double radius;

  @override
  void paint(Canvas canvas, Size size) {
    final Paint paint = Paint()
      ..color = color
      ..strokeWidth = 1
      ..style = PaintingStyle.stroke;
    final RRect rrect = RRect.fromRectAndRadius(
      Offset.zero & size,
      Radius.circular(radius),
    );
    final Path path = Path()..addRRect(rrect);

    for (final PathMetric metric in path.computeMetrics()) {
      double distance = 0;
      while (distance < metric.length) {
        final double next = (distance + AppSpacing.sm).clamp(0, metric.length);
        canvas.drawPath(metric.extractPath(distance, next), paint);
        distance += AppSpacing.md;
      }
    }
  }

  @override
  bool shouldRepaint(covariant _DashedBorderPainter oldDelegate) {
    return oldDelegate.color != color || oldDelegate.radius != radius;
  }
}

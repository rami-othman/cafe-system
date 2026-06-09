import 'dart:ui' show PathMetric;

import 'package:flutter/material.dart';

import '../../../core/constants/app_sizes.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_radius.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_text_styles.dart';
import '../models/cart_item.dart';
import 'cart_item_tile.dart';
import 'order_totals_panel.dart';
import 'order_type_selector.dart';
import 'pos_action_buttons.dart';

class PosCartPanel extends StatelessWidget {
  const PosCartPanel({super.key});

  static const List<CartItem> _items = <CartItem>[
    CartItem(
      name: 'Cappuccino',
      modifiers: 'Oat Milk, Extra Shot',
      price: r'$5.50',
      quantity: 1,
    ),
    CartItem(
      name: 'Almond Croissant',
      modifiers: 'Warmed',
      price: r'$9.00',
      quantity: 2,
    ),
  ];

  @override
  Widget build(BuildContext context) {
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
          const _OrderControls(),
          Expanded(
            child: ListView.separated(
              padding: AppSpacing.allLg,
              itemCount: _items.length + 1,
              separatorBuilder: (BuildContext context, int index) {
                return const SizedBox(height: AppSpacing.md);
              },
              itemBuilder: (BuildContext context, int index) {
                if (index == _items.length) {
                  return const _AddDiscountButton();
                }

                return CartItemTile(item: _items[index]);
              },
            ),
          ),
          const _CartFooter(),
        ],
      ),
    );
  }
}

class _OrderControls extends StatelessWidget {
  const _OrderControls();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: AppSpacing.allMd,
      child: Column(
        children: <Widget>[
          OrderTypeSelector(),
          SizedBox(height: AppSpacing.md),
          _TableCustomerRow(),
        ],
      ),
    );
  }
}

class _TableCustomerRow extends StatelessWidget {
  const _TableCustomerRow();

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        if (constraints.maxWidth < AppSizes.cartControlsStackBreakpoint) {
          return const Column(
            children: <Widget>[
              SizedBox(width: double.infinity, child: _TableInput()),
              SizedBox(height: AppSpacing.sm),
              _CustomerButton(),
            ],
          );
        }

        return const Row(
          children: <Widget>[
            SizedBox(width: AppSizes.tableInputWidth, child: _TableInput()),
            SizedBox(width: AppSpacing.sm),
            Expanded(child: _CustomerButton()),
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

class _CustomerButton extends StatelessWidget {
  const _CustomerButton();

  @override
  Widget build(BuildContext context) {
    return Container(
      height: AppSizes.cartControlHeight,
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border.all(color: AppColors.border),
        borderRadius: AppRadius.control,
      ),
      child: Row(
        children: <Widget>[
          const Icon(
            Icons.person_outline,
            size: 14,
            color: AppColors.textSecondary,
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              'Walk-in Customer',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppTextStyles.bodySmall.copyWith(
                color: AppColors.textDark,
                fontWeight: FontWeight.w400,
              ),
            ),
          ),
          const Icon(
            Icons.keyboard_arrow_down,
            size: 16,
            color: AppColors.textSecondary,
          ),
        ],
      ),
    );
  }
}

class _AddDiscountButton extends StatelessWidget {
  const _AddDiscountButton();

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _DashedBorderPainter(
        color: AppColors.dashedBorder,
        radius: AppRadius.sm,
      ),
      child: SizedBox(
        height: AppSizes.cartControlHeight,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            const Icon(
              Icons.local_offer_outlined,
              color: AppColors.tertiary,
              size: 14,
            ),
            const SizedBox(width: AppSpacing.xs),
            Text(
              'ADD DISCOUNT',
              style: AppTextStyles.labelSmall.copyWith(
                color: AppColors.tertiary,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.6,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CartFooter extends StatelessWidget {
  const _CartFooter();

  @override
  Widget build(BuildContext context) {
    return const DecoratedBox(
      decoration: BoxDecoration(
        color: AppColors.shellBackground,
        border: Border(top: BorderSide(color: AppColors.shellBorder)),
      ),
      child: Padding(
        padding: AppSpacing.allLg,
        child: Column(
          children: <Widget>[
            OrderTotalsPanel(),
            SizedBox(height: AppSpacing.lg),
            PosActionButtons(),
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

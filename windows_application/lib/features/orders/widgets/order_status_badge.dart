import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_radius.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_text_styles.dart';
import '../models/order_status.dart';

class OrderStatusBadge extends StatelessWidget {
  const OrderStatusBadge({super.key, required this.status});

  final OrderStatus status;

  @override
  Widget build(BuildContext context) {
    final _BadgeStyle style = _styleFor(status);

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: 5,
      ),
      decoration: BoxDecoration(
        color: style.background,
        border: Border.all(color: style.border),
        borderRadius: AppRadius.control,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(style.icon, size: 14, color: style.foreground),
          const SizedBox(width: AppSpacing.xs),
          Text(
            status.label,
            style: AppTextStyles.labelSmall.copyWith(
              color: style.foreground,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.6,
            ),
          ),
        ],
      ),
    );
  }

  _BadgeStyle _styleFor(OrderStatus status) {
    return switch (status) {
      OrderStatus.preparing => const _BadgeStyle(
        background: AppColors.orderPreparingBadge,
        border: AppColors.orderPreparingBorder,
        foreground: AppColors.orderPreparingText,
        icon: Icons.restaurant_outlined,
      ),
      OrderStatus.held => const _BadgeStyle(
        background: AppColors.orderHeldBadge,
        border: AppColors.orderHeldBorder,
        foreground: AppColors.orderHeldText,
        icon: Icons.pause_circle_outline,
      ),
      OrderStatus.ready => const _BadgeStyle(
        background: AppColors.orderReadyBadge,
        border: AppColors.orderReadyBorder,
        foreground: AppColors.orderReadyText,
        icon: Icons.check_circle_outline,
      ),
      OrderStatus.completed => const _BadgeStyle(
        background: AppColors.orderCompletedBadge,
        border: AppColors.orderCompletedBorder,
        foreground: AppColors.orderCompletedText,
        icon: Icons.done_all_outlined,
      ),
      OrderStatus.cancelled => const _BadgeStyle(
        background: AppColors.orderCancelledBadge,
        border: AppColors.orderCancelledBorder,
        foreground: AppColors.orderCancelledText,
        icon: Icons.cancel_outlined,
      ),
      OrderStatus.refunded => const _BadgeStyle(
        background: AppColors.orderRefundedBadge,
        border: AppColors.orderRefundedBorder,
        foreground: AppColors.orderRefundedText,
        icon: Icons.keyboard_return_outlined,
      ),
      OrderStatus.partiallyRefunded => const _BadgeStyle(
        background: AppColors.orderHeldBadge,
        border: AppColors.orderHeldBorder,
        foreground: AppColors.orderHeldText,
        icon: Icons.keyboard_return_outlined,
      ),
    };
  }
}

class _BadgeStyle {
  const _BadgeStyle({
    required this.background,
    required this.border,
    required this.foreground,
    required this.icon,
  });

  final Color background;
  final Color border;
  final Color foreground;
  final IconData icon;
}

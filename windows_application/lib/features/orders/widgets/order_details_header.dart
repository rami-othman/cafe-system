import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../core/constants/app_sizes.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_radius.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_text_styles.dart';
import '../models/order_detail.dart';
import 'order_status_badge.dart';

class OrderDetailsHeader extends StatelessWidget {
  const OrderDetailsHeader({
    super.key,
    required this.detail,
    required this.onClose,
    required this.onPrint,
    required this.onCopy,
    required this.onRefund,
  });

  final OrderDetail detail;
  final VoidCallback onClose;
  final VoidCallback onPrint;
  final VoidCallback onCopy;
  final VoidCallback onRefund;

  @override
  Widget build(BuildContext context) {
    final String date = DateFormat('MMM d, yyyy').format(detail.createdAt);
    final String time = DateFormat('h:mm a').format(detail.createdAt);

    return DecoratedBox(
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(bottom: BorderSide(color: AppColors.border)),
      ),
      child: Padding(
        padding: AppSpacing.allXl,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                _HeaderIconButton(
                  tooltip: 'Close order details',
                  icon: Icons.close,
                  onTap: onClose,
                ),
                const Spacer(),
                _HeaderIconButton(
                  tooltip: 'Print order',
                  icon: Icons.print_outlined,
                  onTap: onPrint,
                ),
                const SizedBox(width: AppSpacing.sm),
                _HeaderIconButton(
                  tooltip: 'Copy order',
                  icon: Icons.copy_outlined,
                  onTap: onCopy,
                ),
                const SizedBox(width: AppSpacing.sm),
                _RefundButton(
                  onTap: detail.isRefunded ? null : onRefund,
                  isDisabled: detail.isRefunded,
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.lg),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        detail.displayNumber,
                        style: AppTextStyles.titleLarge.copyWith(
                          color: AppColors.primary,
                          fontSize: 22,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.xs),
                      Text(
                        '$date - $time',
                        style: AppTextStyles.bodySmall.copyWith(
                          color: AppColors.textMuted,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                OrderStatusBadge(status: detail.status),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _HeaderIconButton extends StatelessWidget {
  const _HeaderIconButton({
    required this.tooltip,
    required this.icon,
    required this.onTap,
  });

  final String tooltip;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: SizedBox.square(
        dimension: AppSizes.orderDetailsHeaderIconSize,
        child: Material(
          color: AppColors.surface,
          borderRadius: AppRadius.control,
          child: InkWell(
            onTap: onTap,
            borderRadius: AppRadius.control,
            child: DecoratedBox(
              decoration: BoxDecoration(
                border: Border.all(color: AppColors.border),
                borderRadius: AppRadius.control,
              ),
              child: Icon(icon, size: 18, color: AppColors.primary),
            ),
          ),
        ),
      ),
    );
  }
}

class _RefundButton extends StatelessWidget {
  const _RefundButton({required this.onTap, required this.isDisabled});

  final VoidCallback? onTap;
  final bool isDisabled;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: AppSizes.orderDetailsHeaderIconSize,
      child: OutlinedButton(
        onPressed: onTap,
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.secondary,
          side: const BorderSide(color: AppColors.border),
          shape: const RoundedRectangleBorder(borderRadius: AppRadius.control),
          padding: AppSpacing.horizontalMd,
        ),
        child: Text(isDisabled ? 'Refunded' : 'Refund'),
      ),
    );
  }
}

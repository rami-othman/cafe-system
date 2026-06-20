import 'package:flutter/material.dart';

import '../../../core/constants/app_sizes.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_text_styles.dart';
import '../models/order_detail.dart';

class OrderCustomerSection extends StatelessWidget {
  const OrderCustomerSection({super.key, required this.detail});

  final OrderDetail detail;

  @override
  Widget build(BuildContext context) {
    final String name = detail.hasCustomer
        ? detail.customerName
        : 'Walk-in Customer';
    final String initials = detail.hasCustomer ? _initialsFor(name) : 'WC';

    return _DetailSection(
      title: 'Customer',
      child: Row(
        children: <Widget>[
          CircleAvatar(
            radius: AppSizes.orderDetailsAvatarSize / 2,
            backgroundColor: AppColors.primarySoft,
            child: Text(
              initials,
              style: AppTextStyles.labelMedium.copyWith(
                color: AppColors.primary,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  name,
                  style: AppTextStyles.labelLarge.copyWith(
                    color: AppColors.textPrimary,
                  ),
                ),
                if (detail.customerPhone.isNotEmpty) ...<Widget>[
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    detail.customerPhone,
                    style: AppTextStyles.bodySmall.copyWith(
                      color: AppColors.textMuted,
                    ),
                  ),
                ],
                if (detail.customerEmail.isNotEmpty) ...<Widget>[
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    detail.customerEmail,
                    style: AppTextStyles.bodySmall.copyWith(
                      color: AppColors.textMuted,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _initialsFor(String name) {
    final List<String> parts = name
        .split(' ')
        .where((String part) => part.trim().isNotEmpty)
        .toList(growable: false);
    if (parts.isEmpty) {
      return 'WC';
    }

    return parts.take(2).map((String part) => part[0]).join().toUpperCase();
  }
}

class _DetailSection extends StatelessWidget {
  const _DetailSection({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          title,
          style: AppTextStyles.labelLarge.copyWith(
            color: AppColors.primary,
            fontSize: 14,
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        const Divider(height: 1, color: AppColors.divider),
        const SizedBox(height: AppSpacing.md),
        child,
      ],
    );
  }
}

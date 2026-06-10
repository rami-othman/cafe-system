import 'package:flutter/material.dart';

import '../../../core/constants/app_sizes.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_radius.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_text_styles.dart';
import '../models/order_type.dart';

class OrderTypeSelector extends StatelessWidget {
  const OrderTypeSelector({
    super.key,
    required this.selectedOrderType,
    required this.onOrderTypeSelected,
  });

  final OrderType selectedOrderType;
  final ValueChanged<OrderType> onOrderTypeSelected;

  static const List<OrderType> _types = <OrderType>[
    OrderType.dineIn,
    OrderType.takeaway,
    OrderType.delivery,
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      height: AppSizes.cartControlHeight,
      padding: AppSpacing.allXs,
      decoration: const BoxDecoration(
        color: AppColors.surfaceAlt,
        borderRadius: AppRadius.control,
      ),
      child: Row(
        children: <Widget>[
          for (int index = 0; index < _types.length; index += 1)
            Expanded(
              child: _OrderTypeSegment(
                label: _types[index].label,
                isActive: _types[index] == selectedOrderType,
                onTap: () => onOrderTypeSelected(_types[index]),
              ),
            ),
        ],
      ),
    );
  }
}

class _OrderTypeSegment extends StatelessWidget {
  const _OrderTypeSegment({
    required this.label,
    required this.isActive,
    required this.onTap,
  });

  final String label;
  final bool isActive;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: isActive ? AppColors.surface : AppColors.transparent,
      borderRadius: const BorderRadius.all(Radius.circular(AppRadius.sm / 2)),
      child: InkWell(
        onTap: onTap,
        borderRadius: const BorderRadius.all(Radius.circular(AppRadius.sm / 2)),
        child: Center(
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppTextStyles.labelSmall.copyWith(
              color: isActive ? AppColors.primary : AppColors.textSecondary,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.6,
            ),
          ),
        ),
      ),
    );
  }
}

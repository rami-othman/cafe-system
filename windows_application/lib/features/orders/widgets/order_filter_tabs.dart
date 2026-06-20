import 'package:flutter/material.dart';

import '../../../core/constants/app_sizes.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_radius.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_text_styles.dart';
import '../controllers/orders_state.dart';

class OrderFilterTabs extends StatelessWidget {
  const OrderFilterTabs({
    super.key,
    required this.selectedFilter,
    required this.onFilterSelected,
  });

  final OrdersFilter selectedFilter;
  final ValueChanged<OrdersFilter> onFilterSelected;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: AppSizes.orderFilterTabHeight + AppSpacing.sm,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: OrdersFilter.values.length,
        separatorBuilder: (BuildContext context, int index) {
          return const SizedBox(width: AppSpacing.sm);
        },
        itemBuilder: (BuildContext context, int index) {
          final OrdersFilter filter = OrdersFilter.values[index];

          return _OrderFilterTab(
            label: filter.label,
            isActive: filter == selectedFilter,
            onTap: () => onFilterSelected(filter),
          );
        },
      ),
    );
  }
}

class _OrderFilterTab extends StatelessWidget {
  const _OrderFilterTab({
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
      color: AppColors.transparent,
      borderRadius: AppRadius.control,
      child: InkWell(
        onTap: onTap,
        borderRadius: AppRadius.control,
        child: Container(
          height: AppSizes.orderFilterTabHeight,
          alignment: Alignment.center,
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
          decoration: BoxDecoration(
            color: isActive ? AppColors.primary : AppColors.surface,
            border: isActive ? null : Border.all(color: AppColors.border),
            borderRadius: AppRadius.control,
            boxShadow: isActive
                ? const <BoxShadow>[
                    BoxShadow(
                      color: Color(0x0A000000),
                      offset: Offset(0, 2),
                      blurRadius: 2,
                    ),
                  ]
                : null,
          ),
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppTextStyles.labelSmall.copyWith(
              color: isActive ? AppColors.textInverse : AppColors.textDark,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.6,
            ),
          ),
        ),
      ),
    );
  }
}

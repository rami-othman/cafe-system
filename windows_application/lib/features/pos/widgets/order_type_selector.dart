import 'package:flutter/material.dart';

import '../../../core/constants/app_sizes.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_radius.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_text_styles.dart';

class OrderTypeSelector extends StatelessWidget {
  const OrderTypeSelector({super.key});

  static const List<String> _types = <String>[
    'DINE-IN',
    'TAKEAWAY',
    'DELIVERY',
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
                label: _types[index],
                isActive: index == 0,
              ),
            ),
        ],
      ),
    );
  }
}

class _OrderTypeSegment extends StatelessWidget {
  const _OrderTypeSegment({required this.label, required this.isActive});

  final String label;
  final bool isActive;

  @override
  Widget build(BuildContext context) {
    return Container(
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: isActive ? AppColors.surface : AppColors.transparent,
        borderRadius: const BorderRadius.all(Radius.circular(AppRadius.sm / 2)),
        boxShadow: isActive
            ? const <BoxShadow>[
                BoxShadow(
                  color: Color(0x0D000000),
                  offset: Offset(0, 1),
                  blurRadius: 1,
                ),
              ]
            : null,
      ),
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
    );
  }
}

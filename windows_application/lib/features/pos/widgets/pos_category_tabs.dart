import 'package:flutter/material.dart';

import '../../../core/constants/app_sizes.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_radius.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_text_styles.dart';

class PosCategoryTabs extends StatelessWidget {
  const PosCategoryTabs({super.key});

  static const List<String> _categories = <String>[
    'COFFEE',
    'TEA',
    'COLD DRINKS',
    'DESSERTS',
    'SANDWICHES',
    'ADD-ONS',
  ];

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: AppSizes.categoryTabHeight,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: _categories.length,
        separatorBuilder: (BuildContext context, int index) {
          return const SizedBox(width: AppSpacing.sm);
        },
        itemBuilder: (BuildContext context, int index) {
          return _CategoryTab(label: _categories[index], isActive: index == 0);
        },
      ),
    );
  }
}

class _CategoryTab extends StatelessWidget {
  const _CategoryTab({required this.label, required this.isActive});

  final String label;
  final bool isActive;

  @override
  Widget build(BuildContext context) {
    return Container(
      alignment: Alignment.center,
      padding: const EdgeInsets.symmetric(
        horizontal: AppSizes.categoryTabHorizontalPadding,
      ),
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
        style: AppTextStyles.labelSmall.copyWith(
          color: isActive ? AppColors.textInverse : AppColors.textDark,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.6,
        ),
      ),
    );
  }
}

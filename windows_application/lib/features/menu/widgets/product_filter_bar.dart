import 'package:flutter/material.dart';

import '../../../core/constants/app_sizes.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_radius.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../shared/widgets/app_card.dart';
import '../../../shared/widgets/app_text_field.dart';

class ProductFilterBar extends StatelessWidget {
  const ProductFilterBar({super.key, required this.onSearchChanged});

  final ValueChanged<String> onSearchChanged;

  static const List<String> _filters = <String>[
    'Category: All',
    'Type: All',
    'Status: All',
    'Branch: All',
    'Availability: All',
  ];

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: AppSpacing.allLg,
      child: Wrap(
        spacing: AppSpacing.md,
        runSpacing: AppSpacing.md,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: <Widget>[
          ConstrainedBox(
            constraints: const BoxConstraints(
              minWidth: AppSizes.productsFilterMinWidth,
              maxWidth: 300,
            ),
            child: AppTextField(
              hintText: 'Search by name, SKU...',
              prefixIcon: Icons.search,
              onChanged: onSearchChanged,
            ),
          ),
          for (final String filter in _filters) _FilterButton(label: filter),
          TextButton.icon(
            onPressed: () {},
            style: TextButton.styleFrom(
              foregroundColor: AppColors.textMuted,
              textStyle: AppTextStyles.bodySmall.copyWith(fontSize: 14),
              padding: AppSpacing.horizontalSm,
            ),
            icon: const Icon(Icons.filter_list, size: 16),
            label: const Text('More Filters'),
          ),
        ],
      ),
    );
  }
}

class _FilterButton extends StatelessWidget {
  const _FilterButton({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      onPressed: () {},
      style: OutlinedButton.styleFrom(
        minimumSize: const Size(0, 44),
        foregroundColor: AppColors.textDark,
        backgroundColor: AppColors.contentBackground,
        textStyle: AppTextStyles.bodySmall.copyWith(
          color: AppColors.textDark,
          fontSize: 14,
          fontWeight: FontWeight.w400,
        ),
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
        side: const BorderSide(color: AppColors.border),
        shape: const RoundedRectangleBorder(borderRadius: AppRadius.control),
      ),
      iconAlignment: IconAlignment.end,
      icon: const Icon(Icons.keyboard_arrow_down, size: 18),
      label: Text(label),
    );
  }
}

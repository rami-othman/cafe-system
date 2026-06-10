import 'package:flutter/material.dart';

import '../../../core/constants/app_sizes.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_radius.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_text_styles.dart';

class PosSearchBar extends StatelessWidget {
  const PosSearchBar({
    super.key,
    this.width = AppSizes.posSearchWidth,
    required this.query,
    required this.onChanged,
  });

  final double width;
  final String query;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: AppSizes.posSearchHeight,
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border.all(color: AppColors.border),
        borderRadius: AppRadius.control,
        boxShadow: const <BoxShadow>[
          BoxShadow(
            color: Color(0x0A000000),
            offset: Offset(0, 2),
            blurRadius: 4,
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
        child: Row(
          children: <Widget>[
            const Icon(Icons.search, color: AppColors.textMuted, size: 18),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: TextFormField(
                key: ValueKey<String>('pos-search-$query'),
                initialValue: query,
                onChanged: onChanged,
                decoration: const InputDecoration.collapsed(
                  hintText: 'Search products...',
                ),
                style: AppTextStyles.bodySmall.copyWith(
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.w400,
                ),
                cursorColor: AppColors.primary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

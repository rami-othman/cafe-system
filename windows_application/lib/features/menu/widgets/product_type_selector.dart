import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_radius.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_text_styles.dart';
import '../models/menu_enums.dart';

class ProductTypeSelector extends StatelessWidget {
  const ProductTypeSelector({
    super.key,
    required this.value,
    required this.onChanged,
  });

  final ProductType value;
  final ValueChanged<ProductType> onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Row(
          children: ProductType.values.map((ProductType type) {
            final bool selected = type == value;
            return Expanded(
              child: Padding(
                padding: EdgeInsets.only(
                  right: type == ProductType.combo ? 0 : AppSpacing.xs,
                ),
                child: Material(
                  color: selected ? AppColors.primarySoft : AppColors.surface,
                  shape: RoundedRectangleBorder(
                    borderRadius: AppRadius.control,
                    side: BorderSide(
                      color: selected ? AppColors.secondary : AppColors.border,
                    ),
                  ),
                  child: InkWell(
                    borderRadius: AppRadius.control,
                    onTap: () => onChanged(type),
                    child: SizedBox(
                      height: 40,
                      child: Center(
                        child: Text(
                          _labelFor(type),
                          style: AppTextStyles.bodySmall.copyWith(
                            color: selected
                                ? AppColors.primary
                                : AppColors.textMuted,
                            fontWeight: selected
                                ? FontWeight.w700
                                : FontWeight.w500,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            );
          }).toList(),
        ),
        const SizedBox(height: AppSpacing.xs),
        Text(
          _helperFor(value),
          style: AppTextStyles.bodySmall.copyWith(
            color: AppColors.textMuted,
            fontSize: 11,
          ),
        ),
      ],
    );
  }

  String _labelFor(ProductType type) {
    return switch (type) {
      ProductType.simple => 'Simple',
      ProductType.variant => 'Variant',
      ProductType.combo => 'Combo',
    };
  }

  String _helperFor(ProductType type) {
    return switch (type) {
      ProductType.simple => 'Simple product has no sizes or options.',
      ProductType.variant => 'Variant options will be configured after saving.',
      ProductType.combo => 'Combo items will be configured after saving.',
    };
  }
}

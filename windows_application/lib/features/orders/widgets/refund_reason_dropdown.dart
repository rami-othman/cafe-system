import 'package:flutter/material.dart';

import '../../../core/constants/app_sizes.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_radius.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_text_styles.dart';
import '../models/refund_reason.dart';

class RefundReasonDropdown extends StatelessWidget {
  const RefundReasonDropdown({
    super.key,
    required this.selectedReason,
    required this.onChanged,
  });

  final RefundReason selectedReason;
  final ValueChanged<RefundReason> onChanged;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: AppSizes.refundInputHeight,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: AppColors.white,
          border: Border.all(color: AppColors.border),
          borderRadius: AppRadius.control,
        ),
        child: DropdownButtonHideUnderline(
          child: DropdownButton<RefundReason>(
            value: selectedReason,
            isExpanded: true,
            borderRadius: AppRadius.control,
            padding: AppSpacing.horizontalMd,
            icon: const Icon(
              Icons.keyboard_arrow_down,
              color: AppColors.textMuted,
            ),
            items: RefundReason.values
                .map((RefundReason reason) {
                  return DropdownMenuItem<RefundReason>(
                    value: reason,
                    child: Text(
                      reason.label,
                      style: AppTextStyles.bodySmall.copyWith(
                        color: AppColors.textPrimary,
                      ),
                    ),
                  );
                })
                .toList(growable: false),
            onChanged: (RefundReason? reason) {
              if (reason != null) {
                onChanged(reason);
              }
            },
          ),
        ),
      ),
    );
  }
}

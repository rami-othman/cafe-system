import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_radius.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_text_styles.dart';

class RefundWarningBox extends StatelessWidget {
  const RefundWarningBox({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: AppSpacing.allMd,
      decoration: BoxDecoration(
        color: AppColors.refundWarningBackground,
        border: Border.all(color: AppColors.refundWarningBorder),
        borderRadius: AppRadius.control,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const Icon(
            Icons.warning_amber_rounded,
            color: AppColors.dangerStrong,
            size: 18,
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              'Safety First: This action will reverse the payment and cannot be undone.\n'
              'Please verify all details before confirming.',
              style: AppTextStyles.bodySmall.copyWith(
                color: AppColors.dangerStrong,
                fontSize: 12,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

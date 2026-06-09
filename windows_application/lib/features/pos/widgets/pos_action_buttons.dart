import 'package:flutter/material.dart';

import '../../../core/constants/app_sizes.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_radius.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_text_styles.dart';

class PosActionButtons extends StatelessWidget {
  const PosActionButtons({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: <Widget>[
        const Row(
          children: <Widget>[
            Expanded(child: _SecondaryActionButton(label: 'HOLD')),
            SizedBox(width: AppSpacing.sm),
            Expanded(
              child: _SecondaryActionButton(
                label: 'CANCEL',
                foreground: AppColors.dangerStrong,
              ),
            ),
            SizedBox(width: AppSpacing.sm),
            Expanded(child: _SecondaryActionButton(label: 'PRINT')),
          ],
        ),
        const SizedBox(height: AppSpacing.md),
        SizedBox(
          width: double.infinity,
          height: AppSizes.payButtonHeight,
          child: FilledButton(
            onPressed: () {},
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.tertiary,
              foregroundColor: AppColors.textInverse,
              shape: const RoundedRectangleBorder(
                borderRadius: AppRadius.control,
              ),
              textStyle: AppTextStyles.titleMedium.copyWith(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.45,
              ),
            ),
            child: const Text('PAY \$15.66'),
          ),
        ),
      ],
    );
  }
}

class _SecondaryActionButton extends StatelessWidget {
  const _SecondaryActionButton({
    required this.label,
    this.foreground = AppColors.textMuted,
  });

  final String label;
  final Color foreground;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: AppSizes.cartControlHeight,
      child: OutlinedButton(
        onPressed: () {},
        style: OutlinedButton.styleFrom(
          backgroundColor: AppColors.surface,
          foregroundColor: foreground,
          side: const BorderSide(color: AppColors.border),
          shape: const RoundedRectangleBorder(borderRadius: AppRadius.control),
          textStyle: AppTextStyles.labelSmall.copyWith(
            fontWeight: FontWeight.w800,
            letterSpacing: 0.6,
          ),
        ),
        child: Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          textAlign: TextAlign.center,
        ),
      ),
    );
  }
}

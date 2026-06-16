import 'package:flutter/material.dart';

import '../../../core/constants/app_sizes.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_radius.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_text_styles.dart';

class CouponCodeInput extends StatelessWidget {
  const CouponCodeInput({
    super.key,
    required this.controller,
    required this.onApply,
  });

  final TextEditingController controller;
  final VoidCallback onApply;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final Widget input = _CouponTextField(
          controller: controller,
          onApply: onApply,
        );
        final Widget applyButton = _ApplyButton(onApply: onApply);

        if (constraints.maxWidth < 300) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              input,
              const SizedBox(height: AppSpacing.sm),
              Align(alignment: Alignment.centerRight, child: applyButton),
            ],
          );
        }

        return Row(
          children: <Widget>[
            Expanded(child: input),
            const SizedBox(width: AppSpacing.sm),
            applyButton,
          ],
        );
      },
    );
  }
}

class _CouponTextField extends StatelessWidget {
  const _CouponTextField({required this.controller, required this.onApply});

  final TextEditingController controller;
  final VoidCallback onApply;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: AppSizes.inputHeight,
      padding: AppSpacing.horizontalMd,
      decoration: BoxDecoration(
        color: AppColors.white,
        border: Border.all(color: AppColors.border),
        borderRadius: AppRadius.control,
      ),
      alignment: Alignment.center,
      child: TextField(
        controller: controller,
        cursorColor: AppColors.primary,
        textInputAction: TextInputAction.done,
        onSubmitted: (_) => onApply(),
        decoration: InputDecoration(
          border: InputBorder.none,
          enabledBorder: InputBorder.none,
          focusedBorder: InputBorder.none,
          errorBorder: InputBorder.none,
          disabledBorder: InputBorder.none,
          focusedErrorBorder: InputBorder.none,
          isCollapsed: true,
          hintText: 'Enter code',
          hintStyle: AppTextStyles.bodyMedium.copyWith(
            color: AppColors.textMuted,
            fontWeight: FontWeight.w400,
          ),
        ),
        style: AppTextStyles.bodyMedium.copyWith(color: AppColors.textPrimary),
      ),
    );
  }
}

class _ApplyButton extends StatelessWidget {
  const _ApplyButton({required this.onApply});

  final VoidCallback onApply;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: AppSizes.discountInputApplyWidth,
      height: AppSizes.inputHeight,
      child: FilledButton(
        onPressed: onApply,
        style: FilledButton.styleFrom(
          minimumSize: const Size(0, AppSizes.inputHeight),
          padding: AppSpacing.horizontalSm,
          backgroundColor: AppColors.tertiary,
          foregroundColor: AppColors.white,
          textStyle: AppTextStyles.buttonMedium,
          shape: const RoundedRectangleBorder(borderRadius: AppRadius.control),
        ),
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            'Apply',
            maxLines: 1,
            softWrap: false,
            style: AppTextStyles.buttonMedium.copyWith(
              color: AppColors.white,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
      ),
    );
  }
}

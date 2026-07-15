import 'package:flutter/material.dart';

import '../../../core/constants/app_sizes.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../shared/widgets/app_button.dart';

class DiscountBottomActionBar extends StatelessWidget {
  const DiscountBottomActionBar({
    super.key,
    required this.onDiscard,
    required this.onSaveDraft,
    required this.onActivate,
  });

  final VoidCallback onDiscard;
  final VoidCallback onSaveDraft;
  final VoidCallback onActivate;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.xl,
        vertical: AppSpacing.md,
      ),
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(top: BorderSide(color: AppColors.border)),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: Color(0x0D000000),
            offset: Offset(0, -4),
            blurRadius: 6,
          ),
        ],
      ),
      child: LayoutBuilder(
        builder: (BuildContext context, BoxConstraints constraints) {
          final Widget discard = TextButton(
            onPressed: onDiscard,
            child: Text(
              'Discard Changes',
              style: AppTextStyles.bodyMedium.copyWith(
                color: AppColors.textMuted,
              ),
            ),
          );
          final List<Widget> actions = <Widget>[
            AppButton(
              label: 'Save as Draft',
              variant: AppButtonVariant.outlined,
              onPressed: onSaveDraft,
            ),
            const SizedBox(width: AppSpacing.md),
            AppButton(
              label: 'Activate Discount',
              icon: Icons.bolt,
              variant: AppButtonVariant.accent,
              onPressed: onActivate,
            ),
          ];

          if (constraints.maxWidth <
              AppSizes.createProductFooterStackBreakpoint) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                Align(alignment: Alignment.centerLeft, child: discard),
                const SizedBox(height: AppSpacing.sm),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: actions,
                ),
              ],
            );
          }

          return Row(children: <Widget>[discard, const Spacer(), ...actions]);
        },
      ),
    );
  }
}

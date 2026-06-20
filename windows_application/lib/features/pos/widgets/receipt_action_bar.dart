import 'package:flutter/material.dart';

import '../../../core/constants/app_sizes.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_radius.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_text_styles.dart';

class ReceiptActionBar extends StatelessWidget {
  const ReceiptActionBar({
    super.key,
    required this.onSendViaWhatsApp,
    required this.onPrintReceipt,
  });

  final VoidCallback onSendViaWhatsApp;
  final VoidCallback onPrintReceipt;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: AppSpacing.allLg,
      decoration: const BoxDecoration(
        color: AppColors.white,
        border: Border(top: BorderSide(color: AppColors.border)),
      ),
      child: Wrap(
        alignment: WrapAlignment.end,
        spacing: AppSpacing.md,
        runSpacing: AppSpacing.sm,
        children: <Widget>[
          SizedBox(
            height: AppSizes.receiptActionButtonHeight,
            child: OutlinedButton.icon(
              onPressed: onSendViaWhatsApp,
              icon: const Icon(Icons.send_outlined, size: 18),
              label: const Text('Send via WhatsApp'),
              style: OutlinedButton.styleFrom(
                backgroundColor: AppColors.white,
                foregroundColor: AppColors.primary,
                side: const BorderSide(color: AppColors.border),
                textStyle: AppTextStyles.buttonMedium,
                shape: const RoundedRectangleBorder(
                  borderRadius: AppRadius.control,
                ),
              ),
            ),
          ),
          SizedBox(
            height: AppSizes.receiptActionButtonHeight,
            child: FilledButton.icon(
              onPressed: onPrintReceipt,
              icon: const Icon(Icons.print_outlined, size: 18),
              label: const Text('Print Receipt'),
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.tertiary,
                foregroundColor: AppColors.white,
                textStyle: AppTextStyles.buttonMedium,
                shape: const RoundedRectangleBorder(
                  borderRadius: AppRadius.control,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

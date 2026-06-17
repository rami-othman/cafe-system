import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../core/constants/app_sizes.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_radius.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_text_styles.dart';
import '../models/order_receipt.dart';
import 'receipt_action_bar.dart';
import 'receipt_preview_paper.dart';

class ReceiptPreviewDialog extends StatelessWidget {
  const ReceiptPreviewDialog({super.key, required this.receipt});

  final OrderReceipt receipt;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints viewport) {
        final double availableWidth = math.max(
          viewport.maxWidth - AppSpacing.xxl,
          260,
        );
        final double availableHeight = math.max(
          viewport.maxHeight - AppSpacing.xxl,
          280,
        );

        return Center(
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: math.min(availableWidth, AppSizes.receiptDialogWidth),
              maxHeight: math.min(
                availableHeight,
                AppSizes.receiptDialogMaxHeight,
              ),
            ),
            child: Material(
              color: AppColors.white,
              clipBehavior: Clip.antiAlias,
              borderRadius: AppRadius.dialog,
              child: DecoratedBox(
                decoration: const BoxDecoration(
                  color: AppColors.white,
                  borderRadius: AppRadius.dialog,
                  boxShadow: <BoxShadow>[
                    BoxShadow(
                      color: Color(0x30000000),
                      offset: Offset(0, 18),
                      blurRadius: 36,
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    const _ReceiptDialogHeader(),
                    Flexible(
                      child: DecoratedBox(
                        decoration: const BoxDecoration(
                          color: AppColors.receiptPreviewBackground,
                        ),
                        child: SingleChildScrollView(
                          padding: AppSpacing.allXl,
                          child: Center(
                            child: ReceiptPreviewPaper(receipt: receipt),
                          ),
                        ),
                      ),
                    ),
                    ReceiptActionBar(
                      onSendViaWhatsApp: () => _showPlaceholder(
                        context,
                        'WhatsApp sending will be added later.',
                      ),
                      onPrintReceipt: () => _completePaymentFeedback(context),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  void _showPlaceholder(BuildContext context, String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  void _completePaymentFeedback(BuildContext context) {
    final ScaffoldMessengerState messenger = ScaffoldMessenger.of(context);
    Navigator.of(context).pop();
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(const SnackBar(content: Text('Payment completed')));
  }
}

class _ReceiptDialogHeader extends StatelessWidget {
  const _ReceiptDialogHeader();

  @override
  Widget build(BuildContext context) {
    return Container(
      height: AppSizes.receiptDialogHeaderHeight,
      padding: AppSpacing.horizontalXl,
      decoration: const BoxDecoration(
        color: AppColors.white,
        border: Border(bottom: BorderSide(color: AppColors.border)),
      ),
      child: Row(
        children: <Widget>[
          Expanded(
            child: Text(
              'Receipt Preview',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppTextStyles.labelLarge.copyWith(
                color: AppColors.textPrimary,
                fontSize: 15,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          IconButton(
            onPressed: () => Navigator.of(context).pop(),
            icon: const Icon(Icons.close, size: 20),
            color: AppColors.textPrimary,
            tooltip: 'Close receipt preview',
          ),
        ],
      ),
    );
  }
}

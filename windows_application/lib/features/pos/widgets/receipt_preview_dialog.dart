import 'dart:async';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../../../app/localization/localization_extensions.dart';
import '../../../core/constants/app_sizes.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_radius.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_text_styles.dart';
import '../models/order_receipt.dart';
import '../services/file_handoff.dart';
import '../services/receipt_image_builder.dart';
import 'receipt_action_bar.dart';
import 'receipt_preview_paper.dart';

class ReceiptPreviewDialog extends StatefulWidget {
  const ReceiptPreviewDialog({
    super.key,
    required this.receipt,
    required this.onPrintReceipt,
    required this.onSendViaWhatsApp,
    this.isPrinting = false,
  });

  final OrderReceipt receipt;
  final VoidCallback onPrintReceipt;

  /// Receives a builder that renders the receipt shown here into a PNG.
  final Future<void> Function(Future<Uint8List> Function() buildImage)
  onSendViaWhatsApp;
  final bool isPrinting;

  @override
  State<ReceiptPreviewDialog> createState() => _ReceiptPreviewDialogState();
}

class _ReceiptPreviewDialogState extends State<ReceiptPreviewDialog> {
  final GlobalKey _paperKey = GlobalKey();
  bool _isSendingWhatsApp = false;

  @override
  void initState() {
    super.initState();
    // Bring the local bridge up so the Chrome extension can connect before the
    // cashier presses the WhatsApp button.
    unawaited(startWhatsAppBridge());
  }

  Future<void> _sendViaWhatsApp() async {
    if (_isSendingWhatsApp) return;
    setState(() => _isSendingWhatsApp = true);
    try {
      await widget.onSendViaWhatsApp(() => buildReceiptPng(_paperKey));
    } finally {
      if (mounted) setState(() => _isSendingWhatsApp = false);
    }
  }

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
                            child: RepaintBoundary(
                              key: _paperKey,
                              child: ReceiptPreviewPaper(
                                receipt: widget.receipt,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                    ReceiptActionBar(
                      onSendViaWhatsApp: () => unawaited(_sendViaWhatsApp()),
                      isSendingWhatsApp: _isSendingWhatsApp,
                      onPrintReceipt: widget.onPrintReceipt,
                      isPrinting: widget.isPrinting,
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
              context.l10n.posReceiptPreview,
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
            tooltip: context.l10n.posCloseReceiptPreview,
          ),
        ],
      ),
    );
  }
}

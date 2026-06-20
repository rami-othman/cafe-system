import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/constants/app_sizes.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_radius.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_text_styles.dart';
import '../models/order_detail.dart';
import '../models/refund_reason.dart';
import '../models/refund_result.dart';
import '../models/refund_type.dart';
import 'refund_reason_dropdown.dart';
import 'refund_summary_card.dart';
import 'refund_type_selector.dart';
import 'refund_warning_box.dart';

class RefundDialog extends StatefulWidget {
  const RefundDialog({super.key, required this.orderDetail});

  final OrderDetail orderDetail;

  @override
  State<RefundDialog> createState() => _RefundDialogState();
}

class _RefundDialogState extends State<RefundDialog> {
  late final TextEditingController _amountController;
  late final TextEditingController _notesController;
  RefundType _type = RefundType.full;
  RefundReason _reason = RefundReason.customerRequest;

  @override
  void initState() {
    super.initState();
    _amountController = TextEditingController(text: _fullAmountText);
    _notesController = TextEditingController();
    _amountController.addListener(_handleAmountChanged);
  }

  @override
  void dispose() {
    _amountController
      ..removeListener(_handleAmountChanged)
      ..dispose();
    _notesController.dispose();
    super.dispose();
  }

  String get _fullAmountText => widget.orderDetail.total.toStringAsFixed(2);

  double? get _amount {
    return double.tryParse(_amountController.text.trim());
  }

  String? get _validationMessage {
    if (_amountController.text.trim().isEmpty) {
      return 'Enter a refund amount.';
    }

    final double? amount = _amount;
    if (amount == null || amount <= 0) {
      return 'Refund amount must be greater than zero.';
    }

    if (amount > widget.orderDetail.total) {
      return 'Refund amount cannot exceed order total.';
    }

    return null;
  }

  bool get _canConfirm => _validationMessage == null;

  @override
  Widget build(BuildContext context) {
    return Dialog(
      insetPadding: AppSpacing.allXl,
      backgroundColor: AppColors.transparent,
      child: LayoutBuilder(
        builder: (BuildContext context, BoxConstraints constraints) {
          return ConstrainedBox(
            constraints: const BoxConstraints(
              maxWidth: AppSizes.refundDialogWidth,
              maxHeight: AppSizes.refundDialogMaxHeight,
            ),
            child: DecoratedBox(
              decoration: const BoxDecoration(
                color: AppColors.white,
                borderRadius: AppRadius.dialog,
                boxShadow: <BoxShadow>[
                  BoxShadow(
                    color: Color(0x26000000),
                    offset: Offset(0, 12),
                    blurRadius: 28,
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  _RefundHeader(
                    orderNumber: widget.orderDetail.displayNumber,
                    onClose: () => Navigator.of(context).pop(),
                  ),
                  Flexible(
                    child: SingleChildScrollView(
                      padding: AppSpacing.allXl,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          const RefundWarningBox(),
                          const SizedBox(height: AppSpacing.lg),
                          RefundSummaryCard(orderDetail: widget.orderDetail),
                          const SizedBox(height: AppSpacing.lg),
                          RefundTypeSelector(
                            selectedType: _type,
                            orderTotal: widget.orderDetail.total,
                            onChanged: _selectType,
                          ),
                          const SizedBox(height: AppSpacing.lg),
                          _LabeledField(
                            label: 'REFUND AMOUNT',
                            child: _AmountInput(
                              controller: _amountController,
                              isReadOnly: _type == RefundType.full,
                            ),
                          ),
                          if (_validationMessage != null) ...<Widget>[
                            const SizedBox(height: AppSpacing.xs),
                            Text(
                              _validationMessage!,
                              style: AppTextStyles.bodySmall.copyWith(
                                color: AppColors.dangerStrong,
                                fontSize: 12,
                              ),
                            ),
                          ],
                          const SizedBox(height: AppSpacing.lg),
                          _LabeledField(
                            label: 'REASON FOR REFUND',
                            child: RefundReasonDropdown(
                              selectedReason: _reason,
                              onChanged: (RefundReason reason) {
                                setState(() => _reason = reason);
                              },
                            ),
                          ),
                          const SizedBox(height: AppSpacing.lg),
                          _LabeledField(
                            label: 'MANAGER NOTES (OPTIONAL)',
                            child: _NotesInput(controller: _notesController),
                          ),
                        ],
                      ),
                    ),
                  ),
                  _RefundFooter(
                    canConfirm: _canConfirm,
                    onCancel: () => Navigator.of(context).pop(),
                    onConfirm: _confirm,
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  void _handleAmountChanged() {
    setState(() {});
  }

  void _selectType(RefundType type) {
    if (_type == type) {
      return;
    }

    setState(() {
      _type = type;
      _amountController.text = type == RefundType.full ? _fullAmountText : '';
    });
  }

  void _confirm() {
    if (!_canConfirm) {
      return;
    }

    Navigator.of(context).pop(
      RefundResult(
        orderId: widget.orderDetail.id,
        type: _type,
        amount: _amount!,
        reason: _reason.label,
        managerNotes: _notesController.text.trim(),
        refundedAt: DateTime.now(),
      ),
    );
  }
}

class _RefundHeader extends StatelessWidget {
  const _RefundHeader({required this.orderNumber, required this.onClose});

  final String orderNumber;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: AppSizes.refundDialogHeaderHeight,
      child: DecoratedBox(
        decoration: const BoxDecoration(
          color: AppColors.white,
          border: Border(bottom: BorderSide(color: AppColors.border)),
          borderRadius: BorderRadius.vertical(
            top: Radius.circular(AppRadius.md),
          ),
        ),
        child: Padding(
          padding: AppSpacing.horizontalXl,
          child: Row(
            children: <Widget>[
              const Icon(
                Icons.keyboard_return_outlined,
                color: AppColors.dangerStrong,
                size: 20,
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(
                  'Refund Order $orderNumber',
                  style: AppTextStyles.titleMedium.copyWith(
                    color: AppColors.primary,
                    fontSize: 16,
                  ),
                ),
              ),
              IconButton(
                tooltip: 'Close refund dialog',
                onPressed: onClose,
                icon: const Icon(Icons.close, size: 20),
                color: AppColors.textMuted,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _LabeledField extends StatelessWidget {
  const _LabeledField({required this.label, required this.child});

  final String label;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          label,
          style: AppTextStyles.labelSmall.copyWith(
            color: AppColors.textSecondary,
            letterSpacing: 0.6,
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        child,
      ],
    );
  }
}

class _AmountInput extends StatelessWidget {
  const _AmountInput({required this.controller, required this.isReadOnly});

  final TextEditingController controller;
  final bool isReadOnly;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: AppSizes.refundInputHeight,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: isReadOnly ? AppColors.surfaceAlt : AppColors.white,
          border: Border.all(color: AppColors.border),
          borderRadius: AppRadius.control,
        ),
        child: TextField(
          key: const ValueKey<String>('refundAmountInput'),
          controller: controller,
          readOnly: isReadOnly,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          inputFormatters: <TextInputFormatter>[
            FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,2}')),
          ],
          decoration: const InputDecoration(
            prefixText: r'$ ',
            border: InputBorder.none,
            contentPadding: EdgeInsets.symmetric(
              horizontal: AppSpacing.md,
              vertical: 11,
            ),
          ),
          style: AppTextStyles.bodyMedium.copyWith(
            color: AppColors.textPrimary,
          ),
        ),
      ),
    );
  }
}

class _NotesInput extends StatelessWidget {
  const _NotesInput({required this.controller});

  final TextEditingController controller;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: AppSizes.refundNotesHeight,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: AppColors.white,
          border: Border.all(color: AppColors.border),
          borderRadius: AppRadius.control,
        ),
        child: TextField(
          controller: controller,
          maxLines: null,
          expands: true,
          textAlignVertical: TextAlignVertical.top,
          decoration: const InputDecoration(
            hintText: 'Add context for end of day reporting...',
            border: InputBorder.none,
            contentPadding: AppSpacing.allMd,
          ),
          style: AppTextStyles.bodySmall.copyWith(color: AppColors.textPrimary),
        ),
      ),
    );
  }
}

class _RefundFooter extends StatelessWidget {
  const _RefundFooter({
    required this.canConfirm,
    required this.onCancel,
    required this.onConfirm,
  });

  final bool canConfirm;
  final VoidCallback onCancel;
  final VoidCallback onConfirm;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        color: AppColors.shellBackground,
        border: Border(top: BorderSide(color: AppColors.border)),
        borderRadius: BorderRadius.vertical(
          bottom: Radius.circular(AppRadius.md),
        ),
      ),
      child: Padding(
        padding: AppSpacing.allLg,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: <Widget>[
            TextButton(onPressed: onCancel, child: const Text('Cancel')),
            const SizedBox(width: AppSpacing.md),
            ElevatedButton.icon(
              onPressed: canConfirm ? onConfirm : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.dangerStrong,
                foregroundColor: AppColors.white,
                disabledBackgroundColor: AppColors.paymentDisabledBackground,
                disabledForegroundColor: AppColors.textMuted,
                shape: const RoundedRectangleBorder(
                  borderRadius: AppRadius.control,
                ),
                padding: AppSpacing.horizontalLg,
                minimumSize: const Size(0, AppSizes.refundInputHeight),
              ),
              icon: const Icon(Icons.keyboard_return_outlined, size: 18),
              label: const Text('Confirm Refund'),
            ),
          ],
        ),
      ),
    );
  }
}

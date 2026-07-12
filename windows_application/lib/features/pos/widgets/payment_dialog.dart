import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../core/constants/app_sizes.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_radius.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/utils/currency_formatter.dart';
import '../models/payment_method.dart';
import '../models/payment_result.dart';
import '../controllers/pos_cubit.dart';
import 'payment_amount_input.dart';
import 'payment_method_selector.dart';
import 'payment_quick_amount_buttons.dart';
import 'payment_summary_panel.dart';

class PaymentDialog extends StatefulWidget {
  const PaymentDialog({
    super.key,
    required this.totalDue,
    required this.itemCount,
    this.onSubmit,
  });

  final double totalDue;
  final int itemCount;
  final Future<PaymentCompletionStatus> Function(PaymentResult result)?
  onSubmit;

  @override
  State<PaymentDialog> createState() => _PaymentDialogState();
}

class _PaymentDialogState extends State<PaymentDialog> {
  late final TextEditingController _amountController;
  late final FocusNode _amountFocusNode;
  PaymentMethod _selectedMethod = PaymentMethod.cash;
  bool _hasEditedCashAmount = false;
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _amountController = TextEditingController(
      text: _formatAmount(widget.totalDue),
    );
    _amountFocusNode = FocusNode();
  }

  @override
  void dispose() {
    _amountController.dispose();
    _amountFocusNode.dispose();
    super.dispose();
  }

  double? get _amountReceived {
    return double.tryParse(_amountController.text.trim());
  }

  double get _changeDue {
    final double amountReceived = _amountReceived ?? 0;
    return math.max(amountReceived - widget.totalDue, 0);
  }

  String? get _validationMessage {
    if (_selectedMethod == PaymentMethod.split) {
      return 'Split payment will be supported later.';
    }

    if (_selectedMethod != PaymentMethod.cash) {
      return null;
    }

    if (!_hasEditedCashAmount && (_amountReceived ?? 0) >= widget.totalDue) {
      return null;
    }

    if (_amountController.text.trim().isEmpty || _amountReceived == null) {
      return 'Enter amount received.';
    }

    if ((_amountReceived ?? 0) < widget.totalDue) {
      return 'Amount received is less than total due.';
    }

    return null;
  }

  bool get _canConfirm {
    if (widget.totalDue <= 0) {
      return false;
    }

    return switch (_selectedMethod) {
      PaymentMethod.cash => (_amountReceived ?? -1) >= widget.totalDue,
      PaymentMethod.card || PaymentMethod.wallet => true,
      PaymentMethod.split => false,
    };
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !_isSubmitting,
      child: LayoutBuilder(
        builder: (BuildContext context, BoxConstraints viewport) {
          final double maxWidth = (viewport.maxWidth - AppSpacing.xxl).clamp(
            280,
            AppSizes.paymentDialogWidth,
          );
          final double maxHeight = (viewport.maxHeight - AppSpacing.xxl).clamp(
            360,
            AppSizes.paymentDialogMaxHeight,
          );

          return Center(
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxWidth: maxWidth,
                maxHeight: maxHeight,
              ),
              child: Material(
                color: AppColors.white,
                clipBehavior: Clip.antiAlias,
                borderRadius: const BorderRadius.all(
                  Radius.circular(AppRadius.md),
                ),
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: AppColors.white,
                    borderRadius: const BorderRadius.all(
                      Radius.circular(AppRadius.md),
                    ),
                    boxShadow: const <BoxShadow>[
                      BoxShadow(
                        color: Color(0x26000000),
                        offset: Offset(0, 16),
                        blurRadius: 32,
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      _PaymentHeader(
                        onClose: _isSubmitting
                            ? null
                            : () => Navigator.of(context).pop(),
                      ),
                      PaymentSummaryPanel(
                        totalDue: widget.totalDue,
                        itemCount: widget.itemCount,
                        onViewDetails: () {},
                      ),
                      Flexible(
                        child: SingleChildScrollView(
                          padding: AppSpacing.allXl,
                          child: AbsorbPointer(
                            absorbing: _isSubmitting,
                            child: _PaymentBody(state: this),
                          ),
                        ),
                      ),
                      _PaymentFooter(
                        canConfirm: _canConfirm && !_isSubmitting,
                        isSubmitting: _isSubmitting,
                        onCancel: _isSubmitting
                            ? null
                            : () => Navigator.of(context).pop(),
                        onConfirm: _confirmPayment,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  void _selectMethod(PaymentMethod method) {
    setState(() {
      _selectedMethod = method;
      if (method == PaymentMethod.cash && _amountController.text.isEmpty) {
        _amountController.text = _formatAmount(widget.totalDue);
      }
    });
  }

  void _setCashAmount(double amount) {
    setState(() {
      _hasEditedCashAmount = true;
      _amountController.text = _formatAmount(amount);
    });
  }

  void _onCashAmountChanged() {
    setState(() => _hasEditedCashAmount = true);
  }

  Future<void> _confirmPayment() async {
    if (_isSubmitting || !_canConfirm) {
      setState(() => _hasEditedCashAmount = true);
      return;
    }

    final double amountReceived = switch (_selectedMethod) {
      PaymentMethod.cash => _amountReceived ?? 0,
      PaymentMethod.card || PaymentMethod.wallet => widget.totalDue,
      PaymentMethod.split => 0,
    };

    final PaymentResult result = PaymentResult(
      method: _selectedMethod,
      totalDue: widget.totalDue,
      amountReceived: amountReceived,
      changeDue: _selectedMethod == PaymentMethod.cash ? _changeDue : 0,
    );

    if (widget.onSubmit == null) {
      Navigator.of(context).pop<PaymentResult>(result);
      return;
    }

    setState(() => _isSubmitting = true);
    final PaymentCompletionStatus status = await widget.onSubmit!(result);
    if (!mounted) {
      return;
    }
    if (status == PaymentCompletionStatus.completed ||
        status == PaymentCompletionStatus.uncertain) {
      Navigator.of(context).pop<PaymentResult>(result);
      return;
    }
    setState(() => _isSubmitting = false);
  }
}

class _PaymentHeader extends StatelessWidget {
  const _PaymentHeader({required this.onClose});

  final VoidCallback? onClose;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: AppSizes.paymentDialogHeaderHeight,
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.xl,
        vertical: AppSpacing.lg,
      ),
      decoration: const BoxDecoration(
        color: AppColors.paymentHeaderBackground,
        border: Border(bottom: BorderSide(color: AppColors.border)),
      ),
      child: Row(
        children: <Widget>[
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  'Payment',
                  style: AppTextStyles.headlineMedium.copyWith(
                    color: AppColors.primary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  'Order #618-42',
                  style: AppTextStyles.bodySmall.copyWith(
                    color: AppColors.textSecondary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: onClose,
            icon: const Icon(Icons.close),
            color: AppColors.primary,
            tooltip: 'Close',
          ),
        ],
      ),
    );
  }
}

class _PaymentBody extends StatelessWidget {
  const _PaymentBody({required this.state});

  final _PaymentDialogState state;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          'Select Method',
          style: AppTextStyles.titleMedium.copyWith(
            color: AppColors.primary,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        PaymentMethodSelector(
          selectedMethod: state._selectedMethod,
          onMethodSelected: state._selectMethod,
        ),
        const SizedBox(height: AppSpacing.xl),
        _MethodDetails(state: state),
      ],
    );
  }
}

class _MethodDetails extends StatelessWidget {
  const _MethodDetails({required this.state});

  final _PaymentDialogState state;

  @override
  Widget build(BuildContext context) {
    return switch (state._selectedMethod) {
      PaymentMethod.cash => _CashDetails(state: state),
      PaymentMethod.card || PaymentMethod.wallet => const _PaymentNote(
        message: 'External payment terminal integration will be added later.',
        icon: Icons.info_outline,
      ),
      PaymentMethod.split => const _PaymentNote(
        message: 'Split payment will be supported later.',
        icon: Icons.call_split,
      ),
    };
  }
}

class _CashDetails extends StatelessWidget {
  const _CashDetails({required this.state});

  final _PaymentDialogState state;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          'AMOUNT RECEIVED',
          style: AppTextStyles.labelSmall.copyWith(
            color: AppColors.textSecondary,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        PaymentAmountInput(
          controller: state._amountController,
          focusNode: state._amountFocusNode,
          onChanged: (_) => state._onCashAmountChanged(),
        ),
        const SizedBox(height: AppSpacing.md),
        PaymentQuickAmountButtons(
          totalDue: state.widget.totalDue,
          onAmountSelected: state._setCashAmount,
        ),
        const SizedBox(height: AppSpacing.lg),
        _ChangeDueRow(changeDue: state._changeDue),
        if (state._validationMessage != null) ...<Widget>[
          const SizedBox(height: AppSpacing.sm),
          _ValidationMessage(message: state._validationMessage!),
        ],
      ],
    );
  }
}

class _ChangeDueRow extends StatelessWidget {
  const _ChangeDueRow({required this.changeDue});

  final double changeDue;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: AppSpacing.allMd,
      decoration: const BoxDecoration(
        color: AppColors.shellBackground,
        borderRadius: AppRadius.control,
      ),
      child: Row(
        children: <Widget>[
          Expanded(
            child: Text(
              'Change Due',
              style: AppTextStyles.bodyMedium.copyWith(
                color: AppColors.textSecondary,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          Text(
            CurrencyFormatter.format(changeDue),
            style: AppTextStyles.titleMedium.copyWith(
              color: changeDue > 0
                  ? AppColors.paymentSuccessText
                  : AppColors.textSecondary,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class _PaymentNote extends StatelessWidget {
  const _PaymentNote({required this.message, required this.icon});

  final String message;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: AppSpacing.allLg,
      decoration: BoxDecoration(
        color: AppColors.shellBackground,
        border: Border.all(color: AppColors.border),
        borderRadius: AppRadius.control,
      ),
      child: Row(
        children: <Widget>[
          Icon(icon, size: 18, color: AppColors.secondary),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Text(
              message,
              style: AppTextStyles.bodySmall.copyWith(
                color: AppColors.textSecondary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ValidationMessage extends StatelessWidget {
  const _ValidationMessage({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: <Widget>[
        const Icon(
          Icons.error_outline,
          size: 14,
          color: AppColors.dangerStrong,
        ),
        const SizedBox(width: AppSpacing.xs),
        Expanded(
          child: Text(
            message,
            style: AppTextStyles.labelSmall.copyWith(
              color: AppColors.dangerStrong,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ],
    );
  }
}

class _PaymentFooter extends StatelessWidget {
  const _PaymentFooter({
    required this.canConfirm,
    required this.isSubmitting,
    required this.onCancel,
    required this.onConfirm,
  });

  final bool canConfirm;
  final bool isSubmitting;
  final VoidCallback? onCancel;
  final Future<void> Function() onConfirm;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.xl,
        vertical: AppSpacing.lg,
      ),
      decoration: const BoxDecoration(
        color: AppColors.white,
        border: Border(top: BorderSide(color: AppColors.border)),
      ),
      child: Row(
        children: <Widget>[
          Expanded(
            child: SizedBox(
              height: AppSizes.paymentFooterButtonHeight,
              child: OutlinedButton(
                onPressed: onCancel,
                style: OutlinedButton.styleFrom(
                  backgroundColor: AppColors.shellBackground,
                  foregroundColor: AppColors.primary,
                  side: const BorderSide(color: AppColors.border),
                  textStyle: AppTextStyles.buttonMedium,
                  shape: const RoundedRectangleBorder(
                    borderRadius: AppRadius.control,
                  ),
                ),
                child: const Text('Cancel'),
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            flex: 2,
            child: SizedBox(
              height: AppSizes.paymentFooterButtonHeight,
              child: FilledButton(
                onPressed: canConfirm ? onConfirm : null,
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.tertiary,
                  disabledBackgroundColor: AppColors.paymentDisabledBackground,
                  foregroundColor: AppColors.white,
                  disabledForegroundColor: AppColors.textMuted,
                  textStyle: AppTextStyles.buttonLarge,
                  shape: const RoundedRectangleBorder(
                    borderRadius: AppRadius.control,
                  ),
                ),
                child: isSubmitting
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: AppColors.white,
                        ),
                      )
                    : const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: <Widget>[
                          Flexible(
                            child: Text(
                              'Confirm Payment',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          SizedBox(width: AppSpacing.sm),
                          Icon(Icons.arrow_forward, size: 18),
                        ],
                      ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

String _formatAmount(double amount) {
  return math.max(amount, 0).toStringAsFixed(2);
}

import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../app/localization/localization_extensions.dart';
import '../../../core/constants/app_sizes.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_radius.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../l10n/app_localizations.dart';
import '../models/delivery_company.dart';
import '../models/order_type.dart';
import '../models/payment_method.dart';
import '../models/payment_result.dart';
import '../controllers/pos_cubit.dart';
import 'order_type_selector.dart';
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
    this.availableMethods = PaymentMethod.values,
    this.orderNumber,
    this.requireOrderType = false,
    this.deliveryCompanies = const <DeliveryCompany>[],
    this.walletBalance,
  });

  final double totalDue;
  final int itemCount;
  final Future<PaymentCompletionStatus> Function(PaymentResult result)?
  onSubmit;
  final List<PaymentMethod> availableMethods;
  final String? orderNumber;

  /// When true the cashier must choose the order type (dine-in / takeaway /
  /// delivery) here before confirming — there is no default. A delivery order
  /// must also name the delivery company it is settled through.
  final bool requireOrderType;
  final List<DeliveryCompany> deliveryCompanies;

  /// Funds the order's customer holds. When they cover the total the wallet is
  /// preselected; the cashier can still switch to another method.
  final double? walletBalance;

  @override
  State<PaymentDialog> createState() => _PaymentDialogState();
}

class _PaymentDialogState extends State<PaymentDialog> {
  late final TextEditingController _amountController;
  late final TextEditingController _referenceController;
  late final FocusNode _amountFocusNode;
  PaymentMethod _selectedMethod = PaymentMethod.cash;
  bool _hasEditedCashAmount = false;
  bool _isSubmitting = false;
  OrderType? _orderType;
  int? _deliveryCompanyId;
  bool _onDeliveryAccount = false;
  bool _walletPreselected = false;

  @override
  void initState() {
    super.initState();
    _amountController = TextEditingController(
      text: _formatAmount(widget.totalDue),
    );
    _amountFocusNode = FocusNode();
    _referenceController = TextEditingController();
    if (!widget.availableMethods.contains(_selectedMethod) &&
        widget.availableMethods.isNotEmpty) {
      _selectedMethod = widget.availableMethods.first;
    }
    final double? funds = widget.walletBalance;
    if (funds != null &&
        widget.totalDue > 0 &&
        funds >= widget.totalDue &&
        widget.availableMethods.contains(PaymentMethod.wallet)) {
      _selectedMethod = PaymentMethod.wallet;
      _walletPreselected = true;
    }
  }

  @override
  void dispose() {
    _amountController.dispose();
    _referenceController.dispose();
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

  bool get _orderTypeReady {
    if (!widget.requireOrderType) {
      return true;
    }
    return _orderType != null;
  }

  void _selectOrderType(OrderType type) {
    setState(() {
      _orderType = type;
      if (type != OrderType.delivery) {
        _deliveryCompanyId = null;
        _onDeliveryAccount = false;
      }
    });
  }

  /// `null` = the café's own delivery (the driver hands the cash over).
  void _selectDeliveryCompany(int? id) {
    setState(() {
      _deliveryCompanyId = id;
      if (id == null) {
        _onDeliveryAccount = false;
      }
    });
  }

  void _selectDeliveryCollection({required bool onAccount}) =>
      setState(() => _onDeliveryAccount = onAccount);

  String? _orderTypeMessage(AppLocalizations l10n) {
    if (!widget.requireOrderType) {
      return null;
    }
    if (_orderType == null) {
      return l10n.posOrderTypeRequired;
    }
    return null;
  }

  String? _validationMessage(AppLocalizations l10n) {
    if (_onDeliveryAccount) {
      return null;
    }
    if (_selectedMethod == PaymentMethod.split) {
      return l10n.posSplitUnavailable;
    }

    if (_selectedMethod != PaymentMethod.cash) {
      return null;
    }

    if (!_hasEditedCashAmount && (_amountReceived ?? 0) >= widget.totalDue) {
      return null;
    }

    if (_amountController.text.trim().isEmpty || _amountReceived == null) {
      return l10n.posEnterAmountReceived;
    }

    if ((_amountReceived ?? 0) < widget.totalDue) {
      return l10n.posAmountBelowTotal;
    }

    return null;
  }

  bool get _canConfirm {
    if (widget.totalDue <= 0 || !_orderTypeReady) {
      return false;
    }
    if (_onDeliveryAccount) {
      return true;
    }

    return switch (_selectedMethod) {
      PaymentMethod.cash => (_amountReceived ?? -1) >= widget.totalDue,
      PaymentMethod.card || PaymentMethod.wallet => true,
      PaymentMethod.shamCash => _referenceController.text.trim().isNotEmpty,
      PaymentMethod.split => false,
    };
  }

  void _onReferenceChanged() => setState(() {});

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
                        orderNumber: widget.orderNumber,
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

    if (_onDeliveryAccount) {
      final PaymentResult onAccount = PaymentResult(
        method: PaymentMethod.cash,
        totalDue: widget.totalDue,
        amountReceived: widget.totalDue,
        changeDue: 0,
        orderType: _orderType,
        deliveryCompanyId: _deliveryCompanyId,
        onDeliveryAccount: true,
      );
      await _submit(onAccount);
      return;
    }

    final double amountReceived = switch (_selectedMethod) {
      PaymentMethod.cash => _amountReceived ?? 0,
      PaymentMethod.card ||
      PaymentMethod.wallet ||
      PaymentMethod.shamCash => widget.totalDue,
      PaymentMethod.split => 0,
    };

    final PaymentResult result = PaymentResult(
      method: _selectedMethod,
      totalDue: widget.totalDue,
      amountReceived: amountReceived,
      changeDue: _selectedMethod == PaymentMethod.cash ? _changeDue : 0,
      reference: _selectedMethod == PaymentMethod.shamCash
          ? _referenceController.text.trim()
          : null,
      orderType: widget.requireOrderType ? _orderType : null,
      deliveryCompanyId: widget.requireOrderType &&
              _orderType == OrderType.delivery
          ? _deliveryCompanyId
          : null,
    );

    await _submit(result);
  }

  Future<void> _submit(PaymentResult result) async {
    if (widget.onSubmit == null) {
      Navigator.of(context).pop<PaymentResult>(result);
      return;
    }

    setState(() => _isSubmitting = true);
    PaymentCompletionStatus status;
    try {
      status = await widget.onSubmit!(result);
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() => _isSubmitting = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(context.l10n.posPaymentFailed)));
      return;
    }
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
  const _PaymentHeader({required this.orderNumber, required this.onClose});

  final String? orderNumber;
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
                  context.l10n.posPayment,
                  style: AppTextStyles.headlineMedium.copyWith(
                    color: AppColors.primary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  context.l10n.posOrderNumber(orderNumber ?? '#618-42'),
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
            tooltip: context.l10n.posClose,
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
        if (state.widget.requireOrderType) ...<Widget>[
          _OrderTypeSection(state: state),
          const SizedBox(height: AppSpacing.xl),
        ],
        if (state._onDeliveryAccount)
          _PaymentNote(
            message: context.l10n.posDeliveryPaymentHint,
            icon: Icons.delivery_dining_outlined,
          )
        else ...<Widget>[
          Text(
            context.l10n.posSelectPaymentMethod,
            style: AppTextStyles.titleMedium.copyWith(
              color: AppColors.primary,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          PaymentMethodSelector(
            selectedMethod: state._selectedMethod,
            methods: state.widget.availableMethods,
            onMethodSelected: state._selectMethod,
          ),
          const SizedBox(height: AppSpacing.xl),
          _MethodDetails(state: state),
        ],
      ],
    );
  }
}

class _OrderTypeSection extends StatelessWidget {
  const _OrderTypeSection({required this.state});

  final _PaymentDialogState state;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final String? message = state._orderTypeMessage(l10n);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          l10n.posSelectOrderType,
          style: AppTextStyles.titleMedium.copyWith(
            color: AppColors.primary,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        OrderTypeSelector(
          selectedOrderType: state._orderType,
          onOrderTypeSelected: state._selectOrderType,
        ),
        if (state._orderType == OrderType.delivery) ...<Widget>[
          if (state.widget.deliveryCompanies.isNotEmpty) ...<Widget>[
            const SizedBox(height: AppSpacing.md),
            Text(
              l10n.posSelectDeliveryCompany,
              style: AppTextStyles.labelSmall.copyWith(
                color: AppColors.textSecondary,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            Wrap(
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.sm,
              children: <Widget>[
                ChoiceChip(
                  key: const Key('delivery-company-own'),
                  label: Text(l10n.posDeliveryOwn),
                  selected: state._deliveryCompanyId == null,
                  onSelected: (_) => state._selectDeliveryCompany(null),
                ),
                for (final DeliveryCompany company
                    in state.widget.deliveryCompanies)
                  ChoiceChip(
                    key: Key('delivery-company-${company.id}'),
                    label: Text(company.name),
                    selected: state._deliveryCompanyId == company.id,
                    onSelected: (_) => state._selectDeliveryCompany(company.id),
                  ),
              ],
            ),
          ],
          if (state._deliveryCompanyId != null) ...<Widget>[
            const SizedBox(height: AppSpacing.md),
            Text(
              l10n.posDeliveryCollection,
              style: AppTextStyles.labelSmall.copyWith(
                color: AppColors.textSecondary,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            Wrap(
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.sm,
              children: <Widget>[
                ChoiceChip(
                  key: const Key('delivery-collect-now'),
                  label: Text(l10n.posDeliveryCashNow),
                  selected: !state._onDeliveryAccount,
                  onSelected: (_) =>
                      state._selectDeliveryCollection(onAccount: false),
                ),
                ChoiceChip(
                  key: const Key('delivery-collect-on-account'),
                  label: Text(l10n.posDeliveryOnAccount),
                  selected: state._onDeliveryAccount,
                  onSelected: (_) =>
                      state._selectDeliveryCollection(onAccount: true),
                ),
              ],
            ),
          ],
        ],
        if (message != null) ...<Widget>[
          const SizedBox(height: AppSpacing.sm),
          _ValidationMessage(message: message),
        ],
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
      PaymentMethod.card => _PaymentNote(
        message: context.l10n.posExternalTerminalPending,
        icon: Icons.info_outline,
      ),
      PaymentMethod.wallet => _PaymentNote(
        message: state._walletPreselected
            ? context.l10n.posWalletAutoSelectedNote(
                CurrencyFormatter.formatForContext(
                  context,
                  state.widget.walletBalance ?? 0,
                ),
              )
            : 'سيُسجَّل المبلغ على حساب العميل المرتبط بالطلب (محفظة العميل).',
        icon: Icons.account_balance_wallet_outlined,
      ),
      PaymentMethod.shamCash => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const _PaymentNote(
            message: 'يُسجَّل المبلغ في صندوق الشام كاش. أدخل رقم العملية كما يظهر في التطبيق.',
            icon: Icons.qr_code_2,
          ),
          const SizedBox(height: AppSpacing.md),
          TextField(
            key: const Key('sham-cash-reference'),
            controller: state._referenceController,
            onChanged: (_) => state._onReferenceChanged(),
            decoration: const InputDecoration(
              labelText: 'رقم عملية الشام كاش',
              border: OutlineInputBorder(),
            ),
          ),
        ],
      ),
      PaymentMethod.split => _PaymentNote(
        message: context.l10n.posSplitUnavailable,
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
          context.l10n.posAmountReceived,
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
        if (state._validationMessage(context.l10n) != null) ...<Widget>[
          const SizedBox(height: AppSpacing.sm),
          _ValidationMessage(message: state._validationMessage(context.l10n)!),
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
              context.l10n.posChangeDue,
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
                child: Text(context.l10n.posCancel),
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
                    : Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: <Widget>[
                          Flexible(
                            child: Text(
                              context.l10n.posConfirmPayment,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: AppSpacing.sm),
                          const Icon(Icons.arrow_forward, size: 18),
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

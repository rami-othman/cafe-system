import 'package:flutter/material.dart';

import '../../../core/constants/app_sizes.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_radius.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/utils/currency_formatter.dart';
import '../models/applied_discount.dart';
import '../models/available_discount.dart';
import 'coupon_code_input.dart';
import 'discount_card.dart';

class DiscountDialog extends StatefulWidget {
  const DiscountDialog({
    super.key,
    required this.subtotal,
    this.availableDiscounts,
  });

  final double subtotal;
  final List<AvailableDiscount>? availableDiscounts;

  @override
  State<DiscountDialog> createState() => _DiscountDialogState();
}

class _DiscountDialogState extends State<DiscountDialog> {
  static final String _minimumOrderMessage =
      'Minimum order amount (${CurrencyFormatter.format(20)}) not reached.';
  static final List<AvailableDiscount> _availableDiscounts =
      <AvailableDiscount>[
        AvailableDiscount(
          id: 'morning-rush',
          title: 'Morning Rush',
          subtitle: 'Valid until 11:00 AM',
          badgeLabel: '15% OFF',
          type: AvailableDiscountType.percentage,
          value: 15,
          minimumSubtotal: 20,
          couponCode: 'MORNING15',
        ),
        AvailableDiscount(
          id: 'vip-reward',
          title: 'VIP Reward',
          subtitle: 'Loyalty member tier',
          badgeLabel: '-${CurrencyFormatter.format(5)}',
          type: AvailableDiscountType.fixedAmount,
          value: 5,
          couponCode: 'VIP5',
        ),
        AvailableDiscount(
          id: 'pastry-special',
          title: 'Pastry Special',
          subtitle: 'Buy 1 get 1 free',
          badgeLabel: 'BOGO',
          type: AvailableDiscountType.bogo,
          value: 0,
        ),
      ];

  late final TextEditingController _couponController;
  String? _validationMessage;

  List<AvailableDiscount> get _discounts =>
      widget.availableDiscounts ?? _availableDiscounts;

  @override
  void initState() {
    super.initState();
    _couponController = TextEditingController();
  }

  @override
  void dispose() {
    _couponController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints viewport) {
        final double maxWidth = (viewport.maxWidth - AppSpacing.xxl).clamp(
          280,
          AppSizes.discountDialogWidth,
        );
        final double maxHeight = (viewport.maxHeight - AppSpacing.xxl).clamp(
          320,
          AppSizes.discountDialogMaxHeight,
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
                    _DialogHeader(onClose: () => Navigator.of(context).pop()),
                    Flexible(child: _DialogBody(state: this)),
                    _DialogFooter(onCancel: () => Navigator.of(context).pop()),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  void _applyCouponCode() {
    final String code = _couponController.text.trim().toUpperCase();

    if (code.isEmpty) {
      _showValidation('Enter a coupon code.');
      return;
    }

    AvailableDiscount? discount;
    for (final AvailableDiscount availableDiscount in _discounts) {
      if (availableDiscount.couponCode?.toUpperCase() == code) {
        discount = availableDiscount;
        break;
      }
    }

    if (discount == null) {
      _showValidation('Invalid coupon code.');
      return;
    }

    _applyAvailableDiscount(discount, code: code);
  }

  void _applyAvailableDiscount(AvailableDiscount discount, {String? code}) {
    if (discount.type == AvailableDiscountType.bogo) {
      _showValidation('BOGO discounts will be supported later.');
      return;
    }

    if (!discount.isEligible) {
      _showValidation(discount.message ?? _minimumOrderMessage);
      return;
    }

    if (widget.subtotal < discount.minimumSubtotal) {
      _showValidation(_minimumOrderMessage);
      return;
    }

    Navigator.of(context).pop<AppliedDiscount>(
      AppliedDiscount(
        id: discount.id,
        backendId: discount.backendId,
        title: discount.title,
        type: switch (discount.type) {
          AvailableDiscountType.percentage => AppliedDiscountType.percentage,
          AvailableDiscountType.fixedAmount => AppliedDiscountType.fixedAmount,
          AvailableDiscountType.bogo => AppliedDiscountType.fixedAmount,
        },
        value: discount.value,
        code: code ?? discount.couponCode,
      ),
    );
  }

  void _showValidation(String message) {
    setState(() => _validationMessage = message);
  }
}

class _DialogHeader extends StatelessWidget {
  const _DialogHeader({required this.onClose});

  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: AppSizes.discountDialogHeaderHeight,
      padding: AppSpacing.horizontalXl,
      decoration: const BoxDecoration(
        color: AppColors.white,
        border: Border(bottom: BorderSide(color: AppColors.border)),
      ),
      child: Row(
        children: <Widget>[
          Expanded(
            child: Text(
              'Apply Discount',
              style: AppTextStyles.headlineMedium.copyWith(
                color: AppColors.primary,
                fontWeight: FontWeight.w700,
              ),
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

class _DialogBody extends StatelessWidget {
  const _DialogBody({required this.state});

  final _DiscountDialogState state;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: AppSpacing.allXl,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            'COUPON CODE',
            style: AppTextStyles.labelSmall.copyWith(
              color: AppColors.textSecondary,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          CouponCodeInput(
            controller: state._couponController,
            onApply: state._applyCouponCode,
          ),
          if (state._validationMessage != null) ...<Widget>[
            const SizedBox(height: AppSpacing.sm),
            _ValidationMessage(message: state._validationMessage!),
          ],
          const SizedBox(height: AppSpacing.xl),
          const Divider(height: 1, color: AppColors.border),
          const SizedBox(height: AppSpacing.xl),
          Text(
            'Available Discounts',
            style: AppTextStyles.titleMedium.copyWith(
              color: AppColors.primary,
              fontSize: 18,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          for (final AvailableDiscount discount
              in state._discounts) ...<Widget>[
            DiscountCard(
              discount: discount,
              onApply: () => state._applyAvailableDiscount(discount),
            ),
            if (discount != state._discounts.last)
              const SizedBox(height: AppSpacing.md),
          ],
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

class _DialogFooter extends StatelessWidget {
  const _DialogFooter({required this.onCancel});

  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.xl,
        vertical: AppSpacing.lg,
      ),
      decoration: const BoxDecoration(
        color: AppColors.shellBackground,
        border: Border(top: BorderSide(color: AppColors.border)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: <Widget>[
          OutlinedButton(
            onPressed: onCancel,
            style: OutlinedButton.styleFrom(
              minimumSize: const Size(0, AppSizes.buttonHeight),
              backgroundColor: AppColors.white,
              foregroundColor: AppColors.primary,
              side: const BorderSide(color: AppColors.border),
              textStyle: AppTextStyles.buttonMedium,
              shape: const RoundedRectangleBorder(
                borderRadius: AppRadius.control,
              ),
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
            ),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );
  }
}

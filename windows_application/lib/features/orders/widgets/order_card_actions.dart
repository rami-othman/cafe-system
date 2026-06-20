import 'package:flutter/material.dart';

import '../../../core/constants/app_sizes.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_radius.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_text_styles.dart';
import '../models/order_status.dart';
import '../models/order_summary.dart';

class OrderCardActions extends StatelessWidget {
  const OrderCardActions({
    super.key,
    required this.order,
    required this.onDetails,
    required this.onPay,
    required this.onResume,
    required this.onCancel,
    required this.onComplete,
  });

  final OrderSummary order;
  final VoidCallback onDetails;
  final VoidCallback onPay;
  final VoidCallback onResume;
  final VoidCallback onCancel;
  final VoidCallback onComplete;

  @override
  Widget build(BuildContext context) {
    final List<_OrderAction> actions = switch (order.status) {
      OrderStatus.held => <_OrderAction>[
        _OrderAction.outlined('RESUME', onResume),
        _OrderAction.danger('CANCEL', onCancel),
      ],
      OrderStatus.ready => <_OrderAction>[
        _OrderAction.outlined('DETAILS', onDetails),
        _OrderAction.primary('COMPLETE', onComplete),
      ],
      OrderStatus.preparing => <_OrderAction>[
        _OrderAction.outlined('DETAILS', onDetails),
        _OrderAction.primary('PAY', onPay),
      ],
      OrderStatus.completed || OrderStatus.cancelled => <_OrderAction>[
        _OrderAction.outlined('DETAILS', onDetails),
      ],
    };

    return Row(
      children: <Widget>[
        for (int index = 0; index < actions.length; index++) ...<Widget>[
          Expanded(child: _ActionButton(action: actions[index])),
          if (index != actions.length - 1) const SizedBox(width: AppSpacing.md),
        ],
      ],
    );
  }
}

class _ActionButton extends StatelessWidget {
  const _ActionButton({required this.action});

  final _OrderAction action;

  @override
  Widget build(BuildContext context) {
    final bool isFilled = action.variant == _OrderActionVariant.primary;

    return SizedBox(
      height: AppSizes.orderActionButtonHeight,
      child: Material(
        color: isFilled ? AppColors.tertiary : AppColors.surface,
        borderRadius: AppRadius.control,
        child: InkWell(
          onTap: action.onTap,
          borderRadius: AppRadius.control,
          child: Container(
            alignment: Alignment.center,
            decoration: BoxDecoration(
              border: isFilled ? null : Border.all(color: AppColors.border),
              borderRadius: AppRadius.control,
            ),
            child: Text(
              action.label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppTextStyles.labelSmall.copyWith(
                color: _foregroundFor(action),
                fontWeight: FontWeight.w800,
                letterSpacing: 0.6,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Color _foregroundFor(_OrderAction action) {
    return switch (action.variant) {
      _OrderActionVariant.primary => AppColors.textInverse,
      _OrderActionVariant.outlined => AppColors.textMuted,
      _OrderActionVariant.danger => AppColors.dangerStrong,
    };
  }
}

class _OrderAction {
  const _OrderAction._(this.label, this.onTap, this.variant);

  factory _OrderAction.primary(String label, VoidCallback onTap) {
    return _OrderAction._(label, onTap, _OrderActionVariant.primary);
  }

  factory _OrderAction.outlined(String label, VoidCallback onTap) {
    return _OrderAction._(label, onTap, _OrderActionVariant.outlined);
  }

  factory _OrderAction.danger(String label, VoidCallback onTap) {
    return _OrderAction._(label, onTap, _OrderActionVariant.danger);
  }

  final String label;
  final VoidCallback onTap;
  final _OrderActionVariant variant;
}

enum _OrderActionVariant { primary, outlined, danger }

import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_radius.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../l10n/app_localizations.dart';
import '../../../l10n/app_localizations_en.dart';

/// Pill showing the funds a customer holds on their account (green) or what
/// they owe (red). Renders nothing for a zero or unknown balance.
class WalletBalanceBadge extends StatelessWidget {
  const WalletBalanceBadge({super.key, required this.balance});

  final double? balance;

  @override
  Widget build(BuildContext context) {
    final double? value = balance;
    if (value == null || value == 0) {
      return const SizedBox.shrink();
    }
    final AppLocalizations l10n =
        Localizations.of<AppLocalizations>(context, AppLocalizations) ??
        AppLocalizationsEn();
    final bool hasCredit = value > 0;
    final Color color = hasCredit ? AppColors.success : AppColors.danger;
    final String amount = CurrencyFormatter.formatForContext(
      context,
      value.abs(),
    );

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: 3,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: AppRadius.pillRadius,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(Icons.account_balance_wallet_outlined, size: 11, color: color),
          const SizedBox(width: AppSpacing.xs),
          Text(
            hasCredit
                ? l10n.posCustomerWalletCredit(amount)
                : l10n.posCustomerWalletDebt(amount),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppTextStyles.labelSmall.copyWith(
              color: color,
              fontSize: 10,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}

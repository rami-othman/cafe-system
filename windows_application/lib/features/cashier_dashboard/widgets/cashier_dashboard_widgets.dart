import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_radius.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_text_styles.dart';

/// Shared Cafe 618 building blocks for the Cashier operations surface.
///
/// Everything here draws from the existing design tokens — warm off-white
/// ground, coffee-brown primary, peach accent, white cards with a hairline
/// border — so the dashboard reads as part of the same product rather than a
/// second application bolted on.

/// Minimum comfortable touch target for a cashier tablet.
const double kCashierTouchTarget = 48;

/// A titled group of cards. Sections stack on narrow screens and sit side by
/// side when there is room, which is what keeps a tablet layout intentional.
class CashierSection extends StatelessWidget {
  const CashierSection({
    super.key,
    required this.title,
    required this.child,
    this.scopeLabel,
    this.trailing,
  });

  final String title;
  final Widget child;

  /// Names what the numbers below cover (current shift, branch). Every section
  /// carrying figures states its scope rather than leaving it implied.
  final String? scopeLabel;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Padding(
          padding: const EdgeInsets.only(bottom: AppSpacing.md),
          child: Row(
            children: <Widget>[
              Flexible(
                child: Text(
                  title,
                  style: AppTextStyles.titleMedium,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (scopeLabel case final String scope) ...<Widget>[
                const SizedBox(width: AppSpacing.sm),
                CashierScopeChip(label: scope),
              ],
              const Spacer(),
              ?trailing,
            ],
          ),
        ),
        child,
      ],
    );
  }
}

class CashierScopeChip extends StatelessWidget {
  const CashierScopeChip({super.key, required this.label});

  final String label;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(
      horizontal: AppSpacing.md,
      vertical: AppSpacing.xs,
    ),
    decoration: BoxDecoration(
      color: AppColors.navActiveBackground,
      borderRadius: AppRadius.pillRadius,
    ),
    child: Text(
      label,
      style: AppTextStyles.labelSmall.copyWith(
        color: AppColors.navActiveText,
        fontWeight: FontWeight.w800,
      ),
    ),
  );
}

/// A single operational figure. [emphasis] promotes the one number a cashier
/// checks most — expected drawer cash — without changing the card's shape.
class CashierMetricCard extends StatelessWidget {
  const CashierMetricCard({
    super.key,
    required this.label,
    required this.value,
    required this.icon,
    this.subtext,
    this.emphasis = false,
    this.tone,
    this.footnote,
  });

  final String label;
  final String value;
  final IconData icon;
  final String? subtext;
  final bool emphasis;
  final Color? tone;
  final String? footnote;

  @override
  Widget build(BuildContext context) {
    final Color accent = tone ?? AppColors.secondary;
    return Container(
      constraints: const BoxConstraints(minHeight: 116),
      padding: AppSpacing.allLg,
      decoration: BoxDecoration(
        color: emphasis ? AppColors.paymentSelectedBackground : AppColors.surface,
        borderRadius: AppRadius.card,
        border: Border.all(
          color: emphasis ? accent.withValues(alpha: 0.35) : AppColors.border,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Row(
            children: <Widget>[
              Icon(icon, size: 20, color: accent),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(
                  label,
                  style: AppTextStyles.labelSmall.copyWith(
                    color: AppColors.textSecondary,
                    fontWeight: FontWeight.w700,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: AlignmentDirectional.centerStart,
            child: Text(
              value,
              style: emphasis
                  ? AppTextStyles.headlineLarge.copyWith(color: accent)
                  : AppTextStyles.titleLarge,
            ),
          ),
          if (subtext != null) ...<Widget>[
            const SizedBox(height: AppSpacing.xs),
            Text(
              subtext!,
              style: AppTextStyles.labelSmall.copyWith(
                color: AppColors.textMuted,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
          if (footnote != null) ...<Widget>[
            const SizedBox(height: AppSpacing.sm),
            Text(
              footnote!,
              style: AppTextStyles.labelSmall.copyWith(
                color: AppColors.textMuted,
              ),
              maxLines: 2,
            ),
          ],
        ],
      ),
    );
  }
}

/// A compact shortcut into an existing screen. Rendered only when the actor may
/// actually reach the destination.
class CashierActionTile extends StatelessWidget {
  const CashierActionTile({
    super.key,
    required this.label,
    required this.icon,
    required this.onTap,
    this.badge,
    this.tone,
  });

  final String label;
  final IconData icon;
  final VoidCallback? onTap;
  final String? badge;
  final Color? tone;

  @override
  Widget build(BuildContext context) {
    final bool enabled = onTap != null;
    final Color accent = tone ?? AppColors.secondary;
    return Material(
      color: AppColors.surface,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: AppRadius.card,
        side: const BorderSide(color: AppColors.border),
      ),
      child: InkWell(
        onTap: onTap,
        child: Container(
          constraints: const BoxConstraints(minHeight: kCashierTouchTarget + 28),
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: AppSpacing.md,
          ),
          child: Row(
            children: <Widget>[
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: enabled ? 0.10 : 0.05),
                  borderRadius: AppRadius.control,
                ),
                child: Icon(
                  icon,
                  size: 20,
                  color: enabled ? accent : AppColors.textMuted,
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Text(
                  label,
                  style: AppTextStyles.labelMedium.copyWith(
                    fontWeight: FontWeight.w700,
                    color: enabled
                        ? AppColors.textPrimary
                        : AppColors.textMuted,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (badge != null) ...<Widget>[
                const SizedBox(width: AppSpacing.sm),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.sm,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: accent.withValues(alpha: 0.12),
                    borderRadius: AppRadius.pillRadius,
                  ),
                  child: Text(
                    badge!,
                    style: AppTextStyles.labelSmall.copyWith(
                      color: accent,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// Lays cards out on a grid whose column count follows the available width, so
/// a 1024-1366 tablet gets a deliberate two/three-column layout instead of a
/// squeezed desktop one, and a phone gets a single column.
class CashierCardGrid extends StatelessWidget {
  const CashierCardGrid({
    super.key,
    required this.children,
    this.minTileWidth = 220,
    this.tileHeight = 128,
  });

  final List<Widget> children;
  final double minTileWidth;
  final double tileHeight;

  @override
  Widget build(BuildContext context) {
    if (children.isEmpty) return const SizedBox.shrink();
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final int columns = (constraints.maxWidth / minTileWidth)
            .floor()
            .clamp(1, 4);
        final double spacing = AppSpacing.md;
        final double width =
            (constraints.maxWidth - spacing * (columns - 1)) / columns;
        return Wrap(
          spacing: spacing,
          runSpacing: spacing,
          children: <Widget>[
            for (final Widget child in children)
              SizedBox(width: width, child: child),
          ],
        );
      },
    );
  }
}

/// Shell-first loading: the page's structure renders immediately and each card
/// slot shows a neutral placeholder until the single aggregate call returns.
class CashierSkeletonCard extends StatelessWidget {
  const CashierSkeletonCard({super.key, this.height = 116});

  final double height;

  @override
  Widget build(BuildContext context) => Container(
    height: height,
    decoration: BoxDecoration(
      color: AppColors.surfaceAlt,
      borderRadius: AppRadius.card,
      border: Border.all(color: AppColors.border),
    ),
  );
}

class CashierErrorPanel extends StatelessWidget {
  const CashierErrorPanel({
    super.key,
    required this.message,
    required this.retryLabel,
    required this.onRetry,
  });

  final String message;
  final String retryLabel;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => Container(
    padding: AppSpacing.allLg,
    decoration: BoxDecoration(
      color: AppColors.refundWarningBackground,
      borderRadius: AppRadius.card,
      border: Border.all(color: AppColors.refundWarningBorder),
    ),
    child: Row(
      children: <Widget>[
        const Icon(Icons.error_outline, color: AppColors.danger),
        const SizedBox(width: AppSpacing.md),
        Expanded(
          child: Text(
            message,
            style: AppTextStyles.bodyMedium.copyWith(color: AppColors.danger),
          ),
        ),
        const SizedBox(width: AppSpacing.md),
        SizedBox(
          height: kCashierTouchTarget,
          child: TextButton(onPressed: onRetry, child: Text(retryLabel)),
        ),
      ],
    ),
  );
}

/// Operational alert row. Severity maps to the existing semantic colours; there
/// is deliberately no "target missed" style of alert on this surface.
class CashierAlertRow extends StatelessWidget {
  const CashierAlertRow({
    super.key,
    required this.severity,
    required this.message,
  });

  final String severity;
  final String message;

  @override
  Widget build(BuildContext context) {
    final (Color colour, IconData icon) = switch (severity) {
      'danger' => (AppColors.danger, Icons.report_gmailerrorred_outlined),
      'warning' => (AppColors.warning, Icons.warning_amber_outlined),
      _ => (AppColors.info, Icons.info_outline),
    };
    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.md,
      ),
      decoration: BoxDecoration(
        color: colour.withValues(alpha: 0.08),
        borderRadius: AppRadius.control,
        border: Border.all(color: colour.withValues(alpha: 0.20)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Icon(icon, size: 18, color: colour),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              message,
              style: AppTextStyles.bodySmall.copyWith(
                color: AppColors.textPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class CashierStateBadge extends StatelessWidget {
  const CashierStateBadge({
    super.key,
    required this.label,
    required this.colour,
  });

  final String label;
  final Color colour;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(
      horizontal: AppSpacing.md,
      vertical: AppSpacing.xs,
    ),
    decoration: BoxDecoration(
      color: colour.withValues(alpha: 0.12),
      border: Border.all(color: colour.withValues(alpha: 0.20)),
      borderRadius: AppRadius.pillRadius,
    ),
    child: Text(
      label,
      style: AppTextStyles.labelSmall.copyWith(
        color: colour,
        fontWeight: FontWeight.w800,
      ),
    ),
  );
}

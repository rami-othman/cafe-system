import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_radius.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_text_styles.dart';
import 'app_card.dart';

TextStyle _managementStyle(BuildContext context, TextStyle style) =>
    Directionality.of(context) == TextDirection.rtl
    ? style.copyWith(fontFamily: 'IBMPlexSansArabic')
    : style;

/// Shared desktop presentation primitives for operational management pages.
class ManagementPageHeader extends StatelessWidget {
  const ManagementPageHeader({
    super.key,
    required this.title,
    required this.subtitle,
    this.actions = const <Widget>[],
  });
  final String title;
  final String subtitle;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (BuildContext context, BoxConstraints constraints) {
      final Widget heading = Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            title,
            style: _managementStyle(context, AppTextStyles.headlineMedium),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            subtitle,
            style: _managementStyle(
              context,
              AppTextStyles.bodySmall.copyWith(color: AppColors.textMuted),
            ),
          ),
        ],
      );
      if (actions.isEmpty) return heading;
      if (constraints.maxWidth < 650) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            heading,
            const SizedBox(height: AppSpacing.lg),
            Wrap(
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.sm,
              children: actions,
            ),
          ],
        );
      }
      return Row(
        children: <Widget>[
          Expanded(child: heading),
          Wrap(spacing: AppSpacing.sm, children: actions),
        ],
      );
    },
  );
}

class ManagementKpiCard extends StatelessWidget {
  const ManagementKpiCard({
    super.key,
    required this.label,
    required this.value,
    required this.icon,
    this.color = AppColors.discountIconBackground,
    this.detail,
  });
  final String label;
  final String value;
  final IconData icon;
  final Color color;
  final String? detail;
  @override
  Widget build(BuildContext context) => AppCard(
    padding: AppSpacing.allLg,
    child: Row(
      children: <Widget>[
        Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            color: color,
            borderRadius: AppRadius.control,
          ),
          child: Icon(icon, color: AppColors.secondary),
        ),
        const SizedBox(width: AppSpacing.md),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                label,
                style: _managementStyle(context, AppTextStyles.labelSmall),
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                value,
                style: _managementStyle(context, AppTextStyles.titleLarge),
              ),
              if (detail != null)
                Text(
                  detail!,
                  style: _managementStyle(context, AppTextStyles.labelSmall),
                ),
            ],
          ),
        ),
      ],
    ),
  );
}

class ManagementFilterBar extends StatelessWidget {
  const ManagementFilterBar({super.key, required this.children});
  final List<Widget> children;
  @override
  Widget build(BuildContext context) => AppCard(
    padding: AppSpacing.allMd,
    child: Wrap(
      spacing: AppSpacing.md,
      runSpacing: AppSpacing.md,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: children,
    ),
  );
}

class ManagementTableShell extends StatefulWidget {
  const ManagementTableShell({
    super.key,
    required this.child,
    this.minWidth = 760,
    this.verticalScroll = false,
  });
  final Widget child;
  final double minWidth;
  final bool verticalScroll;

  @override
  State<ManagementTableShell> createState() => _ManagementTableShellState();
}

class _ManagementTableShellState extends State<ManagementTableShell> {
  late final ScrollController _verticalController = ScrollController();

  @override
  void dispose() {
    _verticalController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final Widget table = widget.minWidth <= 0
        ? widget.child
        : SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: ConstrainedBox(
              constraints: BoxConstraints(minWidth: widget.minWidth),
              child: widget.child,
            ),
          );

    final Widget content = widget.verticalScroll
        ? Scrollbar(
            controller: _verticalController,
            thumbVisibility: true,
            child: SingleChildScrollView(
              controller: _verticalController,
              primary: false,
              child: table,
            ),
          )
        : table;

    return AppCard(padding: EdgeInsets.zero, child: content);
  }
}

class ManagementBadge extends StatelessWidget {
  const ManagementBadge({super.key, required this.label, required this.tone});
  final String label;
  final ManagementTone tone;
  @override
  Widget build(BuildContext context) {
    final (Color background, Color text) = switch (tone) {
      ManagementTone.success => (
        AppColors.discountGreenBadge,
        AppColors.discountGreenText,
      ),
      ManagementTone.warning => (
        AppColors.discountOrangeBadge,
        AppColors.discountOrangeText,
      ),
      ManagementTone.danger => (const Color(0xFFFFE6E4), AppColors.danger),
      ManagementTone.info => (
        AppColors.discountBlueBadge,
        AppColors.discountBlueText,
      ),
      ManagementTone.neutral => (AppColors.surfaceAlt, AppColors.textMuted),
    };
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: 5,
      ),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(99),
      ),
      child: Text(
        label,
        style: _managementStyle(
          context,
          AppTextStyles.labelSmall.copyWith(color: text),
        ),
      ),
    );
  }
}

enum ManagementTone { success, warning, danger, info, neutral }

class ManagementMessage extends StatelessWidget {
  const ManagementMessage({
    super.key,
    required this.message,
    this.error = false,
    this.onRetry,
  });
  final String message;
  final bool error;
  final VoidCallback? onRetry;
  @override
  Widget build(BuildContext context) => AppCard(
    child: Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(
            error ? Icons.error_outline : Icons.inventory_2_outlined,
            color: error ? AppColors.danger : AppColors.textMuted,
            size: 34,
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            message,
            style: _managementStyle(context, AppTextStyles.bodyMedium),
          ),
          if (onRetry != null)
            TextButton(
              onPressed: onRetry,
              child: Text(
                Directionality.of(context) == TextDirection.rtl
                    ? 'إعادة المحاولة'
                    : 'Retry',
              ),
            ),
        ],
      ),
    ),
  );
}

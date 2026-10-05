import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_radius.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../shared/widgets/app_card.dart';
import '../models/daily_report_data.dart';

class ReportKpiGrid extends StatelessWidget {
  const ReportKpiGrid({super.key, required this.items});
  final List<ReportKpiItem> items;
  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (BuildContext context, BoxConstraints constraints) {
      final int columns = constraints.maxWidth >= 960
          ? 4
          : constraints.maxWidth >= 520
          ? 2
          : 1;
      final double width =
          (constraints.maxWidth - (AppSpacing.lg * (columns - 1))) / columns;
      return Wrap(
        spacing: AppSpacing.lg,
        runSpacing: AppSpacing.lg,
        children: items
            .map(
              (ReportKpiItem item) => SizedBox(
                width: width,
                height: 144,
                child: ReportKpiCard(item: item),
              ),
            )
            .toList(),
      );
    },
  );
}

class ReportKpiCard extends StatelessWidget {
  const ReportKpiCard({super.key, required this.item});
  final ReportKpiItem item;
  @override
  Widget build(BuildContext context) {
    final bool featured = item.type == ReportKpiType.netSales;
    final bool cash = item.type == ReportKpiType.expectedCash;
    final Color textColor = featured
        ? AppColors.textInverse
        : AppColors.textPrimary;
    final Widget child = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: <Widget>[
        Row(
          children: <Widget>[
            Expanded(
              child: Text(
                item.label,
                style: AppTextStyles.bodySmall.copyWith(
                  color: featured
                      ? AppColors.white.withValues(alpha: .8)
                      : AppColors.textMuted,
                ),
              ),
            ),
            if (item.icon != null)
              Icon(
                item.icon,
                size: 20,
                color: featured ? AppColors.white : AppColors.secondary,
              ),
          ],
        ),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              item.value,
              style: AppTextStyles.headlineMedium.copyWith(
                color: item.valueColor ?? textColor,
              ),
            ),
            if (featured) ...<Widget>[
              const SizedBox(height: AppSpacing.xs),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.sm,
                  vertical: 2,
                ),
                decoration: BoxDecoration(
                  color: AppColors.white.withValues(alpha: .1),
                  borderRadius: AppRadius.pillRadius,
                ),
                child: Text(
                  '+12% vs Yesterday',
                  style: AppTextStyles.labelSmall.copyWith(
                    color: const Color(0xFF80D39A),
                  ),
                ),
              ),
            ],
          ],
        ),
      ],
    );
    if (featured) {
      return DecoratedBox(
        decoration: const BoxDecoration(
          color: AppColors.primary,
          borderRadius: AppRadius.card,
          boxShadow: <BoxShadow>[
            BoxShadow(
              color: Color(0x0A000000),
              blurRadius: 4,
              offset: Offset(0, 2),
            ),
          ],
        ),
        child: Padding(padding: AppSpacing.allSm, child: child),
      );
    }
    if (cash) {
      return AppCard(
        key: const Key('expected-cash-card'),
        padding: EdgeInsets.zero,
        child: DecoratedBox(
          decoration: const BoxDecoration(color: Color(0xFFFFF8F1)),
          child: SizedBox.expand(
            child: Padding(padding: AppSpacing.allLg, child: child),
          ),
        ),
      );
    }

    return AppCard(padding: AppSpacing.allLg, child: child);
  }
}

import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_radius.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../shared/widgets/app_card.dart';
import '../models/daily_report_data.dart';

class ReportSectionCard extends StatelessWidget {
  const ReportSectionCard({
    super.key,
    required this.title,
    required this.child,
    this.trailing,
  });
  final String title;
  final Widget child;
  final Widget? trailing;
  @override
  Widget build(BuildContext context) => AppCard(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Row(
          children: <Widget>[
            Expanded(child: Text(title, style: AppTextStyles.titleMedium)),
            if (trailing case final Widget trailing) trailing,
          ],
        ),
        const SizedBox(height: AppSpacing.lg),
        child,
      ],
    ),
  );
}

class HourlySalesChart extends StatelessWidget {
  const HourlySalesChart({super.key, required this.points});
  final List<HourlySalesPoint> points;
  @override
  Widget build(BuildContext context) => ReportSectionCard(
    title: 'Sales by Hour',
    trailing: Text(
      'Peak: 9:00 AM (\$845.50)',
      style: AppTextStyles.labelSmall.copyWith(color: AppColors.textMuted),
    ),
    child: SizedBox(
      height: 256,
      child: LayoutBuilder(
        builder: (BuildContext context, BoxConstraints constraints) {
          final double maxValue = points
              .map((HourlySalesPoint point) => point.value)
              .reduce((double a, double b) => a > b ? a : b);
          return Stack(
            children: <Widget>[
              Positioned.fill(
                bottom: 26,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: List<Widget>.generate(
                    4,
                    (_) => const Divider(height: 1, color: AppColors.border),
                  ),
                ),
              ),
              Positioned.fill(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: points.map((HourlySalesPoint point) {
                    return Expanded(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 5),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: <Widget>[
                            Expanded(
                              child: Align(
                                alignment: Alignment.bottomCenter,
                                child: FractionallySizedBox(
                                  heightFactor: point.value / maxValue,
                                  widthFactor: .78,
                                  alignment: Alignment.bottomCenter,
                                  child: DecoratedBox(
                                    key: Key('hour-bar-${point.label}'),
                                    decoration: BoxDecoration(
                                      color: point.isPeak
                                          ? AppColors.primary
                                          : AppColors.surfaceAlt,
                                      borderRadius: const BorderRadius.vertical(
                                        top: Radius.circular(AppRadius.sm),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(height: AppSpacing.sm),
                            Text(
                              point.label,
                              style: AppTextStyles.labelSmall.copyWith(
                                color: point.isPeak
                                    ? AppColors.primary
                                    : AppColors.textMuted,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),
            ],
          );
        },
      ),
    ),
  );
}

class PaymentMethodBreakdownCard extends StatelessWidget {
  const PaymentMethodBreakdownCard({super.key, required this.items});
  final List<PaymentMethodReportItem> items;
  @override
  Widget build(BuildContext context) => ReportSectionCard(
    title: 'Payment Method Breakdown',
    child: Column(
      children: <Widget>[
        for (final PaymentMethodReportItem item in items)
          Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.md),
            child: Row(
              children: <Widget>[
                Container(
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(
                    color: item.color,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Text(item.label, style: AppTextStyles.bodySmall),
                ),
                Text('${item.percent}%', style: AppTextStyles.labelMedium),
                const SizedBox(width: AppSpacing.md),
                SizedBox(
                  width: 82,
                  child: Text(
                    item.value,
                    textAlign: TextAlign.right,
                    style: AppTextStyles.labelMedium.copyWith(
                      color: AppColors.textPrimary,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ClipRRect(
          borderRadius: AppRadius.pillRadius,
          child: SizedBox(
            height: 10,
            child: Row(
              children: items
                  .map(
                    (PaymentMethodReportItem item) => Expanded(
                      flex: item.percent,
                      child: ColoredBox(color: item.color),
                    ),
                  )
                  .toList(),
            ),
          ),
        ),
      ],
    ),
  );
}

class OrdersByTypeCard extends StatelessWidget {
  const OrdersByTypeCard({super.key, required this.items});
  final List<OrderTypeReportItem> items;
  @override
  Widget build(BuildContext context) => ReportSectionCard(
    title: 'Orders by Type',
    child: LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final double cardWidth = constraints.maxWidth < 430
            ? constraints.maxWidth
            : (constraints.maxWidth - AppSpacing.md * 2) / 3;
        return Wrap(
          spacing: AppSpacing.md,
          runSpacing: AppSpacing.md,
          children: items.map((OrderTypeReportItem item) {
            return SizedBox(
              width: cardWidth,
              child: DecoratedBox(
                decoration: const BoxDecoration(
                  color: AppColors.background,
                  border: Border.fromBorderSide(
                    BorderSide(color: AppColors.border),
                  ),
                  borderRadius: AppRadius.control,
                ),
                child: Padding(
                  padding: AppSpacing.allMd,
                  child: Column(
                    children: <Widget>[
                      Icon(item.icon, size: 20, color: AppColors.secondary),
                      const SizedBox(height: AppSpacing.sm),
                      Text(item.label, style: AppTextStyles.labelSmall),
                      const SizedBox(height: AppSpacing.xs),
                      Text('${item.count}', style: AppTextStyles.titleMedium),
                      Text(
                        item.value,
                        style: AppTextStyles.labelMedium.copyWith(
                          color: AppColors.secondary,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          }).toList(),
        );
      },
    ),
  );
}

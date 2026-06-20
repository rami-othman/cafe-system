import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_text_styles.dart';
import '../models/order_timeline_event.dart';

class OrderTimelineSection extends StatelessWidget {
  const OrderTimelineSection({super.key, required this.events});

  final List<OrderTimelineEvent> events;

  @override
  Widget build(BuildContext context) {
    return _DetailSection(
      title: 'Timeline',
      child: Column(
        children: <Widget>[
          for (int index = 0; index < events.length; index++)
            _TimelineEventRow(
              event: events[index],
              isLast: index == events.length - 1,
            ),
        ],
      ),
    );
  }
}

class _TimelineEventRow extends StatelessWidget {
  const _TimelineEventRow({required this.event, required this.isLast});

  final OrderTimelineEvent event;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    final String time = DateFormat('h:mm a').format(event.time);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        SizedBox(
          width: 20,
          child: Column(
            children: <Widget>[
              Container(
                width: 9,
                height: 9,
                decoration: const BoxDecoration(
                  color: AppColors.tertiary,
                  shape: BoxShape.circle,
                ),
              ),
              if (!isLast)
                Container(
                  width: 1,
                  height: 48,
                  color: AppColors.orderDetailsTimelineLine,
                ),
            ],
          ),
        ),
        const SizedBox(width: AppSpacing.md),
        Expanded(
          child: Padding(
            padding: EdgeInsets.only(bottom: isLast ? 0 : AppSpacing.lg),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  event.title,
                  style: AppTextStyles.labelLarge.copyWith(
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  '$time - ${event.subtitle}',
                  style: AppTextStyles.bodySmall.copyWith(
                    color: AppColors.textMuted,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _DetailSection extends StatelessWidget {
  const _DetailSection({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          title,
          style: AppTextStyles.labelLarge.copyWith(
            color: AppColors.primary,
            fontSize: 14,
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        const Divider(height: 1, color: AppColors.divider),
        const SizedBox(height: AppSpacing.md),
        child,
      ],
    );
  }
}

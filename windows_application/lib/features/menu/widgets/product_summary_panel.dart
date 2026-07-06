import 'dart:ui' show PathMetric;

import 'package:flutter/material.dart';

import '../../../core/constants/app_sizes.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_radius.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../shared/widgets/app_card.dart';
import 'setup_progress_list.dart';

class ProductSummaryPanel extends StatelessWidget {
  const ProductSummaryPanel({super.key});

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: AppSpacing.allLg,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text('Product Summary', style: AppTextStyles.titleMedium),
          const SizedBox(height: AppSpacing.md),
          CustomPaint(
            painter: _DashedBorderPainter(),
            child: const SizedBox(
              height: AppSizes.createProductUploadHeight,
              width: double.infinity,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: <Widget>[
                  Icon(
                    Icons.add_photo_alternate_outlined,
                    size: 36,
                    color: AppColors.secondary,
                  ),
                  SizedBox(height: AppSpacing.sm),
                  Text('Upload Product Image', style: AppTextStyles.bodySmall),
                  SizedBox(height: AppSpacing.xs),
                  Text(
                    'Recommended: 800x800px',
                    style: TextStyle(
                      fontFamily: AppTextStyles.fontFamily,
                      fontSize: 11,
                      color: AppColors.textMuted,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          const Divider(),
          const SizedBox(height: AppSpacing.sm),
          Row(
            children: <Widget>[
              Text(
                'Current Status',
                style: AppTextStyles.labelSmall.copyWith(
                  color: AppColors.textSecondary,
                  letterSpacing: 0.4,
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.sm,
                  vertical: AppSpacing.xs,
                ),
                decoration: const BoxDecoration(
                  color: Color(0x1AD97706),
                  borderRadius: AppRadius.pillRadius,
                ),
                child: Text(
                  'DRAFT',
                  style: AppTextStyles.labelSmall.copyWith(
                    color: Color(0xFFD97706),
                    fontSize: 11,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          const Divider(),
          const SizedBox(height: AppSpacing.md),
          const SetupProgressList(),
        ],
      ),
    );
  }
}

class _DashedBorderPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    const double dashWidth = 6;
    const double dashGap = 4;
    final RRect border = RRect.fromRectAndRadius(
      Offset.zero & size,
      const Radius.circular(AppRadius.sm),
    );
    final Path path = Path()..addRRect(border);
    final Paint paint = Paint()
      ..color = AppColors.dashedBorder
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;

    for (final PathMetric metric in path.computeMetrics()) {
      double distance = 0;
      while (distance < metric.length) {
        canvas.drawPath(
          metric.extractPath(distance, distance + dashWidth),
          paint,
        );
        distance += dashWidth + dashGap;
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

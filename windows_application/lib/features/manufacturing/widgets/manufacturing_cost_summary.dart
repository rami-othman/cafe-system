import 'package:flutter/material.dart';

import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../shared/widgets/app_card.dart';
import '../models/manufacturing_production_models.dart';

class ManufacturingCostSummary extends StatelessWidget {
  const ManufacturingCostSummary({super.key, required this.order});
  final ManufacturingProductionOrder order;

  @override
  Widget build(BuildContext context) => AppCard(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('تكلفة الإنتاج', style: AppTextStyles.titleMedium),
        const SizedBox(height: AppSpacing.md),
        Wrap(
          spacing: AppSpacing.xl,
          runSpacing: AppSpacing.md,
          children: [
            _cost('تكلفة المواد', order.actualCost),
            _cost('تكلفة المواد للوحدة (${order.unit})', order.actualUnitCost),
            _cost('تكاليف التشغيل', order.additionalCostTotal),
            _cost('التكلفة الكاملة للدفعة', order.fullCost),
            _cost('التكلفة الكاملة للوحدة', order.fullUnitCost),
          ],
        ),
        const SizedBox(height: AppSpacing.md),
        const Text(
          'التكلفة الكاملة تشمل تكاليف التشغيل المدخلة للمتابعة؛ لا تُنشئ دفعاً أو مصروفاً مالياً تلقائياً.',
        ),
      ],
    ),
  );

  Widget _cost(String label, String? value) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(label, style: AppTextStyles.labelSmall),
      Text(value ?? '—', style: AppTextStyles.labelLarge),
    ],
  );
}

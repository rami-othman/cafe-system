import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_radius.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_text_styles.dart';

class SetupProgressList extends StatelessWidget {
  const SetupProgressList({super.key});

  static const List<(IconData, String)> _lockedSteps = <(IconData, String)>[
    (Icons.tune_outlined, 'Variants & Pricing'),
    (Icons.add_circle_outline, 'Modifiers'),
    (Icons.event_available_outlined, 'Availability'),
    (Icons.storefront_outlined, 'Branch Pricing'),
    (Icons.history, 'History'),
  ];

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          'SETUP PROGRESS',
          style: AppTextStyles.labelSmall.copyWith(
            color: AppColors.textSecondary,
            letterSpacing: 0.6,
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        Container(
          padding: AppSpacing.allSm,
          decoration: const BoxDecoration(
            color: Color(0x1A805437),
            borderRadius: AppRadius.control,
          ),
          child: Row(
            children: <Widget>[
              const Icon(
                Icons.info_outline,
                size: 16,
                color: AppColors.secondary,
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(
                  'General Info',
                  style: AppTextStyles.bodySmall.copyWith(
                    color: AppColors.secondary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const Icon(
                Icons.chevron_right,
                size: 16,
                color: AppColors.secondary,
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.xs),
        ..._lockedSteps.map(
          ((IconData, String) step) =>
              _LockedProgressRow(icon: step.$1, label: step.$2),
        ),
        const SizedBox(height: AppSpacing.md),
        Center(
          child: Text(
            'Save general info to unlock other tabs.',
            textAlign: TextAlign.center,
            style: AppTextStyles.bodySmall.copyWith(
              color: AppColors.textMuted,
              fontSize: 11,
            ),
          ),
        ),
      ],
    );
  }
}

class _LockedProgressRow extends StatelessWidget {
  const _LockedProgressRow({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: AppSpacing.allSm,
      child: Row(
        children: <Widget>[
          Icon(icon, size: 16, color: AppColors.textMuted),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              label,
              style: AppTextStyles.bodySmall.copyWith(
                color: AppColors.textMuted,
              ),
            ),
          ),
          const Icon(Icons.lock_outline, size: 16, color: AppColors.textMuted),
        ],
      ),
    );
  }
}

import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../shared/widgets/app_button.dart';

class ReportHeader extends StatelessWidget {
  const ReportHeader({
    super.key,
    required this.dateLabel,
    required this.onDateTap,
    required this.onPrint,
    required this.onExport,
  });
  final String dateLabel;
  final VoidCallback onDateTap;
  final VoidCallback onPrint;
  final VoidCallback onExport;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (BuildContext context, BoxConstraints constraints) {
      final Widget details = Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text('Daily Operational Report', style: AppTextStyles.headlineMedium),
          const SizedBox(height: AppSpacing.xs),
          TextButton.icon(
            onPressed: onDateTap,
            icon: const Icon(Icons.calendar_today_outlined, size: 15),
            label: Text(dateLabel),
            style: TextButton.styleFrom(
              foregroundColor: AppColors.textMuted,
              padding: EdgeInsets.zero,
              textStyle: AppTextStyles.bodySmall,
            ),
          ),
        ],
      );
      final Widget actions = Wrap(
        spacing: AppSpacing.md,
        runSpacing: AppSpacing.sm,
        children: <Widget>[
          AppButton(
            label: 'Print',
            icon: Icons.print_outlined,
            variant: AppButtonVariant.outlined,
            minimumHeight: 40,
            onPressed: onPrint,
          ),
          AppButton(
            label: 'Export Report',
            icon: Icons.file_download_outlined,
            variant: AppButtonVariant.secondary,
            minimumHeight: 40,
            onPressed: onExport,
          ),
        ],
      );
      if (constraints.maxWidth < 640) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            details,
            const SizedBox(height: AppSpacing.lg),
            actions,
          ],
        );
      }
      return Row(
        children: <Widget>[
          Expanded(child: details),
          actions,
        ],
      );
    },
  );
}

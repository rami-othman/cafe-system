import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_text_styles.dart';

class AppBreadcrumbItem {
  const AppBreadcrumbItem({required this.label, this.onTap, this.key});

  final String label;
  final VoidCallback? onTap;
  final Key? key;
}

class AppBreadcrumbs extends StatelessWidget {
  const AppBreadcrumbs({super.key, required this.items});

  final List<AppBreadcrumbItem> items;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: AppSpacing.sm,
      runSpacing: AppSpacing.xs,
      children: <Widget>[
        for (int index = 0; index < items.length; index++) ...<Widget>[
          if (index > 0)
            Icon(
              Directionality.of(context) == TextDirection.rtl
                  ? Icons.chevron_left
                  : Icons.chevron_right,
              size: 14,
              color: AppColors.textMuted,
            ),
          _BreadcrumbLabel(
            item: items[index],
            isCurrent: index == items.length - 1,
          ),
        ],
      ],
    );
  }
}

class _BreadcrumbLabel extends StatelessWidget {
  const _BreadcrumbLabel({required this.item, required this.isCurrent});

  final AppBreadcrumbItem item;
  final bool isCurrent;

  @override
  Widget build(BuildContext context) {
    final TextStyle style = AppTextStyles.bodySmall.copyWith(
      color: isCurrent ? AppColors.textPrimary : AppColors.secondary,
      fontWeight: isCurrent ? FontWeight.w500 : FontWeight.w600,
    );

    if (item.onTap == null) {
      return Text(item.label, key: item.key, style: style);
    }

    return TextButton(
      key: item.key,
      onPressed: item.onTap,
      style: TextButton.styleFrom(
        minimumSize: Size.zero,
        padding: EdgeInsets.zero,
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        foregroundColor: AppColors.secondary,
        textStyle: style,
      ),
      child: Text(item.label),
    );
  }
}

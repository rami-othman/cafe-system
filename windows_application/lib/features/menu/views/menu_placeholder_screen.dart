import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../shared/layouts/desktop_page_layout.dart';
import '../../../shared/widgets/app_breadcrumbs.dart';

class MenuPlaceholderScreen extends StatelessWidget {
  const MenuPlaceholderScreen({
    super.key,
    required this.title,
    this.breadcrumbs = const <AppBreadcrumbItem>[],
  });

  final String title;
  final List<AppBreadcrumbItem> breadcrumbs;

  @override
  Widget build(BuildContext context) {
    return DesktopPageLayout(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            if (breadcrumbs.isNotEmpty) ...<Widget>[
              AppBreadcrumbs(
                items: <AppBreadcrumbItem>[
                  ...breadcrumbs,
                  AppBreadcrumbItem(label: title),
                ],
              ),
              const SizedBox(height: 12),
            ],
            Text(
              title,
              style: AppTextStyles.headlineMedium.copyWith(
                color: AppColors.primary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

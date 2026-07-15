import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../shared/layouts/desktop_page_layout.dart';

class MenuPlaceholderScreen extends StatelessWidget {
  const MenuPlaceholderScreen({super.key, required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return DesktopPageLayout(
      child: Center(
        child: Text(
          title,
          style: AppTextStyles.headlineMedium.copyWith(
            color: AppColors.primary,
          ),
        ),
      ),
    );
  }
}

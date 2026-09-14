import 'package:flutter/material.dart';

import '../../../core/branding/brand_header.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../l10n/app_localizations.dart';

class AuthSplashScreen extends StatelessWidget {
  const AuthSplashScreen({super.key});

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: AppColors.background,
    body: Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          const BrandLogo(compact: false, size: 120),
          const SizedBox(height: AppSpacing.xl),
          const CircularProgressIndicator(color: AppColors.tertiary),
          const SizedBox(height: AppSpacing.lg),
          Text(
            AppLocalizations.of(context).authRestoringSession,
            style: AppTextStyles.bodyMedium,
          ),
        ],
      ),
    ),
  );
}

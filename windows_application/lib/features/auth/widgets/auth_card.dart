import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_radius.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_text_styles.dart';

class AuthCard extends StatelessWidget {
  const AuthCard({
    super.key,
    required this.title,
    required this.subtitle,
    required this.child,
  });

  final String title;
  final String subtitle;
  final Widget child;

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: AppColors.background,
    body: Stack(
      children: <Widget>[
        const Positioned(
          top: -180,
          right: -120,
          child: _CoffeeHalo(size: 420, opacity: .07),
        ),
        const Positioned(
          bottom: -150,
          left: -110,
          child: _CoffeeHalo(size: 330, opacity: .05),
        ),
        Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(AppSpacing.xl),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 460),
              child: Container(
                padding: const EdgeInsets.all(AppSpacing.xxxl),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: AppRadius.panel,
                  border: Border.all(color: AppColors.border),
                  boxShadow: const <BoxShadow>[
                    BoxShadow(
                      color: Color(0x173B2417),
                      blurRadius: 36,
                      offset: Offset(0, 16),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: <Widget>[
                    const Center(child: _BrandMark()),
                    const SizedBox(height: AppSpacing.xl),
                    Text(
                      'Cafe System 618',
                      textAlign: TextAlign.center,
                      style: AppTextStyles.headlineMedium,
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      subtitle,
                      textAlign: TextAlign.center,
                      style: AppTextStyles.labelLarge.copyWith(
                        color: AppColors.tertiary,
                        letterSpacing: .3,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xxxl),
                    Text(title, style: AppTextStyles.titleLarge),
                    const SizedBox(height: AppSpacing.sm),
                    child,
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    ),
  );
}

class _BrandMark extends StatelessWidget {
  const _BrandMark();

  @override
  Widget build(BuildContext context) => Container(
    width: 54,
    height: 54,
    alignment: Alignment.center,
    decoration: BoxDecoration(
      color: AppColors.primary,
      borderRadius: AppRadius.control,
      boxShadow: const <BoxShadow>[
        BoxShadow(
          color: Color(0x263B2417),
          blurRadius: 14,
          offset: Offset(0, 6),
        ),
      ],
    ),
    child: const Icon(Icons.local_cafe_outlined, color: AppColors.textInverse),
  );
}

class _CoffeeHalo extends StatelessWidget {
  const _CoffeeHalo({required this.size, required this.opacity});
  final double size;
  final double opacity;

  @override
  Widget build(BuildContext context) => Container(
    width: size,
    height: size,
    decoration: BoxDecoration(
      color: AppColors.tertiary.withValues(alpha: opacity),
      shape: BoxShape.circle,
    ),
  );
}

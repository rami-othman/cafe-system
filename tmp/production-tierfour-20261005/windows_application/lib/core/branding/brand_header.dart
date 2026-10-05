import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_text_styles.dart';
import 'app_brand.dart';

class BrandLogo extends StatelessWidget {
  const BrandLogo({
    super.key,
    this.compact = true,
    this.darkSurface = false,
    this.size = 44,
  });

  final bool compact;
  final bool darkSurface;
  final double size;

  @override
  Widget build(BuildContext context) => Image.asset(
    compact
        ? (darkSurface ? AppBrand.logoMarkDark : AppBrand.logoMarkLight)
        : (darkSurface ? AppBrand.logoFullDark : AppBrand.logoFullLight),
    width: size,
    height: size,
    fit: BoxFit.contain,
    filterQuality: FilterQuality.high,
    semanticLabel: AppBrand.productName,
  );
}

class BrandHeader extends StatelessWidget {
  const BrandHeader({
    super.key,
    required this.identity,
    this.compact = false,
    this.darkSurface = false,
  });

  final BrandIdentity identity;
  final bool compact;
  final bool darkSurface;

  @override
  Widget build(BuildContext context) {
    final Color primaryText = darkSurface
        ? AppColors.textInverse
        : AppColors.textPrimary;
    final Color secondaryText = darkSurface
        ? AppColors.background
        : AppColors.textSecondary;
    final Widget logo = BrandLogo(
      compact: true,
      darkSurface: darkSurface,
      size: compact ? 42 : 48,
    );
    if (compact) return Tooltip(message: identity.displayName, child: logo);

    return Row(
      children: <Widget>[
        logo,
        const SizedBox(width: AppSpacing.sm),
        Flexible(
          child: Tooltip(
            message: identity.displayName,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  identity.displayName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.bodyLarge.copyWith(
                    color: primaryText,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                Text(
                  identity.subtitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.labelSmall.copyWith(
                    color: secondaryText,
                    fontSize: 10,
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

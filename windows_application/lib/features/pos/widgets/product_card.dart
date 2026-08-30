import 'package:flutter/material.dart';

import '../../../core/constants/app_sizes.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_radius.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../app/localization/localization_extensions.dart';
import '../models/pos_product.dart';

class ProductCard extends StatelessWidget {
  const ProductCard({super.key, required this.product, this.onTap});

  final PosProduct product;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: product.isAvailable ? 1 : 0.6,
      child: Stack(
        children: <Widget>[
          Material(
            color: AppColors.surface,
            clipBehavior: Clip.antiAlias,
            shape: const RoundedRectangleBorder(
              borderRadius: AppRadius.card,
              side: BorderSide(color: AppColors.border),
            ),
            child: InkWell(
              onTap: onTap,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  _ProductVisual(product: product),
                  Expanded(child: _ProductDetails(product: product)),
                ],
              ),
            ),
          ),
          if (!product.isAvailable) _UnavailableOverlay(product: product),
        ],
      ),
    );
  }
}

class _ProductVisual extends StatelessWidget {
  const _ProductVisual({required this.product});

  final PosProduct product;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: AppSizes.productCardImageHeight,
      width: double.infinity,
      color: product.isAvailable
          ? AppColors.productVisualBackground
          : AppColors.surfaceAlt,
      child: product.imageUrl == null || product.imageUrl!.trim().isEmpty
          ? Icon(
              product.icon ?? Icons.restaurant_menu_outlined,
              color: AppColors.secondary,
              size: 34,
            )
          : Image.network(
              product.imageUrl!,
              fit: BoxFit.cover,
              errorBuilder:
                  (
                    BuildContext context,
                    Object error,
                    StackTrace? stackTrace,
                  ) => Icon(
                    product.icon ?? Icons.restaurant_menu_outlined,
                    color: AppColors.secondary,
                    size: 34,
                  ),
            ),
    );
  }
}

class _ProductDetails extends StatelessWidget {
  const _ProductDetails({required this.product});

  final PosProduct product;

  @override
  Widget build(BuildContext context) {
    final Color priceColor = product.isAvailable
        ? AppColors.tertiary
        : AppColors.textMuted;

    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            product.name,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: AppTextStyles.labelLarge.copyWith(
              color: AppColors.primary,
              fontSize: 18,
              fontWeight: FontWeight.w800,
            ),
          ),
          const Spacer(),
          Row(
            children: <Widget>[
              Expanded(
                child: Text(
                  product.size,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.labelSmall.copyWith(
                    color: AppColors.textMuted,
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.6,
                  ),
                ),
              ),
              Flexible(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: AlignmentDirectional.centerEnd,
                  child: Text(
                    CurrencyFormatter.formatForContext(
                      context,
                      product.price,
                      currencyCode: product.currencyCode ?? 'SYP',
                    ),
                    maxLines: 1,
                    style: AppTextStyles.titleMedium.copyWith(
                      color: priceColor,
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _UnavailableOverlay extends StatelessWidget {
  const _UnavailableOverlay({required this.product});

  final PosProduct product;

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: ColoredBox(
        color: AppColors.shellBackground.withValues(alpha: 0.5),
        child: Center(
          child: Container(
            height: AppSizes.unavailableBadgeHeight,
            alignment: Alignment.center,
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
            decoration: BoxDecoration(
              color: AppColors.white.withValues(alpha: 0.9),
              border: Border.all(color: AppColors.border),
              borderRadius: AppRadius.pillRadius,
              boxShadow: const <BoxShadow>[
                BoxShadow(
                  color: Color(0x0D000000),
                  offset: Offset(0, 1),
                  blurRadius: 2,
                ),
              ],
            ),
            child: Text(
              _label(context),
              style: AppTextStyles.labelSmall.copyWith(
                color: AppColors.textMuted,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.6,
              ),
            ),
          ),
        ),
      ),
    );
  }

  String _label(BuildContext context) => switch (product.unavailabilityReason) {
    'sold_out' => context.l10n.commonSoldOut,
    'temporarily_unavailable' => context.l10n.posTemporarilyUnavailable,
    _ => context.l10n.posTemporarilyUnavailable,
  };
}

import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../core/constants/app_sizes.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_radius.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../shared/widgets/app_card.dart';
import '../models/menu_enums.dart';
import '../models/menu_product.dart';
import 'product_status_chip.dart';
import 'product_type_chip.dart';

class ProductsTable extends StatelessWidget {
  const ProductsTable({super.key, required this.products});

  final List<MenuProduct> products;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: EdgeInsets.zero,
      child: Column(
        children: <Widget>[
          LayoutBuilder(
            builder: (BuildContext context, BoxConstraints constraints) {
              final double width = math.max(
                constraints.maxWidth,
                AppSizes.productsTableMinWidth,
              );

              return SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: SizedBox(
                  width: width,
                  child: Column(
                    children: <Widget>[
                      const _ProductTableHeader(),
                      for (final MenuProduct product in products)
                        _ProductTableRow(product: product),
                    ],
                  ),
                ),
              );
            },
          ),
          const _PaginationFooter(),
        ],
      ),
    );
  }
}

class _ProductTableHeader extends StatelessWidget {
  const _ProductTableHeader();

  @override
  Widget build(BuildContext context) {
    return Container(
      height: AppSizes.productsTableHeaderHeight,
      color: AppColors.menuTableHeader,
      child: const Row(
        children: <Widget>[
          _CheckboxCell(),
          _HeaderCell(label: 'PRODUCT', flex: 28),
          _HeaderCell(label: 'SKU', flex: 12),
          _HeaderCell(label: 'CATEGORY', flex: 12),
          _HeaderCell(label: 'TYPE', flex: 10),
          _HeaderCell(label: 'BASE PRICE', flex: 11),
          _HeaderCell(label: 'STATUS', flex: 12),
          _HeaderCell(label: 'ACTIONS', flex: 15, alignRight: true),
        ],
      ),
    );
  }
}

class _ProductTableRow extends StatelessWidget {
  const _ProductTableRow({required this.product});

  final MenuProduct product;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: AppSizes.productsTableRowHeight,
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(bottom: BorderSide(color: AppColors.divider)),
      ),
      child: Row(
        children: <Widget>[
          const _CheckboxCell(),
          _BodyCell(
            flex: 28,
            child: Row(
              children: <Widget>[
                _ProductThumbnail(product: product),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        product.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTextStyles.bodySmall.copyWith(
                          color: AppColors.textPrimary,
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      if (product.listSubtitle != null) ...<Widget>[
                        const SizedBox(height: 2),
                        Text(
                          product.listSubtitle!,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppTextStyles.labelSmall.copyWith(
                            color: AppColors.textMuted,
                            fontSize: 10,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
          _BodyCell(
            flex: 12,
            child: Text(
              product.sku,
              style: AppTextStyles.bodySmall.copyWith(
                color: AppColors.textMuted,
                fontFamily: 'monospace',
              ),
            ),
          ),
          _BodyCell(
            flex: 12,
            child: Text(product.categoryName, style: _bodyStyle),
          ),
          _BodyCell(
            flex: 10,
            child: Align(
              alignment: Alignment.centerLeft,
              child: ProductTypeChip(type: product.type),
            ),
          ),
          _BodyCell(
            flex: 11,
            child: Text(
              '\$${product.basePrice.toStringAsFixed(2)}',
              style: _bodyStyle.copyWith(fontWeight: FontWeight.w700),
            ),
          ),
          _BodyCell(
            flex: 12,
            child: Align(
              alignment: Alignment.centerLeft,
              child: ProductStatusChip(status: product.status),
            ),
          ),
          const _BodyCell(
            flex: 15,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: <Widget>[
                _RowAction(icon: Icons.edit_outlined, tooltip: 'Edit or view'),
                _RowAction(icon: Icons.copy_outlined, tooltip: 'Duplicate'),
                _RowAction(icon: Icons.more_horiz, tooltip: 'More actions'),
              ],
            ),
          ),
        ],
      ),
    );
  }

  TextStyle get _bodyStyle => AppTextStyles.bodySmall.copyWith(
    color: AppColors.textDark,
    fontSize: 13,
    fontWeight: FontWeight.w500,
  );
}

class _ProductThumbnail extends StatelessWidget {
  const _ProductThumbnail({required this.product});

  final MenuProduct product;

  @override
  Widget build(BuildContext context) {
    final IconData icon = switch (product.id) {
      'croissant' => Icons.bakery_dining_outlined,
      'morning-combo' => Icons.inventory_2_outlined,
      _ => Icons.coffee_outlined,
    };

    return Container(
      width: AppSizes.productThumbnailSize,
      height: AppSizes.productThumbnailSize,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: product.type == ProductType.combo
            ? AppColors.discountOrangeBadge
            : AppColors.surfaceAlt,
        border: Border.all(color: AppColors.border),
        borderRadius: AppRadius.control,
      ),
      child: Icon(icon, size: 22, color: AppColors.secondary),
    );
  }
}

class _CheckboxCell extends StatelessWidget {
  const _CheckboxCell();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 48,
      child: Center(
        child: Checkbox(
          value: false,
          onChanged: (_) {},
          materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
          visualDensity: VisualDensity.compact,
        ),
      ),
    );
  }
}

class _HeaderCell extends StatelessWidget {
  const _HeaderCell({
    required this.label,
    required this.flex,
    this.alignRight = false,
  });

  final String label;
  final int flex;
  final bool alignRight;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      flex: flex,
      child: Padding(
        padding: AppSpacing.horizontalLg,
        child: Align(
          alignment: alignRight ? Alignment.centerRight : Alignment.centerLeft,
          child: Text(
            label,
            style: AppTextStyles.labelSmall.copyWith(
              color: AppColors.primary,
              fontSize: 11,
              letterSpacing: 0.5,
            ),
          ),
        ),
      ),
    );
  }
}

class _BodyCell extends StatelessWidget {
  const _BodyCell({required this.flex, required this.child});

  final int flex;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      flex: flex,
      child: Padding(padding: AppSpacing.horizontalLg, child: child),
    );
  }
}

class _RowAction extends StatelessWidget {
  const _RowAction({required this.icon, required this.tooltip});

  final IconData icon;
  final String tooltip;

  @override
  Widget build(BuildContext context) {
    return SizedBox.square(
      dimension: 30,
      child: IconButton(
        onPressed: () {},
        tooltip: tooltip,
        padding: EdgeInsets.zero,
        constraints: const BoxConstraints.tightFor(width: 30, height: 30),
        visualDensity: VisualDensity.compact,
        iconSize: 16,
        color: AppColors.textMuted,
        icon: Icon(icon),
      ),
    );
  }
}

class _PaginationFooter extends StatelessWidget {
  const _PaginationFooter();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: AppSpacing.allLg,
      color: AppColors.contentBackground,
      child: Wrap(
        alignment: WrapAlignment.spaceBetween,
        runSpacing: AppSpacing.md,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: <Widget>[
          Text(
            'Showing 1 to 5 of 124 entries',
            style: AppTextStyles.bodySmall.copyWith(
              color: AppColors.textMuted,
              fontSize: 14,
              fontWeight: FontWeight.w400,
            ),
          ),
          const Wrap(
            spacing: AppSpacing.sm,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: <Widget>[
              _PageButton(icon: Icons.chevron_left, enabled: false),
              _PageButton(label: '1', isActive: true),
              _PageButton(label: '2'),
              _PageButton(label: '3'),
              Padding(
                padding: EdgeInsets.symmetric(horizontal: AppSpacing.xs),
                child: Text('...'),
              ),
              _PageButton(label: '25'),
              _PageButton(icon: Icons.chevron_right),
            ],
          ),
        ],
      ),
    );
  }
}

class _PageButton extends StatelessWidget {
  const _PageButton({
    this.label,
    this.icon,
    this.isActive = false,
    this.enabled = true,
  });

  final String? label;
  final IconData? icon;
  final bool isActive;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    return SizedBox.square(
      dimension: 32,
      child: OutlinedButton(
        onPressed: enabled ? () {} : null,
        style: OutlinedButton.styleFrom(
          padding: EdgeInsets.zero,
          minimumSize: const Size.square(32),
          foregroundColor: isActive
              ? AppColors.textInverse
              : AppColors.textMuted,
          backgroundColor: isActive ? AppColors.primary : AppColors.surface,
          disabledForegroundColor: AppColors.textMuted,
          side: BorderSide(
            color: isActive ? AppColors.primary : AppColors.border,
          ),
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.all(Radius.circular(6)),
          ),
        ),
        child: icon == null
            ? Text(label!, style: AppTextStyles.bodySmall)
            : Icon(icon, size: 16),
      ),
    );
  }
}

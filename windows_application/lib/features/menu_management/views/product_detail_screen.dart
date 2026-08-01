import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../shared/layouts/desktop_page_layout.dart';
import '../controllers/product_detail_cubit.dart';
import '../controllers/product_lifecycle_cubit.dart';
import '../controllers/product_catalog_cubit.dart';
import '../models/catalog_models.dart';
import '../widgets/catalog_formatters.dart';
import 'product_catalog_screen.dart'
    show CatalogProductImage, CatalogProductStatus;

class ProductDetailScreen extends StatefulWidget {
  const ProductDetailScreen({super.key, required this.productId});
  final int productId;
  @override
  State<ProductDetailScreen> createState() => _ProductDetailScreenState();
}

class _ProductDetailScreenState extends State<ProductDetailScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => context.read<ProductDetailCubit>().load(widget.productId),
    );
  }

  @override
  Widget build(
    BuildContext context,
  ) => BlocListener<ProductLifecycleCubit, ProductLifecycleState>(
    listenWhen: (previous, current) =>
        previous.status != current.status &&
        current.productId == widget.productId &&
        (current.status == ProductLifecycleStatus.success ||
            current.status == ProductLifecycleStatus.failure),
    listener: (context, lifecycle) async {
      if (lifecycle.status == ProductLifecycleStatus.success) {
        await Future.wait<void>(<Future<void>>[
          context.read<ProductDetailCubit>().load(widget.productId),
          context.read<ProductCatalogCubit>().refresh(),
        ]);
      }
      if (!context.mounted) return;
      final String? message =
          lifecycle.successMessage ?? lifecycle.errorMessage;
      if (message != null) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(message)));
      }
    },
    child: BlocBuilder<ProductDetailCubit, ProductDetailState>(
      builder: (context, state) {
        if (state.isLoading && state.product == null) {
          return const DesktopPageLayout(
            child: Center(child: CircularProgressIndicator()),
          );
        }
        if (state.product == null) {
          return DesktopPageLayout(
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Text(state.errorMessage ?? 'Product not found.'),
                  const SizedBox(height: AppSpacing.md),
                  OutlinedButton(
                    onPressed: () => context.read<ProductDetailCubit>().load(
                      widget.productId,
                    ),
                    child: const Text('Retry'),
                  ),
                ],
              ),
            ),
          );
        }
        final ProductDetail product = state.product!;
        return DesktopPageLayout(
          padding: EdgeInsets.zero,
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.xl,
              AppSpacing.xl,
              AppSpacing.xl,
              96,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                TextButton.icon(
                  onPressed: () => context.canPop()
                      ? context.pop()
                      : context.go('/menu-management/products'),
                  icon: const Icon(Icons.arrow_back),
                  label: const Text('Products'),
                ),
                const SizedBox(height: AppSpacing.sm),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    CatalogProductImage(url: product.imageUrl),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Text(
                            product.name,
                            style: AppTextStyles.headlineMedium.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: AppSpacing.xs),
                          CatalogProductStatus(product: product),
                        ],
                      ),
                    ),
                    if (!product.isArchived) ...<Widget>[
                      IconButton(
                        key: const Key('edit-product-action'),
                        tooltip: 'Edit product',
                        onPressed: () => context.go(
                          '/menu-management/products/${product.id}/edit',
                        ),
                        icon: const Icon(Icons.edit_outlined),
                      ),
                      const SizedBox(width: AppSpacing.xs),
                      FilledButton.icon(
                        key: const Key('manage-variants-action'),
                        onPressed: () => context.go(
                          '/menu-management/products/${product.id}/variants',
                        ),
                        icon: const Icon(Icons.tune_outlined),
                        label: const Text('Manage Variants'),
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      OutlinedButton.icon(
                        key: const Key('manage-modifiers-action'),
                        onPressed: () => context.go(
                          '/menu-management/products/${product.id}/modifiers',
                        ),
                        icon: const Icon(Icons.tune_outlined),
                        label: const Text('Manage Modifiers'),
                      ),
                    ],
                    const SizedBox(width: AppSpacing.sm),
                    _LifecycleButton(product: product),
                  ],
                ),
                const SizedBox(height: AppSpacing.lg),
                _Section(
                  title: 'General',
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Wrap(
                        spacing: 36,
                        runSpacing: AppSpacing.md,
                        children: <Widget>[
                          _Field('Arabic name', product.nameAr ?? '—'),
                          _Field('English name', product.nameEn ?? '—'),
                          _Field('Description', product.description ?? '—'),
                          _Field(
                            'Arabic description',
                            product.descriptionAr ?? '—',
                          ),
                          _Field(
                            'English description',
                            product.descriptionEn ?? '—',
                          ),
                          _Field(
                            'Product type',
                            productTypeLabel(product.productType),
                          ),
                          _Field(
                            'Catalog category',
                            product.category?.name ?? '—',
                          ),
                          _Field(
                            'Reporting category',
                            product.reportingCategory?.name ?? '—',
                          ),
                          _Field(
                            'Kitchen station',
                            product.kitchenStation?.name ?? '—',
                          ),
                          _Field(
                            'Preparation time',
                            product.preparationTimeMinutes == null
                                ? '—'
                                : '${product.preparationTimeMinutes} min',
                          ),
                          _Field(
                            'Stock tracking',
                            booleanLabel(product.isStockTracked),
                          ),
                          _Field('Updated', catalogDate(product.updatedAt)),
                          if (product.isArchived)
                            _Field('Archived', catalogDate(product.archivedAt)),
                        ],
                      ),
                      if (!product.isArchived) ...<Widget>[
                        const SizedBox(height: AppSpacing.lg),
                        OutlinedButton.icon(
                          key: const Key('manage-availability-action'),
                          onPressed: () => context.go(
                            '/menu-management/products/${product.id}/availability',
                          ),
                          icon: const Icon(Icons.schedule_outlined),
                          label: const Text('Manage Availability'),
                        ),
                        const SizedBox(height: AppSpacing.sm),
                        OutlinedButton.icon(
                          key: const Key(
                            'manage-operational-availability-action',
                          ),
                          onPressed: () => context.go(
                            '/menu-management/products/${product.id}/operational-availability',
                          ),
                          icon: const Icon(Icons.do_not_disturb_on_outlined),
                          label: const Text('Manage Operational Availability'),
                        ),
                      ] else ...<Widget>[
                        const SizedBox(height: AppSpacing.lg),
                        OutlinedButton.icon(
                          key: const Key(
                            'view-operational-availability-action',
                          ),
                          onPressed: () => context.go(
                            '/menu-management/products/${product.id}/operational-availability',
                          ),
                          icon: const Icon(Icons.visibility_outlined),
                          label: const Text('View Operational Availability'),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.lg),
                _Section(
                  title: 'Variants (${product.variants.length})',
                  child: product.variants.isEmpty
                      ? const Text('No variants returned for this product.')
                      : Column(
                          children: product.variants
                              .map(_VariantCard.new)
                              .toList(growable: false),
                        ),
                ),
                const SizedBox(height: AppSpacing.lg),
                _Section(
                  title: 'Modifier Groups (${product.modifierGroups.length})',
                  child: product.modifierGroups.isEmpty
                      ? const Text(
                          'No modifier groups are assigned to this product.',
                        )
                      : Column(
                          children: product.modifierGroups
                              .map(_ModifierCard.new)
                              .toList(growable: false),
                        ),
                ),
              ],
            ),
          ),
        );
      },
    ),
  );
}

class _LifecycleButton extends StatelessWidget {
  const _LifecycleButton({required this.product});
  final ProductDetail product;

  @override
  Widget build(BuildContext context) {
    final bool busy = context.select<ProductLifecycleCubit, bool>(
      (cubit) => cubit.state.isSubmittingFor(product.id),
    );
    final bool archive = !product.isArchived;
    return archive
        ? OutlinedButton.icon(
            key: const Key('archive-product-action'),
            style: OutlinedButton.styleFrom(
              foregroundColor: Theme.of(context).colorScheme.error,
            ),
            onPressed: busy ? null : () => _confirm(context, archive: true),
            icon: busy
                ? const SizedBox.square(
                    dimension: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.archive_outlined),
            label: const Text('Archive Product'),
          )
        : FilledButton.icon(
            key: const Key('restore-product-action'),
            onPressed: busy ? null : () => _confirm(context, archive: false),
            icon: busy
                ? const SizedBox.square(
                    dimension: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.restore),
            label: const Text('Restore Product'),
          );
  }

  Future<void> _confirm(BuildContext context, {required bool archive}) async {
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (dialog) => AlertDialog(
        title: Text(archive ? 'Archive Product?' : 'Restore Product?'),
        content: Text(
          archive
              ? 'This Product will no longer be available for new Menu configuration or normal Catalog use. Existing Orders and published historical Versions will not be changed.\n\nThe Product is not permanently deleted. Central Modifier Groups are not deleted, and Variants remain stored according to Backend behavior.'
              : 'This restores the Product to the editable Catalog. Its availability in Menus still depends on Menu assignments, schedules, operational status, validation, and publishing.',
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.pop(dialog, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: archive
                ? FilledButton.styleFrom(
                    backgroundColor: Theme.of(dialog).colorScheme.error,
                  )
                : null,
            onPressed: () => Navigator.pop(dialog, true),
            child: Text(archive ? 'Archive Product' : 'Restore Product'),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;
    if (archive) {
      await context.read<ProductLifecycleCubit>().archive(product.id);
    } else {
      await context.read<ProductLifecycleCubit>().restore(product.id);
    }
  }
}

class _Section extends StatelessWidget {
  const _Section({required this.title, required this.child});
  final String title;
  final Widget child;
  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: AppSpacing.allLg,
    decoration: BoxDecoration(
      color: AppColors.surface,
      border: Border.all(color: AppColors.border),
      borderRadius: BorderRadius.circular(12),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(title, style: AppTextStyles.titleMedium),
        const SizedBox(height: AppSpacing.md),
        child,
      ],
    ),
  );
}

class _Field extends StatelessWidget {
  const _Field(this.label, this.value);
  final String label;
  final String value;
  @override
  Widget build(BuildContext context) => SizedBox(
    width: 220,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          label,
          style: AppTextStyles.labelSmall.copyWith(color: AppColors.textMuted),
        ),
        Text(value, style: AppTextStyles.bodyMedium),
      ],
    ),
  );
}

class _VariantCard extends StatelessWidget {
  const _VariantCard(this.variant);
  final ProductVariant variant;
  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: AppSpacing.allMd,
      child: Wrap(
        spacing: 28,
        runSpacing: AppSpacing.sm,
        children: <Widget>[
          _Field('Name', variant.name),
          _Field('SKU', variant.sku ?? '—'),
          _Field('Barcode', variant.barcode ?? '—'),
          _Field('Base price', catalogMoney(variant.basePrice)),
          _Field(
            'Cost price',
            variant.costPrice == null ? '—' : catalogMoney(variant.costPrice!),
          ),
          _Field('Default', booleanLabel(variant.isDefault)),
          _Field('Active', booleanLabel(variant.isActive)),
        ],
      ),
    ),
  );
}

class _ModifierCard extends StatelessWidget {
  const _ModifierCard(this.group);
  final ModifierGroup group;
  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: AppSpacing.allMd,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(group.name, style: AppTextStyles.titleMedium),
          const SizedBox(height: AppSpacing.sm),
          Wrap(
            spacing: 28,
            runSpacing: AppSpacing.sm,
            children: <Widget>[
              _Field('Group type', group.groupType),
              _Field('Selection type', group.selectionType),
              _Field('Required', booleanLabel(group.effectiveRequired)),
              _Field('Minimum', '${group.effectiveMinimum}'),
              _Field('Maximum', '${group.effectiveMaximum}'),
              _Field(
                'Allow quantity',
                booleanLabel(group.effectiveAllowQuantity),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          Text('Options', style: AppTextStyles.labelLarge),
          if (group.options.isEmpty)
            const Text('No options returned.')
          else
            ...group.options.map(
              (option) => ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(option.name),
                subtitle: Text(
                  'Price delta: ${catalogMoney(option.priceDelta)} · Available: ${booleanLabel(option.isAvailable)} · Active: ${booleanLabel(option.isActive)}',
                ),
              ),
            ),
        ],
      ),
    ),
  );
}

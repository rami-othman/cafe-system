import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../shared/layouts/desktop_page_layout.dart';
import '../controllers/product_catalog_cubit.dart';
import '../controllers/product_catalog_state.dart';
import '../models/catalog_models.dart';
import '../models/product_catalog_filter.dart';
import '../widgets/catalog_formatters.dart';

class ProductCatalogScreen extends StatefulWidget {
  const ProductCatalogScreen({super.key});
  @override
  State<ProductCatalogScreen> createState() => _ProductCatalogScreenState();
}

class _ProductCatalogScreenState extends State<ProductCatalogScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => context.read<ProductCatalogCubit>().loadInitialData(),
    );
  }

  @override
  Widget build(
    BuildContext context,
  ) => BlocBuilder<ProductCatalogCubit, ProductCatalogState>(
    builder: (BuildContext context, ProductCatalogState state) {
      final ProductCatalogCubit cubit = context.read<ProductCatalogCubit>();
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
              Row(
                children: <Widget>[
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          'Menu Management',
                          style: AppTextStyles.headlineMedium.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: AppSpacing.xs),
                        Text(
                          'Products',
                          style: AppTextStyles.titleLarge.copyWith(
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  FilledButton.icon(
                    key: const Key('create-product-action'),
                    onPressed: () =>
                        context.go('/menu-management/products/create'),
                    icon: const Icon(Icons.add),
                    label: const Text('Create Product'),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  IconButton(
                    tooltip: 'Refresh products',
                    onPressed: state.isLoading || state.isRefreshing
                        ? null
                        : cubit.refresh,
                    icon: const Icon(Icons.refresh),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.lg),
              _Filters(
                state: state,
                onSearch: cubit.updateSearch,
                onChanged: cubit.updateFilter,
                onClear: cubit.clearFilters,
              ),
              if (state.referenceErrors.isNotEmpty) ...<Widget>[
                const SizedBox(height: AppSpacing.md),
                _ReferenceWarning(errors: state.referenceErrors),
              ],
              const SizedBox(height: AppSpacing.lg),
              Text(
                '${state.pagination.total} product${state.pagination.total == 1 ? '' : 's'}',
                style: AppTextStyles.bodyMedium.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              if (state.isLoading && state.products.isEmpty)
                const SizedBox(
                  height: 280,
                  child: Center(child: CircularProgressIndicator()),
                )
              else if (state.status == ProductCatalogLoadStatus.failure &&
                  state.products.isEmpty)
                _ErrorPanel(
                  message: state.errorMessage ?? 'Unable to load products.',
                  onRetry: cubit.loadProducts,
                )
              else if (state.products.isEmpty)
                _EmptyPanel(
                  hasFilters: state.filter.hasActiveFilters,
                  onClear: cubit.clearFilters,
                )
              else ...<Widget>[
                _ProductList(products: state.products),
                if (state.status == ProductCatalogLoadStatus.failure)
                  Padding(
                    padding: const EdgeInsets.only(top: AppSpacing.md),
                    child: _ErrorPanel(
                      message:
                          state.errorMessage ?? 'Unable to load more products.',
                      onRetry: cubit.loadNextPage,
                    ),
                  ),
                if (state.hasMorePages)
                  Padding(
                    padding: const EdgeInsets.only(top: AppSpacing.lg),
                    child: Center(
                      child: OutlinedButton.icon(
                        onPressed: state.isLoadingNextPage
                            ? null
                            : cubit.loadNextPage,
                        icon: state.isLoadingNextPage
                            ? const SizedBox.square(
                                dimension: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Icon(Icons.expand_more),
                        label: Text(
                          state.isLoadingNextPage
                              ? 'Loading...'
                              : 'Load more products',
                        ),
                      ),
                    ),
                  ),
              ],
            ],
          ),
        ),
      );
    },
  );
}

class _Filters extends StatelessWidget {
  const _Filters({
    required this.state,
    required this.onSearch,
    required this.onChanged,
    required this.onClear,
  });
  final ProductCatalogState state;
  final ValueChanged<String> onSearch;
  final ValueChanged<ProductCatalogFilter> onChanged;
  final VoidCallback onClear;
  @override
  Widget build(BuildContext context) {
    final ProductCatalogFilter filter = state.filter;
    return Container(
      padding: AppSpacing.allMd,
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border.all(color: AppColors.border),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          TextField(
            key: const Key('product-catalog-search'),
            onChanged: onSearch,
            decoration: const InputDecoration(
              prefixIcon: Icon(Icons.search),
              hintText: 'Search products, SKU, or barcode',
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          Wrap(
            spacing: AppSpacing.md,
            runSpacing: AppSpacing.md,
            children: <Widget>[
              _drop<int>(
                'Category',
                filter.categoryId,
                state.categories
                    .map(
                      (item) => DropdownMenuItem<int>(
                        value: item.id,
                        child: Text(item.name),
                      ),
                    )
                    .toList(),
                (value) => onChanged(
                  filter.copyWith(
                    categoryId: value,
                    clearCategory: value == null,
                  ),
                ),
              ),
              _drop<int>(
                'Reporting Category',
                filter.reportingCategoryId,
                state.reportingCategories
                    .map(
                      (item) => DropdownMenuItem<int>(
                        value: item.id,
                        child: Text(item.name),
                      ),
                    )
                    .toList(),
                (value) => onChanged(
                  filter.copyWith(
                    reportingCategoryId: value,
                    clearReportingCategory: value == null,
                  ),
                ),
              ),
              _drop<int>(
                'Kitchen Station',
                filter.kitchenStationId,
                state.kitchenStations
                    .map(
                      (item) => DropdownMenuItem<int>(
                        value: item.id,
                        child: Text(item.name),
                      ),
                    )
                    .toList(),
                (value) => onChanged(
                  filter.copyWith(
                    kitchenStationId: value,
                    clearKitchenStation: value == null,
                  ),
                ),
              ),
              _drop<String>(
                'Product Type',
                filter.productType,
                const <DropdownMenuItem<String>>[
                  DropdownMenuItem(value: 'standard', child: Text('Standard')),
                  DropdownMenuItem(
                    value: 'open_price',
                    child: Text('Open price'),
                  ),
                  DropdownMenuItem(value: 'combo', child: Text('Combo')),
                ],
                (value) => onChanged(
                  filter.copyWith(
                    productType: value,
                    clearProductType: value == null,
                  ),
                ),
              ),
              _drop<String>(
                'Status',
                filter.status,
                const <DropdownMenuItem<String>>[
                  DropdownMenuItem(value: 'active', child: Text('Active')),
                  DropdownMenuItem(value: 'archived', child: Text('Archived')),
                  DropdownMenuItem(value: 'all', child: Text('All')),
                ],
                (value) =>
                    onChanged(filter.copyWith(status: value ?? 'active')),
              ),
              _drop<bool>(
                'Has Variants',
                filter.hasVariants,
                const <DropdownMenuItem<bool>>[
                  DropdownMenuItem(value: true, child: Text('Yes')),
                  DropdownMenuItem(value: false, child: Text('No')),
                ],
                (value) => onChanged(
                  filter.copyWith(
                    hasVariants: value,
                    clearHasVariants: value == null,
                  ),
                ),
              ),
              _drop<bool>(
                'Has Modifier Groups',
                filter.hasModifierGroups,
                const <DropdownMenuItem<bool>>[
                  DropdownMenuItem(value: true, child: Text('Yes')),
                  DropdownMenuItem(value: false, child: Text('No')),
                ],
                (value) => onChanged(
                  filter.copyWith(
                    hasModifierGroups: value,
                    clearHasModifierGroups: value == null,
                  ),
                ),
              ),
              _drop<String>(
                'Sort',
                '${filter.sort}:${filter.direction}',
                const <DropdownMenuItem<String>>[
                  DropdownMenuItem(
                    value: 'sort_order:asc',
                    child: Text('Sort order'),
                  ),
                  DropdownMenuItem(value: 'name:asc', child: Text('Name A–Z')),
                  DropdownMenuItem(value: 'name:desc', child: Text('Name Z–A')),
                  DropdownMenuItem(
                    value: 'created_at:desc',
                    child: Text('Newest first'),
                  ),
                ],
                (value) {
                  final List<String> parts = (value ?? 'sort_order:asc').split(
                    ':',
                  );
                  onChanged(
                    filter.copyWith(sort: parts[0], direction: parts[1]),
                  );
                },
              ),
            ],
          ),
          if (filter.hasActiveFilters)
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: onClear,
                child: const Text('Clear Filters'),
              ),
            ),
        ],
      ),
    );
  }

  Widget _drop<T>(
    String label,
    T? value,
    List<DropdownMenuItem<T>> items,
    ValueChanged<T?> onChanged,
  ) => SizedBox(
    width: 205,
    child: DropdownButtonFormField<T>(
      key: ValueKey<T?>(value),
      initialValue: value,
      isExpanded: true,
      decoration: InputDecoration(labelText: label),
      hint: const Text('All'),
      items: items,
      onChanged: onChanged,
    ),
  );
}

class _ProductList extends StatelessWidget {
  const _ProductList({required this.products});
  final List<ProductSummary> products;
  @override
  Widget build(BuildContext context) => Container(
    decoration: BoxDecoration(
      color: AppColors.surface,
      border: Border.all(color: AppColors.border),
      borderRadius: BorderRadius.circular(12),
    ),
    child: Column(
      children: products
          .map((product) => _ProductRow(product: product))
          .toList(growable: false),
    ),
  );
}

class _ProductRow extends StatelessWidget {
  const _ProductRow({required this.product});
  final ProductSummary product;
  @override
  Widget build(BuildContext context) => InkWell(
    onTap: () => context.go('/menu-management/products/${product.id}'),
    child: Padding(
      padding: AppSpacing.allMd,
      child: Row(
        children: <Widget>[
          CatalogProductImage(url: product.imageUrl),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            flex: 3,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(product.name, style: AppTextStyles.titleMedium),
                if (product.category != null)
                  Text(
                    product.category!.name,
                    style: AppTextStyles.bodySmall.copyWith(
                      color: AppColors.textMuted,
                    ),
                  ),
              ],
            ),
          ),
          Expanded(
            child: _Metric(
              label: 'Default',
              value: product.defaultVariant?.name ?? '—',
            ),
          ),
          Expanded(
            child: _Metric(
              label: 'Price',
              value: product.defaultVariant == null
                  ? '—'
                  : catalogMoney(product.defaultVariant!.basePrice),
            ),
          ),
          Expanded(
            child: _Metric(label: 'Variants', value: '${product.variantCount}'),
          ),
          Expanded(
            child: _Metric(
              label: 'Modifiers',
              value: '${product.modifierGroupCount}',
            ),
          ),
          Expanded(
            child: _Metric(
              label: 'Station',
              value: product.kitchenStation?.name ?? '—',
            ),
          ),
          SizedBox(
            width: 92,
            child: CatalogProductStatus(active: product.isActive),
          ),
        ],
      ),
    ),
  );
}

class _Metric extends StatelessWidget {
  const _Metric({required this.label, required this.value});
  final String label;
  final String value;
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: <Widget>[
      Text(
        label,
        style: AppTextStyles.labelSmall.copyWith(color: AppColors.textMuted),
      ),
      Text(
        value,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: AppTextStyles.bodySmall,
      ),
    ],
  );
}

class CatalogProductImage extends StatelessWidget {
  const CatalogProductImage({super.key, this.url});
  final String? url;
  @override
  Widget build(BuildContext context) => ClipRRect(
    borderRadius: BorderRadius.circular(8),
    child: SizedBox(
      width: 48,
      height: 48,
      child: url == null
          ? const ColoredBox(
              color: AppColors.productVisualBackground,
              child: Icon(Icons.restaurant_outlined),
            )
          : Image.network(
              url!,
              fit: BoxFit.cover,
              errorBuilder: (_, _, _) => const ColoredBox(
                color: AppColors.productVisualBackground,
                child: Icon(Icons.restaurant_outlined),
              ),
            ),
    ),
  );
}

class CatalogProductStatus extends StatelessWidget {
  const CatalogProductStatus({super.key, required this.active});
  final bool active;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
    decoration: BoxDecoration(
      color: active ? AppColors.discountGreenBadge : AppColors.surfaceAlt,
      borderRadius: BorderRadius.circular(20),
    ),
    child: Text(
      active ? 'Active' : 'Archived',
      textAlign: TextAlign.center,
      style: AppTextStyles.labelSmall.copyWith(
        color: active ? AppColors.success : AppColors.textMuted,
      ),
    ),
  );
}

class _EmptyPanel extends StatelessWidget {
  const _EmptyPanel({required this.hasFilters, required this.onClear});
  final bool hasFilters;
  final VoidCallback onClear;
  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(48),
      child: Column(
        children: <Widget>[
          Text(
            hasFilters
                ? 'No products match the current filters.'
                : 'No products have been created yet.',
            style: AppTextStyles.titleMedium,
          ),
          if (hasFilters)
            TextButton(onPressed: onClear, child: const Text('Clear Filters')),
        ],
      ),
    ),
  );
}

class _ErrorPanel extends StatelessWidget {
  const _ErrorPanel({required this.message, required this.onRetry});
  final String message;
  final VoidCallback onRetry;
  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: AppSpacing.allLg,
    color: AppColors.surfaceAlt,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(message),
        const SizedBox(height: AppSpacing.sm),
        OutlinedButton(onPressed: onRetry, child: const Text('Retry')),
      ],
    ),
  );
}

class _ReferenceWarning extends StatelessWidget {
  const _ReferenceWarning({required this.errors});
  final Map<String, String> errors;
  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: AppSpacing.allMd,
    color: AppColors.discountOrangeBadge,
    child: Text('Some filters could not be loaded: ${errors.keys.join(', ')}.'),
  );
}

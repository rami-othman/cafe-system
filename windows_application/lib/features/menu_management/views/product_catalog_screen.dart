import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../app/localization/localization_extensions.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../shared/layouts/desktop_page_layout.dart';
import '../controllers/product_catalog_cubit.dart';
import '../controllers/product_catalog_state.dart';
import '../controllers/product_lifecycle_cubit.dart';
import '../models/catalog_models.dart';
import '../models/product_catalog_filter.dart';
import '../widgets/catalog_formatters.dart';
import '../widgets/menu_context_and_filters.dart';
import '../widgets/menu_page_header.dart';

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
  ) => BlocListener<ProductLifecycleCubit, ProductLifecycleState>(
    listenWhen: (previous, current) =>
        previous.status != current.status &&
        (current.status == ProductLifecycleStatus.success ||
            current.status == ProductLifecycleStatus.failure),
    listener: (context, lifecycle) async {
      if (lifecycle.status == ProductLifecycleStatus.success) {
        await context.read<ProductCatalogCubit>().refresh();
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
    child: BlocBuilder<ProductCatalogCubit, ProductCatalogState>(
      builder: (BuildContext context, ProductCatalogState state) {
        final ProductCatalogCubit cubit = context.read<ProductCatalogCubit>();
        final _ProductCatalogCopy copy = _ProductCatalogCopy.of(context);
        return DesktopPageLayout(
          padding: EdgeInsets.zero,
          child: SingleChildScrollView(
            padding: const EdgeInsetsDirectional.fromSTEB(
              AppSpacing.xl,
              AppSpacing.xl,
              AppSpacing.xl,
              96,
            ),
            child: Align(
              alignment: AlignmentDirectional.topCenter,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 1500),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    MenuPageHeader(
                      title: copy.title,
                      subtitle: copy.subtitle,
                      primaryAction: FilledButton.icon(
                        key: const Key('create-product-action'),
                        onPressed: () =>
                            context.go('/menu-management/products/create'),
                        icon: const Icon(Icons.add),
                        label: Text(copy.createProduct),
                      ),
                      secondaryActions: <Widget>[
                        IconButton(
                          tooltip: copy.refreshProducts,
                          onPressed: state.isLoading || state.isRefreshing
                              ? null
                              : cubit.refresh,
                          icon: const Icon(Icons.refresh),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.xl),
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
                      copy.productCount(state.pagination.total),
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
                        message:
                            state.errorMessage ?? copy.unableToLoadProducts,
                        onRetry: cubit.loadProducts,
                      )
                    else if (state.products.isEmpty)
                      _EmptyPanel(
                        filter: state.filter,
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
                                state.errorMessage ?? copy.unableToLoadProducts,
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
                                    ? copy.loading
                                    : copy.loadMoreProducts,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        );
      },
    ),
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
    final _ProductCatalogCopy copy = _ProductCatalogCopy.of(context);
    final List<ActiveMenuFilter> activeFilters = _activeFilters(filter, copy);
    final int advancedCount = _advancedFilterCount(filter);
    return CompactFilterBar(
      searchFieldKey: const Key('product-catalog-search'),
      searchLabel: copy.search,
      onSearchChanged: onSearch,
      quickFilters: <Widget>[
        Semantics(
          label: copy.lifecycle,
          child: SegmentedButton<String>(
            segments: <ButtonSegment<String>>[
              ButtonSegment(value: 'active', label: Text(copy.active)),
              ButtonSegment(value: 'inactive', label: Text(copy.inactive)),
              ButtonSegment(value: 'archived', label: Text(copy.archived)),
              ButtonSegment(value: 'all', label: Text(copy.all)),
            ],
            selected: <String>{filter.status},
            onSelectionChanged: (values) =>
                onChanged(filter.copyWith(status: values.first)),
            showSelectedIcon: false,
          ),
        ),
      ],
      activeFilters: activeFilters,
      onClearAll: onClear,
      clearAllLabel: copy.clearAll,
      onMoreFilters: () => _showAdvancedFilters(
        context,
        filter: filter,
        state: state,
        onApply: onChanged,
      ),
      moreFiltersLabel: advancedCount == 0
          ? copy.moreFilters
          : '${copy.moreFilters} ($advancedCount)',
      moreFiltersSemanticLabel: copy.moreFiltersSemantic(advancedCount),
      sortTooltip: copy.sort,
      sortAction: PopupMenuButton<String>(
        key: const Key('product-catalog-sort'),
        tooltip: copy.sort,
        onSelected: (value) {
          final List<String> parts = value.split(':');
          onChanged(filter.copyWith(sort: parts[0], direction: parts[1]));
        },
        itemBuilder: (context) => <PopupMenuEntry<String>>[
          PopupMenuItem(value: 'sort_order:asc', child: Text(copy.sortOrder)),
          PopupMenuItem(value: 'name:asc', child: Text(copy.nameAscending)),
          PopupMenuItem(value: 'name:desc', child: Text(copy.nameDescending)),
          PopupMenuItem(value: 'created_at:desc', child: Text(copy.newest)),
        ],
        child: Container(
          height: 44,
          padding: const EdgeInsetsDirectional.symmetric(
            horizontal: AppSpacing.md,
          ),
          decoration: BoxDecoration(
            border: Border.all(color: AppColors.border),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              const Icon(Icons.sort, size: 18),
              const SizedBox(width: AppSpacing.xs),
              Text(_sortAffordance(filter, copy)),
            ],
          ),
        ),
      ),
    );
  }

  List<ActiveMenuFilter> _activeFilters(
    ProductCatalogFilter filter,
    _ProductCatalogCopy copy,
  ) {
    final List<ActiveMenuFilter> result = <ActiveMenuFilter>[];
    if (filter.search.isNotEmpty) {
      result.add(
        ActiveMenuFilter(
          label: '${copy.search}: ${filter.search}',
          onRemove: () => onSearch(''),
        ),
      );
    }
    if (filter.status != 'active') {
      result.add(
        ActiveMenuFilter(
          label: filter.status == 'archived' ? copy.archived : copy.allProducts,
          onRemove: () => onChanged(filter.copyWith(status: 'active')),
        ),
      );
    }
    if (filter.categoryId != null) {
      result.add(
        ActiveMenuFilter(
          label: _categoryName(filter.categoryId) ?? copy.category,
          onRemove: () => onChanged(filter.copyWith(clearCategory: true)),
        ),
      );
    }
    if (filter.reportingCategoryId != null) {
      result.add(
        ActiveMenuFilter(
          label:
              '${copy.reportingCategory}: ${_reportingName(filter.reportingCategoryId) ?? '—'}',
          onRemove: () =>
              onChanged(filter.copyWith(clearReportingCategory: true)),
        ),
      );
    }
    if (filter.kitchenStationId != null) {
      result.add(
        ActiveMenuFilter(
          label:
              '${copy.kitchenStation}: ${_stationName(filter.kitchenStationId) ?? '—'}',
          onRemove: () => onChanged(filter.copyWith(clearKitchenStation: true)),
        ),
      );
    }
    if (filter.productType != null) {
      result.add(
        ActiveMenuFilter(
          label:
              '${copy.productType}: ${_productTypeLabel(filter.productType!, copy)}',
          onRemove: () => onChanged(filter.copyWith(clearProductType: true)),
        ),
      );
    }
    if (filter.hasVariants != null) {
      result.add(
        ActiveMenuFilter(
          label: filter.hasVariants! ? copy.hasVariants : copy.noVariants,
          onRemove: () => onChanged(filter.copyWith(clearHasVariants: true)),
        ),
      );
    }
    if (filter.hasModifierGroups != null) {
      result.add(
        ActiveMenuFilter(
          label: filter.hasModifierGroups!
              ? copy.hasModifiers
              : copy.noModifiers,
          onRemove: () =>
              onChanged(filter.copyWith(clearHasModifierGroups: true)),
        ),
      );
    }
    if (filter.sort != 'sort_order' || filter.direction != 'asc') {
      result.add(
        ActiveMenuFilter(
          label: '${copy.sort}: ${_sortLabel(filter, copy)}',
          onRemove: () =>
              onChanged(filter.copyWith(sort: 'sort_order', direction: 'asc')),
        ),
      );
    }
    return result;
  }

  String? _categoryName(int? id) {
    for (final CatalogCategory item in state.categories) {
      if (item.id == id) return item.name;
    }
    return null;
  }

  String? _reportingName(int? id) {
    for (final ReportingCategory item in state.reportingCategories) {
      if (item.id == id) return item.name;
    }
    return null;
  }

  String? _stationName(int? id) {
    for (final KitchenStation item in state.kitchenStations) {
      if (item.id == id) return item.name;
    }
    return null;
  }
}

int _advancedFilterCount(ProductCatalogFilter filter) => <Object?>[
  filter.categoryId,
  filter.reportingCategoryId,
  filter.kitchenStationId,
  filter.productType,
  filter.hasVariants,
  filter.hasModifierGroups,
].where((item) => item != null).length;

Future<void> _showAdvancedFilters(
  BuildContext context, {
  required ProductCatalogFilter filter,
  required ProductCatalogState state,
  required ValueChanged<ProductCatalogFilter> onApply,
}) async {
  ProductCatalogFilter draft = filter;
  final _ProductCatalogCopy copy = _ProductCatalogCopy.of(context);
  await showDialog<void>(
    context: context,
    builder: (dialogContext) => StatefulBuilder(
      builder: (context, setDialogState) => AlertDialog(
        title: Text(copy.moreFilters),
        content: SizedBox(
          width: 720,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Text(
                  copy.moreFiltersHelper,
                  style: AppTextStyles.bodyMedium.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: AppSpacing.lg),
                _AdvancedFilterSection(
                  title: copy.filterClassification,
                  child: _AdvancedFilterPair(
                    first: _AdvancedDropdown<int>(
                      key: const Key('product-filter-category'),
                      label: copy.category,
                      value: draft.categoryId,
                      items: state.categories
                          .map(
                            (item) => DropdownMenuItem<int>(
                              value: item.id,
                              child: Text(item.name),
                            ),
                          )
                          .toList(),
                      onChanged: (value) => setDialogState(
                        () => draft = draft.copyWith(
                          categoryId: value,
                          clearCategory: value == null,
                        ),
                      ),
                    ),
                    second: _AdvancedDropdown<int>(
                      key: const Key('product-filter-reporting-category'),
                      label: copy.reportingCategory,
                      value: draft.reportingCategoryId,
                      items: state.reportingCategories
                          .map(
                            (item) => DropdownMenuItem<int>(
                              value: item.id,
                              child: Text(item.name),
                            ),
                          )
                          .toList(),
                      onChanged: (value) => setDialogState(
                        () => draft = draft.copyWith(
                          reportingCategoryId: value,
                          clearReportingCategory: value == null,
                        ),
                      ),
                    ),
                  ),
                ),
                _AdvancedFilterSection(
                  title: copy.filterPreparation,
                  child: _AdvancedFilterPair(
                    first: _AdvancedDropdown<int>(
                      key: const Key('product-filter-kitchen-station'),
                      label: copy.kitchenStation,
                      value: draft.kitchenStationId,
                      items: state.kitchenStations
                          .map(
                            (item) => DropdownMenuItem<int>(
                              value: item.id,
                              child: Text(item.name),
                            ),
                          )
                          .toList(),
                      onChanged: (value) => setDialogState(
                        () => draft = draft.copyWith(
                          kitchenStationId: value,
                          clearKitchenStation: value == null,
                        ),
                      ),
                    ),
                    second: _AdvancedDropdown<String>(
                      key: const Key('product-filter-type'),
                      label: copy.productType,
                      value: draft.productType,
                      items: <DropdownMenuItem<String>>[
                        DropdownMenuItem(
                          value: 'standard',
                          child: Text(copy.standard),
                        ),
                        DropdownMenuItem(
                          value: 'open_price',
                          child: Text(copy.openPrice),
                        ),
                        DropdownMenuItem(
                          value: 'combo',
                          child: Text(copy.combo),
                        ),
                      ],
                      onChanged: (value) => setDialogState(
                        () => draft = draft.copyWith(
                          productType: value,
                          clearProductType: value == null,
                        ),
                      ),
                    ),
                  ),
                ),
                _AdvancedFilterSection(
                  title: copy.filterProductSetup,
                  child: _AdvancedFilterPair(
                    first: _AdvancedDropdown<bool>(
                      key: const Key('product-filter-variants'),
                      label: copy.hasVariants,
                      value: draft.hasVariants,
                      items: <DropdownMenuItem<bool>>[
                        DropdownMenuItem(value: true, child: Text(copy.yes)),
                        DropdownMenuItem(value: false, child: Text(copy.no)),
                      ],
                      onChanged: (value) => setDialogState(
                        () => draft = draft.copyWith(
                          hasVariants: value,
                          clearHasVariants: value == null,
                        ),
                      ),
                    ),
                    second: _AdvancedDropdown<bool>(
                      key: const Key('product-filter-modifiers'),
                      label: copy.hasModifiers,
                      value: draft.hasModifierGroups,
                      items: <DropdownMenuItem<bool>>[
                        DropdownMenuItem(value: true, child: Text(copy.yes)),
                        DropdownMenuItem(value: false, child: Text(copy.no)),
                      ],
                      onChanged: (value) => setDialogState(
                        () => draft = draft.copyWith(
                          hasModifierGroups: value,
                          clearHasModifierGroups: value == null,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        actions: <Widget>[
          Semantics(
            label: copy.clearFilters,
            button: true,
            child: TextButton(
              onPressed: () => setDialogState(
                () => draft = draft.copyWith(
                  clearCategory: true,
                  clearReportingCategory: true,
                  clearKitchenStation: true,
                  clearProductType: true,
                  clearHasVariants: true,
                  clearHasModifierGroups: true,
                ),
              ),
              child: Text(copy.clearFilters),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: Text(copy.cancel),
          ),
          FilledButton(
            key: const Key('product-filters-apply'),
            onPressed: () {
              Navigator.pop(dialogContext);
              onApply(draft);
            },
            child: Text(copy.applyFilters),
          ),
        ],
      ),
    ),
  );
}

class _AdvancedDropdown<T> extends StatelessWidget {
  const _AdvancedDropdown({
    super.key,
    required this.label,
    required this.value,
    required this.items,
    required this.onChanged,
  });
  final String label;
  final T? value;
  final List<DropdownMenuItem<T>> items;
  final ValueChanged<T?> onChanged;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: AppSpacing.md),
    child: DropdownButtonFormField<T>(
      key: ValueKey<T?>(value),
      initialValue: value,
      isExpanded: true,
      decoration: InputDecoration(labelText: label),
      hint: Text(_ProductCatalogCopy.of(context).all),
      items: items,
      onChanged: onChanged,
    ),
  );
}

class _AdvancedFilterSection extends StatelessWidget {
  const _AdvancedFilterSection({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: AppSpacing.md),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Semantics(
          header: true,
          child: Text(title, style: AppTextStyles.labelLarge),
        ),
        const SizedBox(height: AppSpacing.sm),
        child,
      ],
    ),
  );
}

class _AdvancedFilterPair extends StatelessWidget {
  const _AdvancedFilterPair({required this.first, required this.second});

  final Widget first;
  final Widget second;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      if (constraints.maxWidth < 540) {
        return Column(children: <Widget>[first, second]);
      }
      return Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Expanded(child: first),
          const SizedBox(width: AppSpacing.lg),
          Expanded(child: second),
        ],
      );
    },
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
      children: <Widget>[
        for (int index = 0; index < products.length; index++) ...<Widget>[
          _ProductRow(product: products[index]),
          if (index < products.length - 1)
            const Divider(height: 1, color: AppColors.divider),
        ],
      ],
    ),
  );
}

class _ProductRow extends StatelessWidget {
  const _ProductRow({required this.product});
  final ProductSummary product;

  @override
  Widget build(BuildContext context) {
    final _ProductCatalogCopy copy = _ProductCatalogCopy.of(context);
    final String name = product.displayName(Localizations.localeOf(context));
    final String setupSummary = copy.setupSummary(
      product.variantCount,
      product.modifierGroupCount,
    );
    final String category = product.category?.name ?? '';
    final String businessSummary = <String>[
      setupSummary,
      if (product.kitchenStation != null) product.kitchenStation!.name,
    ].join(' · ');
    return LayoutBuilder(
      builder: (context, constraints) {
        final bool stacked = constraints.maxWidth < 760;
        final Widget identity = Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppTextStyles.titleMedium,
              ),
              if (category.isNotEmpty) ...<Widget>[
                const SizedBox(height: AppSpacing.xs),
                Text(
                  category,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.bodySmall.copyWith(
                    color: AppColors.textMuted,
                  ),
                ),
              ],
            ],
          ),
        );
        final Widget price = _ProductPrice(
          label: copy.basePrice,
          value: product.defaultVariant == null
              ? '—'
              : catalogMoney(product.defaultVariant!.basePrice),
        );
        final Widget summary = _ProductBusinessSummary(value: businessSummary);
        final Widget endControls = Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            _CatalogStatusBadge(product: product),
            const SizedBox(width: AppSpacing.xs),
            _ProductActions(product: product),
          ],
        );
        return Semantics(
          button: true,
          label:
              '$name, ${product.isArchived
                  ? copy.archived
                  : product.isInactive
                  ? copy.inactive
                  : copy.active}',
          child: Material(
            color: AppColors.surface,
            child: InkWell(
              key: Key('product-row-${product.id}'),
              onTap: () =>
                  context.go('/menu-management/products/${product.id}'),
              child: Padding(
                padding: AppSpacing.allLg,
                child: stacked
                    ? Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: <Widget>[
                              CatalogProductImage(url: product.imageUrl),
                              const SizedBox(width: AppSpacing.md),
                              identity,
                              const SizedBox(width: AppSpacing.sm),
                              endControls,
                            ],
                          ),
                          const SizedBox(height: AppSpacing.md),
                          Wrap(
                            spacing: AppSpacing.xl,
                            runSpacing: AppSpacing.sm,
                            children: <Widget>[price, summary],
                          ),
                        ],
                      )
                    : Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: <Widget>[
                          CatalogProductImage(url: product.imageUrl),
                          const SizedBox(width: AppSpacing.md),
                          identity,
                          const SizedBox(width: AppSpacing.xl),
                          price,
                          const SizedBox(width: AppSpacing.xl),
                          Flexible(child: summary),
                          const SizedBox(width: AppSpacing.lg),
                          endControls,
                        ],
                      ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _ProductPrice extends StatelessWidget {
  const _ProductPrice({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => ConstrainedBox(
    constraints: const BoxConstraints(minWidth: 88, maxWidth: 104),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Text(
          value,
          textDirection: TextDirection.ltr,
          style: AppTextStyles.titleMedium,
        ),
        const SizedBox(height: AppSpacing.xs),
        Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: AppTextStyles.labelSmall.copyWith(color: AppColors.textMuted),
        ),
      ],
    ),
  );
}

class _ProductBusinessSummary extends StatelessWidget {
  const _ProductBusinessSummary({required this.value});

  final String value;

  @override
  Widget build(BuildContext context) => ConstrainedBox(
    constraints: const BoxConstraints(maxWidth: 270),
    child: Text(
      value,
      maxLines: 2,
      overflow: TextOverflow.ellipsis,
      style: AppTextStyles.bodyMedium.copyWith(color: AppColors.textSecondary),
    ),
  );
}

String _productTypeLabel(String value, _ProductCatalogCopy copy) =>
    switch (value) {
      'open_price' => copy.openPrice,
      'combo' => copy.combo,
      _ => copy.standard,
    };

String _sortLabel(ProductCatalogFilter filter, _ProductCatalogCopy copy) =>
    switch ('${filter.sort}:${filter.direction}') {
      'name:asc' => copy.nameAscending,
      'name:desc' => copy.nameDescending,
      'created_at:desc' => copy.newest,
      _ => copy.sortOrder,
    };

String _sortAffordance(ProductCatalogFilter filter, _ProductCatalogCopy copy) =>
    filter.sort == 'sort_order' && filter.direction == 'asc'
    ? copy.sort
    : '${copy.sort}: ${_sortLabel(filter, copy)}';

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
  const CatalogProductStatus({super.key, required this.product});
  final ProductSummary product;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
    decoration: BoxDecoration(
      color: product.isArchived
          ? AppColors.discountOrangeBadge
          : product.isActive
          ? AppColors.discountGreenBadge
          : AppColors.surfaceAlt,
      borderRadius: BorderRadius.circular(20),
    ),
    child: Text(
      product.isArchived
          ? 'Archived'
          : product.isActive
          ? 'Active'
          : 'Inactive',
      textAlign: TextAlign.center,
      style: AppTextStyles.labelSmall.copyWith(
        color: product.isActive && !product.isArchived
            ? AppColors.success
            : AppColors.textMuted,
      ),
    ),
  );
}

class _CatalogStatusBadge extends StatelessWidget {
  const _CatalogStatusBadge({required this.product});
  final ProductSummary product;
  @override
  Widget build(BuildContext context) {
    final _ProductCatalogCopy copy = _ProductCatalogCopy.of(context);
    final bool archived = product.isArchived;
    final bool active = product.isActive && !archived;
    final String label = archived
        ? copy.archived
        : active
        ? copy.active
        : copy.inactive;
    final Color color = archived
        ? AppColors.warning
        : active
        ? AppColors.success
        : AppColors.textMuted;
    return Semantics(
      label: '${copy.status}: $label',
      child: Container(
        padding: const EdgeInsetsDirectional.symmetric(
          horizontal: AppSpacing.sm,
          vertical: AppSpacing.xs,
        ),
        decoration: BoxDecoration(
          color: color.withValues(alpha: .12),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(
              archived
                  ? Icons.archive_outlined
                  : active
                  ? Icons.check_circle_outline
                  : Icons.pause_circle_outline,
              size: 16,
              color: color,
            ),
            const SizedBox(width: AppSpacing.xs),
            Text(label, style: AppTextStyles.labelSmall.copyWith(color: color)),
          ],
        ),
      ),
    );
  }
}

class _EmptyPanel extends StatelessWidget {
  const _EmptyPanel({
    required this.filter,
    required this.hasFilters,
    required this.onClear,
  });
  final ProductCatalogFilter filter;
  final bool hasFilters;
  final VoidCallback onClear;
  @override
  Widget build(BuildContext context) {
    final _ProductCatalogCopy copy = _ProductCatalogCopy.of(context);
    final String message =
        filter.status == 'archived' && !filter.hasActiveFiltersExceptStatus
        ? copy.noArchivedProducts
        : filter.status == 'active' && !filter.hasActiveFilters
        ? copy.noActiveProducts
        : hasFilters
        ? copy.noMatchingProducts
        : copy.noProductsYet;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(48),
        child: Column(
          children: <Widget>[
            Text(message, style: AppTextStyles.titleMedium),
            if (hasFilters)
              TextButton(onPressed: onClear, child: Text(copy.clearAll)),
          ],
        ),
      ),
    );
  }
}

class _ProductActions extends StatelessWidget {
  const _ProductActions({required this.product});
  final ProductSummary product;
  @override
  Widget build(BuildContext context) {
    final bool busy = context.select<ProductLifecycleCubit, bool>(
      (cubit) => cubit.state.isSubmittingFor(product.id),
    );
    final _ProductCatalogCopy copy = _ProductCatalogCopy.of(context);
    final String name = product.displayName(Localizations.localeOf(context));
    return PopupMenuButton<_ProductAction>(
      key: Key('product-actions-${product.id}'),
      tooltip: copy.productActions(name),
      enabled: !busy,
      icon: busy
          ? const SizedBox.square(
              dimension: 18,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : const Icon(Icons.more_vert),
      onSelected: (action) => _run(context, action),
      itemBuilder: (context) => <PopupMenuEntry<_ProductAction>>[
        PopupMenuItem(value: _ProductAction.open, child: Text(copy.open)),
        if (!product.isArchived) ...<PopupMenuEntry<_ProductAction>>[
          PopupMenuItem(value: _ProductAction.edit, child: Text(copy.edit)),
          PopupMenuItem(
            value: _ProductAction.variants,
            child: Text(copy.manageVariants),
          ),
          PopupMenuItem(
            value: _ProductAction.modifiers,
            child: Text(copy.manageModifiers),
          ),
          PopupMenuItem(
            value: product.isActive
                ? _ProductAction.deactivate
                : _ProductAction.activate,
            child: Text(product.isActive ? 'Deactivate' : 'Activate'),
          ),
          PopupMenuItem(
            value: _ProductAction.archive,
            child: Text(
              copy.archive,
              style: const TextStyle(color: Colors.red),
            ),
          ),
        ] else
          PopupMenuItem(
            value: _ProductAction.restore,
            child: Text(copy.restore),
          ),
      ],
    );
  }

  Future<void> _run(BuildContext context, _ProductAction action) async {
    final String path = '/menu-management/products/${product.id}';
    switch (action) {
      case _ProductAction.open:
        context.go(path);
        return;
      case _ProductAction.edit:
        context.go('$path/edit');
        return;
      case _ProductAction.variants:
        context.go('$path/variants');
        return;
      case _ProductAction.modifiers:
        context.go('$path/modifiers');
        return;
      case _ProductAction.archive:
        await _showLifecycleDialog(context, product, archive: true);
        return;
      case _ProductAction.activate:
        await context.read<ProductLifecycleCubit>().activate(product.id);
        return;
      case _ProductAction.deactivate:
        await context.read<ProductLifecycleCubit>().deactivate(product.id);
        return;
      case _ProductAction.restore:
        await _showLifecycleDialog(context, product, archive: false);
        return;
    }
  }
}

enum _ProductAction {
  open,
  edit,
  variants,
  modifiers,
  activate,
  deactivate,
  archive,
  restore,
}

Future<void> _showLifecycleDialog(
  BuildContext context,
  ProductSummary product, {
  required bool archive,
}) async {
  final ProductLifecycleCubit cubit = context.read<ProductLifecycleCubit>();
  final ProductMenuUsage? usage = archive
      ? await cubit.menuUsage(product.id)
      : null;
  if (!context.mounted) return;
  await showDialog<void>(
    context: context,
    builder: (dialog) => AlertDialog(
      title: Text(archive ? 'Archive Product?' : 'Restore Product?'),
      content: SizedBox(
        width: 500,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              archive
                  ? 'This Product will no longer be available for new Menu configuration or normal Catalog use. Existing Orders and published historical Versions will not be changed.\n\nThe Product is not permanently deleted. Central Modifier Groups are not deleted, and Variants remain stored according to Backend behavior.'
                  : 'This restores the Product to the editable Catalog. Its availability in Menus still depends on Menu assignments, schedules, operational status, validation, and publishing.',
            ),
            if (usage != null && usage.activePlacementCount > 0) ...<Widget>[
              const SizedBox(height: AppSpacing.md),
              Text(
                'This Product is currently used in ${usage.activePlacementCount} Menu placement${usage.activePlacementCount == 1 ? '' : 's'}${usage.menuNames.isEmpty ? '.' : ': ${usage.menuNames.join(', ')}.'}',
                style: AppTextStyles.bodyMedium,
              ),
            ],
          ],
        ),
      ),
      actions: <Widget>[
        TextButton(
          onPressed: () => Navigator.pop(dialog),
          child: const Text('Cancel'),
        ),
        FilledButton(
          style: archive
              ? FilledButton.styleFrom(
                  backgroundColor: Theme.of(dialog).colorScheme.error,
                )
              : null,
          onPressed: () async {
            Navigator.pop(dialog);
            if (archive) {
              await cubit.archive(product.id);
            } else {
              await cubit.restore(product.id);
            }
          },
          child: Text(archive ? 'Archive Product' : 'Restore Product'),
        ),
      ],
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
        Text(message, style: AppTextStyles.bodyMedium),
        const SizedBox(height: AppSpacing.sm),
        OutlinedButton.icon(
          onPressed: onRetry,
          icon: const Icon(Icons.refresh),
          label: const Text('Retry'),
        ),
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
    decoration: BoxDecoration(
      color: AppColors.discountOrangeBadge,
      borderRadius: BorderRadius.circular(8),
    ),
    child: Text(
      'Some filters are unavailable: ${errors.keys.join(', ')}.',
      style: AppTextStyles.bodySmall,
    ),
  );
}

class _ProductCatalogCopy {
  const _ProductCatalogCopy._(this._context);
  factory _ProductCatalogCopy.of(BuildContext context) =>
      _ProductCatalogCopy._(context);
  final BuildContext _context;
  String get title => _context.maybeL10n?.productCatalogTitle ?? 'Products';
  String get subtitle =>
      _context.maybeL10n?.productCatalogSubtitle ??
      'Manage the products available across your menus.';
  String get createProduct =>
      _context.maybeL10n?.productCatalogCreateProduct ?? 'Create Product';
  String get refreshProducts =>
      _context.maybeL10n?.productCatalogRefresh ?? 'Refresh products';
  String get search =>
      _context.maybeL10n?.productCatalogSearch ??
      'Search products, SKU, or barcode';
  String get lifecycle =>
      _context.maybeL10n?.productCatalogLifecycle ?? 'Lifecycle';
  String get active => _context.maybeL10n?.commonActive ?? 'Active';
  String get inactive => _context.maybeL10n?.commonInactive ?? 'Inactive';
  String get archived => _context.maybeL10n?.statusArchived ?? 'Archived';
  String get all => _context.maybeL10n?.catalogSetupAll ?? 'All';
  String get allProducts =>
      _context.maybeL10n?.productCatalogAllProducts ?? 'All products';
  String get moreFilters =>
      _context.maybeL10n?.productCatalogMoreFilters ?? 'More filters';
  String get moreFiltersHelper =>
      _context.maybeL10n?.productCatalogMoreFiltersHelper ??
      'Refine the product list with additional criteria.';
  String get filterClassification =>
      _context.maybeL10n?.productCatalogFilterClassification ??
      'Classification';
  String get filterPreparation =>
      _context.maybeL10n?.productCatalogFilterPreparation ?? 'Preparation';
  String get filterProductSetup =>
      _context.maybeL10n?.productCatalogFilterProductSetup ?? 'Product setup';
  String moreFiltersSemantic(int count) =>
      _context.maybeL10n?.productCatalogMoreFiltersSemantic(count) ??
      'More filters, $count active';
  String get clearAll =>
      _context.maybeL10n?.productCatalogClearAll ?? 'Clear all';
  String get clearFilters =>
      _context.maybeL10n?.productCatalogClearFilters ?? 'Clear filters';
  String get applyFilters =>
      _context.maybeL10n?.productCatalogApplyFilters ?? 'Apply filters';
  String get cancel => _context.maybeL10n?.commonCancel ?? 'Cancel';
  String get sort => _context.maybeL10n?.productCatalogSort ?? 'Sort';
  String get sortOrder =>
      _context.maybeL10n?.productCatalogSortOrder ?? 'Sort order';
  String get nameAscending =>
      _context.maybeL10n?.productCatalogNameAscending ?? 'Name A–Z';
  String get nameDescending =>
      _context.maybeL10n?.productCatalogNameDescending ?? 'Name Z–A';
  String get newest =>
      _context.maybeL10n?.productCatalogNewest ?? 'Newest first';
  String get category => _context.maybeL10n?.catalogSetupCategory ?? 'Category';
  String get reportingCategory =>
      _context.maybeL10n?.catalogSetupReportingCategory ?? 'Reporting Category';
  String get kitchenStation =>
      _context.maybeL10n?.catalogSetupKitchenStation ?? 'Kitchen Station';
  String get productType =>
      _context.maybeL10n?.productCatalogProductType ?? 'Product type';
  String get hasVariants =>
      _context.maybeL10n?.productCatalogHasVariants ?? 'Has variants';
  String get noVariants =>
      _context.maybeL10n?.productCatalogNoVariants ?? 'No variants';
  String get hasModifiers =>
      _context.maybeL10n?.productCatalogHasModifiers ?? 'Has modifiers';
  String get noModifiers =>
      _context.maybeL10n?.productCatalogNoModifiers ?? 'No modifiers';
  String get yes => _context.maybeL10n?.commonYes ?? 'Yes';
  String get no => _context.maybeL10n?.commonNo ?? 'No';
  String get standard =>
      _context.maybeL10n?.productCatalogStandard ?? 'Standard';
  String get openPrice =>
      _context.maybeL10n?.productCatalogOpenPrice ?? 'Open price';
  String get combo => _context.maybeL10n?.productCatalogCombo ?? 'Combo';
  String get basePrice => _context.maybeL10n?.priceSourceBase ?? 'Base price';
  String get status => _context.maybeL10n?.productCatalogStatus ?? 'Status';
  String get open => _context.maybeL10n?.productCatalogOpen ?? 'Open';
  String get edit => _context.maybeL10n?.commonEdit ?? 'Edit';
  String get manageVariants =>
      _context.maybeL10n?.productCatalogManageVariants ?? 'Manage Variants';
  String get manageModifiers =>
      _context.maybeL10n?.productCatalogManageModifiers ?? 'Manage Modifiers';
  String get archive => _context.maybeL10n?.productCatalogArchive ?? 'Archive';
  String get restore => _context.maybeL10n?.productCatalogRestore ?? 'Restore';
  String productActions(String name) =>
      _context.maybeL10n?.productCatalogActionsFor(name) ?? 'Actions for $name';
  String productCount(int count) =>
      _context.maybeL10n?.productCount(count) ??
      '$count product${count == 1 ? '' : 's'}';
  String setupSummary(int variants, int modifiers) =>
      _context.maybeL10n?.productCatalogSetupSummary(variants, modifiers) ??
      '$variants variant${variants == 1 ? '' : 's'} · $modifiers modifier group${modifiers == 1 ? '' : 's'}';
  String get loading => _context.maybeL10n?.commonLoading ?? 'Loading...';
  String get loadMoreProducts =>
      _context.maybeL10n?.productCatalogLoadMore ?? 'Load more products';
  String get unableToLoadProducts =>
      _context.maybeL10n?.productCatalogUnableToLoad ??
      'Unable to load products.';
  String get noArchivedProducts =>
      _context.maybeL10n?.productCatalogNoArchived ??
      'No archived products are available.';
  String get noActiveProducts =>
      _context.maybeL10n?.productCatalogNoActive ??
      'No active products are available.';
  String get noMatchingProducts =>
      _context.maybeL10n?.productCatalogNoMatches ??
      'No products match these filters.';
  String get noProductsYet =>
      _context.maybeL10n?.productCatalogNoProductsYet ??
      'No products have been created yet.';
}

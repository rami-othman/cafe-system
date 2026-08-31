import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../app/menu_management_route_locations.dart';
import '../../../app/localization/localization_extensions.dart';
import '../../../core/services/service_locator.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../shared/layouts/desktop_page_layout.dart';
import '../controllers/product_detail_cubit.dart';
import '../controllers/product_lifecycle_cubit.dart';
import '../availability/widgets/product_availability_workspace.dart';
import '../products/controllers/product_modifier_assignments_cubit.dart';
import '../products/views/product_modifier_assignments_screen.dart';
import '../variants/controllers/variants_cubit.dart';
import '../variants/views/variants_screen.dart';
import '../models/catalog_models.dart';
import '../widgets/catalog_formatters.dart';
import '../widgets/menu_content_components.dart';
import '../widgets/menu_page_header.dart';
import '../recipes/controllers/recipe_cubits.dart';
import '../recipes/views/variant_recipe_screen.dart';
import 'product_catalog_screen.dart'
    show CatalogProductImage, CatalogProductStatus;

class ProductDetailScreen extends StatefulWidget {
  const ProductDetailScreen({
    super.key,
    required this.productId,
    this.tab = ProductWorkspaceTab.overview,
    this.variantId,
  });
  final int productId;
  final ProductWorkspaceTab tab;
  final int? variantId;
  @override
  State<ProductDetailScreen> createState() => _ProductDetailScreenState();
}

class _ProductDetailScreenState extends State<ProductDetailScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<ProductDetailCubit>().load(widget.productId);
      if (widget.tab == ProductWorkspaceTab.usage) {
        context.read<ProductDetailCubit>().loadUsage(widget.productId);
      }
    });
  }

  @override
  void didUpdateWidget(covariant ProductDetailScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.tab == ProductWorkspaceTab.usage &&
        oldWidget.tab != ProductWorkspaceTab.usage) {
      context.read<ProductDetailCubit>().loadUsage(widget.productId);
    }
  }

  void _selectTab(ProductWorkspaceTab tab) {
    if (tab == ProductWorkspaceTab.usage) {
      context.read<ProductDetailCubit>().loadUsage(widget.productId);
    }
    context.go(
      MenuManagementRouteLocations.productWorkspace(widget.productId, tab: tab),
    );
  }

  @override
  Widget build(BuildContext context) =>
      BlocListener<ProductLifecycleCubit, ProductLifecycleState>(
        listenWhen: (previous, current) =>
            previous.status != current.status &&
            current.productId == widget.productId &&
            (current.status == ProductLifecycleStatus.success ||
                current.status == ProductLifecycleStatus.failure),
        listener: (context, lifecycle) async {
          if (lifecycle.status == ProductLifecycleStatus.success) {
            await context.read<ProductDetailCubit>().load(widget.productId);
          }
          if (!context.mounted) {
            return;
          }
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
                      Text(
                        state.errorMessage ??
                            context.l10n.productDetailNotFound,
                      ),
                      const SizedBox(height: AppSpacing.md),
                      OutlinedButton(
                        onPressed: () => context
                            .read<ProductDetailCubit>()
                            .load(widget.productId),
                        child: Text(context.l10n.commonRetry),
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
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 1180),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        _WorkspaceHeader(product: product),
                        const SizedBox(height: AppSpacing.xl),
                        _WorkspaceNavigation(
                          selected: widget.tab,
                          onSelected: _selectTab,
                        ),
                        const SizedBox(height: AppSpacing.lg),
                        _workspaceBody(product, state),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      );

  Widget _workspaceBody(ProductDetail product, ProductDetailState state) =>
      switch (widget.tab) {
        ProductWorkspaceTab.overview => _Overview(product: product),
        ProductWorkspaceTab.variants =>
          product.isArchived
              ? _DestinationPanel(
                  title: context.l10n.productUxVariants,
                  message: context.l10n.productDetailArchivedVariantsMessage,
                  actionLabel: context.l10n.productDetailViewAction,
                  onPressed: null,
                )
              : BlocProvider<VariantsCubit>(
                  create: (_) => serviceLocator<VariantsCubit>(),
                  child: VariantsScreen(
                    productId: product.id,
                    embedded: true,
                    onSummaryChanged: context
                        .read<ProductDetailCubit>()
                        .replaceProduct,
                  ),
                ),
        ProductWorkspaceTab.modifiers =>
          product.isArchived
              ? _DestinationPanel(
                  title: context.l10n.productUxModifiers,
                  message: context.l10n.productDetailArchivedModifiersMessage,
                  actionLabel: context.l10n.productDetailViewAction,
                  onPressed: null,
                )
              : BlocProvider<ProductModifierAssignmentsCubit>(
                  create: (_) =>
                      serviceLocator<ProductModifierAssignmentsCubit>(),
                  child: ProductModifierAssignmentsScreen(
                    productId: product.id,
                    embedded: true,
                    onSummaryChanged: context
                        .read<ProductDetailCubit>()
                        .replaceProduct,
                  ),
                ),
        ProductWorkspaceTab.recipe => BlocProvider<VariantRecipeCubit>(
          create: (_) =>
              VariantRecipeCubit(context.read<ProductDetailCubit>().repository),
          child: RecipeMaterialsWorkspace(
            product: product,
            readOnly: product.isArchived,
            selectedVariantId: widget.variantId,
            onVariantChanged: (variantId) => context.go(
              MenuManagementRouteLocations.productWorkspace(
                product.id,
                tab: ProductWorkspaceTab.recipe,
                variantId: variantId,
              ),
            ),
          ),
        ),
        ProductWorkspaceTab.availability => ProductAvailabilityWorkspace(
          product: product,
        ),
        ProductWorkspaceTab.usage => _UsagePanel(
          state: state,
          onRetry: () =>
              context.read<ProductDetailCubit>().loadUsage(product.id),
        ),
      };
}

class _WorkspaceHeader extends StatelessWidget {
  const _WorkspaceHeader({required this.product});
  final ProductDetail product;
  @override
  Widget build(BuildContext context) => Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: <Widget>[
      CatalogProductImage(url: product.imageUrl),
      const SizedBox(width: AppSpacing.md),
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            MenuPageHeader(
              title: product.displayName(Localizations.localeOf(context)),
              subtitle:
                  product.category?.displayName(
                    Localizations.localeOf(context),
                  ) ??
                  context.l10n.productDetailUncategorized,
              primaryAction: product.isArchived
                  ? null
                  : FilledButton.icon(
                      key: const Key('edit-product-action'),
                      onPressed: () => context.go(
                        '/menu-management/products/${product.id}/edit',
                      ),
                      icon: const Icon(Icons.edit_outlined),
                      label: Text(context.l10n.productDetailEdit),
                    ),
              overflowActions: <MenuOverflowAction>[
                MenuOverflowAction(
                  label: product.isArchived
                      ? context.l10n.productDetailRestoreMenuAction
                      : context.l10n.productDetailArchiveMenuAction,
                  icon: product.isArchived
                      ? Icons.restore
                      : Icons.archive_outlined,
                  onSelected: () => _LifecycleAction.confirm(context, product),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
            Wrap(
              spacing: AppSpacing.md,
              runSpacing: AppSpacing.sm,
              children: <Widget>[
                CatalogProductStatus(product: product),
                _HeaderMetric(
                  context.l10n.productDetailBasePrice,
                  product.defaultVariant == null
                      ? '—'
                      : catalogMoney(
                          context,
                          product.defaultVariant!.basePrice,
                        ),
                ),
                _HeaderMetric(
                  context.l10n.productUxVariants,
                  '${product.variantCount}',
                ),
                _HeaderMetric(
                  context.l10n.productUxModifiers,
                  '${product.modifierGroupCount}',
                ),
                if (product.kitchenStation != null)
                  _HeaderMetric(
                    context.l10n.productDetailKitchenStation,
                    product.kitchenStation!.displayName(
                      Localizations.localeOf(context),
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    ],
  );
}

class _HeaderMetric extends StatelessWidget {
  const _HeaderMetric(this.label, this.value);
  final String label;
  final String value;
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: <Widget>[
      Text(
        label,
        style: Theme.of(
          context,
        ).textTheme.labelSmall?.copyWith(color: AppColors.textMuted),
      ),
      Text(
        value,
        textDirection: label == context.l10n.productDetailBasePrice
            ? TextDirection.ltr
            : null,
        style: Theme.of(context).textTheme.labelLarge,
      ),
    ],
  );
}

class _WorkspaceNavigation extends StatelessWidget {
  const _WorkspaceNavigation({
    required this.selected,
    required this.onSelected,
  });
  final ProductWorkspaceTab selected;
  final ValueChanged<ProductWorkspaceTab> onSelected;
  @override
  Widget build(BuildContext context) => Semantics(
    container: true,
    label: context.l10n.productDetailWorkspaceNavigation,
    child: SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: SegmentedButton<ProductWorkspaceTab>(
        showSelectedIcon: false,
        selected: <ProductWorkspaceTab>{selected},
        onSelectionChanged: (tabs) => onSelected(tabs.single),
        segments: <ButtonSegment<ProductWorkspaceTab>>[
          ButtonSegment(
            value: ProductWorkspaceTab.overview,
            label: Text(context.maybeL10n?.productUxOverview ?? 'Overview'),
          ),
          ButtonSegment(
            value: ProductWorkspaceTab.variants,
            label: Text(context.maybeL10n?.productUxVariants ?? 'Variants'),
          ),
          ButtonSegment(
            value: ProductWorkspaceTab.modifiers,
            label: Text(context.maybeL10n?.productUxModifiers ?? 'Modifiers'),
          ),
          ButtonSegment(
            value: ProductWorkspaceTab.recipe,
            label: Text(
              context.maybeL10n?.productUxRecipeMaterials ??
                  'Recipe & Materials',
            ),
          ),
          ButtonSegment(
            value: ProductWorkspaceTab.availability,
            label: Text(
              context.maybeL10n?.productUxAvailability ?? 'Availability',
            ),
          ),
          ButtonSegment(
            value: ProductWorkspaceTab.usage,
            label: Text(context.maybeL10n?.productUxUsage ?? 'Usage'),
          ),
        ],
      ),
    ),
  );
}

class _Overview extends StatelessWidget {
  const _Overview({required this.product});
  final ProductDetail product;
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: <Widget>[
      _BusinessSummary(product: product),
      const SizedBox(height: AppSpacing.lg),
      ContentSection(
        title:
            context.maybeL10n?.productOverviewProductSetup ?? 'Product Setup',
        description: context.l10n.productDetailSetupHelp,
        child: _BusinessDetails(product: product),
      ),
      const SizedBox(height: AppSpacing.lg),
      Visibility(
        visible: false,
        maintainState: true,
        child: ContentSection(
          title: 'Overview',
          description: 'The current product setup at a glance.',
          child: Wrap(
            spacing: 48,
            runSpacing: AppSpacing.lg,
            children: <Widget>[
              _Fact('Category', product.category?.name ?? '—'),
              _Fact('Default Variant', product.defaultVariant?.name ?? '—'),
              _Fact(
                'Base Price',
                product.defaultVariant == null
                    ? '—'
                    : catalogMoney(context, product.defaultVariant!.basePrice),
                technical: true,
              ),
              _Fact('Variant Count', '${product.variantCount}'),
              _Fact('Modifier Groups', '${product.modifierGroupCount}'),
              _Fact('Kitchen Station', product.kitchenStation?.name ?? '—'),
              _Fact('Stock Tracking', booleanLabel(product.isStockTracked)),
              _Fact(
                'Preparation Time',
                product.preparationTimeMinutes == null
                    ? '—'
                    : '${product.preparationTimeMinutes} minutes',
              ),
              _Fact(
                'Reporting Category',
                product.reportingCategory?.name ?? '—',
              ),
              _Fact('Product Type', productTypeLabel(product.productType)),
            ],
          ),
        ),
      ),
      if (product.description?.isNotEmpty ?? false) ...<Widget>[
        const SizedBox(height: AppSpacing.lg),
        ContentSection(
          title: context.l10n.productDetailDescription,
          child: Text(product.description!),
        ),
      ],
      const SizedBox(height: AppSpacing.lg),
      DetailsDisclosure(
        title: context.l10n.productDetailAdvancedTechnical,
        child: Wrap(
          spacing: 48,
          runSpacing: AppSpacing.lg,
          children: <Widget>[
            _Fact(
              context.l10n.productDetailProductId,
              '${product.id}',
              technical: true,
            ),
            _Fact(
              context.l10n.productEditorSortOrder,
              '${product.sortOrder}',
              technical: true,
            ),
            _Fact(context.l10n.menuListCreated, catalogDate(product.createdAt)),
            _Fact(
              context.l10n.productDetailUpdated,
              catalogDate(product.updatedAt),
            ),
            if (product.imageUrl != null)
              _Fact(
                context.l10n.productDetailImageUrl,
                product.imageUrl!,
                technical: true,
              ),
            if (product.isArchived)
              _Fact(
                context.l10n.commonArchived,
                catalogDate(product.archivedAt),
              ),
          ],
        ),
      ),
    ],
  );
}

class _BusinessSummary extends StatelessWidget {
  const _BusinessSummary({required this.product});
  final ProductDetail product;

  @override
  Widget build(BuildContext context) {
    final l10n = context.maybeL10n;
    final String notConfigured =
        l10n?.productOverviewNotConfigured ?? 'Not configured';
    return LayoutBuilder(
      builder: (context, constraints) {
        final bool fourColumns = constraints.maxWidth >= 900;
        final double gap = AppSpacing.md;
        final double width = fourColumns
            ? (constraints.maxWidth - (gap * 3)) / 4
            : (constraints.maxWidth - gap) / 2;
        final List<_SummaryMetric> metrics = <_SummaryMetric>[
          _SummaryMetric(
            label: l10n?.productOverviewBasePrice ?? 'Base Price',
            value: product.defaultVariant == null
                ? notConfigured
                : catalogMoney(context, product.defaultVariant!.basePrice),
            ltrValue: product.defaultVariant != null,
          ),
          _SummaryMetric(
            label: l10n?.productOverviewVariants ?? 'Variants',
            value: '${product.variantCount}',
          ),
          _SummaryMetric(
            label: l10n?.productOverviewModifierGroups ?? 'Modifier Groups',
            value: '${product.modifierGroupCount}',
          ),
          _SummaryMetric(
            label: l10n?.productOverviewStockTracking ?? 'Stock Tracking',
            value: product.isStockTracked
                ? l10n?.productOverviewEnabled ?? 'Enabled'
                : l10n?.productOverviewDisabled ?? 'Disabled',
          ),
        ];
        return Wrap(
          spacing: gap,
          runSpacing: gap,
          children: metrics
              .map((metric) => SizedBox(width: width, child: metric))
              .toList(growable: false),
        );
      },
    );
  }
}

class _SummaryMetric extends StatelessWidget {
  const _SummaryMetric({
    required this.label,
    required this.value,
    this.ltrValue = false,
  });
  final String label;
  final String value;
  final bool ltrValue;

  @override
  Widget build(BuildContext context) => Container(
    key: Key('product-summary-$label'),
    padding: AppSpacing.allLg,
    decoration: BoxDecoration(
      color: AppColors.surface,
      border: Border.all(color: AppColors.border),
      borderRadius: BorderRadius.circular(12),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          label,
          style: Theme.of(
            context,
          ).textTheme.labelSmall?.copyWith(color: AppColors.textMuted),
        ),
        const SizedBox(height: AppSpacing.xs),
        Text(
          value,
          textDirection: ltrValue ? TextDirection.ltr : null,
          style: Theme.of(context).textTheme.titleMedium,
        ),
      ],
    ),
  );
}

class _BusinessDetails extends StatelessWidget {
  const _BusinessDetails({required this.product});
  final ProductDetail product;

  @override
  Widget build(BuildContext context) {
    final l10n = context.maybeL10n;
    final String notConfigured =
        l10n?.productOverviewNotConfigured ?? 'Not configured';
    final List<_Fact> facts = <_Fact>[
      _Fact(
        l10n?.productOverviewCategory ?? 'Category',
        product.category?.displayName(Localizations.localeOf(context)) ??
            notConfigured,
      ),
      _Fact(
        l10n?.productOverviewDefaultVariant ?? 'Default Variant',
        product.defaultVariant?.displayName(Localizations.localeOf(context)) ??
            notConfigured,
      ),
      _Fact(
        l10n?.productOverviewKitchenStation ?? 'Kitchen Station',
        product.kitchenStation?.displayName(Localizations.localeOf(context)) ??
            notConfigured,
      ),
      _Fact(
        l10n?.productOverviewProductType ?? 'Product Type',
        productTypeLabel(product.productType),
      ),
      _Fact(
        l10n?.productOverviewReportingCategory ?? 'Reporting Category',
        product.reportingCategory?.displayName(
              Localizations.localeOf(context),
            ) ??
            notConfigured,
      ),
      _Fact(
        l10n?.productOverviewPreparationTime ?? 'Preparation Time',
        product.preparationTimeMinutes == null
            ? notConfigured
            : '${product.preparationTimeMinutes} ${l10n?.productOverviewMinutes ?? 'minutes'}',
      ),
    ];
    return LayoutBuilder(
      builder: (context, constraints) => Wrap(
        spacing: AppSpacing.xxl,
        runSpacing: AppSpacing.lg,
        children: facts
            .map(
              (fact) => SizedBox(
                width: constraints.maxWidth >= 720
                    ? (constraints.maxWidth - AppSpacing.xxl) / 2
                    : constraints.maxWidth,
                child: fact,
              ),
            )
            .toList(growable: false),
      ),
    );
  }
}

class _Fact extends StatelessWidget {
  const _Fact(this.label, this.value, {this.technical = false});
  final String label;
  final String value;
  final bool technical;
  @override
  Widget build(BuildContext context) => SizedBox(
    width: 210,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          label,
          style: Theme.of(
            context,
          ).textTheme.labelSmall?.copyWith(color: AppColors.textMuted),
        ),
        Text(value, textDirection: technical ? TextDirection.ltr : null),
      ],
    ),
  );
}

class _DestinationPanel extends StatelessWidget {
  const _DestinationPanel({
    required this.title,
    required this.message,
    required this.actionLabel,
    required this.onPressed,
  });
  final String title;
  final String message;
  final String actionLabel;
  final VoidCallback? onPressed;
  @override
  Widget build(BuildContext context) => ContentSection(
    title: title,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(message),
        const SizedBox(height: AppSpacing.lg),
        OutlinedButton(onPressed: onPressed, child: Text(actionLabel)),
      ],
    ),
  );
}

class _UsagePanel extends StatelessWidget {
  const _UsagePanel({required this.state, required this.onRetry});
  final ProductDetailState state;
  final VoidCallback onRetry;
  @override
  Widget build(BuildContext context) => ContentSection(
    title: context.l10n.productUxUsage,
    description: context.l10n.productDetailUsageHelp,
    child: Builder(
      builder: (context) {
        if (state.isLoadingUsage) {
          return const Padding(
            padding: EdgeInsets.all(AppSpacing.lg),
            child: Center(child: CircularProgressIndicator()),
          );
        }
        if (state.usageError != null) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(state.usageError!),
              const SizedBox(height: AppSpacing.md),
              OutlinedButton(
                onPressed: onRetry,
                child: Text(context.l10n.commonRetry),
              ),
            ],
          );
        }
        final ProductMenuUsage? usage = state.usage;
        if (usage == null || usage.activePlacementCount == 0) {
          return Text(context.l10n.productDetailUsageEmpty);
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              context.l10n.productDetailUsageCount(usage.activePlacementCount),
            ),
            if (usage.menuNames.isNotEmpty) ...<Widget>[
              const SizedBox(height: AppSpacing.sm),
              ...usage.menuNames.map(
                (name) => ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.restaurant_menu_outlined),
                  title: Text(name),
                ),
              ),
            ],
          ],
        );
      },
    ),
  );
}

class _LifecycleAction {
  static Future<void> confirm(
    BuildContext context,
    ProductDetail product,
  ) async {
    final bool archive = !product.isArchived;
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (dialog) => AlertDialog(
        title: Text(
          archive
              ? context.l10n.productDetailArchiveTitle
              : context.l10n.productDetailRestoreTitle,
        ),
        content: Text(
          archive
              ? 'This Product will no longer be available for new Menu configuration or normal Catalog use. Existing Orders and published historical Versions will not be changed.'
              : 'This restores the Product to the editable Catalog. Availability still depends on Menu assignments, schedules, operational status, validation, and publishing.',
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.pop(dialog, false),
            child: Text(context.l10n.commonCancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialog, true),
            child: Text(
              archive
                  ? context.l10n.productDetailArchiveAction
                  : context.l10n.productDetailRestoreAction,
            ),
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

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/localization/localization_extensions.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_radius.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../shared/layouts/desktop_page_layout.dart';
import '../../controllers/product_catalog_cubit.dart';
import '../../models/catalog_models.dart';
import '../../widgets/catalog_formatters.dart';
import '../../pricing/configured_price_validation.dart';
import '../controllers/variants_cubit.dart';
import '../controllers/variants_state.dart';
import '../models/variant_editor_draft.dart';

class VariantsScreen extends StatefulWidget {
  const VariantsScreen({
    super.key,
    required this.productId,
    this.embedded = false,
    this.onSummaryChanged,
  });
  final int productId;
  final bool embedded;
  final ValueChanged<ProductDetail>? onSummaryChanged;
  @override
  State<VariantsScreen> createState() => _VariantsScreenState();
}

class _VariantsScreenState extends State<VariantsScreen> {
  bool _reorderMode = false;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => context.read<VariantsCubit>().load(widget.productId),
    );
  }

  @override
  Widget build(BuildContext context) =>
      BlocListener<VariantsCubit, VariantsState>(
        listenWhen: (before, after) =>
            before.successMessage != after.successMessage &&
            after.successMessage != null,
        listener: (context, state) {
          context.read<ProductCatalogCubit>().refresh();
          if (state.summaryChanged && state.product != null) {
            widget.onSummaryChanged?.call(state.product!);
          }
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text(state.successMessage!)));
        },
        child: BlocBuilder<VariantsCubit, VariantsState>(builder: _build),
      );

  Widget _build(BuildContext context, VariantsState state) {
    if (state.product == null) {
      if (state.status == VariantsStatus.initial ||
          state.status == VariantsStatus.loading) {
        return const DesktopPageLayout(
          child: Center(child: CircularProgressIndicator()),
        );
      }
      return DesktopPageLayout(
        child: Center(
          child: _Retry(
            message: state.formError ?? 'Product not found.',
            onRetry: () => context.read<VariantsCubit>().load(widget.productId),
          ),
        ),
      );
    }
    final ProductDetail product = state.product!;
    if (product.isArchived) {
      return DesktopPageLayout(
        child: Center(
          child: _Retry(
            message: 'This product is archived and variants are read-only.',
            onRetry: () =>
                context.go('/menu-management/products/${product.id}'),
          ),
        ),
      );
    }
    return DesktopPageLayout(
      padding: EdgeInsets.zero,
      child: SingleChildScrollView(
        padding: const EdgeInsetsDirectional.fromSTEB(
          AppSpacing.xl,
          AppSpacing.md,
          AppSpacing.xl,
          AppSpacing.xxxl,
        ),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 980),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                if (!widget.embedded) ...<Widget>[
                  TextButton.icon(
                    onPressed: () =>
                        context.go('/menu-management/products/${product.id}'),
                    icon: const Icon(Icons.arrow_back),
                    label: Text(product.name),
                  ),
                  const SizedBox(height: AppSpacing.md),
                ],
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    const Expanded(
                      child: _ScreenIntroduction(
                        title: 'Variants',
                        helper:
                            'Manage the selling options available for this Product.',
                      ),
                    ),
                    const SizedBox(width: AppSpacing.md),
                    FilledButton.icon(
                      key: const Key('add-variant-action'),
                      onPressed: state.isMutating ? null : () => _edit(),
                      icon: const Icon(Icons.add),
                      label: const Text('Add Variant'),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.lg),
                Wrap(
                  spacing: AppSpacing.sm,
                  runSpacing: AppSpacing.sm,
                  children: <Widget>[
                    SegmentedButton<VariantFilter>(
                      segments: const <ButtonSegment<VariantFilter>>[
                        ButtonSegment(
                          value: VariantFilter.active,
                          label: Text('Active'),
                        ),
                        ButtonSegment(
                          value: VariantFilter.inactive,
                          label: Text('Inactive'),
                        ),
                        ButtonSegment(
                          value: VariantFilter.archived,
                          label: Text('Archived'),
                        ),
                        ButtonSegment(
                          value: VariantFilter.all,
                          label: Text('All'),
                        ),
                      ],
                      selected: <VariantFilter>{state.filter},
                      onSelectionChanged: state.isMutating || _reorderMode
                          ? null
                          : (value) => context
                                .read<VariantsCubit>()
                                .selectFilter(value.first),
                    ),
                    OutlinedButton.icon(
                      key: const Key('variant-reorder-action'),
                      onPressed:
                          state.isMutating ||
                              (state.filter != VariantFilter.active &&
                                  !_reorderMode)
                          ? null
                          : () => setState(() => _reorderMode = !_reorderMode),
                      icon: Icon(_reorderMode ? Icons.check : Icons.reorder),
                      label: Text(_reorderMode ? 'Done' : 'Reorder'),
                    ),
                    IconButton(
                      tooltip: 'Refresh Variants',
                      onPressed: state.isMutating
                          ? null
                          : () => context.read<VariantsCubit>().refresh(),
                      icon: const Icon(Icons.refresh),
                    ),
                  ],
                ),
                if (state.formError != null) ...<Widget>[
                  const SizedBox(height: AppSpacing.md),
                  _ErrorBanner(state.formError!),
                ],
                const SizedBox(height: AppSpacing.lg),
                _VariantTable(
                  state: state,
                  reorderMode: _reorderMode,
                  edit: _edit,
                  setDefault: _setDefault,
                  activate: (variant) =>
                      context.read<VariantsCubit>().activate(variant),
                  deactivate: (variant) =>
                      context.read<VariantsCubit>().deactivate(variant),
                  archive: _archive,
                  restore: _restore,
                  move: _move,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _edit([ProductVariant? variant]) => showDialog<void>(
    context: context,
    builder: (_) => BlocProvider.value(
      value: context.read<VariantsCubit>(),
      child: _VariantEditorDialog(variant: variant),
    ),
  );
  Future<void> _setDefault(ProductVariant variant) async {
    if (await _confirm(
              'Set “${variant.name}” as the Default Variant?',
              'The Product’s displayed base price, SKU, barcode, and legacy POS compatibility will use this Variant. Existing Orders are not changed.',
              confirm: 'Set Default',
            ) ==
            true &&
        mounted) {
      await context.read<VariantsCubit>().setDefault(variant.id);
    }
  }

  Future<void> _archive(ProductVariant variant) async {
    final VariantsState state = context.read<VariantsCubit>().state;
    if (!variant.isDefault) {
      if (await _confirm(
                'Archive “${variant.name}”?',
                'This Variant will be archived and can be restored later.',
                confirm: 'Archive',
              ) ==
              true &&
          mounted) {
        await context.read<VariantsCubit>().archive(variant.id);
      }
      return;
    }
    final List<ProductVariant> choices = state.activeVariants
        .where((item) => item.id != variant.id)
        .toList();
    if (choices.isEmpty) {
      await _onlyActive();
      return;
    }
    if (!mounted) {
      return;
    }
    final int? replacementId = await _replacementDialog(variant, choices);
    if (replacementId != null && mounted) {
      await context.read<VariantsCubit>().archive(
        variant.id,
        replacementDefaultVariantId: replacementId,
      );
    }
  }

  Future<void> _onlyActive() => showDialog<void>(
    context: context,
    builder: (dialog) => AlertDialog(
      title: const Text('Cannot archive Default Variant'),
      content: const Text('The only active Variant cannot be archived.'),
      actions: <Widget>[
        TextButton(
          onPressed: () => Navigator.pop(dialog),
          child: const Text('Close'),
        ),
      ],
    ),
  );
  Future<int?> _replacementDialog(
    ProductVariant current,
    List<ProductVariant> choices,
  ) => showDialog<int>(
    context: context,
    builder: (dialog) {
      int selected = choices.first.id;
      return StatefulBuilder(
        builder: (_, setState) => AlertDialog(
          title: Text('Archive “${current.name}”?'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              const Text('Select an active replacement Default Variant.'),
              const SizedBox(height: AppSpacing.md),
              DropdownButtonFormField<int>(
                initialValue: selected,
                items: choices
                    .map(
                      (item) => DropdownMenuItem(
                        value: item.id,
                        child: Text(item.name),
                      ),
                    )
                    .toList(),
                onChanged: (value) => setState(() => selected = value!),
              ),
            ],
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.pop(dialog),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialog, selected),
              child: const Text('Archive'),
            ),
          ],
        ),
      );
    },
  );
  Future<void> _restore(ProductVariant variant) async {
    final bool hasDefault = context
        .read<VariantsCubit>()
        .state
        .activeVariants
        .any((item) => item.isDefault);
    if (!hasDefault &&
        await _confirm(
              'Restore “${variant.name}” as Default?',
              'This Product has no active Default Variant, so this restored Variant must become the Default Variant.',
              confirm: 'Restore as Default',
            ) !=
            true) {
      return;
    }
    if (mounted) {
      await context.read<VariantsCubit>().restore(
        variant.id,
        makeDefault: !hasDefault,
      );
    }
  }

  Future<bool?> _confirm(
    String title,
    String content, {
    String confirm = 'Confirm',
  }) => showDialog<bool>(
    context: context,
    builder: (dialog) => AlertDialog(
      title: Text(title),
      content: Text(content),
      actions: <Widget>[
        TextButton(
          onPressed: () => Navigator.pop(dialog, false),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(dialog, true),
          child: Text(confirm),
        ),
      ],
    ),
  );
  Future<void> _move(ProductVariant variant, int direction) async {
    final List<ProductVariant> items = List<ProductVariant>.from(
      context.read<VariantsCubit>().state.activeVariants,
    );
    final int from = items.indexWhere((item) => item.id == variant.id);
    final int to = from + direction;
    if (from < 0 || to < 0 || to >= items.length) return;
    items.insert(to, items.removeAt(from));
    await context.read<VariantsCubit>().reorder(items);
  }
}

class _VariantTable extends StatelessWidget {
  const _VariantTable({
    required this.state,
    required this.reorderMode,
    required this.edit,
    required this.setDefault,
    required this.activate,
    required this.deactivate,
    required this.archive,
    required this.restore,
    required this.move,
  });
  final VariantsState state;
  final bool reorderMode;
  final ValueChanged<ProductVariant> edit;
  final ValueChanged<ProductVariant> setDefault;
  final ValueChanged<ProductVariant> activate;
  final ValueChanged<ProductVariant> deactivate;
  final ValueChanged<ProductVariant> archive;
  final ValueChanged<ProductVariant> restore;
  final void Function(ProductVariant, int) move;
  @override
  Widget build(BuildContext context) {
    final List<ProductVariant> items = state.visibleVariants;
    if (items.isEmpty) return _Empty(filter: state.filter);
    return _VariantCompactRows(
      items: items,
      state: state,
      recipeRequired: state.product!.isStockTracked,
      reorderMode: reorderMode,
      edit: edit,
      setDefault: setDefault,
      activate: activate,
      deactivate: deactivate,
      archive: archive,
      restore: restore,
      move: move,
    );
    /*
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: DataTable(
        columns: const <DataColumn>[
          DataColumn(label: Text('Order')),
          DataColumn(label: Text('Variant name')),
          DataColumn(label: Text('SKU')),
          DataColumn(label: Text('Barcode')),
          DataColumn(label: Text('Base Price')),
          DataColumn(label: Text('Cost Price')),
          DataColumn(label: Text('Default')),
          DataColumn(label: Text('Status')),
          DataColumn(label: Text('Actions')),
        ],
        rows: items
            .map((variant) {
              final int order = state.activeVariants.indexWhere(
                (item) => item.id == variant.id,
              );
              return DataRow(
                cells: <DataCell>[
                  DataCell(
                    variant.isArchived
                        ? const Text('—')
                        : Row(
                            mainAxisSize: MainAxisSize.min,
                            children: <Widget>[
                              IconButton(
                                tooltip: 'Move up',
                                onPressed: state.isMutating || order == 0
                                    ? null
                                    : () => move(variant, -1),
                                icon: const Icon(Icons.arrow_upward),
                              ),
                              IconButton(
                                tooltip: 'Move down',
                                onPressed:
                                    state.isMutating ||
                                        order == state.activeVariants.length - 1
                                    ? null
                                    : () => move(variant, 1),
                                icon: const Icon(Icons.arrow_downward),
                              ),
                            ],
                          ),
                  ),
                  DataCell(Text(variant.name)),
                  DataCell(Text(variant.sku ?? '—')),
                  DataCell(Text(variant.barcode ?? '—')),
                  DataCell(Text(catalogMoney(variant.basePrice))),
                  DataCell(
                    Text(
                      variant.costPrice == null
                          ? '—'
                          : catalogMoney(variant.costPrice!),
                    ),
                  ),
                  DataCell(
                    variant.isDefault
                        ? const Chip(label: Text('Default'))
                        : const Text('—'),
                  ),
                  DataCell(
                    Chip(
                      label: Text(variant.isArchived ? 'Archived' : 'Active'),
                    ),
                  ),
                  DataCell(
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: <Widget>[
                        IconButton(
                          tooltip: 'Edit',
                          onPressed: state.isMutating || variant.isArchived
                              ? null
                              : () => edit(variant),
                          icon: const Icon(Icons.edit_outlined),
                        ),
                        if (!variant.isArchived)
                          IconButton(
                            key: Key('manage-recipe-${variant.id}'),
                            tooltip: 'Manage Recipe / Materials',
                            onPressed: state.isMutating
                                ? null
                                : () => context.go(
                                    '/menu-management/product-variants/${variant.id}/recipe?productId=${state.product!.id}',
                                  ),
                            icon: const Icon(Icons.receipt_long_outlined),
                          ),
                        if (!variant.isArchived)
                          IconButton(
                            key: Key('manage-price-overrides-${variant.id}'),
                            tooltip: 'Manage Price Overrides',
                            onPressed: state.isMutating
                                ? null
                                : () => context.go(
                                    '/menu-management/products/${state.product!.id}/variants/${variant.id}/pricing',
                                  ),
                            icon: const Icon(Icons.price_change_outlined),
                          ),
                        if (!variant.isArchived)
                          IconButton(
                            key: Key('manage-availability-${variant.id}'),
                            tooltip: 'Manage Scheduled Availability',
                            onPressed: state.isMutating
                                ? null
                                : () => context.go(
                                    '/menu-management/products/${state.product!.id}/availability?variantId=${variant.id}&from=variants',
                                  ),
                            icon: const Icon(Icons.schedule_outlined),
                          ),
                        if (!variant.isArchived)
                          IconButton(
                            key: Key(
                              'manage-operational-availability-${variant.id}',
                            ),
                            tooltip: 'Manage Availability / Sold Out',
                            onPressed: state.isMutating
                                ? null
                                : () => context.go(
                                    '/menu-management/products/${state.product!.id}/operational-availability?variantId=${variant.id}&from=variants',
                                  ),
                            icon: const Icon(Icons.do_not_disturb_on_outlined),
                          ),
                        if (!variant.isArchived && !variant.isDefault)
                          IconButton(
                            tooltip: 'Set as Default',
                            onPressed: state.isMutating
                                ? null
                                : () => setDefault(variant),
                            icon: const Icon(Icons.star_outline),
                          ),
                        IconButton(
                          tooltip: variant.isArchived ? 'Restore' : 'Archive',
                          onPressed: state.isMutating
                              ? null
                              : () => variant.isArchived
                                    ? restore(variant)
                                    : archive(variant),
                          icon: Icon(
                            variant.isArchived
                                ? Icons.restore
                                : Icons.archive_outlined,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              );
            })
            .toList(growable: false),
      ),
    );
  }
}
*/
  }
}

class _VariantCompactRows extends StatelessWidget {
  const _VariantCompactRows({
    required this.items,
    required this.state,
    required this.recipeRequired,
    required this.reorderMode,
    required this.edit,
    required this.setDefault,
    required this.activate,
    required this.deactivate,
    required this.archive,
    required this.restore,
    required this.move,
  });
  final List<ProductVariant> items;
  final VariantsState state;
  final bool recipeRequired;
  final bool reorderMode;
  final ValueChanged<ProductVariant> edit;
  final ValueChanged<ProductVariant> setDefault;
  final ValueChanged<ProductVariant> activate;
  final ValueChanged<ProductVariant> deactivate;
  final ValueChanged<ProductVariant> archive;
  final ValueChanged<ProductVariant> restore;
  final void Function(ProductVariant, int) move;

  @override
  Widget build(BuildContext context) => Column(
    children: items
        .map((ProductVariant variant) {
          final int order = state.activeVariants.indexWhere(
            (item) => item.id == variant.id,
          );
          return Container(
            key: Key('variant-row-${variant.id}'),
            margin: const EdgeInsets.only(bottom: AppSpacing.sm),
            padding: AppSpacing.allLg,
            decoration: BoxDecoration(
              color: AppColors.surface,
              border: Border.all(color: AppColors.border),
              borderRadius: AppRadius.card,
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                if (reorderMode && !variant.isArchived) ...<Widget>[
                  Column(
                    children: <Widget>[
                      const Icon(
                        Icons.drag_indicator,
                        semanticLabel: 'Reorder',
                      ),
                      IconButton(
                        tooltip: 'Move up',
                        onPressed: state.isMutating || order == 0
                            ? null
                            : () => move(variant, -1),
                        icon: const Icon(Icons.keyboard_arrow_up),
                      ),
                      IconButton(
                        tooltip: 'Move down',
                        onPressed:
                            state.isMutating ||
                                order == state.activeVariants.length - 1
                            ? null
                            : () => move(variant, 1),
                        icon: const Icon(Icons.keyboard_arrow_down),
                      ),
                    ],
                  ),
                  const SizedBox(width: AppSpacing.sm),
                ],
                Expanded(
                  flex: 3,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Wrap(
                        spacing: AppSpacing.sm,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: <Widget>[
                          Text(
                            variant.displayName(
                              Localizations.localeOf(context),
                            ),
                            style: Theme.of(context).textTheme.titleSmall,
                          ),
                          if (variant.isDefault) const _VariantBadge('Default'),
                        ],
                      ),
                      if (variant.sku?.isNotEmpty == true)
                        Text(
                          'SKU: ${variant.sku}',
                          textDirection: TextDirection.ltr,
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(color: AppColors.textSecondary),
                        ),
                    ],
                  ),
                ),
                Expanded(
                  child: _VariantFact(
                    catalogMoney(variant.basePrice),
                    'Base price',
                    ltr: true,
                  ),
                ),
                Expanded(
                  flex: 2,
                  child: _VariantStatus(
                    state.recipeConfigured[variant.id] == true
                        ? 'Recipe configured'
                        : recipeRequired
                        ? 'Recipe missing'
                        : 'Recipe not configured',
                    state.recipeConfigured[variant.id] == true
                        ? Icons.check_circle_outline
                        : recipeRequired
                        ? Icons.warning_amber_outlined
                        : Icons.info_outline,
                    state.recipeConfigured[variant.id] == true
                        ? AppColors.success
                        : recipeRequired
                        ? AppColors.warning
                        : AppColors.textSecondary,
                  ),
                ),
                Expanded(
                  child: _VariantStatus(
                    variant.isArchived
                        ? 'Archived'
                        : variant.isInactive
                        ? 'Inactive'
                        : 'Active',
                    variant.isArchived
                        ? Icons.archive_outlined
                        : variant.isInactive
                        ? Icons.pause_circle_outline
                        : Icons.check_circle_outline,
                    variant.isArchived
                        ? AppColors.textSecondary
                        : variant.isInactive
                        ? AppColors.textMuted
                        : AppColors.success,
                  ),
                ),
                PopupMenuButton<_VariantAction>(
                  key: Key('variant-overflow-${variant.id}'),
                  tooltip: 'Actions for ${variant.name}',
                  icon: const Icon(Icons.more_vert),
                  onSelected: (action) =>
                      _variantAction(context, action, variant),
                  itemBuilder: (context) => _items(context, variant),
                ),
              ],
            ),
          );
        })
        .toList(growable: false),
  );

  List<PopupMenuEntry<_VariantAction>> _items(
    BuildContext context,
    ProductVariant variant,
  ) => variant.isArchived
      ? <PopupMenuEntry<_VariantAction>>[
          _item(
            _VariantAction.restore,
            context.l10n.commonRestore,
            Icons.restore,
          ),
        ]
      : <PopupMenuEntry<_VariantAction>>[
          _item(_VariantAction.edit, 'Edit Variant', Icons.edit_outlined),
          _item(
            _VariantAction.recipe,
            'Manage Recipe',
            Icons.receipt_long_outlined,
          ),
          _item(_VariantAction.pricing, 'Pricing', Icons.price_change_outlined),
          _item(
            _VariantAction.sellingHours,
            'Selling Hours',
            Icons.schedule_outlined,
          ),
          _item(
            _VariantAction.currentAvailability,
            'Current Availability',
            Icons.do_not_disturb_on_outlined,
          ),
          if (!variant.isDefault)
            _item(
              _VariantAction.setDefault,
              'Set as Default',
              Icons.star_outline,
            ),
          const PopupMenuDivider(),
          _item(
            variant.isActive
                ? _VariantAction.deactivate
                : _VariantAction.activate,
            variant.isActive
                ? context.l10n.commonDeactivate
                : context.l10n.commonActivate,
            variant.isActive
                ? Icons.pause_circle_outline
                : Icons.play_circle_outline,
          ),
          _item(
            _VariantAction.archive,
            context.l10n.commonArchive,
            Icons.archive_outlined,
          ),
        ];

  PopupMenuItem<_VariantAction> _item(
    _VariantAction action,
    String label,
    IconData icon,
  ) => PopupMenuItem<_VariantAction>(
    value: action,
    child: Row(
      children: <Widget>[
        Icon(icon, size: 18),
        const SizedBox(width: AppSpacing.sm),
        Text(label),
      ],
    ),
  );

  void _variantAction(
    BuildContext context,
    _VariantAction action,
    ProductVariant variant,
  ) {
    if (state.isMutating) return;
    switch (action) {
      case _VariantAction.edit:
        edit(variant);
      case _VariantAction.recipe:
        context.go(
          '/menu-management/product-variants/${variant.id}/recipe?productId=${state.product!.id}',
        );
      case _VariantAction.pricing:
        context.go(
          '/menu-management/products/${state.product!.id}/variants/${variant.id}/pricing',
        );
      case _VariantAction.sellingHours:
        context.go(
          '/menu-management/products/${state.product!.id}/availability?variantId=${variant.id}&from=variants',
        );
      case _VariantAction.currentAvailability:
        context.go(
          '/menu-management/products/${state.product!.id}/operational-availability?variantId=${variant.id}&from=variants',
        );
      case _VariantAction.setDefault:
        setDefault(variant);
      case _VariantAction.activate:
        activate(variant);
      case _VariantAction.deactivate:
        deactivate(variant);
      case _VariantAction.archive:
        archive(variant);
      case _VariantAction.restore:
        restore(variant);
    }
  }
}

enum _VariantAction {
  edit,
  recipe,
  pricing,
  sellingHours,
  currentAvailability,
  setDefault,
  activate,
  deactivate,
  archive,
  restore,
}

class _VariantBadge extends StatelessWidget {
  const _VariantBadge(this.label);
  final String label;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsetsDirectional.symmetric(
      horizontal: AppSpacing.sm,
      vertical: 2,
    ),
    decoration: BoxDecoration(
      color: AppColors.primarySoft,
      borderRadius: AppRadius.pillRadius,
    ),
    child: Text(
      label.toUpperCase(),
      style: Theme.of(context).textTheme.labelSmall?.copyWith(
        color: AppColors.primary,
        fontWeight: FontWeight.w700,
      ),
    ),
  );
}

class _VariantFact extends StatelessWidget {
  const _VariantFact(this.value, this.label, {this.ltr = false});
  final String value;
  final String label;
  final bool ltr;
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: <Widget>[
      Text(
        value,
        textDirection: ltr ? TextDirection.ltr : null,
        style: Theme.of(context).textTheme.titleSmall,
      ),
      Text(
        label,
        style: Theme.of(
          context,
        ).textTheme.bodySmall?.copyWith(color: AppColors.textSecondary),
      ),
    ],
  );
}

class _VariantStatus extends StatelessWidget {
  const _VariantStatus(this.label, this.icon, this.color);
  final String label;
  final IconData icon;
  final Color color;
  @override
  Widget build(BuildContext context) => Semantics(
    label: label,
    child: Row(
      children: <Widget>[
        Icon(icon, size: 16, color: color),
        const SizedBox(width: AppSpacing.xs),
        Flexible(
          child: Text(
            label,
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: color),
          ),
        ),
      ],
    ),
  );
}

class _ScreenIntroduction extends StatelessWidget {
  const _ScreenIntroduction({required this.title, required this.helper});
  final String title;
  final String helper;
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: <Widget>[
      Text(title, style: Theme.of(context).textTheme.headlineSmall),
      const SizedBox(height: AppSpacing.xs),
      Text(
        helper,
        style: Theme.of(
          context,
        ).textTheme.bodyMedium?.copyWith(color: AppColors.textSecondary),
      ),
    ],
  );
}

class _VariantEditorDialog extends StatefulWidget {
  const _VariantEditorDialog({this.variant});
  final ProductVariant? variant;
  @override
  State<_VariantEditorDialog> createState() => _VariantEditorDialogState();
}

class _VariantEditorDialogState extends State<_VariantEditorDialog> {
  late VariantEditorDraft _draft;
  bool _makeDefault = false;
  @override
  void initState() {
    super.initState();
    final ProductVariant? v = widget.variant;
    _draft = v == null
        ? const VariantEditorDraft()
        : VariantEditorDraft(
            name: v.name,
            nameAr: v.nameAr ?? '',
            nameEn: v.nameEn ?? '',
            sku: v.sku ?? '',
            barcode: v.barcode ?? '',
            basePrice: v.basePrice.toStringAsFixed(2),
            costPrice: v.costPrice?.toStringAsFixed(2) ?? '',
            isActive: v.isActive,
            sortOrder: v.sortOrder.toString(),
          );
  }

  @override
  Widget build(BuildContext context) =>
      BlocBuilder<VariantsCubit, VariantsState>(
        builder: (_, state) => AlertDialog(
          title: Text(widget.variant == null ? 'Add Variant' : 'Edit Variant'),
          content: SizedBox(
            width: 560,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  _field(
                    'Name',
                    _draft.name,
                    (v) => _set(_draft.copyWith(name: v)),
                    state.fieldErrors['name'],
                    required: true,
                  ),
                  _field(
                    'Arabic name',
                    _draft.nameAr,
                    (v) => _set(_draft.copyWith(nameAr: v)),
                    state.fieldErrors['nameAr'],
                  ),
                  _field(
                    'English name',
                    _draft.nameEn,
                    (v) => _set(_draft.copyWith(nameEn: v)),
                    state.fieldErrors['nameEn'],
                  ),
                  _field(
                    'SKU',
                    _draft.sku,
                    (v) => _set(_draft.copyWith(sku: v)),
                    state.fieldErrors['sku'],
                  ),
                  _field(
                    'Barcode',
                    _draft.barcode,
                    (v) => _set(_draft.copyWith(barcode: v)),
                    state.fieldErrors['barcode'],
                  ),
                  _field(
                    'Base Price',
                    _draft.basePrice,
                    (v) => _set(_draft.copyWith(basePrice: v)),
                    localizedConfiguredPriceError(
                      context,
                      state.fieldErrors['basePrice'],
                    ),
                    required: true,
                    decimal: true,
                  ),
                  _field(
                    'Cost Price',
                    _draft.costPrice,
                    (v) => _set(_draft.copyWith(costPrice: v)),
                    state.fieldErrors['costPrice'],
                    decimal: true,
                  ),
                  _field(
                    'Sort Order',
                    _draft.sortOrder,
                    (v) => _set(_draft.copyWith(sortOrder: v)),
                    state.fieldErrors['sortOrder'],
                    integer: true,
                  ),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Active status'),
                    value: _draft.isActive,
                    onChanged: (v) => _set(_draft.copyWith(isActive: v)),
                  ),
                  if (widget.variant == null)
                    CheckboxListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Make this the Default Variant'),
                      subtitle: const Text('A Default Variant must be active.'),
                      value: _makeDefault,
                      onChanged: _draft.isActive
                          ? (v) => setState(() => _makeDefault = v ?? false)
                          : null,
                    ),
                  if (state.formError != null) _ErrorBanner(state.formError!),
                ],
              ),
            ),
          ),
          actions: <Widget>[
            TextButton(
              onPressed: state.isMutating ? null : () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: state.isMutating ? null : _submit,
              child: Text(state.isMutating ? 'Saving...' : 'Save'),
            ),
          ],
        ),
      );
  Widget _field(
    String label,
    String value,
    ValueChanged<String> changed,
    String? error, {
    bool required = false,
    bool decimal = false,
    bool integer = false,
  }) => Padding(
    padding: const EdgeInsets.only(bottom: AppSpacing.sm),
    child: TextFormField(
      initialValue: value,
      onChanged: changed,
      keyboardType: decimal || integer
          ? const TextInputType.numberWithOptions(decimal: true)
          : null,
      inputFormatters: integer
          ? <TextInputFormatter>[FilteringTextInputFormatter.digitsOnly]
          : null,
      decoration: InputDecoration(
        labelText: required ? '$label *' : label,
        errorText: error,
      ),
    ),
  );
  void _set(VariantEditorDraft draft) => setState(() => _draft = draft);
  Future<void> _submit() async {
    final VariantsCubit cubit = context.read<VariantsCubit>();
    final bool success = widget.variant == null
        ? await cubit.create(_draft, makeDefault: _makeDefault)
        : await cubit.update(widget.variant!.id, _draft);
    if (success && mounted) Navigator.pop(context);
  }
}

class _ErrorBanner extends StatelessWidget {
  const _ErrorBanner(this.message);
  final String message;
  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: AppSpacing.allMd,
    color: AppColors.discountOrangeBadge,
    child: Text(message),
  );
}

class _Empty extends StatelessWidget {
  const _Empty({required this.filter});
  final VariantFilter filter;
  @override
  Widget build(BuildContext context) => Center(
    child: Text(
      filter == VariantFilter.archived
          ? 'No archived Variants.'
          : 'No Variants returned for this product.',
    ),
  );
}

class _Retry extends StatelessWidget {
  const _Retry({required this.message, required this.onRetry});
  final String message;
  final VoidCallback onRetry;
  @override
  Widget build(BuildContext context) => Column(
    mainAxisSize: MainAxisSize.min,
    children: <Widget>[
      Text(message),
      const SizedBox(height: AppSpacing.md),
      OutlinedButton(onPressed: onRetry, child: const Text('Retry')),
    ],
  );
}

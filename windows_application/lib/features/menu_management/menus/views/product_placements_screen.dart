// ignore_for_file: use_build_context_synchronously

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../app/localization/localization_extensions.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../shared/layouts/desktop_page_layout.dart';
import '../../models/catalog_models.dart';
import '../controllers/product_placements_cubit.dart';
import '../models/menu_models.dart';
import '../models/product_placement.dart';

/// A compact, section-first view over the bounded Menu Detail aggregate.
class ProductPlacementsScreen extends StatefulWidget {
  const ProductPlacementsScreen({
    super.key,
    required this.menuId,
    this.embedded = false,
    this.initialMenu,
    this.onAddSection,
  });

  final int menuId;
  final bool embedded;
  final MenuRecord? initialMenu;
  final Future<void> Function()? onAddSection;

  @override
  State<ProductPlacementsScreen> createState() =>
      _ProductPlacementsScreenState();
}

class _ProductPlacementsScreenState extends State<ProductPlacementsScreen> {
  bool _reorderMode = false;
  String _query = '';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final cubit = context.read<ProductPlacementsCubit>();
      widget.initialMenu == null
          ? cubit.load(widget.menuId)
          : cubit.hydrate(widget.initialMenu!);
    });
  }

  @override
  Widget build(BuildContext context) =>
      BlocConsumer<ProductPlacementsCubit, ProductPlacementsState>(
        listenWhen: (before, after) =>
            before.successMessage != after.successMessage ||
            before.errorMessage != after.errorMessage,
        listener: (_, state) {
          final message = state.successMessage ?? state.errorMessage;
          if (message != null) {
            ScaffoldMessenger.of(
              context,
            ).showSnackBar(SnackBar(content: Text(message)));
          }
        },
        builder: (context, state) {
          final menu = state.menu;
          if (menu == null) return _loadingOrError(context, state);
          final sections = [...menu.sections]
            ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
          final body = Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _ProductsHeader(
                reorderMode: _reorderMode,
                canAdd: !state.readOnly && sections.any(_sectionMutable),
                canReorder: !state.readOnly && sections.any(_sectionMutable),
                busy: state.isBusy,
                onAdd: () =>
                    _pick(context, sections.firstWhere(_sectionMutable).id),
                onReorder: () => setState(() => _reorderMode = true),
                onDone: () => setState(() => _reorderMode = false),
              ),
              const SizedBox(height: AppSpacing.md),
              if (menu.isArchived)
                _Notice(context.l10n.menuProductsArchivedMenuReadOnly),
              if (sections.isEmpty)
                _NoSections(
                  canAdd: !state.readOnly && !state.isBusy,
                  onAdd: widget.onAddSection,
                )
              else ...[
                TextField(
                  key: const Key('menu-products-search'),
                  onChanged: (value) => setState(() => _query = value.trim()),
                  decoration: InputDecoration(
                    isDense: true,
                    hintText: context.l10n.menuProductsSearchHint,
                    prefixIcon: const Icon(Icons.search_outlined, size: 20),
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                for (final section in sections)
                  _section(context, state, section, sections),
              ],
            ],
          );
          return widget.embedded
              ? body
              : DesktopPageLayout(child: SingleChildScrollView(child: body));
        },
      );

  Widget _loadingOrError(BuildContext context, ProductPlacementsState state) {
    final child = state.status == PlacementStatus.failure
        ? _CompositionError(
            onRetry: () =>
                context.read<ProductPlacementsCubit>().load(widget.menuId),
          )
        : const ProductCompositionSkeleton();
    return widget.embedded ? child : DesktopPageLayout(child: child);
  }

  Widget _section(
    BuildContext context,
    ProductPlacementsState state,
    MenuSectionRecord section,
    List<MenuSectionRecord> allSections,
  ) {
    final mutable = !state.readOnly && _sectionMutable(section);
    final all = [
      ...(state.placements[section.id] ?? const <ProductPlacement>[]),
    ]..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
    final shown = all.where(_matchesQuery).toList();
    final active = all.where((placement) => !placement.isArchived).toList();
    return Container(
      key: Key('composition-section-${section.id}'),
      margin: const EdgeInsets.only(bottom: AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border.all(color: AppColors.border),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          _SectionHeader(
            section: section,
            count: all.length,
            mutable: mutable,
            showAdd: !_reorderMode,
            busy: state.isBusy,
            onAdd: () => _pick(context, section.id),
          ),
          const Divider(height: 1),
          if (shown.isEmpty)
            _SectionEmpty(
              searching: _query.isNotEmpty && all.isNotEmpty,
              canAdd: mutable && !_reorderMode,
              onAdd: () => _pick(context, section.id),
            ),
          for (final placement in shown)
            _row(
              context,
              state,
              placement,
              active.indexWhere((item) => item.id == placement.id),
              active.length,
              mutable,
              allSections,
            ),
        ],
      ),
    );
  }

  Widget _row(
    BuildContext context,
    ProductPlacementsState state,
    ProductPlacement placement,
    int activeIndex,
    int activeCount,
    bool sectionMutable,
    List<MenuSectionRecord> sections,
  ) {
    final product = placement.product;
    final canMutate = sectionMutable && !placement.isArchived;
    final locale = Localizations.localeOf(context);
    final name = placement.displayNameOverride.isNotEmpty
        ? placement.displayNameOverride
        : product?.displayName(locale) ?? placement.displayName;
    final alternate = _alternateProductName(product, locale, name);
    return Container(
      key: Key('composition-product-${placement.id}'),
      constraints: const BoxConstraints(minHeight: 53),
      padding: const EdgeInsetsDirectional.only(start: 16, end: 8),
      decoration: BoxDecoration(
        color: placement.isArchived ? AppColors.surfaceAlt : null,
        border: const Border(bottom: BorderSide(color: AppColors.border)),
      ),
      child: Row(
        children: [
          if (_reorderMode) ...[
            const Icon(Icons.drag_handle_outlined, size: 18),
            const SizedBox(width: AppSpacing.sm),
          ],
          Expanded(
            child: Wrap(
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: AppSpacing.sm,
              runSpacing: 4,
              children: [
                Text(
                  name,
                  key: Key('composition-product-name-${placement.id}'),
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: placement.isArchived ? AppColors.textMuted : null,
                  ),
                ),
                if (alternate.isNotEmpty)
                  Text(
                    alternate,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                for (final badge in _badges(context, placement))
                  _StateBadge(label: badge),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Text(
            context.l10n.menuProductsBasePrice(
              product?.defaultVariant?.basePrice.toString() ?? '—',
            ),
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: AppColors.textSecondary),
          ),
          const SizedBox(width: 4),
          if (_reorderMode)
            _OrderingButtons(
              upEnabled: !state.isBusy && canMutate && activeIndex > 0,
              downEnabled:
                  !state.isBusy &&
                  canMutate &&
                  activeIndex >= 0 &&
                  activeIndex < activeCount - 1,
              onUp: () => context.read<ProductPlacementsCubit>().reorder(
                placement.sectionId,
                activeIndex,
                activeIndex - 1,
              ),
              onDown: () => context.read<ProductPlacementsCubit>().reorder(
                placement.sectionId,
                activeIndex,
                activeIndex + 1,
              ),
            )
          else
            PopupMenuButton<String>(
              key: Key('placement-actions-${placement.id}'),
              tooltip: context.l10n.menuProductsActions,
              onSelected: (value) =>
                  _action(context, value, placement, sections),
              itemBuilder: (_) => _actionItems(
                context,
                placement,
                canMutate,
                !state.readOnly && sectionMutable && placement.isArchived,
              ),
            ),
        ],
      ),
    );
  }

  Future<void> _pick(BuildContext context, int sectionId) async {
    final cubit = context.read<ProductPlacementsCubit>();
    final rtl = Directionality.of(context) == TextDirection.rtl;
    await showGeneralDialog<void>(
      context: context,
      barrierDismissible: true,
      barrierLabel: context.l10n.commonClose,
      barrierColor: Colors.black38,
      transitionDuration: const Duration(milliseconds: 180),
      pageBuilder: (_, _, _) => BlocProvider.value(
        value: cubit,
        child: _ProductPicker(initialSectionId: sectionId),
      ),
      transitionBuilder: (_, animation, _, child) => SlideTransition(
        position: Tween<Offset>(
          begin: Offset(rtl ? -.08 : .08, 0),
          end: Offset.zero,
        ).animate(CurvedAnimation(parent: animation, curve: Curves.easeOut)),
        child: FadeTransition(opacity: animation, child: child),
      ),
    );
  }

  Future<void> _action(
    BuildContext context,
    String action,
    ProductPlacement placement,
    List<MenuSectionRecord> sections,
  ) async {
    final cubit = context.read<ProductPlacementsCubit>();
    if (action == 'move') {
      final target = await showDialog<int>(
        context: context,
        builder: (_) => _Move(placement, sections),
      );
      if (target != null && context.mounted) {
        await cubit.move(placement, target);
      }
      return;
    }
    if (action == 'feature' || action == 'unfeature') {
      await cubit.update(
        placement.id,
        _draft(placement, featured: action == 'feature'),
      );
      return;
    }
    if (action == 'show' || action == 'hide') {
      await cubit.update(
        placement.id,
        _draft(placement, visible: action == 'show'),
      );
      return;
    }
    if (action == 'archive' && await _confirm(context, archive: true)) {
      await cubit.archive(placement.id);
    }
    if (action == 'restore' && await _confirm(context, archive: false)) {
      await cubit.restore(placement.id);
    }
  }

  ProductPlacementDraft _draft(
    ProductPlacement placement, {
    bool? featured,
    bool? visible,
  }) => ProductPlacementDraft(
    displayNameOverride: placement.displayNameOverride,
    displayDescriptionOverride: placement.displayDescriptionOverride,
    displayImageOverride: placement.displayImageOverride,
    sortOrder: placement.sortOrder,
    isFeatured: featured ?? placement.isFeatured,
    isVisible: visible ?? placement.isVisible,
  );

  bool _matchesQuery(ProductPlacement placement) {
    if (_query.isEmpty) return true;
    final query = _query.toLowerCase();
    final product = placement.product;
    return <String>[
      placement.displayNameOverride,
      product?.name ?? '',
      product?.nameAr ?? '',
      product?.nameEn ?? '',
    ].any((value) => value.toLowerCase().contains(query));
  }

  bool _sectionMutable(MenuSectionRecord section) =>
      !section.isArchived && section.isActive;

  List<String> _badges(BuildContext context, ProductPlacement placement) {
    final product = placement.product;
    final l10n = context.l10n;
    return [
      if (placement.isArchived) l10n.menuProductsArchivedPlacement,
      if (product?.isArchived == true) l10n.menuProductsArchivedProduct,
      if (product?.isActive == false && product?.isArchived != true)
        l10n.menuProductsInactive,
      if (!placement.isArchived && placement.isFeatured)
        l10n.menuProductsFeatured,
      if (!placement.isArchived && !placement.isVisible)
        l10n.menuProductsHidden,
    ];
  }

  List<PopupMenuEntry<String>> _actionItems(
    BuildContext context,
    ProductPlacement placement,
    bool canMutate,
    bool canRestore,
  ) {
    final l10n = context.l10n;
    if (placement.isArchived) {
      return [
        if (canRestore)
          PopupMenuItem(
            value: 'restore',
            child: Text(l10n.menuProductsRestore),
          ),
      ];
    }
    if (!canMutate) return const [];
    return [
      PopupMenuItem(
        value: placement.isFeatured ? 'unfeature' : 'feature',
        child: Text(
          placement.isFeatured
              ? l10n.menuProductsRemoveFeatured
              : l10n.menuProductsMarkFeatured,
        ),
      ),
      PopupMenuItem(
        value: placement.isVisible ? 'hide' : 'show',
        child: Text(
          placement.isVisible ? l10n.menuProductsHide : l10n.menuProductsShow,
        ),
      ),
      PopupMenuItem(value: 'move', child: Text(l10n.menuProductsMove)),
      PopupMenuItem(
        value: 'archive',
        child: Text(
          l10n.menuProductsRemove,
          style: const TextStyle(color: AppColors.danger),
        ),
      ),
    ];
  }
}

class _ProductsHeader extends StatelessWidget {
  const _ProductsHeader({
    required this.reorderMode,
    required this.canAdd,
    required this.canReorder,
    required this.busy,
    required this.onAdd,
    required this.onReorder,
    required this.onDone,
  });
  final bool reorderMode, canAdd, canReorder, busy;
  final VoidCallback onAdd, onReorder, onDone;
  @override
  Widget build(BuildContext context) => Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              reorderMode
                  ? context.l10n.menuProductsReorder
                  : context.l10n.menuProductsTitle,
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 3),
            Text(
              reorderMode
                  ? context.l10n.menuProductsReorderHelp
                  : context.l10n.menuProductsHelp,
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: AppColors.textSecondary),
            ),
          ],
        ),
      ),
      const SizedBox(width: AppSpacing.sm),
      if (reorderMode)
        FilledButton(
          key: const Key('menu-products-reorder-done'),
          onPressed: onDone,
          child: Text(context.l10n.menuProductsDone),
        )
      else ...[
        if (canReorder)
          OutlinedButton(
            key: const Key('menu-products-reorder'),
            onPressed: busy ? null : onReorder,
            child: Text(context.l10n.menuProductsReorder),
          ),
        if (canReorder) const SizedBox(width: AppSpacing.sm),
        if (canAdd)
          FilledButton.icon(
            key: const Key('menu-products-add'),
            onPressed: busy ? null : onAdd,
            icon: const Icon(Icons.add, size: 18),
            label: Text(context.l10n.menuProductsAdd),
          ),
      ],
    ],
  );
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({
    required this.section,
    required this.count,
    required this.mutable,
    required this.showAdd,
    required this.busy,
    required this.onAdd,
  });
  final MenuSectionRecord section;
  final int count;
  final bool mutable, showAdd, busy;
  final VoidCallback onAdd;
  @override
  Widget build(BuildContext context) {
    final locale = Localizations.localeOf(context);
    final primary = section.displayName(locale);
    final alternate = locale.languageCode == 'ar'
        ? section.nameEn
        : section.nameAr;
    return SizedBox(
      height: 48,
      child: Padding(
        padding: const EdgeInsetsDirectional.only(start: 16, end: 8),
        child: Row(
          children: [
            Expanded(
              child: Row(
                children: [
                  Flexible(
                    child: Text(
                      primary,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  if (alternate.isNotEmpty && alternate != primary) ...[
                    const SizedBox(width: AppSpacing.sm),
                    Flexible(
                      child: Text(
                        alternate,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            Text(
              context.l10n.menuProductsCount(count),
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: AppColors.textSecondary),
            ),
            if (mutable && showAdd)
              IconButton(
                tooltip: context.l10n.menuProductsAdd,
                onPressed: busy ? null : onAdd,
                icon: const Icon(Icons.add, size: 18),
              ),
          ],
        ),
      ),
    );
  }
}

class _OrderingButtons extends StatelessWidget {
  const _OrderingButtons({
    required this.upEnabled,
    required this.downEnabled,
    required this.onUp,
    required this.onDown,
  });
  final bool upEnabled, downEnabled;
  final VoidCallback onUp, onDown;
  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      IconButton(
        key: const Key('placement-move-up'),
        tooltip: context.l10n.menuProductsMoveUp,
        onPressed: upEnabled ? onUp : null,
        icon: const Icon(Icons.arrow_upward_outlined, size: 18),
      ),
      IconButton(
        key: const Key('placement-move-down'),
        tooltip: context.l10n.menuProductsMoveDown,
        onPressed: downEnabled ? onDown : null,
        icon: const Icon(Icons.arrow_downward_outlined, size: 18),
      ),
    ],
  );
}

class _StateBadge extends StatelessWidget {
  const _StateBadge({required this.label});
  final String label;
  @override
  Widget build(BuildContext context) {
    final featured = label == context.l10n.menuProductsFeatured;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: featured ? AppColors.discountOrangeBadge : AppColors.surfaceAlt,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
          color: featured ? AppColors.discountOrangeText : AppColors.textMuted,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _SectionEmpty extends StatelessWidget {
  const _SectionEmpty({
    required this.searching,
    required this.canAdd,
    required this.onAdd,
  });
  final bool searching, canAdd;
  final VoidCallback onAdd;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
    child: Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            searching
                ? context.l10n.menuProductsNoMatches
                : context.l10n.menuProductsEmpty,
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: AppColors.textSecondary),
          ),
          if (canAdd && !searching) ...[
            const SizedBox(height: AppSpacing.sm),
            FilledButton.icon(
              onPressed: onAdd,
              icon: const Icon(Icons.add, size: 18),
              label: Text(context.l10n.menuProductsAdd),
            ),
          ],
        ],
      ),
    ),
  );
}

class _NoSections extends StatelessWidget {
  const _NoSections({required this.canAdd, this.onAdd});
  final bool canAdd;
  final Future<void> Function()? onAdd;
  @override
  Widget build(BuildContext context) => Container(
    key: const Key('menu-products-no-sections'),
    width: double.infinity,
    padding: const EdgeInsets.all(AppSpacing.xl),
    decoration: BoxDecoration(
      border: Border.all(color: AppColors.border),
      borderRadius: BorderRadius.circular(12),
    ),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          context.l10n.menuProductsNoSections,
          style: Theme.of(
            context,
          ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: AppSpacing.xs),
        Text(context.l10n.menuProductsNoSectionsHelp),
        if (canAdd && onAdd != null) ...[
          const SizedBox(height: AppSpacing.md),
          FilledButton.icon(
            onPressed: onAdd,
            icon: const Icon(Icons.add, size: 18),
            label: Text(context.l10n.menuSectionsAdd),
          ),
        ],
      ],
    ),
  );
}

class _Notice extends StatelessWidget {
  const _Notice(this.text);
  final String text;
  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    margin: const EdgeInsets.only(bottom: AppSpacing.md),
    padding: const EdgeInsets.all(AppSpacing.md),
    decoration: BoxDecoration(
      color: AppColors.surfaceAlt,
      borderRadius: BorderRadius.circular(8),
    ),
    child: Text(text, style: Theme.of(context).textTheme.bodySmall),
  );
}

class _CompositionError extends StatelessWidget {
  const _CompositionError({required this.onRetry});
  final VoidCallback onRetry;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 48),
    child: Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.cloud_off_outlined, size: 32),
          const SizedBox(height: AppSpacing.sm),
          Text(context.l10n.menuProductsLoadError),
          TextButton(onPressed: onRetry, child: Text(context.l10n.commonRetry)),
        ],
      ),
    ),
  );
}

class ProductCompositionSkeleton extends StatelessWidget {
  const ProductCompositionSkeleton({super.key});
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Container(width: 110, height: 24, color: AppColors.surfaceAlt),
      const SizedBox(height: AppSpacing.xs),
      Container(width: 300, height: 14, color: AppColors.surfaceAlt),
      const SizedBox(height: AppSpacing.lg),
      for (var group = 0; group < 3; group++) ...[
        Container(
          height: 48,
          decoration: BoxDecoration(
            color: AppColors.surfaceAlt,
            borderRadius: BorderRadius.circular(10),
          ),
        ),
        const SizedBox(height: 1),
        Container(height: 53, color: AppColors.surfaceAlt),
        const SizedBox(height: 1),
        Container(height: 53, color: AppColors.surfaceAlt),
        const SizedBox(height: AppSpacing.md),
      ],
    ],
  );
}

// Screen 6 owns this picker workflow. It is deliberately preserved here.
class _ProductPicker extends StatefulWidget {
  const _ProductPicker({required this.initialSectionId});
  final int initialSectionId;
  @override
  State<_ProductPicker> createState() => _ProductPickerState();
}

class _ProductPickerState extends State<_ProductPicker> {
  final _search = TextEditingController();
  final _selected = <int>{};
  Timer? _debounce;
  late int _sectionId = widget.initialSectionId;
  bool _submitting = false;
  String? _resultMessage;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => context.read<ProductPlacementsCubit>().searchProducts(
        '',
        sectionId: _sectionId,
      ),
    );
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final window = MediaQuery.sizeOf(context);
    return Align(
      alignment: AlignmentDirectional.centerEnd,
      child: Material(
        color: AppColors.surface,
        child: SafeArea(
          child: SizedBox(
            key: const Key('menu-products-picker-sheet'),
            width: window.width < 480 ? window.width : 480,
            height: window.height,
            child: BlocBuilder<ProductPlacementsCubit, ProductPlacementsState>(
              builder: _buildSheet,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSheet(BuildContext context, ProductPlacementsState state) {
    final sections =
        (state.menu?.sections ?? const <MenuSectionRecord>[])
            .where((section) => !section.isArchived && section.isActive)
            .toList()
          ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
    if (!sections.any((section) => section.id == _sectionId) &&
        sections.isNotEmpty) {
      _sectionId = sections.first.id;
    }
    final section = sections.cast<MenuSectionRecord?>().firstWhere(
      (candidate) => candidate?.id == _sectionId,
      orElse: () => null,
    );
    final placedIds =
        (state.placements[_sectionId] ?? const <ProductPlacement>[])
            .where((placement) => !placement.isArchived)
            .map((placement) => placement.productId)
            .toSet();
    final products = state.pickerProducts;
    final allUnavailable =
        products.isNotEmpty &&
        products.every((product) => placedIds.contains(product.id));
    final l10n = context.l10n;
    final selectedCount = _selected
        .where((id) => !placedIds.contains(id))
        .length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsetsDirectional.fromSTEB(24, 18, 16, 14),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  l10n.menuProductsPickerTitle,
                  style: Theme.of(
                    context,
                  ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
                ),
              ),
              IconButton(
                tooltip: l10n.commonClose,
                onPressed: _submitting
                    ? null
                    : () => Navigator.of(context).pop(),
                icon: const Icon(Icons.close, size: 20),
              ),
            ],
          ),
        ),
        const Divider(height: 1),
        Padding(
          padding: const EdgeInsetsDirectional.fromSTEB(24, 16, 24, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                l10n.menuProductsPickerTargetSection,
                style: Theme.of(
                  context,
                ).textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: AppSpacing.xs),
              DropdownButtonFormField<int>(
                key: const Key('menu-products-picker-section'),
                initialValue: section?.id,
                isExpanded: true,
                onChanged: _submitting || sections.isEmpty
                    ? null
                    : (value) => _changeSection(value, state),
                items: [
                  for (final item in sections)
                    DropdownMenuItem<int>(
                      value: item.id,
                      child: Text(
                        item.displayName(Localizations.localeOf(context)),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                ],
                decoration: const InputDecoration(isDense: true),
              ),
              const SizedBox(height: AppSpacing.md),
              TextField(
                key: const Key('menu-products-picker-search'),
                controller: _search,
                enabled: !_submitting,
                textInputAction: TextInputAction.search,
                onChanged: _searchChanged,
                onSubmitted: (_) => _runSearch(),
                decoration: InputDecoration(
                  isDense: true,
                  hintText: l10n.menuProductsPickerSearchHint,
                  prefixIcon: const Icon(Icons.search_outlined, size: 20),
                ),
              ),
              if (_resultMessage != null) ...[
                const SizedBox(height: AppSpacing.sm),
                _PickerNotice(text: _resultMessage!),
              ],
              if (state.pickerErrorMessage != null) ...[
                const SizedBox(height: AppSpacing.sm),
                _PickerRetryNotice(onRetry: _runSearch),
              ],
            ],
          ),
        ),
        Expanded(
          child: Padding(
            padding: const EdgeInsetsDirectional.fromSTEB(24, 4, 24, 12),
            child: DecoratedBox(
              decoration: BoxDecoration(
                border: Border.all(color: AppColors.border),
                borderRadius: BorderRadius.circular(8),
              ),
              child: _productList(
                context,
                state,
                products,
                placedIds,
                allUnavailable,
              ),
            ),
          ),
        ),
        const Divider(height: 1),
        Padding(
          padding: const EdgeInsetsDirectional.fromSTEB(24, 12, 24, 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                l10n.menuProductsPickerSelected(selectedCount),
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: AppColors.textSecondary,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: _submitting
                          ? null
                          : () => Navigator.of(context).pop(),
                      child: Text(l10n.commonCancel),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: FilledButton(
                      key: const Key('menu-products-picker-submit'),
                      onPressed:
                          selectedCount == 0 || _submitting || section == null
                          ? null
                          : _submit,
                      child: _submitting
                          ? const SizedBox(
                              height: 18,
                              width: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : Text(l10n.menuProductsAdd),
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

  Widget _productList(
    BuildContext context,
    ProductPlacementsState state,
    List<ProductSummary> products,
    Set<int> placedIds,
    bool allUnavailable,
  ) {
    if (state.pickerLoading && products.isEmpty) {
      return const _ProductPickerSkeleton();
    }
    if (products.isEmpty) {
      return _PickerMessage(text: context.l10n.menuProductsPickerNoMatches);
    }
    if (allUnavailable) {
      return _PickerMessage(text: context.l10n.menuProductsPickerNoEligible);
    }
    final locale = Localizations.localeOf(context);
    return ListView.separated(
      key: const Key('menu-products-picker-list'),
      itemCount: products.length,
      separatorBuilder: (_, _) => const Divider(height: 1),
      itemBuilder: (context, index) {
        final product = products[index];
        final unavailable = placedIds.contains(product.id);
        final primary = product.displayName(locale);
        final secondary = locale.languageCode == 'ar'
            ? product.nameEn
            : product.nameAr;
        return Semantics(
          label: unavailable
              ? context.l10n.menuProductsPickerAlreadyInSection(
                  _sectionName(context),
                )
              : primary,
          enabled: !unavailable && !_submitting,
          child: InkWell(
            onTap: unavailable || _submitting
                ? null
                : () => _toggle(product.id),
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 56),
              child: Padding(
                padding: const EdgeInsetsDirectional.fromSTEB(10, 8, 14, 8),
                child: Row(
                  children: [
                    Checkbox(
                      value: _selected.contains(product.id) && !unavailable,
                      onChanged: unavailable || _submitting
                          ? null
                          : (_) => _toggle(product.id),
                    ),
                    const SizedBox(width: AppSpacing.xs),
                    Expanded(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            primary,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context).textTheme.bodyMedium
                                ?.copyWith(
                                  color: unavailable
                                      ? AppColors.textMuted
                                      : AppColors.textPrimary,
                                  fontWeight: FontWeight.w700,
                                ),
                          ),
                          if (unavailable)
                            Text(
                              context.l10n.menuProductsPickerAlreadyInSection(
                                _sectionName(context),
                              ),
                              overflow: TextOverflow.ellipsis,
                              style: Theme.of(context).textTheme.bodySmall
                                  ?.copyWith(color: AppColors.textMuted),
                            )
                          else if (secondary != null &&
                              secondary.isNotEmpty &&
                              secondary != primary)
                            Text(
                              secondary,
                              overflow: TextOverflow.ellipsis,
                              style: Theme.of(context).textTheme.bodySmall
                                  ?.copyWith(color: AppColors.textSecondary),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  void _changeSection(int? value, ProductPlacementsState state) {
    if (value == null || value == _sectionId) return;
    final placed = (state.placements[value] ?? const <ProductPlacement>[])
        .where((placement) => !placement.isArchived)
        .map((placement) => placement.productId)
        .toSet();
    setState(() {
      _sectionId = value;
      _selected.removeWhere(placed.contains);
      _resultMessage = null;
    });
  }

  void _searchChanged(String _) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), _runSearch);
  }

  void _runSearch() => context.read<ProductPlacementsCubit>().searchProducts(
    _search.text.trim(),
    sectionId: _sectionId,
  );

  void _toggle(int productId) => setState(() {
    _selected.contains(productId)
        ? _selected.remove(productId)
        : _selected.add(productId);
  });

  String _sectionName(BuildContext context) {
    for (final section
        in context.read<ProductPlacementsCubit>().state.menu?.sections ??
            const <MenuSectionRecord>[]) {
      if (section.id == _sectionId) {
        return section.displayName(Localizations.localeOf(context));
      }
    }
    return '';
  }

  Future<void> _submit() async {
    if (_submitting || _selected.isEmpty) return;
    setState(() {
      _submitting = true;
      _resultMessage = null;
    });
    final result = await context.read<ProductPlacementsCubit>().createMany(
      _sectionId,
      _selected.toList(growable: false),
    );
    if (!mounted) return;
    if (result.fullySucceeded) {
      Navigator.of(context).pop();
      return;
    }
    final l10n = context.l10n;
    setState(() {
      _submitting = false;
      _selected
        ..clear()
        ..addAll(result.failedProductIds);
      _resultMessage = result.refreshFailed
          ? l10n.menuProductsPickerLoadError
          : result.conflictedProductIds.isNotEmpty &&
                result.failedProductIds.length ==
                    result.conflictedProductIds.length
          ? l10n.menuProductsPickerConflict(_sectionName(context))
          : l10n.menuProductsPickerPartialAdded(
              result.successfulProductIds.length,
              result.failedProductIds.length,
            );
    });
  }
}

class _PickerNotice extends StatelessWidget {
  const _PickerNotice({required this.text});
  final String text;
  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(AppSpacing.sm),
    decoration: BoxDecoration(
      color: AppColors.surfaceAlt,
      borderRadius: BorderRadius.circular(6),
    ),
    child: Text(text, style: Theme.of(context).textTheme.bodySmall),
  );
}

class _PickerRetryNotice extends StatelessWidget {
  const _PickerRetryNotice({required this.onRetry});
  final VoidCallback onRetry;
  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: const EdgeInsetsDirectional.fromSTEB(8, 4, 4, 4),
    decoration: BoxDecoration(
      color: AppColors.surfaceAlt,
      borderRadius: BorderRadius.circular(6),
    ),
    child: Row(
      children: [
        Expanded(
          child: Text(
            context.l10n.menuProductsPickerLoadError,
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ),
        TextButton(onPressed: onRetry, child: Text(context.l10n.commonRetry)),
      ],
    ),
  );
}

class _PickerMessage extends StatelessWidget {
  const _PickerMessage({required this.text});
  final String text;
  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: AppSpacing.allLg,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            text,
            textAlign: TextAlign.center,
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: AppColors.textSecondary),
          ),
        ],
      ),
    ),
  );
}

class _ProductPickerSkeleton extends StatelessWidget {
  const _ProductPickerSkeleton();
  @override
  Widget build(BuildContext context) => ListView.separated(
    itemCount: 7,
    separatorBuilder: (_, _) => const Divider(height: 1),
    itemBuilder: (_, _) => const Padding(
      padding: EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      child: Row(
        children: [
          SizedBox(
            width: 18,
            height: 18,
            child: DecoratedBox(
              decoration: BoxDecoration(color: AppColors.surfaceAlt),
            ),
          ),
          SizedBox(width: 12),
          Expanded(
            child: SizedBox(
              height: 14,
              child: DecoratedBox(
                decoration: BoxDecoration(color: AppColors.surfaceAlt),
              ),
            ),
          ),
        ],
      ),
    ),
  );
}

class _Move extends StatelessWidget {
  const _Move(this.placement, this.sections);
  final ProductPlacement placement;
  final List<MenuSectionRecord> sections;
  @override
  Widget build(BuildContext context) {
    final eligible = sections.where(
      (section) =>
          section.id != placement.sectionId &&
          !section.isArchived &&
          section.isActive,
    );
    return AlertDialog(
      title: Text(context.l10n.menuProductsMove),
      content: SizedBox(
        width: 400,
        child: ListView(
          shrinkWrap: true,
          children: [
            for (final section in eligible)
              ListTile(
                title: Text(
                  section.displayName(Localizations.localeOf(context)),
                ),
                onTap: () => Navigator.pop(context, section.id),
              ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(context.l10n.commonCancel),
        ),
      ],
    );
  }
}

Future<bool> _confirm(BuildContext context, {required bool archive}) async =>
    await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(
          archive
              ? context.l10n.menuProductsRemove
              : context.l10n.menuProductsRestore,
        ),
        content: Text(
          archive
              ? context.l10n.menuProductsRemoveHelp
              : context.l10n.menuProductsRestoreHelp,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(context.l10n.commonCancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(
              archive
                  ? context.l10n.menuProductsRemove
                  : context.l10n.menuProductsRestore,
            ),
          ),
        ],
      ),
    ) ??
    false;

String _alternateProductName(
  ProductSummary? product,
  Locale locale,
  String primary,
) {
  if (product == null) return '';
  final alternate = locale.languageCode == 'ar'
      ? product.nameEn ?? ''
      : product.nameAr ?? '';
  return alternate == primary ? '' : alternate;
}

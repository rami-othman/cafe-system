import 'package:flutter/material.dart';

import '../../../../app/localization/localization_extensions.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/utils/currency_formatter.dart';
import '../../../../shared/widgets/app_card.dart';
import '../controllers/menu_review_cubit.dart';
import '../models/review_models.dart';

class MenuPreviewPanel extends StatefulWidget {
  const MenuPreviewPanel({
    super.key,
    required this.state,
    required this.cubit,
    required this.onReviewReadiness,
    required this.onAssignments,
  });

  final MenuReviewState state;
  final MenuReviewCubit cubit;
  final VoidCallback onReviewReadiness;
  final VoidCallback onAssignments;

  @override
  State<MenuPreviewPanel> createState() => _MenuPreviewPanelState();
}

class _MenuPreviewPanelState extends State<MenuPreviewPanel> {
  String? _scopeKey;
  final Set<String> _expandedProducts = <String>{};

  @override
  void didUpdateWidget(covariant MenuPreviewPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    final String? nextScope = widget.state.publishingScopeKey;
    if (_scopeKey != null && nextScope != _scopeKey) {
      _expandedProducts.clear();
    }
    _scopeKey = nextScope;
  }

  void _changeLanguage(String value) {
    if (value == widget.state.language) return;
    widget.cubit.setLanguage(value);
    widget.cubit.preview();
  }

  void _changeHidden(bool value) {
    if (value == widget.state.includeHidden) return;
    widget.cubit.setIncludeHidden(value);
    widget.cubit.preview();
  }

  void _changeUnavailable(bool value) {
    if (value == widget.state.includeUnavailable) return;
    widget.cubit.setIncludeUnavailable(value);
    widget.cubit.preview();
  }

  void _changeExpandedProduct(String id, bool expanded) {
    if (_expandedProducts.contains(id) == expanded) return;

    // ExpansionTile can restore PageStorage state while its widget subtree is
    // building. Defer the parent state update until that frame has completed.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _expandedProducts.contains(id) == expanded) return;
      setState(() {
        if (expanded) {
          _expandedProducts.add(id);
        } else {
          _expandedProducts.remove(id);
        }
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    final MenuReviewState state = widget.state;
    final ResolvedPreview? preview = state.preview;
    return CustomScrollView(
      key: const PageStorageKey<String>('menu-review-preview'),
      slivers: <Widget>[
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.only(top: AppSpacing.md),
            child: _PreviewControls(
              state: state,
              onLanguageChanged: _changeLanguage,
              onHiddenChanged: _changeHidden,
              onUnavailableChanged: _changeUnavailable,
              onRefresh: state.previewStatus == ReviewRequestStatus.loading
                  ? null
                  : widget.cubit.preview,
            ),
          ),
        ),
        if (preview != null && !preview.canPublish)
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.only(top: AppSpacing.md),
              child: _PreviewValidationBanner(
                onReviewReadiness: widget.onReviewReadiness,
              ),
            ),
          ),
        if (state.previewStatus == ReviewRequestStatus.loading)
          const SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.only(top: AppSpacing.md),
              child: _PreviewLoadingSkeleton(),
            ),
          )
        else if (state.previewStatus == ReviewRequestStatus.failure)
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.only(top: AppSpacing.md),
              child: _PreviewError(
                message: state.previewError,
                onRetry: widget.cubit.preview,
              ),
            ),
          )
        else if (preview == null)
          const SliverToBoxAdapter(child: SizedBox.shrink())
        else if (preview.menus.isEmpty)
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.only(top: AppSpacing.md),
              child: _NoMenusPreview(onAssignments: widget.onAssignments),
            ),
          )
        else
          SliverPadding(
            padding: const EdgeInsets.only(top: AppSpacing.md),
            sliver: SliverList.builder(
              itemCount: preview.menus.length,
              itemBuilder: (BuildContext context, int index) =>
                  _PreviewMenuCard(
                    key: ValueKey<String>(
                      'preview-menu-${preview.menus[index].id}',
                    ),
                    menu: preview.menus[index],
                    currencyCode: state.selectedBranch?.currency ?? 'SYP',
                    expandedProducts: _expandedProducts,
                    onExpansionChanged: _changeExpandedProduct,
                  ),
            ),
          ),
        const SliverToBoxAdapter(child: SizedBox(height: AppSpacing.lg)),
      ],
    );
  }
}

class _PreviewControls extends StatelessWidget {
  const _PreviewControls({
    required this.state,
    required this.onLanguageChanged,
    required this.onHiddenChanged,
    required this.onUnavailableChanged,
    required this.onRefresh,
  });

  final MenuReviewState state;
  final ValueChanged<String> onLanguageChanged;
  final ValueChanged<bool> onHiddenChanged;
  final ValueChanged<bool> onUnavailableChanged;
  final VoidCallback? onRefresh;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return AppCard(
      child: LayoutBuilder(
        builder: (BuildContext context, BoxConstraints constraints) => Wrap(
          spacing: AppSpacing.md,
          runSpacing: AppSpacing.sm,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: <Widget>[
            ConstrainedBox(
              constraints: BoxConstraints(
                maxWidth: constraints.maxWidth > 700
                    ? 270
                    : constraints.maxWidth,
              ),
              child: Text(
                l10n.reviewPreviewContext,
                style: const TextStyle(color: AppColors.textSecondary),
              ),
            ),
            SizedBox(
              width: 174,
              child: DropdownButtonFormField<String>(
                key: const Key('preview-language'),
                initialValue: state.language,
                isDense: true,
                decoration: InputDecoration(
                  labelText: l10n.reviewPreviewLanguage,
                ),
                items: <DropdownMenuItem<String>>[
                  DropdownMenuItem(
                    value: 'default',
                    child: Text(l10n.reviewPreviewLanguageDefault),
                  ),
                  DropdownMenuItem(
                    value: 'ar',
                    child: Text(l10n.reviewPreviewLanguageArabic),
                  ),
                  DropdownMenuItem(
                    value: 'en',
                    child: Text(l10n.reviewPreviewLanguageEnglish),
                  ),
                ],
                onChanged: (String? value) {
                  if (value != null) onLanguageChanged(value);
                },
              ),
            ),
            FilterChip(
              key: const Key('preview-hidden-toggle'),
              label: Text(l10n.reviewPreviewShowHidden),
              selected: state.includeHidden,
              onSelected: onHiddenChanged,
            ),
            FilterChip(
              key: const Key('preview-unavailable-toggle'),
              label: Text(l10n.reviewPreviewShowUnavailable),
              selected: state.includeUnavailable,
              onSelected: onUnavailableChanged,
            ),
            OutlinedButton.icon(
              key: const Key('refresh-preview'),
              onPressed: onRefresh,
              icon: const Icon(Icons.refresh),
              label: Text(l10n.reviewPreviewRefresh),
            ),
          ],
        ),
      ),
    );
  }
}

class _PreviewValidationBanner extends StatelessWidget {
  const _PreviewValidationBanner({required this.onReviewReadiness});
  final VoidCallback onReviewReadiness;

  @override
  Widget build(BuildContext context) => AppCard(
    child: Row(
      children: <Widget>[
        const Icon(Icons.info_outline, color: AppColors.warning),
        const SizedBox(width: AppSpacing.sm),
        Expanded(child: Text(context.l10n.reviewPreviewBlockingBanner)),
        TextButton(
          onPressed: onReviewReadiness,
          child: Text(context.l10n.reviewPreviewReviewReadiness),
        ),
      ],
    ),
  );
}

class _PreviewMenuCard extends StatelessWidget {
  const _PreviewMenuCard({
    super.key,
    required this.menu,
    required this.currencyCode,
    required this.expandedProducts,
    required this.onExpansionChanged,
  });

  final ResolvedMenu menu;
  final String currencyCode;
  final Set<String> expandedProducts;
  final void Function(String id, bool expanded) onExpansionChanged;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return AppCard(
      margin: const EdgeInsets.only(bottom: AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              _OrderMarker(value: menu.priority + 1),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: _BackendText(
                  menu.name,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              _PreviewStatusBadge(
                label: menu.isScheduledAvailable
                    ? l10n.reviewPreviewAvailableNow
                    : l10n.reviewPreviewOutsideScheduledHours,
                tone: menu.isScheduledAvailable
                    ? _StatusTone.good
                    : _StatusTone.warning,
              ),
            ],
          ),
          if (menu.description.isNotEmpty) ...<Widget>[
            const SizedBox(height: 4),
            _BackendText(
              menu.description,
              style: const TextStyle(color: AppColors.textSecondary),
            ),
          ],
          const SizedBox(height: AppSpacing.sm),
          for (final ResolvedSection section in menu.sections)
            _PreviewSection(
              section: section,
              menuId: menu.id,
              currencyCode: currencyCode,
              expandedProducts: expandedProducts,
              onExpansionChanged: onExpansionChanged,
            ),
        ],
      ),
    );
  }
}

class _PreviewSection extends StatelessWidget {
  const _PreviewSection({
    required this.section,
    required this.menuId,
    required this.currencyCode,
    required this.expandedProducts,
    required this.onExpansionChanged,
  });

  final ResolvedSection section;
  final int menuId;
  final String currencyCode;
  final Set<String> expandedProducts;
  final void Function(String id, bool expanded) onExpansionChanged;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: AppSpacing.sm),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        const Divider(height: AppSpacing.md),
        _BackendText(
          section.name,
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
        if (section.description.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: _BackendText(
              section.description,
              style: const TextStyle(
                fontSize: 12,
                color: AppColors.textSecondary,
              ),
            ),
          ),
        if (section.products.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
            child: Text(
              context.l10n.reviewPreviewEmptySection,
              style: const TextStyle(color: AppColors.textSecondary),
            ),
          ),
        for (final ResolvedProduct product in section.products)
          _PreviewProductRow(
            key: ValueKey<String>(
              'preview-product-$menuId-${product.placementId}',
            ),
            product: product,
            currencyCode: currencyCode,
            expanded: expandedProducts.contains(
              '$menuId-${product.placementId}',
            ),
            onExpansionChanged: (bool value) =>
                onExpansionChanged('$menuId-${product.placementId}', value),
          ),
      ],
    ),
  );
}

class _PreviewProductRow extends StatelessWidget {
  const _PreviewProductRow({
    super.key,
    required this.product,
    required this.currencyCode,
    required this.expanded,
    required this.onExpansionChanged,
  });

  final ResolvedProduct product;
  final String currencyCode;
  final bool expanded;
  final ValueChanged<bool> onExpansionChanged;

  @override
  Widget build(BuildContext context) {
    final ResolvedVariant? sellingVariant = product.variants
        .cast<ResolvedVariant?>()
        .firstWhere(
          (ResolvedVariant? item) => item?.isDefault ?? false,
          orElse: () =>
              product.variants.isEmpty ? null : product.variants.first,
        );
    final bool inspectable =
        product.variants.length > 1 || product.modifiers.isNotEmpty;
    final Widget row = Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Wrap(
                  spacing: 6,
                  runSpacing: 4,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: <Widget>[
                    _BackendText(
                      product.name,
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                    if (product.isFeatured)
                      _PreviewStatusBadge(
                        label: context.l10n.reviewPreviewFeatured,
                        tone: _StatusTone.neutral,
                      ),
                    if (_productStatus(context, product)
                        case final _ProductStatus status)
                      _PreviewStatusBadge(
                        label: status.label,
                        tone: status.tone,
                      ),
                  ],
                ),
                if (product.description.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: _BackendText(
                      product.description,
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Directionality(
            textDirection: TextDirection.ltr,
            child: Text(
              sellingVariant == null
                  ? '—'
                  : CurrencyFormatter.formatForContext(
                      context,
                      sellingVariant.effectivePrice,
                      currencyCode: currencyCode,
                    ),
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
    if (!inspectable) return row;
    return ExpansionTile(
      key: PageStorageKey<String>(
        'preview-product-detail-${product.placementId}',
      ),
      tilePadding: EdgeInsets.zero,
      childrenPadding: const EdgeInsets.only(bottom: AppSpacing.sm),
      initiallyExpanded: expanded,
      onExpansionChanged: onExpansionChanged,
      title: row,
      children: <Widget>[
        if (product.variants.length > 1)
          _VariantList(variants: product.variants, currencyCode: currencyCode),
        if (product.modifiers.isNotEmpty)
          _ModifierGroups(
            groups: product.modifiers,
            currencyCode: currencyCode,
          ),
      ],
    );
  }

  _ProductStatus? _productStatus(BuildContext context, ResolvedProduct value) {
    final l10n = context.l10n;
    if (!value.isVisible) {
      return _ProductStatus(l10n.reviewPreviewHidden, _StatusTone.neutral);
    }
    if (value.isSellable) return null;
    if (value.reasons.any((String reason) => reason.contains('sold_out'))) {
      return _ProductStatus(l10n.reviewPreviewSoldOut, _StatusTone.warning);
    }
    if (value.reasons.any(
      (String reason) => reason.contains('temporarily_unavailable'),
    )) {
      return _ProductStatus(
        l10n.reviewPreviewTemporarilyUnavailable,
        _StatusTone.warning,
      );
    }
    if (!value.isScheduledAvailable) {
      return _ProductStatus(
        l10n.reviewPreviewOutsideScheduledHours,
        _StatusTone.warning,
      );
    }
    return _ProductStatus(l10n.reviewPreviewUnavailable, _StatusTone.warning);
  }
}

class _VariantList extends StatelessWidget {
  const _VariantList({required this.variants, required this.currencyCode});
  final List<ResolvedVariant> variants;
  final String currencyCode;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsetsDirectional.only(start: AppSpacing.md),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          context.l10n.reviewPreviewVariants,
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
        for (final ResolvedVariant variant in variants)
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Row(
              children: <Widget>[
                Expanded(
                  child: Wrap(
                    spacing: 6,
                    runSpacing: 4,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: <Widget>[
                      _BackendText(variant.name),
                      if (variant.isDefault)
                        _PreviewStatusBadge(
                          label: context.l10n.reviewPreviewDefault,
                          tone: _StatusTone.neutral,
                        ),
                      if (!variant.isSellable)
                        _PreviewStatusBadge(
                          label: !variant.isScheduledAvailable
                              ? context.l10n.reviewPreviewOutsideScheduledHours
                              : context.l10n.reviewPreviewUnavailable,
                          tone: _StatusTone.warning,
                        ),
                    ],
                  ),
                ),
                Directionality(
                  textDirection: TextDirection.ltr,
                  child: Text(
                    CurrencyFormatter.formatForContext(
                      context,
                      variant.effectivePrice,
                      currencyCode: currencyCode,
                    ),
                  ),
                ),
              ],
            ),
          ),
      ],
    ),
  );
}

class _ModifierGroups extends StatelessWidget {
  const _ModifierGroups({required this.groups, required this.currencyCode});
  final List<ResolvedModifierGroup> groups;
  final String currencyCode;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsetsDirectional.only(
      start: AppSpacing.md,
      top: AppSpacing.sm,
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          context.l10n.reviewPreviewModifiers,
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
        for (final ResolvedModifierGroup group in groups)
          ExpansionTile(
            tilePadding: EdgeInsets.zero,
            title: _BackendText(group.name),
            subtitle: Text(
              '${group.isRequired ? context.l10n.reviewPreviewRequired : context.l10n.reviewPreviewOptional} · ${group.minSelections}–${group.maxSelections}',
            ),
            children: <Widget>[
              for (final ResolvedModifierOption option in group.options)
                ListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  title: _BackendText(option.name),
                  trailing: Directionality(
                    textDirection: TextDirection.ltr,
                    child: Text(
                      '${option.priceDelta >= 0 ? '+' : ''}${CurrencyFormatter.formatForContext(context, option.priceDelta, currencyCode: currencyCode)}',
                    ),
                  ),
                  subtitle: option.isAvailable
                      ? null
                      : Text(context.l10n.reviewPreviewOptionUnavailable),
                ),
            ],
          ),
      ],
    ),
  );
}

class _NoMenusPreview extends StatelessWidget {
  const _NoMenusPreview({required this.onAssignments});
  final VoidCallback onAssignments;

  @override
  Widget build(BuildContext context) => AppCard(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          context.l10n.reviewPreviewNoMenus,
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 4),
        Text(context.l10n.reviewPreviewNoMenusHelp),
        const SizedBox(height: AppSpacing.sm),
        OutlinedButton(
          onPressed: onAssignments,
          child: Text(context.l10n.reviewGoToAssignments),
        ),
      ],
    ),
  );
}

class _PreviewError extends StatelessWidget {
  const _PreviewError({required this.message, required this.onRetry});
  final String? message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => AppCard(
    child: Row(
      children: <Widget>[
        const Icon(Icons.error_outline, color: AppColors.danger),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                context.l10n.reviewPreviewError,
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
              if (message != null && message!.isNotEmpty)
                Text(
                  message!,
                  style: const TextStyle(color: AppColors.textSecondary),
                ),
            ],
          ),
        ),
        TextButton(
          onPressed: onRetry,
          child: Text(context.l10n.reviewPreviewRetry),
        ),
      ],
    ),
  );
}

class _PreviewLoadingSkeleton extends StatelessWidget {
  const _PreviewLoadingSkeleton();

  @override
  Widget build(BuildContext context) => Column(
    children: List<Widget>.generate(
      2,
      (int index) => AppCard(
        margin: const EdgeInsets.only(bottom: AppSpacing.md),
        child: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            _SkeletonLine(width: 190, height: 18),
            SizedBox(height: AppSpacing.md),
            _SkeletonLine(width: 120, height: 14),
            SizedBox(height: AppSpacing.sm),
            _SkeletonLine(width: double.infinity, height: 42),
            SizedBox(height: 1),
            _SkeletonLine(width: double.infinity, height: 42),
          ],
        ),
      ),
    ),
  );
}

class _SkeletonLine extends StatelessWidget {
  const _SkeletonLine({required this.width, required this.height});
  final double width;
  final double height;

  @override
  Widget build(BuildContext context) => Container(
    width: width,
    height: height,
    decoration: BoxDecoration(
      color: AppColors.surfaceAlt,
      borderRadius: BorderRadius.circular(6),
    ),
  );
}

enum _StatusTone { good, warning, neutral }

class _PreviewStatusBadge extends StatelessWidget {
  const _PreviewStatusBadge({required this.label, required this.tone});
  final String label;
  final _StatusTone tone;

  @override
  Widget build(BuildContext context) {
    final Color color = switch (tone) {
      _StatusTone.good => const Color(0xFFE3F5E8),
      _StatusTone.warning => const Color(0xFFFFE8D2),
      _StatusTone.neutral => AppColors.surfaceAlt,
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        label,
        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
      ),
    );
  }
}

class _OrderMarker extends StatelessWidget {
  const _OrderMarker({required this.value});
  final int value;

  @override
  Widget build(BuildContext context) => Container(
    width: 24,
    height: 24,
    alignment: Alignment.center,
    decoration: BoxDecoration(
      color: AppColors.textPrimary,
      borderRadius: BorderRadius.circular(8),
    ),
    child: Text(
      '$value',
      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
    ),
  );
}

class _BackendText extends StatelessWidget {
  const _BackendText(this.value, {this.style});
  final String value;
  final TextStyle? style;

  @override
  Widget build(BuildContext context) => Directionality(
    textDirection: _hasArabic(value) ? TextDirection.rtl : TextDirection.ltr,
    child: Text(value, style: style),
  );
}

bool _hasArabic(String value) => RegExp(r'[\u0600-\u06FF]').hasMatch(value);

class _ProductStatus {
  const _ProductStatus(this.label, this.tone);
  final String label;
  final _StatusTone tone;
}

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../l10n/app_localizations.dart';
import '../controllers/discount_targets_cubit.dart';
import '../models/discount_form_references.dart';

class DiscountProductTargets extends StatelessWidget {
  const DiscountProductTargets({
    super.key,
    required this.controller,
    required this.enabled,
    required this.onChanged,
  });
  final DiscountTargetsCubit controller;
  final bool enabled;
  final VoidCallback onChanged;
  @override
  Widget build(
    BuildContext context,
  ) => BlocBuilder<DiscountTargetsCubit, DiscountTargetsState>(
    bloc: controller,
    builder: (context, state) {
      final l10n = AppLocalizations.of(context);
      final arabic = l10n.localeName.startsWith('ar');
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          OutlinedButton(
            key: const Key('discount-products-selector'),
            onPressed: enabled
                ? () async {
                    final ids = await _pick(
                      context,
                      0,
                      l10n.discountSelectedProducts,
                      state.selections.keys.toSet(),
                    );
                    if (ids != null) {
                      controller.setProducts(ids);
                      onChanged();
                    }
                  }
                : null,
            child: Text(l10n.discountSelectedProducts),
          ),
          for (final s in state.selections.values)
            Padding(
              padding: const EdgeInsets.only(top: AppSpacing.md),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          s.product?.label(arabic) ?? '#${s.productId}',
                        ),
                      ),
                      IconButton(
                        key: Key('discount-remove-product-${s.productId}'),
                        tooltip: l10n.commonDelete,
                        onPressed: enabled
                            ? () {
                                controller.removeProduct(s.productId);
                                onChanged();
                              }
                            : null,
                        icon: const Icon(Icons.close),
                      ),
                    ],
                  ),
                  if (s.hasUnavailable) Text(l10n.discountUnavailableTarget),
                  Wrap(
                    spacing: AppSpacing.sm,
                    runSpacing: AppSpacing.sm,
                    children: [
                      for (final mode in ['all', 'selected'])
                        ChoiceChip(
                          key: Key(
                            'discount-variant-mode-${s.productId}-$mode',
                          ),
                          label: Text(
                            mode == 'all'
                                ? l10n.discountAllVariants
                                : l10n.discountSelectedVariants,
                          ),
                          selected: s.variantMode == mode,
                          onSelected: enabled
                              ? (_) {
                                  controller.setMode(s.productId, mode);
                                  onChanged();
                                }
                              : null,
                        ),
                    ],
                  ),
                  if (s.variantMode == 'selected') ...[
                    OutlinedButton(
                      key: Key('discount-variants-selector-${s.productId}'),
                      onPressed: enabled && s.product?.isAvailable != false
                          ? () async {
                              final ids = await _pick(
                                context,
                                s.productId,
                                l10n.discountSelectedVariants,
                                s.variantIds.toSet(),
                              );
                              if (ids != null) {
                                controller.setVariants(s.productId, ids);
                                onChanged();
                              }
                            }
                          : null,
                      child: Text(l10n.discountSelectedVariants),
                    ),
                    Wrap(
                      spacing: AppSpacing.sm,
                      runSpacing: AppSpacing.sm,
                      children: [
                        for (final id in s.variantIds)
                          InputChip(
                            key: Key('discount-remove-variant-$id'),
                            label: Text(
                              s.variants
                                      .where((v) => v.id == id)
                                      .map(
                                        (v) =>
                                            '${v.label(arabic)}${v.isAvailable ? '' : ' · ${l10n.discountUnavailableTarget}'}',
                                      )
                                      .firstOrNull ??
                                  '#$id',
                            ),
                            onDeleted: enabled
                                ? () {
                                    controller.setVariants(
                                      s.productId,
                                      s.variantIds.toSet()..remove(id),
                                    );
                                    onChanged();
                                  }
                                : null,
                          ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
        ],
      );
    },
  );
  Future<Set<int>?> _pick(
    BuildContext context,
    int id,
    String title,
    Set<int> ids,
  ) async {
    controller.load(productId: id, search: '', page: 1);
    final result = await showDialog<Set<int>>(
      context: context,
      builder: (_) => _DiscountPagedPicker(
        controller: controller,
        productId: id,
        title: title,
        initial: ids,
      ),
    );
    controller.invalidatePage(id);
    return result;
  }
}

class _DiscountPagedPicker extends StatefulWidget {
  const _DiscountPagedPicker({
    required this.controller,
    required this.productId,
    required this.title,
    required this.initial,
  });
  final DiscountTargetsCubit controller;
  final int productId;
  final String title;
  final Set<int> initial;
  @override
  State<_DiscountPagedPicker> createState() => _DiscountPagedPickerState();
}

class _DiscountPagedPickerState extends State<_DiscountPagedPicker> {
  late final Set<int> selection = {...widget.initial};
  @override
  Widget build(
    BuildContext context,
  ) => BlocBuilder<DiscountTargetsCubit, DiscountTargetsState>(
    bloc: widget.controller,
    builder: (context, state) {
      final l10n = AppLocalizations.of(context);
      final page =
          state.pages[widget.productId] ?? const DiscountTargetPageState();
      final saved = widget.productId == 0
          ? state.selections.values
                .map((s) => s.product)
                .whereType<DiscountFormReference>()
          : state.selections[widget.productId]?.variants ??
                <DiscountFormReference>[];
      final canNavigate = !page.loading && page.error == null;
      final unavailable = saved.where(
        (v) => selection.contains(v.id) && !v.isAvailable,
      );
      return AlertDialog(
        title: Text(widget.title),
        content: SizedBox(
          width: 420,
          height: 400,
          child: Column(
            children: [
              TextField(
                key: const Key('discount-reference-search'),
                maxLength: 100,
                decoration: InputDecoration(hintText: l10n.discountV2Search),
                onChanged: (value) => widget.controller.load(
                  productId: widget.productId,
                  search: value,
                  page: 1,
                ),
              ),
              if (page.loading) const LinearProgressIndicator(),
              if (page.error != null) ...[
                Text(
                  page.error == 'forbidden'
                      ? l10n.discountReferenceForbidden
                      : l10n.discountReferenceFailed,
                ),
                TextButton(
                  onPressed: () =>
                      widget.controller.load(productId: widget.productId),
                  child: Text(l10n.commonRetry),
                ),
              ],
              Expanded(
                child: ListView(
                  children: [
                    for (final item in unavailable)
                      CheckboxListTile(
                        value: true,
                        title: Text(
                          item.label(l10n.localeName.startsWith('ar')),
                        ),
                        subtitle: Text(l10n.discountUnavailableTarget),
                        onChanged: (_) =>
                            setState(() => selection.remove(item.id)),
                      ),
                    if (!page.loading &&
                        page.error == null &&
                        page.page.items.isEmpty)
                      Text(l10n.discountFormNoOptions),
                    if (!page.loading && page.error == null)
                      for (final item in page.page.items)
                        CheckboxListTile(
                          key: Key('discount-reference-${item.id}'),
                          title: Text(
                            item.label(l10n.localeName.startsWith('ar')),
                          ),
                          value: selection.contains(item.id),
                          onChanged: item.isAvailable
                              ? (value) => setState(() {
                                  if (value == true) {
                                    selection.add(item.id);
                                  } else {
                                    selection.remove(item.id);
                                  }
                                })
                              : null,
                        ),
                  ],
                ),
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  IconButton(
                    tooltip: l10n.discountReferencePrevious,
                    onPressed: canNavigate && page.page.currentPage > 1
                        ? () => widget.controller.load(
                            productId: widget.productId,
                            page: page.page.currentPage - 1,
                          )
                        : null,
                    icon: const Icon(Icons.chevron_left),
                  ),
                  if (canNavigate)
                    Text('${page.page.currentPage} / ${page.page.lastPage}'),
                  IconButton(
                    tooltip: l10n.discountReferenceNext,
                    onPressed:
                        canNavigate &&
                            page.page.currentPage < page.page.lastPage
                        ? () => widget.controller.load(
                            productId: widget.productId,
                            page: page.page.currentPage + 1,
                          )
                        : null,
                    icon: const Icon(Icons.chevron_right),
                  ),
                ],
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(l10n.commonCancel),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, selection),
            child: Text(l10n.discountFormDone),
          ),
        ],
      );
    },
  );
}

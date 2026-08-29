import 'package:flutter/material.dart';

import '../../../core/constants/app_sizes.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_radius.dart';
import '../../../core/theme/app_spacing.dart';

class MenuContextItem {
  const MenuContextItem({
    required this.label,
    required this.value,
    this.icon,
    this.isTechnical = false,
  });

  final String label;
  final String value;
  final IconData? icon;

  /// IDs, SKU/barcodes, and comparable system values retain LTR reading order.
  final bool isTechnical;
}

/// Presents the existing Product/Variant/Branch/Channel context without
/// assigning new business meaning to it.
class ContextBar extends StatelessWidget {
  const ContextBar({
    super.key,
    required this.items,
    this.selectors = const <Widget>[],
    this.actions = const <Widget>[],
    this.changeContextLabel,
    this.onRequestContextChange,
    this.onBeforeContextChange,
  });

  final List<MenuContextItem> items;
  final List<Widget> selectors;
  final List<Widget> actions;
  final String? changeContextLabel;
  final Future<void> Function(BuildContext context)? onRequestContextChange;

  /// Connect an existing screen-level dirty-state guard here before a context
  /// switch. The foundation deliberately owns no dirty state.
  final Future<bool> Function()? onBeforeContextChange;

  Future<void> _requestChange(BuildContext context) async {
    if (onBeforeContextChange != null && !await onBeforeContextChange!()) {
      return;
    }
    if (!context.mounted) return;
    await onRequestContextChange?.call(context);
  }

  @override
  Widget build(BuildContext context) {
    final List<Widget> controls = <Widget>[
      ...selectors,
      if (changeContextLabel != null && onRequestContextChange != null)
        OutlinedButton.icon(
          onPressed: () => _requestChange(context),
          icon: const Icon(Icons.swap_horiz),
          label: Text(changeContextLabel!),
        ),
      ...actions,
    ];

    return Semantics(
      label: 'Current menu context',
      child: Container(
        padding: AppSpacing.allLg,
        decoration: BoxDecoration(
          color: AppColors.surface,
          border: Border.all(color: AppColors.border),
          borderRadius: AppRadius.card,
        ),
        child: LayoutBuilder(
          builder: (BuildContext context, BoxConstraints constraints) {
            final bool stack =
                constraints.maxWidth < AppSizes.menuContextInlineBreakpoint;
            final Widget itemList = Wrap(
              spacing: AppSpacing.lg,
              runSpacing: AppSpacing.md,
              children: items
                  .map((MenuContextItem item) => _ContextValue(item: item))
                  .toList(),
            );
            final Widget controlList = Wrap(
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.sm,
              alignment: WrapAlignment.end,
              children: controls,
            );
            if (controls.isEmpty) return itemList;
            if (stack) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  itemList,
                  const SizedBox(height: AppSpacing.lg),
                  controlList,
                ],
              );
            }
            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Expanded(child: itemList),
                const SizedBox(width: AppSpacing.lg),
                controlList,
              ],
            );
          },
        ),
      ),
    );
  }
}

class _ContextValue extends StatelessWidget {
  const _ContextValue({required this.item});

  final MenuContextItem item;

  @override
  Widget build(BuildContext context) {
    final Widget value = Text(
      item.value,
      maxLines: 2,
      overflow: TextOverflow.ellipsis,
      textDirection: item.isTechnical ? TextDirection.ltr : null,
      textAlign: TextAlign.start,
      style: Theme.of(context).textTheme.titleSmall,
    );
    return Semantics(
      label: '${item.label}: ${item.value}',
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 300),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            if (item.icon != null) ...<Widget>[
              Icon(item.icon, size: 18),
              const SizedBox(width: AppSpacing.sm),
            ],
            Flexible(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    item.label,
                    style: Theme.of(context).textTheme.labelMedium,
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  value,
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class ActiveMenuFilter {
  const ActiveMenuFilter({required this.label, required this.onRemove});

  final String label;
  final VoidCallback onRemove;
}

class CompactFilterBar extends StatelessWidget {
  const CompactFilterBar({
    super.key,
    required this.searchLabel,
    required this.onSearchChanged,
    this.searchController,
    this.quickFilters = const <Widget>[],
    this.activeFilters = const <ActiveMenuFilter>[],
    this.onMoreFilters,
    this.moreFiltersLabel = 'More filters',
    this.moreFiltersSemanticLabel,
    this.sortAction,
    this.sortTooltip = 'Sort',
    this.searchFieldKey,
    this.onClearAll,
    this.clearAllLabel = 'Clear all',
  });

  final String searchLabel;
  final ValueChanged<String> onSearchChanged;
  final TextEditingController? searchController;
  final List<Widget> quickFilters;
  final List<ActiveMenuFilter> activeFilters;
  final VoidCallback? onMoreFilters;
  final String moreFiltersLabel;
  final String? moreFiltersSemanticLabel;
  final Widget? sortAction;
  final String sortTooltip;
  final Key? searchFieldKey;
  final VoidCallback? onClearAll;
  final String clearAllLabel;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Menu filters',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.sm,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: <Widget>[
              SizedBox(
                width: 288,
                child: TextField(
                  key: searchFieldKey,
                  controller: searchController,
                  onChanged: onSearchChanged,
                  decoration: InputDecoration(
                    labelText: searchLabel,
                    prefixIcon: const Icon(Icons.search),
                    suffixIcon: searchController?.text.isNotEmpty == true
                        ? IconButton(
                            tooltip: 'Clear $searchLabel',
                            onPressed: () {
                              searchController!.clear();
                              onSearchChanged('');
                            },
                            icon: const Icon(Icons.close),
                          )
                        : null,
                  ),
                ),
              ),
              ...quickFilters,
              if (onMoreFilters != null)
                Semantics(
                  label: moreFiltersSemanticLabel ?? moreFiltersLabel,
                  button: true,
                  child: OutlinedButton.icon(
                    onPressed: onMoreFilters,
                    icon: const Icon(Icons.tune),
                    label: Text(moreFiltersLabel),
                  ),
                ),
              if (sortAction != null)
                Tooltip(message: sortTooltip, child: sortAction!),
            ],
          ),
          if (activeFilters.isNotEmpty) ...<Widget>[
            const SizedBox(height: AppSpacing.sm),
            Wrap(
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.sm,
              children: activeFilters
                  .map<Widget>(
                    (ActiveMenuFilter filter) => Tooltip(
                      message: 'Remove ${filter.label}',
                      child: Semantics(
                        button: true,
                        label: 'Remove ${filter.label}',
                        child: InputChip(
                          label: Text(filter.label),
                          onDeleted: filter.onRemove,
                          deleteIcon: const Icon(Icons.close),
                        ),
                      ),
                    ),
                  )
                  .toList(),
            ),
            if (activeFilters.length > 1 && onClearAll != null)
              Align(
                alignment: AlignmentDirectional.centerStart,
                child: TextButton(
                  onPressed: onClearAll,
                  child: Text(clearAllLabel),
                ),
              ),
          ],
        ],
      ),
    );
  }
}

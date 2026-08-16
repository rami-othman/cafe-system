import 'package:flutter/material.dart';

import '../../../core/constants/app_sizes.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';

class MenuBreadcrumb {
  const MenuBreadcrumb({required this.label, this.onTap});

  final String label;
  final VoidCallback? onTap;
}

/// Shared page anatomy for future Menu Management screens.
///
/// The optional [navigationSlot] intentionally does not provide navigation
/// behaviour. Batch 2 will supply the route-backed module navigation.
class MenuModuleScaffold extends StatelessWidget {
  const MenuModuleScaffold({
    super.key,
    required this.child,
    this.navigationSlot,
    this.breadcrumbs = const <MenuBreadcrumb>[],
    this.padding,
    this.breadcrumbPadding,
  });

  final Widget child;
  final Widget? navigationSlot;
  final List<MenuBreadcrumb> breadcrumbs;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? breadcrumbPadding;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.contentBackground,
      child: LayoutBuilder(
        builder: (BuildContext context, BoxConstraints constraints) {
          final bool compact = constraints.maxWidth < 1440;
          final EdgeInsetsGeometry pagePadding =
              padding ??
              EdgeInsetsDirectional.all(
                compact
                    ? AppSizes.menuModuleCompactContentPadding
                    : AppSizes.menuModuleStandardContentPadding,
              );

          return Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              ?navigationSlot,
              Expanded(
                child: Align(
                  alignment: AlignmentDirectional.topCenter,
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(
                      maxWidth: AppSizes.menuModuleContentMaxWidth,
                    ),
                    child: Padding(
                      padding: pagePadding,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: <Widget>[
                          if (breadcrumbs.isNotEmpty) ...<Widget>[
                            Padding(
                              padding: breadcrumbPadding ?? EdgeInsets.zero,
                              child: _MenuBreadcrumbs(items: breadcrumbs),
                            ),
                            const SizedBox(height: AppSpacing.lg),
                          ],
                          Expanded(child: child),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _MenuBreadcrumbs extends StatelessWidget {
  const _MenuBreadcrumbs({required this.items});

  final List<MenuBreadcrumb> items;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Breadcrumbs',
      child: Wrap(
        spacing: AppSpacing.xs,
        runSpacing: AppSpacing.xs,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: <Widget>[
          for (int index = 0; index < items.length; index++) ...<Widget>[
            if (index > 0)
              Icon(
                Directionality.of(context) == TextDirection.rtl
                    ? Icons.chevron_left
                    : Icons.chevron_right,
                size: 18,
                semanticLabel: '/',
              ),
            _MenuBreadcrumbItem(
              item: items[index],
              isCurrent: index == items.length - 1,
            ),
          ],
        ],
      ),
    );
  }
}

class _MenuBreadcrumbItem extends StatelessWidget {
  const _MenuBreadcrumbItem({required this.item, required this.isCurrent});

  final MenuBreadcrumb item;
  final bool isCurrent;

  @override
  Widget build(BuildContext context) {
    final Text child = Text(
      item.label,
      overflow: TextOverflow.ellipsis,
      style: Theme.of(context).textTheme.labelLarge?.copyWith(
        color: isCurrent ? AppColors.textPrimary : AppColors.textSecondary,
        fontWeight: isCurrent ? FontWeight.w700 : FontWeight.w500,
      ),
    );
    if (item.onTap == null || isCurrent) return child;
    return TextButton(onPressed: item.onTap, child: child);
  }
}

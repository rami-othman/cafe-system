import 'package:flutter/material.dart';

import '../../../core/theme/app_spacing.dart';
import '../models/pos_menu_runtime_models.dart';

/// Compact published-menu and section navigation preserving runtime order.
class PosMenuNavigation extends StatelessWidget {
  const PosMenuNavigation({
    super.key,
    required this.menus,
    required this.selectedMenuId,
    required this.sections,
    required this.selectedSectionId,
    required this.languageCode,
    required this.onMenuSelected,
    required this.onSectionSelected,
  });

  final List<PosStaticMenu> menus;
  final int? selectedMenuId;
  final List<PosStaticSection> sections;
  final int? selectedSectionId;
  final String languageCode;
  final ValueChanged<int> onMenuSelected;
  final ValueChanged<int> onSectionSelected;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: <Widget>[
      if (menus.length > 1) ...<Widget>[
        _RuntimeTabs(
          items: menus
              .map(
                (PosStaticMenu item) => _RuntimeTab(
                  id: item.id,
                  label: item.name.resolve(languageCode),
                ),
              )
              .toList(growable: false),
          selectedId: selectedMenuId,
          onSelected: onMenuSelected,
        ),
        const SizedBox(height: AppSpacing.md),
      ],
      if (sections.isNotEmpty)
        _RuntimeTabs(
          items: sections
              .map(
                (PosStaticSection item) => _RuntimeTab(
                  id: item.id,
                  label: item.name.resolve(languageCode),
                ),
              )
              .toList(growable: false),
          selectedId: selectedSectionId,
          onSelected: onSectionSelected,
        ),
    ],
  );
}

class _RuntimeTab {
  const _RuntimeTab({required this.id, required this.label});

  final int id;
  final String label;
}

class _RuntimeTabs extends StatelessWidget {
  const _RuntimeTabs({
    required this.items,
    required this.selectedId,
    required this.onSelected,
  });

  final List<_RuntimeTab> items;
  final int? selectedId;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) => SizedBox(
    height: 40,
    child: ListView.separated(
      scrollDirection: Axis.horizontal,
      itemCount: items.length,
      separatorBuilder: (BuildContext context, int index) =>
          const SizedBox(width: AppSpacing.sm),
      itemBuilder: (BuildContext context, int index) {
        final _RuntimeTab item = items[index];
        return ChoiceChip(
          label: Text(item.label, overflow: TextOverflow.ellipsis),
          selected: item.id == selectedId,
          onSelected: (_) => onSelected(item.id),
        );
      },
    ),
  );
}

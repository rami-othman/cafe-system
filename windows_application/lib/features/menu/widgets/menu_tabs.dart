import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_radius.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_text_styles.dart';
import '../controllers/menu_state.dart';

class MenuTabs extends StatelessWidget {
  const MenuTabs({
    super.key,
    required this.selectedTab,
    required this.onSelected,
  });

  final MenuTab selectedTab;
  final ValueChanged<MenuTab> onSelected;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border.all(color: AppColors.border),
        borderRadius: AppRadius.control,
      ),
      child: Padding(
        padding: AppSpacing.allXs,
        child: Wrap(
          spacing: AppSpacing.xs,
          children: MenuTab.values
              .map(
                (MenuTab tab) => _MenuTabButton(
                  label: _labelFor(tab),
                  isSelected: tab == selectedTab,
                  onPressed: () => onSelected(tab),
                ),
              )
              .toList(growable: false),
        ),
      ),
    );
  }

  String _labelFor(MenuTab tab) {
    return switch (tab) {
      MenuTab.overview => 'Overview',
      MenuTab.products => 'Products',
      MenuTab.categories => 'Categories',
      MenuTab.modifiers => 'Modifiers',
      MenuTab.combos => 'Combos',
    };
  }
}

class _MenuTabButton extends StatelessWidget {
  const _MenuTabButton({
    required this.label,
    required this.isSelected,
    required this.onPressed,
  });

  final String label;
  final bool isSelected;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: isSelected ? AppColors.navActiveBackground : AppColors.transparent,
      borderRadius: AppRadius.control,
      child: InkWell(
        onTap: onPressed,
        borderRadius: AppRadius.control,
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.lg,
            vertical: 6,
          ),
          child: Text(
            label,
            style: AppTextStyles.bodySmall.copyWith(
              color: isSelected
                  ? AppColors.navActiveText
                  : AppColors.textSecondary,
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../shared/widgets/app_button.dart';
import '../../../shared/widgets/app_card.dart';
import '../models/modifier_group.dart';
import 'assigned_product_chips.dart';
import 'menu_status_chip.dart';
import 'modifier_options_table.dart';

class ModifierGroupDetailPanel extends StatelessWidget {
  const ModifierGroupDetailPanel({
    super.key,
    required this.group,
    required this.onEditGroup,
    required this.onAddOption,
    required this.onManageLinks,
    required this.onOptionAction,
    required this.onRemoveProduct,
  });

  final ModifierGroup group;
  final VoidCallback onEditGroup;
  final VoidCallback onAddOption;
  final VoidCallback onManageLinks;
  final ValueChanged<String> onOptionAction;
  final ValueChanged<String> onRemoveProduct;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Padding(
            padding: AppSpacing.allXl,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Wrap(
                        crossAxisAlignment: WrapCrossAlignment.center,
                        spacing: AppSpacing.md,
                        runSpacing: AppSpacing.sm,
                        children: <Widget>[
                          Text(
                            group.name,
                            key: const Key('modifier-detail-title'),
                            style: AppTextStyles.headlineMedium,
                          ),
                          MenuStatusChip(
                            label: group.isActive ? 'Active' : 'Inactive',
                            tone: group.isActive
                                ? MenuStatusTone.success
                                : MenuStatusTone.neutral,
                          ),
                        ],
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      Text(
                        group.description,
                        style: AppTextStyles.bodySmall.copyWith(
                          color: AppColors.textMuted,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: AppSpacing.lg),
                AppButton(
                  label: 'Edit Group',
                  icon: Icons.edit_outlined,
                  variant: AppButtonVariant.outlined,
                  onPressed: onEditGroup,
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Padding(
            padding: AppSpacing.allXl,
            child: Column(
              children: <Widget>[
                _SectionHeader(
                  title: 'Options (${group.options.length})',
                  actionLabel: 'Add Option',
                  actionIcon: Icons.add,
                  onPressed: onAddOption,
                ),
                const SizedBox(height: AppSpacing.lg),
                ModifierOptionsTable(
                  options: group.options,
                  onAction: onOptionAction,
                ),
                const SizedBox(height: AppSpacing.xl),
                _SectionHeader(
                  title:
                      'Assigned Products (${group.assignedProductIds.length})',
                  actionLabel: 'Manage Links',
                  actionIcon: Icons.link,
                  onPressed: onManageLinks,
                ),
                const SizedBox(height: AppSpacing.md),
                AssignedProductChips(
                  productNames: _visibleProductNames(group),
                  totalCount: group.assignedProductIds.length,
                  onRemove: onRemoveProduct,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  List<String> _visibleProductNames(ModifierGroup group) {
    const Map<String, String> names = <String, String>{
      'latte': 'Latte',
      'cappuccino': 'Cappuccino',
      'flat-white': 'Flat White',
      'macchiato': 'Macchiato',
      'cortado': 'Cortado',
      'americano': 'Americano',
      'espresso': 'Espresso',
      'iced-americano': 'Iced Americano',
      'cheesecake': 'Cheesecake',
    };
    return group.assignedProductIds
        .take(6)
        .map((String id) => names[id] ?? _humanize(id))
        .toList(growable: false);
  }

  String _humanize(String value) {
    return value
        .split('-')
        .map(
          (String word) =>
              '${word.substring(0, 1).toUpperCase()}${word.substring(1)}',
        )
        .join(' ');
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({
    required this.title,
    required this.actionLabel,
    required this.actionIcon,
    required this.onPressed,
  });

  final String title;
  final String actionLabel;
  final IconData actionIcon;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: <Widget>[
        Expanded(child: Text(title, style: AppTextStyles.titleLarge)),
        TextButton.icon(
          onPressed: onPressed,
          icon: Icon(actionIcon, size: 17),
          label: Text(actionLabel),
        ),
      ],
    );
  }
}

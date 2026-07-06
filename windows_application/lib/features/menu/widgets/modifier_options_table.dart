import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../core/constants/app_sizes.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_radius.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_text_styles.dart';
import '../models/menu_enums.dart';
import '../models/modifier_option.dart';
import 'menu_status_chip.dart';

class ModifierOptionsTable extends StatelessWidget {
  const ModifierOptionsTable({
    super.key,
    required this.options,
    required this.onAction,
  });

  final List<ModifierOption> options;
  final ValueChanged<String> onAction;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final double width = math.max(
          constraints.maxWidth,
          AppSizes.modifierOptionsTableMinWidth,
        );
        return ClipRRect(
          borderRadius: AppRadius.card,
          child: DecoratedBox(
            decoration: BoxDecoration(
              border: Border.all(color: AppColors.border),
              borderRadius: AppRadius.card,
            ),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: SizedBox(
                width: width,
                child: Column(
                  children: <Widget>[
                    const _OptionsHeader(),
                    ...options.map(
                      (ModifierOption option) =>
                          _OptionRow(option: option, onAction: onAction),
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
}

class _OptionsHeader extends StatelessWidget {
  const _OptionsHeader();

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 42,
      color: AppColors.menuTableHeader,
      child: const Row(
        children: <Widget>[
          SizedBox(width: 44),
          Expanded(flex: 3, child: _HeaderLabel('NAME')),
          Expanded(flex: 2, child: _HeaderLabel('UPCHARGE')),
          Expanded(flex: 2, child: _HeaderLabel('STATUS')),
          SizedBox(width: 132, child: _HeaderLabel('ACTIONS')),
        ],
      ),
    );
  }
}

class _HeaderLabel extends StatelessWidget {
  const _HeaderLabel(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    return Text(
      label,
      style: AppTextStyles.labelSmall.copyWith(
        color: AppColors.textSecondary,
        fontSize: 10,
        letterSpacing: 0.4,
      ),
    );
  }
}

class _OptionRow extends StatelessWidget {
  const _OptionRow({required this.option, required this.onAction});

  final ModifierOption option;
  final ValueChanged<String> onAction;

  @override
  Widget build(BuildContext context) {
    final bool lowStock = option.stockStatus == StockStatus.lowStock;
    return Container(
      constraints: const BoxConstraints(minHeight: 58),
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(top: BorderSide(color: AppColors.border)),
      ),
      child: Row(
        children: <Widget>[
          const SizedBox(
            width: 44,
            child: Icon(
              Icons.drag_indicator,
              size: 18,
              color: AppColors.textMuted,
            ),
          ),
          Expanded(
            flex: 3,
            child: Row(
              children: <Widget>[
                Flexible(
                  child: Text(
                    option.name,
                    overflow: TextOverflow.ellipsis,
                    style: AppTextStyles.bodySmall.copyWith(
                      color: AppColors.textPrimary,
                    ),
                  ),
                ),
                if (option.isDefault) ...<Widget>[
                  const SizedBox(width: AppSpacing.sm),
                  const MenuStatusChip(
                    label: 'Default',
                    tone: MenuStatusTone.neutral,
                  ),
                ],
              ],
            ),
          ),
          Expanded(
            flex: 2,
            child: Text(
              _priceLabel(option),
              style: AppTextStyles.bodySmall.copyWith(
                color: AppColors.textPrimary,
              ),
            ),
          ),
          Expanded(
            flex: 2,
            child: Align(
              alignment: Alignment.centerLeft,
              child: MenuStatusChip(
                label: lowStock ? 'Low Stock' : 'In Stock',
                tone: lowStock
                    ? MenuStatusTone.warning
                    : MenuStatusTone.success,
              ),
            ),
          ),
          SizedBox(
            width: 132,
            child: Row(
              children: <Widget>[
                _ActionButton(
                  icon: Icons.edit_outlined,
                  tooltip: 'Edit ${option.name}',
                  onPressed: () => onAction('Edit ${option.name}'),
                ),
                _ActionButton(
                  icon: Icons.delete_outline,
                  tooltip: 'Delete ${option.name}',
                  onPressed: () => onAction('Delete ${option.name}'),
                ),
                _ActionButton(
                  icon: Icons.block,
                  tooltip: 'Disable ${option.name}',
                  onPressed: () => onAction('Disable ${option.name}'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _priceLabel(ModifierOption option) {
    if (option.extraPrice == 0) {
      return '\$0.00';
    }
    return '+\$${option.extraPrice.toStringAsFixed(2)}';
  }
}

class _ActionButton extends StatelessWidget {
  const _ActionButton({
    required this.icon,
    required this.tooltip,
    required this.onPressed,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      onPressed: onPressed,
      tooltip: tooltip,
      visualDensity: VisualDensity.compact,
      icon: Icon(icon, size: 17),
      color: AppColors.textSecondary,
    );
  }
}

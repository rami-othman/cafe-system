import 'package:flutter/material.dart';

import '../../../core/constants/app_sizes.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_radius.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_text_styles.dart';
import '../models/discount_list_item.dart';

class DiscountSearchControls extends StatelessWidget {
  const DiscountSearchControls({
    super.key,
    required this.selectedStatus,
    required this.onSearchChanged,
    required this.onStatusChanged,
  });

  final DiscountStatus? selectedStatus;
  final ValueChanged<String> onSearchChanged;
  final ValueChanged<DiscountStatus?> onStatusChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(17),
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border.all(color: AppColors.border),
        borderRadius: AppRadius.card,
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: AppColors.black.withValues(alpha: 0.04),
            blurRadius: 2,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: LayoutBuilder(
        builder: (BuildContext context, BoxConstraints constraints) {
          final bool stackControls = constraints.maxWidth < 620;
          final Widget search = SizedBox(
            width: stackControls
                ? double.infinity
                : AppSizes.discountsSearchWidth,
            child: TextField(
              key: const Key('discounts-search-field'),
              onChanged: onSearchChanged,
              style: AppTextStyles.bodySmall.copyWith(
                color: AppColors.textDark,
                fontSize: 14,
              ),
              decoration: const InputDecoration(
                constraints: BoxConstraints(
                  minHeight: AppSizes.discountsControlHeight,
                ),
                hintText: 'Search discounts...',
                prefixIcon: Icon(Icons.search, size: 18),
                filled: true,
                fillColor: AppColors.background,
                isDense: true,
                contentPadding: EdgeInsets.symmetric(
                  horizontal: AppSpacing.lg,
                  vertical: 11,
                ),
              ),
            ),
          );

          final Widget filters = Wrap(
            spacing: AppSpacing.md,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: <Widget>[
              _StatusDropdown(
                selectedStatus: selectedStatus,
                onChanged: onStatusChanged,
              ),
              Tooltip(
                message: 'Advanced filters',
                child: OutlinedButton(
                  onPressed: () => ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Advanced filters will be available soon.'),
                    ),
                  ),
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size.square(40),
                    maximumSize: const Size.square(40),
                    padding: EdgeInsets.zero,
                    side: const BorderSide(color: AppColors.border),
                    shape: const RoundedRectangleBorder(
                      borderRadius: AppRadius.control,
                    ),
                  ),
                  child: const Icon(Icons.filter_list, size: 19),
                ),
              ),
            ],
          );

          if (stackControls) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                search,
                const SizedBox(height: AppSpacing.md),
                filters,
              ],
            );
          }

          return Row(children: <Widget>[search, const Spacer(), filters]);
        },
      ),
    );
  }
}

class _StatusDropdown extends StatelessWidget {
  const _StatusDropdown({
    required this.selectedStatus,
    required this.onChanged,
  });

  final DiscountStatus? selectedStatus;
  final ValueChanged<DiscountStatus?> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const Key('discount-status-filter'),
      height: AppSizes.discountsControlHeight,
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
      decoration: BoxDecoration(
        color: AppColors.background,
        border: Border.all(color: AppColors.border),
        borderRadius: AppRadius.control,
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<DiscountStatus?>(
          value: selectedStatus,
          hint: Text('All Statuses', style: _textStyle),
          icon: const Icon(Icons.keyboard_arrow_down, size: 21),
          style: _textStyle,
          onChanged: onChanged,
          items: <DropdownMenuItem<DiscountStatus?>>[
            DropdownMenuItem<DiscountStatus?>(
              value: null,
              child: Text('All Statuses', style: _textStyle),
            ),
            for (final DiscountStatus status in DiscountStatus.values)
              DropdownMenuItem<DiscountStatus?>(
                value: status,
                child: Text(_titleCase(status.name), style: _textStyle),
              ),
          ],
        ),
      ),
    );
  }

  TextStyle get _textStyle => AppTextStyles.bodySmall.copyWith(
    color: AppColors.textDark,
    fontSize: 14,
    fontWeight: FontWeight.w400,
  );

  String _titleCase(String value) =>
      '${value[0].toUpperCase()}${value.substring(1)}';
}

import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../core/constants/app_sizes.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_radius.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../shared/widgets/app_empty_state.dart';
import '../models/discount_list_item.dart';
import 'discount_status_badge.dart';

class DiscountsTable extends StatelessWidget {
  const DiscountsTable({
    super.key,
    required this.discounts,
    required this.currentPage,
    required this.totalEntries,
    required this.totalPages,
    required this.onPageChanged,
    required this.onView,
    required this.onEdit,
    required this.onToggleStatus,
    required this.onDelete,
  });

  final List<DiscountListItem> discounts;
  final int currentPage;
  final int totalEntries;
  final int totalPages;
  final ValueChanged<int> onPageChanged;
  final ValueChanged<DiscountListItem> onView;
  final ValueChanged<DiscountListItem> onEdit;
  final ValueChanged<DiscountListItem> onToggleStatus;
  final ValueChanged<DiscountListItem> onDelete;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border.all(color: AppColors.border),
        borderRadius: AppRadius.card,
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: AppColors.black.withValues(alpha: 0.04),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: discounts.isEmpty
          ? const SizedBox(
              height: 292,
              child: AppEmptyState(
                icon: Icons.search_off_outlined,
                message: 'No discounts match your search or status filter.',
              ),
            )
          : Column(
              children: <Widget>[
                LayoutBuilder(
                  builder: (BuildContext context, BoxConstraints constraints) {
                    final double width = math.max(
                      constraints.maxWidth,
                      AppSizes.discountsTableMinWidth,
                    );
                    return SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: SizedBox(
                        width: width,
                        child: Column(
                          children: <Widget>[
                            const _DiscountTableHeader(),
                            for (final DiscountListItem discount in discounts)
                              _DiscountTableRow(
                                discount: discount,
                                onView: onView,
                                onEdit: onEdit,
                                onToggleStatus: onToggleStatus,
                                onDelete: onDelete,
                              ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
                _DiscountPagination(
                  currentPage: currentPage,
                  totalEntries: totalEntries,
                  currentPageEntryCount: discounts.length,
                  totalPages: totalPages,
                  onPageChanged: onPageChanged,
                ),
              ],
            ),
    );
  }
}

class _DiscountTableHeader extends StatelessWidget {
  const _DiscountTableHeader();

  @override
  Widget build(BuildContext context) {
    return Container(
      height: AppSizes.discountsTableHeaderHeight,
      color: AppColors.menuTableHeader,
      child: const Row(
        children: <Widget>[
          _HeaderCell(label: 'Discount Name', flex: 23),
          _HeaderCell(label: 'Type', flex: 15),
          _HeaderCell(label: 'Value', flex: 13),
          _HeaderCell(label: 'Conditions', flex: 21),
          _HeaderCell(label: 'Valid Period', flex: 20),
          _HeaderCell(label: 'Status', flex: 13),
          _HeaderCell(label: 'Actions', flex: 14, alignRight: true),
        ],
      ),
    );
  }
}

class _DiscountTableRow extends StatefulWidget {
  const _DiscountTableRow({required this.discount, required this.onView, required this.onEdit, required this.onToggleStatus, required this.onDelete});

  final DiscountListItem discount;
  final ValueChanged<DiscountListItem> onView;
  final ValueChanged<DiscountListItem> onEdit;
  final ValueChanged<DiscountListItem> onToggleStatus;
  final ValueChanged<DiscountListItem> onDelete;

  @override
  State<_DiscountTableRow> createState() => _DiscountTableRowState();
}

class _DiscountTableRowState extends State<_DiscountTableRow> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final DiscountListItem discount = widget.discount;
    final bool isExpired = discount.status == DiscountStatus.expired;
    final Color textColor = isExpired
        ? AppColors.textMuted
        : AppColors.textDark;

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 120),
        constraints: const BoxConstraints(
          minHeight: AppSizes.discountsTableRowMinHeight,
        ),
        decoration: BoxDecoration(
          color: isExpired
              ? AppColors.surfaceAlt.withValues(alpha: 0.55)
              : _isHovered
              ? AppColors.background
              : AppColors.surface,
          border: const Border(bottom: BorderSide(color: AppColors.divider)),
        ),
        child: Row(
          children: <Widget>[
            _BodyCell(
              flex: 23,
              child: _NameCell(discount: discount, color: textColor),
            ),
            _BodyCell(
              flex: 15,
              child: _CellText(discount.type, color: textColor),
            ),
            _BodyCell(
              flex: 13,
              child: _CellText(
                discount.displayValue,
                color: textColor,
                isEmphasized: true,
              ),
            ),
            _BodyCell(
              flex: 21,
              child: _CellText(discount.conditions, color: textColor),
            ),
            _BodyCell(
              flex: 20,
              child: _ValidPeriodCell(discount: discount, color: textColor),
            ),
            _BodyCell(
              flex: 13,
              child: DiscountStatusBadge(status: discount.status),
            ),
            _BodyCell(
              flex: 14,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: <Widget>[
                  _RowAction(
                    icon: Icons.visibility_outlined,
                    tooltip: 'View discount',
                    onPressed: () => widget.onView(discount),
                  ),
                  _RowAction(
                    icon: Icons.edit_outlined,
                    tooltip: 'Edit discount',
                    onPressed: () => widget.onEdit(discount),
                  ),
                  _RowAction(
                    icon: discount.isActive ? Icons.pause_circle_outline : Icons.play_circle_outline,
                    tooltip: discount.isActive ? 'Deactivate discount' : 'Activate discount',
                    onPressed: () => widget.onToggleStatus(discount),
                  ),
                  _RowAction(
                    icon: Icons.delete_outline,
                    tooltip: 'Delete discount',
                    onPressed: () => widget.onDelete(discount),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _HeaderCell extends StatelessWidget {
  const _HeaderCell({
    required this.label,
    required this.flex,
    this.alignRight = false,
  });

  final String label;
  final int flex;
  final bool alignRight;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      flex: flex,
      child: Padding(
        padding: AppSpacing.horizontalLg,
        child: Align(
          alignment: alignRight ? Alignment.centerRight : Alignment.centerLeft,
          child: Text(
            label,
            style: AppTextStyles.labelMedium.copyWith(
              color: AppColors.primary,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
    );
  }
}

class _BodyCell extends StatelessWidget {
  const _BodyCell({required this.flex, required this.child});

  final int flex;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      flex: flex,
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.lg,
          vertical: AppSpacing.sm,
        ),
        child: child,
      ),
    );
  }
}

class _NameCell extends StatelessWidget {
  const _NameCell({required this.discount, required this.color});

  final DiscountListItem discount;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          discount.name,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: AppTextStyles.bodySmall.copyWith(
            color: color,
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          discount.secondaryLabel,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: AppTextStyles.labelSmall.copyWith(
            color: AppColors.textMuted,
            fontSize: 11,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}

class _CellText extends StatelessWidget {
  const _CellText(this.text, {required this.color, this.isEmphasized = false});

  final String text;
  final Color color;
  final bool isEmphasized;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      maxLines: 2,
      overflow: TextOverflow.ellipsis,
      style: AppTextStyles.bodySmall.copyWith(
        color: color,
        fontSize: 13,
        fontWeight: isEmphasized ? FontWeight.w700 : FontWeight.w500,
      ),
    );
  }
}

class _ValidPeriodCell extends StatelessWidget {
  const _ValidPeriodCell({required this.discount, required this.color});

  final DiscountListItem discount;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        _CellText(discount.validPeriodPrimary, color: color),
        if (discount.validPeriodSecondary != null) ...<Widget>[
          const SizedBox(height: 2),
          Text(
            discount.validPeriodSecondary!,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppTextStyles.labelSmall.copyWith(
              color: AppColors.textMuted,
              fontSize: 11,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ],
    );
  }
}

class _RowAction extends StatelessWidget {
  const _RowAction({required this.icon, required this.tooltip, required this.onPressed});

  final IconData icon;
  final String tooltip;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: SizedBox.square(
        dimension: 28,
        child: IconButton(
          onPressed: onPressed,
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints.tightFor(width: 28, height: 28),
          visualDensity: VisualDensity.compact,
          icon: Icon(icon, size: 17, color: AppColors.textMuted),
        ),
      ),
    );
  }
}

class _DiscountPagination extends StatelessWidget {
  const _DiscountPagination({
    required this.currentPage,
    required this.totalEntries,
    required this.currentPageEntryCount,
    required this.totalPages,
    required this.onPageChanged,
  });

  final int currentPage;
  final int totalEntries;
  final int currentPageEntryCount;
  final int totalPages;
  final ValueChanged<int> onPageChanged;

  @override
  Widget build(BuildContext context) {
    final int start = (currentPage - 1) * 4 + 1;
    final int end = start + currentPageEntryCount - 1;
    return Container(
      width: double.infinity,
      padding: AppSpacing.allLg,
      child: Wrap(
        alignment: WrapAlignment.spaceBetween,
        runSpacing: AppSpacing.md,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: <Widget>[
          Text(
            'Showing $start to $end of $totalEntries entries',
            style: AppTextStyles.bodySmall.copyWith(
              color: AppColors.textMuted,
              fontSize: 14,
              fontWeight: FontWeight.w400,
            ),
          ),
          Wrap(
            spacing: AppSpacing.sm,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: <Widget>[
              _PageButton(
                icon: Icons.chevron_left,
                enabled: currentPage > 1,
                onPressed: () => onPageChanged(currentPage - 1),
              ),
              for (final int page in _visiblePages)
                _PageButton(
                  label: '$page',
                  isActive: page == currentPage,
                  onPressed: () => onPageChanged(page),
                ),
              _PageButton(
                icon: Icons.chevron_right,
                enabled: currentPage < totalPages,
                onPressed: () => onPageChanged(currentPage + 1),
              ),
            ],
          ),
        ],
      ),
    );
  }

  List<int> get _visiblePages {
    if (totalPages <= 3 || currentPage <= 2) {
      return List<int>.generate(
        math.min(3, totalPages),
        (int index) => index + 1,
      );
    }
    if (currentPage >= totalPages - 1) {
      return List<int>.generate(3, (int index) => totalPages - 2 + index);
    }
    return <int>[currentPage - 1, currentPage, currentPage + 1];
  }
}

class _PageButton extends StatelessWidget {
  const _PageButton({
    this.label,
    this.icon,
    this.isActive = false,
    this.enabled = true,
    required this.onPressed,
  });

  final String? label;
  final IconData? icon;
  final bool isActive;
  final bool enabled;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox.square(
      dimension: 32,
      child: OutlinedButton(
        onPressed: enabled ? onPressed : null,
        style: OutlinedButton.styleFrom(
          padding: EdgeInsets.zero,
          minimumSize: const Size.square(32),
          foregroundColor: isActive
              ? AppColors.paginationActive
              : AppColors.textMuted,
          backgroundColor: isActive ? AppColors.background : AppColors.surface,
          side: BorderSide(
            color: isActive ? AppColors.paginationActive : AppColors.border,
          ),
          shape: const RoundedRectangleBorder(borderRadius: AppRadius.control),
        ),
        child: icon == null
            ? Text(label!, style: AppTextStyles.bodySmall)
            : Icon(icon, size: 16),
      ),
    );
  }
}

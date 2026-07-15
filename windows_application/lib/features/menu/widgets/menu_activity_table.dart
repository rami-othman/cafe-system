import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../core/constants/app_sizes.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_radius.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_text_styles.dart';
import '../models/menu_activity.dart';

class MenuActivityTable extends StatelessWidget {
  const MenuActivityTable({super.key, required this.activities});

  final List<MenuActivity> activities;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.md,
            AppSpacing.md,
            AppSpacing.md,
            AppSpacing.sm,
          ),
          child: Text(
            'Recent Menu Activity',
            style: AppTextStyles.titleMedium.copyWith(fontSize: 16),
          ),
        ),
        LayoutBuilder(
          builder: (BuildContext context, BoxConstraints constraints) {
            final double tableWidth = math.max(
              constraints.maxWidth,
              AppSizes.menuTableMinWidth,
            );

            return SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: SizedBox(
                width: tableWidth,
                child: Column(
                  children: <Widget>[
                    const _TableRow(
                      isHeader: true,
                      activity: 'Activity',
                      user: 'User',
                      dateTime: 'Date & Time',
                      status: 'Status',
                    ),
                    for (final MenuActivity activity in activities)
                      _TableRow(
                        activity: activity.activity,
                        user: activity.user,
                        dateTime: activity.dateTimeLabel,
                        status: activity.status,
                      ),
                  ],
                ),
              ),
            );
          },
        ),
      ],
    );
  }
}

class _TableRow extends StatelessWidget {
  const _TableRow({
    required this.activity,
    required this.user,
    required this.dateTime,
    required this.status,
    this.isHeader = false,
  });

  final String activity;
  final String user;
  final String dateTime;
  final String status;
  final bool isHeader;

  @override
  Widget build(BuildContext context) {
    final TextStyle style = isHeader
        ? AppTextStyles.labelSmall.copyWith(
            color: AppColors.textPrimary,
            fontWeight: FontWeight.w500,
          )
        : AppTextStyles.bodySmall.copyWith(
            color: AppColors.textMuted,
            fontSize: 14,
            fontWeight: FontWeight.w400,
          );

    return Container(
      height: AppSizes.menuTableRowHeight,
      decoration: BoxDecoration(
        color: isHeader ? AppColors.menuTableHeader : AppColors.surface,
        border: isHeader
            ? null
            : const Border(bottom: BorderSide(color: AppColors.divider)),
      ),
      child: Row(
        children: <Widget>[
          _Cell(
            flex: 44,
            child: Text(
              activity,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: style.copyWith(
                color: isHeader ? AppColors.textPrimary : AppColors.textDark,
              ),
            ),
          ),
          _Cell(flex: 12, child: Text(user, style: style)),
          _Cell(flex: 24, child: Text(dateTime, style: style)),
          _Cell(
            flex: 20,
            child: isHeader
                ? Text(status, style: style)
                : Align(
                    alignment: Alignment.centerLeft,
                    child: _StatusChip(status: status),
                  ),
          ),
        ],
      ),
    );
  }
}

class _Cell extends StatelessWidget {
  const _Cell({required this.flex, required this.child});

  final int flex;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      flex: flex,
      child: Padding(padding: AppSpacing.horizontalMd, child: child),
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.status});

  final String status;

  @override
  Widget build(BuildContext context) {
    final bool isPending = status == 'Pending Sync';

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: 2,
      ),
      decoration: BoxDecoration(
        color: isPending
            ? AppColors.menuPendingBadge
            : AppColors.menuAppliedBadge,
        borderRadius: AppRadius.pillRadius,
      ),
      child: Text(
        status,
        style: AppTextStyles.labelSmall.copyWith(
          color: isPending
              ? AppColors.menuPendingText
              : AppColors.menuAppliedText,
          fontSize: 10,
          letterSpacing: 0.3,
        ),
      ),
    );
  }
}

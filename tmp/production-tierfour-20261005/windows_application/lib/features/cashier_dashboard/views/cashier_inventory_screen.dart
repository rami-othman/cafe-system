import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../app/localization/localization_extensions.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_radius.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_text_styles.dart';
import '../controllers/cashier_inventory_cubit.dart';
import '../models/cashier_dashboard.dart';
import '../widgets/cashier_dashboard_widgets.dart';

/// The Cashier's operational stock view for the effective POS warehouse.
///
/// Quantities, units and stock state only. There is no cost, weighted average,
/// valuation, supplier price or accounting column here — the endpoint behind it
/// does not select those fields at all — and no warehouse picker, because the
/// only warehouse a cashier operates is the one their sales consume from.
class CashierInventoryScreen extends StatefulWidget {
  const CashierInventoryScreen({super.key, this.initialState});

  /// Deep-linked filter from the dashboard's "low" / "negative" tiles.
  final String? initialState;

  @override
  State<CashierInventoryScreen> createState() => _CashierInventoryScreenState();
}

class _CashierInventoryScreenState extends State<CashierInventoryScreen> {
  late final TextEditingController _search = TextEditingController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        context.read<CashierInventoryCubit>().load(
          initialStateFilter: widget.initialState,
        );
      }
    });
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<CashierInventoryCubit, CashierInventoryState>(
      builder: (BuildContext context, CashierInventoryState state) {
        return ListView(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.xl,
            AppSpacing.lg,
            AppSpacing.xl,
            AppSpacing.xxl,
          ),
          children: <Widget>[
            Text(
              context.l10n.cashierInventoryTitle,
              style: AppTextStyles.headlineMedium,
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              state.page?.configured == true
                  ? state.page!.warehouseName
                  : context.l10n.cashierInventorySubtitle,
              style: AppTextStyles.bodySmall.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            _Filters(controller: _search, state: state),
            const SizedBox(height: AppSpacing.lg),
            if (state.status == CashierInventoryStatus.error)
              CashierErrorPanel(
                message: context.l10n.cashierInventoryError,
                retryLabel: context.l10n.cashierRetry,
                onRetry: () => context.read<CashierInventoryCubit>().load(),
              )
            else if (state.showsSkeleton)
              Column(
                children: List<Widget>.generate(
                  6,
                  (_) => const Padding(
                    padding: EdgeInsets.only(bottom: AppSpacing.sm),
                    child: CashierSkeletonCard(height: 56),
                  ),
                ),
              )
            else if (state.page?.configured != true)
              _EmptyNotice(message: context.l10n.cashierInventoryUnavailable)
            else if (state.page!.items.isEmpty)
              _EmptyNotice(message: context.l10n.cashierInventoryEmpty)
            else
              _StockTable(rows: state.page!.items),
          ],
        );
      },
    );
  }
}

class _Filters extends StatelessWidget {
  const _Filters({required this.controller, required this.state});

  final TextEditingController controller;
  final CashierInventoryState state;

  @override
  Widget build(BuildContext context) {
    final List<(String?, String)> options = <(String?, String)>[
      (null, context.l10n.cashierInventoryFilterAll),
      ('low', context.l10n.cashierInventoryStateLow),
      ('zero', context.l10n.cashierInventoryStateZero),
      ('negative', context.l10n.cashierInventoryStateNegative),
      ('normal', context.l10n.cashierInventoryStateNormal),
    ];

    return Wrap(
      spacing: AppSpacing.sm,
      runSpacing: AppSpacing.sm,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: <Widget>[
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 320, minWidth: 200),
          child: SizedBox(
            height: kCashierTouchTarget,
            child: TextField(
              controller: controller,
              onSubmitted: (String value) =>
                  context.read<CashierInventoryCubit>().search(value.trim()),
              decoration: InputDecoration(
                hintText: context.l10n.cashierInventorySearchHint,
                prefixIcon: const Icon(Icons.search, size: 20),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.md,
                ),
              ),
            ),
          ),
        ),
        for (final (String?, String) option in options)
          _FilterChip(
            label: option.$2,
            selected: state.stateFilter == option.$1,
            onTap: () =>
                context.read<CashierInventoryCubit>().filterByState(option.$1),
          ),
      ],
    );
  }
}

class _FilterChip extends StatelessWidget {
  const _FilterChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Material(
    color: selected ? AppColors.navActiveBackground : AppColors.surface,
    clipBehavior: Clip.antiAlias,
    shape: RoundedRectangleBorder(
      borderRadius: AppRadius.pillRadius,
      side: const BorderSide(color: AppColors.border),
    ),
    child: InkWell(
      onTap: onTap,
      child: Container(
        height: kCashierTouchTarget,
        alignment: Alignment.center,
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
        child: Text(
          label,
          style: AppTextStyles.labelMedium.copyWith(
            fontWeight: FontWeight.w700,
            color: selected ? AppColors.navActiveText : AppColors.textSecondary,
          ),
        ),
      ),
    ),
  );
}

class _StockTable extends StatelessWidget {
  const _StockTable({required this.rows});

  final List<CashierStockRow> rows;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: AppRadius.card,
        border: Border.all(color: AppColors.border),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: <Widget>[
          for (int index = 0; index < rows.length; index++)
            _StockRowTile(row: rows[index], isLast: index == rows.length - 1),
        ],
      ),
    );
  }
}

class _StockRowTile extends StatelessWidget {
  const _StockRowTile({required this.row, required this.isLast});

  final CashierStockRow row;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    final bool arabic = context.isArabic;
    final String name = arabic
        ? (row.nameAr.isEmpty ? row.nameEn : row.nameAr)
        : (row.nameEn.isEmpty ? row.nameAr : row.nameEn);
    final (String label, Color colour) = switch (row.state) {
      'negative' => (context.l10n.cashierInventoryStateNegative, AppColors.danger),
      'zero' => (context.l10n.cashierInventoryStateZero, AppColors.textSecondary),
      'low' => (context.l10n.cashierInventoryStateLow, AppColors.warning),
      _ => (context.l10n.cashierInventoryStateNormal, AppColors.success),
    };

    return Container(
      constraints: const BoxConstraints(minHeight: kCashierTouchTarget + 8),
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
        vertical: AppSpacing.md,
      ),
      decoration: BoxDecoration(
        border: isLast
            ? null
            : const Border(bottom: BorderSide(color: AppColors.divider)),
      ),
      child: Row(
        children: <Widget>[
          Expanded(
            flex: 3,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Text(
                  name,
                  style: AppTextStyles.labelMedium.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                if (row.sku.isNotEmpty)
                  Text(
                    row.sku,
                    style: AppTextStyles.labelSmall.copyWith(
                      color: AppColors.textMuted,
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            flex: 2,
            child: Text(
              '${row.quantity} ${row.unit}',
              style: AppTextStyles.labelMedium.copyWith(
                fontWeight: FontWeight.w800,
                color: row.state == 'negative'
                    ? AppColors.danger
                    : AppColors.textPrimary,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          CashierStateBadge(label: label, colour: colour),
        ],
      ),
    );
  }
}

class _EmptyNotice extends StatelessWidget {
  const _EmptyNotice({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) => Container(
    padding: AppSpacing.allXl,
    decoration: BoxDecoration(
      color: AppColors.surface,
      borderRadius: AppRadius.card,
      border: Border.all(color: AppColors.border),
    ),
    child: Text(
      message,
      style: AppTextStyles.bodyMedium.copyWith(color: AppColors.textSecondary),
    ),
  );
}

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../app/app_router.dart';
import '../../../core/constants/app_sizes.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../shared/layouts/desktop_page_layout.dart';
import '../../../shared/widgets/app_button.dart';
import '../controllers/discounts_cubit.dart';
import '../controllers/discounts_state.dart';
import '../models/discount_list_item.dart';
import '../widgets/discount_search_controls.dart';
import '../widgets/discount_summary_card.dart';
import '../widgets/discounts_table.dart';

class DiscountsListScreen extends StatelessWidget {
  const DiscountsListScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<DiscountsCubit, DiscountsState>(
      builder: (BuildContext context, DiscountsState state) {
        final DiscountsCubit cubit = context.read<DiscountsCubit>();
        final List<DiscountListItem> filteredDiscounts =
            cubit.filteredDiscounts;
        final List<DiscountSummaryMetric> summaryMetrics = _summaryMetrics(
          state.discounts,
        );

        return DesktopPageLayout(
          padding: EdgeInsets.zero,
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.xl,
              AppSpacing.xl,
              AppSpacing.xl,
              96,
            ),
            child: ConstrainedBox(
              constraints: const BoxConstraints(
                maxWidth: AppSizes.discountsContentMaxWidth,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  _PageHeader(
                    onCreateDiscount: () =>
                        context.go(AppRoutes.discountCreate),
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  LayoutBuilder(
                    builder:
                        (BuildContext context, BoxConstraints constraints) {
                          final bool stackCards = constraints.maxWidth < 790;
                          final List<Widget> cards = <Widget>[
                            DiscountSummaryCard(
                              metric: summaryMetrics[0],
                              icon: Icons.local_offer_outlined,
                              iconBackground: AppColors.discountIconBackground,
                            ),
                            DiscountSummaryCard(
                              metric: summaryMetrics[1],
                              icon: Icons.redeem_outlined,
                              iconBackground: const Color(0xFFFFDBC7),
                            ),
                            DiscountSummaryCard(
                              metric: summaryMetrics[2],
                              icon: Icons.savings_outlined,
                              iconBackground: AppColors.surfaceAlt,
                            ),
                          ];

                          if (stackCards) {
                            return Column(
                              children: <Widget>[
                                for (
                                  int index = 0;
                                  index < cards.length;
                                  index++
                                ) ...<Widget>[
                                  SizedBox(
                                    width: double.infinity,
                                    child: cards[index],
                                  ),
                                  if (index != cards.length - 1)
                                    const SizedBox(height: AppSpacing.lg),
                                ],
                              ],
                            );
                          }

                          return Row(
                            children: <Widget>[
                              Expanded(child: cards[0]),
                              const SizedBox(width: AppSpacing.lg),
                              Expanded(child: cards[1]),
                              const SizedBox(width: AppSpacing.lg),
                              Expanded(child: cards[2]),
                            ],
                          );
                        },
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  DiscountSearchControls(
                    selectedStatus: state.selectedStatus,
                    onSearchChanged: cubit.updateSearchQuery,
                    onStatusChanged: cubit.updateStatus,
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  if (state.errorMessage != null) ...<Widget>[
                    _DiscountError(message: state.errorMessage!),
                    const SizedBox(height: AppSpacing.lg),
                  ],
                  if (state.isLoading)
                    const SizedBox(
                      height: 292,
                      child: Center(child: CircularProgressIndicator()),
                    )
                  else
                    DiscountsTable(
                      discounts: cubit.currentPageDiscounts,
                      currentPage: state.currentPage,
                      totalEntries: filteredDiscounts.length,
                      totalPages: cubit.totalPages,
                      onPageChanged: cubit.changePage,
                      onView: (DiscountListItem discount) =>
                          _showDetails(context, discount),
                      onEdit: (DiscountListItem discount) =>
                          context.go(AppRoutes.discountCreate, extra: discount),
                      onToggleStatus: (DiscountListItem discount) async {
                        final bool saved = await cubit.setStatus(
                          discount.id,
                          !discount.isActive,
                        );
                        if (context.mounted) {
                          _showSnackBar(
                            context,
                            saved
                                ? 'Discount ${discount.isActive ? 'deactivated' : 'activated'}.'
                                : state.errorMessage ??
                                      'Unable to update discount status.',
                          );
                        }
                      },
                      onDelete: (DiscountListItem discount) =>
                          _confirmDelete(context, cubit, discount),
                    ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  List<DiscountSummaryMetric> _summaryMetrics(
    List<DiscountListItem> discounts,
  ) {
    final int active = discounts
        .where(
          (DiscountListItem discount) =>
              discount.status == DiscountStatus.active,
        )
        .length;
    final int usage = discounts.fold<int>(
      0,
      (int total, DiscountListItem discount) => total + discount.usageCount,
    );
    final double saved = discounts.fold<double>(0, (
      double total,
      DiscountListItem discount,
    ) {
      return total +
          double.tryParse(
            discount.estimatedSavedValue.replaceAll(RegExp(r'[^0-9.]'), ''),
          )!;
    });
    return <DiscountSummaryMetric>[
      DiscountSummaryMetric(label: 'ACTIVE DISCOUNTS', value: '$active'),
      DiscountSummaryMetric(label: 'TOTAL USAGE (THIS MONTH)', value: '$usage'),
      DiscountSummaryMetric(
        label: 'ESTIMATED VALUE SAVED',
        value: '\$${saved.toStringAsFixed(2)}',
      ),
    ];
  }

  Future<void> _confirmDelete(
    BuildContext context,
    DiscountsCubit cubit,
    DiscountListItem discount,
  ) async {
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) => AlertDialog(
        title: const Text('Delete discount?'),
        content: Text('“${discount.name}” will no longer be available in POS.'),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true) {
      return;
    }
    final bool deleted = await cubit.deleteDiscount(discount.id);
    if (context.mounted) {
      _showSnackBar(
        context,
        deleted
            ? 'Discount deleted.'
            : cubit.state.errorMessage ?? 'Unable to delete discount.',
      );
    }
  }

  void _showDetails(BuildContext context, DiscountListItem discount) {
    showDialog<void>(
      context: context,
      builder: (BuildContext context) => AlertDialog(
        title: Text(discount.name),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(discount.secondaryLabel),
            const SizedBox(height: AppSpacing.sm),
            Text('${discount.displayValue} · ${discount.conditions}'),
            const SizedBox(height: AppSpacing.sm),
            Text('${discount.validPeriodPrimary} · ${discount.status.label}'),
            const SizedBox(height: AppSpacing.sm),
            Text(
              'Used ${discount.usageCount} times · ${discount.estimatedSavedValue} saved',
            ),
          ],
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  void _showSnackBar(BuildContext context, String message) =>
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(message)));
}

class _DiscountError extends StatelessWidget {
  const _DiscountError({required this.message});
  final String message;

  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: AppSpacing.allMd,
    color: AppColors.discountOrangeBadge,
    child: Text(
      message,
      style: AppTextStyles.bodySmall.copyWith(
        color: AppColors.discountOrangeText,
      ),
    ),
  );
}

class _PageHeader extends StatelessWidget {
  const _PageHeader({required this.onCreateDiscount});

  final VoidCallback onCreateDiscount;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final Widget heading = Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              'Discounts & Coupons',
              style: AppTextStyles.headlineMedium.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              'Manage promotional offers and pricing rules',
              style: AppTextStyles.bodySmall.copyWith(
                color: AppColors.textMuted,
                fontSize: 14,
                fontWeight: FontWeight.w400,
              ),
            ),
          ],
        );
        final Widget action = AppButton(
          label: 'Create Discount',
          icon: Icons.add,
          minimumHeight: AppSizes.discountsControlHeight,
          onPressed: onCreateDiscount,
        );

        if (constraints.maxWidth < 560) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              heading,
              const SizedBox(height: AppSpacing.lg),
              action,
            ],
          );
        }

        return Row(
          children: <Widget>[
            Expanded(child: heading),
            action,
          ],
        );
      },
    );
  }
}

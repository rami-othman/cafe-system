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

  static const List<DiscountSummaryMetric> _summaryMetrics =
      <DiscountSummaryMetric>[
        DiscountSummaryMetric(label: 'ACTIVE DISCOUNTS', value: '12'),
        DiscountSummaryMetric(label: 'TOTAL USAGE (THIS MONTH)', value: '486'),
        DiscountSummaryMetric(
          label: 'ESTIMATED VALUE SAVED',
          value: '\$1,240.50',
        ),
      ];

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<DiscountsCubit, DiscountsState>(
      builder: (BuildContext context, DiscountsState state) {
        final DiscountsCubit cubit = context.read<DiscountsCubit>();
        final List<DiscountListItem> filteredDiscounts =
            cubit.filteredDiscounts;

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
                              metric: _summaryMetrics[0],
                              icon: Icons.local_offer_outlined,
                              iconBackground: AppColors.discountIconBackground,
                            ),
                            DiscountSummaryCard(
                              metric: _summaryMetrics[1],
                              icon: Icons.redeem_outlined,
                              iconBackground: const Color(0xFFFFDBC7),
                            ),
                            DiscountSummaryCard(
                              metric: _summaryMetrics[2],
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
                  DiscountsTable(
                    discounts: cubit.currentPageDiscounts,
                    currentPage: state.currentPage,
                    totalEntries: filteredDiscounts.length,
                    totalPages: cubit.totalPages,
                    onPageChanged: cubit.changePage,
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
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

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../app/app_router.dart';
import '../../../core/constants/app_sizes.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../l10n/app_localizations.dart';
import '../../../shared/layouts/desktop_page_layout.dart';
import '../../../shared/widgets/app_button.dart';
import '../controllers/discounts_cubit.dart';
import '../controllers/discounts_state.dart';
import '../models/discount_list_item.dart';
import '../widgets/discount_search_controls.dart';
import '../widgets/discount_summary_card.dart';
import '../widgets/discount_localization.dart';
import '../widgets/discounts_table.dart';

class DiscountsListScreen extends StatelessWidget {
  const DiscountsListScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<DiscountsCubit, DiscountsState>(
      builder: (BuildContext context, DiscountsState state) {
        final DiscountsCubit cubit = context.read<DiscountsCubit>();
        final AppLocalizations l10n = AppLocalizations.of(context);
        final List<DiscountListItem> filteredDiscounts = cubit
            .filteredDiscountsMatching(
              matchesLocalizedLabel: (DiscountListItem discount) =>
                  discount.matchesLocalizedLabel(state.searchQuery, l10n),
            );
        final int totalPages = cubit.totalPagesFor(filteredDiscounts);
        final List<DiscountSummaryMetric> summaryMetrics = _summaryMetrics(
          state.discounts,
          AppLocalizations.of(context),
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
                    _DiscountError(
                      message: _localizedFailure(context, state.errorMessage!),
                    ),
                    const SizedBox(height: AppSpacing.lg),
                  ],
                  if (state.isLoading)
                    const SizedBox(
                      height: 292,
                      child: Center(child: CircularProgressIndicator()),
                    )
                  else
                    DiscountsTable(
                      discounts: cubit.pageFor(filteredDiscounts),
                      currentPage: state.currentPage,
                      totalEntries: filteredDiscounts.length,
                      totalPages: totalPages,
                      onPageChanged: (int page) =>
                          cubit.changePage(page, availablePages: totalPages),
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
                                ? AppLocalizations.of(
                                    context,
                                  ).discountsStatusUpdated(
                                    discount.isActive
                                        ? AppLocalizations.of(
                                            context,
                                          ).discountInactive.toLowerCase()
                                        : AppLocalizations.of(
                                            context,
                                          ).discountActive.toLowerCase(),
                                  )
                                : AppLocalizations.of(
                                    context,
                                  ).discountsStatusUpdateFailed,
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
    AppLocalizations l10n,
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
      return total + discount.estimatedSavedValue;
    });
    return <DiscountSummaryMetric>[
      DiscountSummaryMetric(
        label: l10n.discountsActiveMetric,
        value: NumberFormat.decimalPattern(l10n.localeName).format(active),
      ),
      DiscountSummaryMetric(
        label: l10n.discountsUsageMetric,
        value: NumberFormat.decimalPattern(l10n.localeName).format(usage),
      ),
      DiscountSummaryMetric(
        label: l10n.discountsSavedMetric,
        value: CurrencyFormatter.format(saved, locale: l10n.localeName),
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
        title: Text(AppLocalizations.of(context).discountsDeleteTitle),
        content: Text(
          AppLocalizations.of(context).discountsDeleteBody(discount.name),
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(AppLocalizations.of(context).commonCancel),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(AppLocalizations.of(context).commonDelete),
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
            ? AppLocalizations.of(context).discountsDeleted
            : AppLocalizations.of(context).discountsDeleteFailed,
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
            Text(discount.secondaryLabel(AppLocalizations.of(context))),
            const SizedBox(height: AppSpacing.sm),
            Text(
              '${discount.valueLabel(AppLocalizations.of(context))} · ${discount.conditionsLabel(AppLocalizations.of(context))}',
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              '${discount.periodLabel(AppLocalizations.of(context))} · ${discount.status.label(AppLocalizations.of(context))}',
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              AppLocalizations.of(context).discountsUsedSaved(
                discount.usageCount,
                discount.savedValueLabel(AppLocalizations.of(context)),
              ),
            ),
          ],
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(AppLocalizations.of(context).commonClose),
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

String _localizedFailure(BuildContext context, String message) =>
    AppLocalizations.of(context).discountRequestFailed;

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
              AppLocalizations.of(context).discountsTitle,
              style: AppTextStyles.headlineMedium.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              AppLocalizations.of(context).discountsSubtitle,
              style: AppTextStyles.bodySmall.copyWith(
                color: AppColors.textMuted,
                fontSize: 14,
                fontWeight: FontWeight.w400,
              ),
            ),
          ],
        );
        final Widget action = AppButton(
          label: AppLocalizations.of(context).discountsCreate,
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

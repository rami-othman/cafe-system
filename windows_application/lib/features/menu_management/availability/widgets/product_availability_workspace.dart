import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../../app/localization/localization_extensions.dart';
import '../../../../../app/menu_management_route_locations.dart';
import '../../../../../core/services/service_locator.dart';
import '../../../../../core/theme/app_colors.dart';
import '../../../../../core/theme/app_spacing.dart';
import '../../../../../core/theme/app_text_styles.dart';
import '../../../../../core/utils/currency_formatter.dart';
import '../../models/catalog_models.dart';
import '../../operational_availability/controllers/operational_availability_cubit.dart';
import '../../operational_availability/controllers/operational_availability_state.dart';
import '../../operational_availability/models/operational_availability_models.dart';
import '../../pricing/controllers/variant_price_overrides_cubit.dart';
import '../../pricing/controllers/variant_price_overrides_state.dart';
import '../../pricing/models/variant_price_models.dart';
import '../controllers/availability_cubit.dart';
import '../controllers/availability_state.dart';
import '../schedule_summary.dart';

class ProductAvailabilityWorkspace extends StatelessWidget {
  const ProductAvailabilityWorkspace({
    super.key,
    required this.product,
    this.availabilityCubit,
    this.priceCubit,
    this.operationalCubit,
  });
  final ProductDetail product;
  final AvailabilityCubit? availabilityCubit;
  final VariantPriceOverridesCubit? priceCubit;
  final OperationalAvailabilityCubit? operationalCubit;

  @override
  Widget build(BuildContext context) {
    final int? initialVariantId =
        product.defaultVariant?.id ?? product.variants.firstOrNull?.id;
    return MultiBlocProvider(
      providers: <BlocProvider<dynamic>>[
        availabilityCubit == null
            ? BlocProvider<AvailabilityCubit>(
                create: (_) =>
                    serviceLocator<AvailabilityCubit>()
                      ..load(product.id, variantId: initialVariantId),
              )
            : BlocProvider<AvailabilityCubit>.value(value: availabilityCubit!),
        priceCubit == null
            ? BlocProvider<VariantPriceOverridesCubit>(
                create: (_) {
                  final cubit = serviceLocator<VariantPriceOverridesCubit>();
                  if (initialVariantId != null) {
                    cubit.load(product.id, initialVariantId);
                  }
                  return cubit;
                },
              )
            : BlocProvider<VariantPriceOverridesCubit>.value(
                value: priceCubit!,
              ),
        operationalCubit == null
            ? BlocProvider<OperationalAvailabilityCubit>(
                create: (_) => serviceLocator<OperationalAvailabilityCubit>()
                  ..load(
                    product.id,
                    variantId: initialVariantId,
                    channel: 'pos',
                  ),
              )
            : BlocProvider<OperationalAvailabilityCubit>.value(
                value: operationalCubit!,
              ),
      ],
      child: _AvailabilityWorkspaceBody(product: product),
    );
  }
}

class _AvailabilityWorkspaceBody extends StatefulWidget {
  const _AvailabilityWorkspaceBody({required this.product});
  final ProductDetail product;
  @override
  State<_AvailabilityWorkspaceBody> createState() =>
      _AvailabilityWorkspaceBodyState();
}

class _AvailabilityWorkspaceBodyState
    extends State<_AvailabilityWorkspaceBody> {
  bool _initialized = false;
  int _contextRequest = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _initialize(context.read<AvailabilityCubit>().state);
    });
  }

  Future<void> _applyContext({
    required int? variantId,
    required int? branchId,
    required String? channel,
  }) async {
    final int request = ++_contextRequest;
    final schedule = context.read<AvailabilityCubit>();
    schedule.selectContext(
      variantId: variantId,
      branchId: branchId,
      channel: channel,
      clearVariant: variantId == null,
      clearBranch: branchId == null,
      clearChannel: channel == null,
    );
    await schedule.preview(DateTime.now());
    if (!mounted || request != _contextRequest) {
      return;
    }
    if (!mounted || variantId == null || branchId == null || channel == null) {
      return;
    }
    final prices = context.read<VariantPriceOverridesCubit>();
    if (prices.state.variant?.id == variantId) {
      await prices.selectEffectiveContext(branchId: branchId, channel: channel);
    } else {
      await prices.load(
        widget.product.id,
        variantId,
        branchId: branchId,
        channel: channel,
      );
    }
    if (!mounted || request != _contextRequest) {
      return;
    }
    await context.read<OperationalAvailabilityCubit>().load(
      widget.product.id,
      variantId: variantId,
      branchId: branchId,
      channel: channel,
    );
  }

  void _initialize(AvailabilityState state) {
    if (_initialized || state.product == null) return;
    final branchId = state.branches
        .where((item) => item.isActive)
        .firstOrNull
        ?.id;
    final variantId =
        state.selectedVariantId ??
        state.product!.defaultVariant?.id ??
        state.product!.variants.firstOrNull?.id;
    if (variantId == null || branchId == null) return;
    _initialized = true;
    _applyContext(variantId: variantId, branchId: branchId, channel: 'pos');
  }

  @override
  Widget build(BuildContext context) =>
      BlocListener<AvailabilityCubit, AvailabilityState>(
        listenWhen: (previous, current) =>
            previous.status != current.status ||
            previous.product != current.product,
        listener: (_, state) => _initialize(state),
        child: BlocBuilder<AvailabilityCubit, AvailabilityState>(
          builder: (context, schedule) {
            final l10n = context.l10n;
            if (schedule.status == AvailabilityStatus.initial ||
                (schedule.status == AvailabilityStatus.loading &&
                    schedule.product == null)) {
              return const Center(
                child: Padding(
                  padding: AppSpacing.allXl,
                  child: CircularProgressIndicator(),
                ),
              );
            }
            if (schedule.product == null) {
              return _WorkspaceMessage(
                message:
                    schedule.errorMessage ?? l10n.batch8AvailabilityLoadError,
                onRetry: () =>
                    context.read<AvailabilityCubit>().load(widget.product.id),
              );
            }
            return BlocBuilder<
              VariantPriceOverridesCubit,
              VariantPriceOverridesState
            >(
              builder: (context, prices) =>
                  BlocBuilder<
                    OperationalAvailabilityCubit,
                    OperationalAvailabilityState
                  >(
                    builder: (context, operational) {
                      final variant = schedule.selectedVariant;
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Text(
                            l10n.batch8AvailabilityTitle,
                            style: AppTextStyles.headlineMedium,
                          ),
                          const SizedBox(height: AppSpacing.xs),
                          Text(
                            l10n.batch8AvailabilityHelp,
                            style: AppTextStyles.bodyMedium.copyWith(
                              color: AppColors.textSecondary,
                            ),
                          ),
                          const SizedBox(height: AppSpacing.md),
                          _ContextBar(
                            state: schedule,
                            onChanged: (variantId, branchId, channel) =>
                                _applyContext(
                                  variantId: variantId,
                                  branchId: branchId,
                                  channel: channel,
                                ),
                          ),
                          const SizedBox(height: AppSpacing.lg),
                          LayoutBuilder(
                            builder: (context, constraints) {
                              final cards = <Widget>[
                                _PriceCard(
                                  product: widget.product,
                                  variant: variant,
                                  state: prices,
                                ),
                                _ScheduleCard(
                                  product: widget.product,
                                  state: schedule,
                                ),
                                _OperationalCard(
                                  product: widget.product,
                                  variantId: schedule.selectedVariantId,
                                  state: operational,
                                ),
                              ];
                              if (constraints.maxWidth < 860) {
                                return Column(
                                  children: cards
                                      .map(
                                        (card) => Padding(
                                          padding: const EdgeInsets.only(
                                            bottom: AppSpacing.md,
                                          ),
                                          child: card,
                                        ),
                                      )
                                      .toList(growable: false),
                                );
                              }
                              return Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: <Widget>[
                                  for (
                                    var index = 0;
                                    index < cards.length;
                                    index++
                                  ) ...<Widget>[
                                    Expanded(child: cards[index]),
                                    if (index < cards.length - 1)
                                      const SizedBox(width: AppSpacing.md),
                                  ],
                                ],
                              );
                            },
                          ),
                          const SizedBox(height: AppSpacing.lg),
                          _EffectiveResult(
                            prices: prices,
                            schedule: schedule,
                            operational: operational,
                          ),
                        ],
                      );
                    },
                  ),
            );
          },
        ),
      );
}

class _ContextBar extends StatelessWidget {
  const _ContextBar({required this.state, required this.onChanged});
  final AvailabilityState state;
  final void Function(int? variantId, int? branchId, String? channel) onChanged;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Container(
      padding: AppSpacing.allMd,
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border.all(color: AppColors.border),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Wrap(
        spacing: AppSpacing.md,
        runSpacing: AppSpacing.sm,
        children: <Widget>[
          SizedBox(
            width: 250,
            child: DropdownButtonFormField<int>(
              key: const Key('availability-workspace-variant'),
              isExpanded: true,
              initialValue: state.selectedVariantId,
              decoration: InputDecoration(labelText: l10n.batch8Variant),
              items: state.product!.variants
                  .map(
                    (item) => DropdownMenuItem(
                      value: item.id,
                      child: Text(
                        item.displayName(Localizations.localeOf(context)),
                      ),
                    ),
                  )
                  .toList(growable: false),
              onChanged: (value) => onChanged(
                value,
                state.selectedBranchId,
                state.selectedChannel,
              ),
            ),
          ),
          SizedBox(
            width: 230,
            child: DropdownButtonFormField<int>(
              key: const Key('availability-workspace-branch'),
              isExpanded: true,
              initialValue: state.selectedBranchId,
              decoration: InputDecoration(labelText: l10n.batch8Branch),
              items: state.branches
                  .where((item) => item.isActive)
                  .map(
                    (item) => DropdownMenuItem(
                      value: item.id,
                      child: Text(item.name),
                    ),
                  )
                  .toList(growable: false),
              onChanged: (value) => onChanged(
                state.selectedVariantId,
                value,
                state.selectedChannel,
              ),
            ),
          ),
          SizedBox(
            width: 220,
            child: DropdownButtonFormField<String>(
              key: const Key('availability-workspace-channel'),
              isExpanded: true,
              initialValue: state.selectedChannel,
              decoration: InputDecoration(labelText: l10n.batch8Channel),
              items: availabilityChannels
                  .map(
                    (item) => DropdownMenuItem(
                      value: item,
                      child: Text(availabilityChannelLabel(item)),
                    ),
                  )
                  .toList(growable: false),
              onChanged: (value) => onChanged(
                state.selectedVariantId,
                state.selectedBranchId,
                value,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PriceCard extends StatelessWidget {
  const _PriceCard({
    required this.product,
    required this.variant,
    required this.state,
  });
  final ProductDetail product;
  final ProductVariant? variant;
  final VariantPriceOverridesState state;
  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final price = state.effectivePrice;
    final loading =
        state.isEffectiveLoading ||
        state.status == VariantPriceOverridesStatus.loading;
    return _SummaryCard(
      icon: Icons.sell_outlined,
      title: l10n.batch8SellingPrice,
      value: loading
          ? l10n.batch8Loading
          : price == null
          ? _catalogMoney(variant?.basePrice)
          : _money(price.effectivePrice),
      facts: <Widget>[
        _Fact(
          l10n.batch8BasePrice,
          price == null
              ? _catalogMoney(variant?.basePrice)
              : _money(price.basePrice),
        ),
        _Fact(
          l10n.batch8Using,
          state.effectiveError ?? _priceSource(context, price),
        ),
      ],
      action: l10n.batch8ManagePricing,
      onPressed: variant == null
          ? null
          : () => context.push(
              MenuManagementRouteLocations.variantPricing(
                product.id,
                variant!.id,
              ),
            ),
      retry: state.effectiveError == null
          ? null
          : () => context
                .read<VariantPriceOverridesCubit>()
                .selectEffectiveContext(
                  branchId: state.effectiveBranchId,
                  channel: state.effectiveChannel,
                ),
    );
  }
}

class _ScheduleCard extends StatelessWidget {
  const _ScheduleCard({required this.product, required this.state});
  final ProductDetail product;
  final AvailabilityState state;
  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final noRestriction =
        state.preview?.reason == 'no_schedule_restriction' &&
        state.exactRules.isEmpty;
    final value = state.isPreviewLoading
        ? l10n.batch8Checking
        : noRestriction
        ? l10n.batch8NoScheduleRestrictions
        : state.preview == null
        ? l10n.batch8Checking
        : state.preview!.isScheduledAvailable
        ? l10n.batch8AvailableNow
        : l10n.batch8UnavailableNow;
    final detail =
        state.previewError ??
        (noRestriction
            ? l10n.batch8NoScheduleRestrictionsHelp
            : state.preview == null
            ? l10n.batch8ScheduleLoadingHelp
            : state.preview!.isScheduledAvailable
            ? l10n.batch8AvailableAccordingSchedule
            : l10n.batch8UnavailableAccordingSchedule);
    return _SummaryCard(
      icon: Icons.schedule_outlined,
      title: l10n.batch8RegularAvailability,
      value: value,
      facts: <Widget>[
        _Fact(l10n.batch8Using, detail),
        if (state.exactRules.isNotEmpty)
          _Fact(
            l10n.batch8ScheduleRules,
            state.exactRules.map(scheduleSummary).join('\n'),
          ),
      ],
      action: l10n.batch8ManageSchedule,
      onPressed: () => context.push(
        MenuManagementRouteLocations.scheduledAvailability(
          product.id,
          variantId: state.selectedVariantId,
        ),
      ),
      retry: state.previewError == null
          ? null
          : () => context.read<AvailabilityCubit>().preview(DateTime.now()),
    );
  }
}

class _OperationalCard extends StatelessWidget {
  const _OperationalCard({
    required this.product,
    required this.variantId,
    required this.state,
  });
  final ProductDetail product;
  final int? variantId;
  final OperationalAvailabilityState state;
  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final preview = state.preview;
    final value =
        state.previewStatus == OperationalAvailabilityPreviewStatus.loading
        ? l10n.batch8Checking
        : state.previewError != null
        ? l10n.batch8Unavailable
        : _operationalLabel(l10n, preview?.status);
    final detail =
        state.previewError ??
        (preview == null
            ? l10n.batch8CurrentLoadingHelp
            : preview.unavailableUntil == null
            ? preview.isFallback
                  ? l10n.batch8NoTemporaryRestriction
                  : l10n.batch8TemporaryRestrictionActive
            : l10n.batch8TemporaryUntil(_time(preview.unavailableUntil!)));
    return _SummaryCard(
      icon: Icons.bolt_outlined,
      title: l10n.batch8CurrentAvailability,
      value: value,
      facts: <Widget>[_Fact(l10n.batch8Using, detail)],
      action: l10n.batch8ManageAvailability,
      onPressed: () => context.push(
        MenuManagementRouteLocations.operationalAvailability(
          product.id,
          variantId: variantId,
        ),
      ),
      retry: state.previewError == null
          ? null
          : () => context.read<OperationalAvailabilityCubit>().retryPreview(),
    );
  }
}

class _EffectiveResult extends StatelessWidget {
  const _EffectiveResult({
    required this.prices,
    required this.schedule,
    required this.operational,
  });
  final VariantPriceOverridesState prices;
  final AvailabilityState schedule;
  final OperationalAvailabilityState operational;
  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final availability =
        operational.previewStatus == OperationalAvailabilityPreviewStatus.loaded
        ? _operationalLabel(l10n, operational.preview?.status)
        : schedule.preview == null
        ? l10n.batch8Checking
        : schedule.preview!.isScheduledAvailable
        ? l10n.batch8AvailableNow
        : l10n.batch8UnavailableNow;
    return Container(
      width: double.infinity,
      padding: AppSpacing.allLg,
      decoration: BoxDecoration(
        color: AppColors.primarySoft,
        border: Border.all(color: AppColors.border),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Wrap(
        spacing: 48,
        runSpacing: AppSpacing.md,
        children: <Widget>[
          Text(
            l10n.batch8EffectiveSellingResult,
            style: AppTextStyles.titleMedium,
          ),
          _Fact(
            l10n.batch8EffectiveSellingPrice,
            prices.effectivePrice == null
                ? l10n.batch8Loading
                : _money(prices.effectivePrice!.effectivePrice),
          ),
          _Fact(l10n.batch8Availability, availability),
        ],
      ),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({
    required this.icon,
    required this.title,
    required this.value,
    required this.facts,
    required this.action,
    required this.onPressed,
    this.retry,
  });
  final IconData icon;
  final String title, value, action;
  final List<Widget> facts;
  final VoidCallback? onPressed;
  final VoidCallback? retry;
  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: AppSpacing.allLg,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Icon(icon, color: AppColors.primary),
          const SizedBox(height: AppSpacing.md),
          Text(
            title,
            style: AppTextStyles.labelLarge.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(value, style: AppTextStyles.titleLarge),
          const SizedBox(height: AppSpacing.sm),
          ...facts,
          const SizedBox(height: AppSpacing.md),
          OutlinedButton(onPressed: onPressed, child: Text(action)),
          if (retry != null)
            TextButton(onPressed: retry, child: Text(context.l10n.batch8Retry)),
        ],
      ),
    ),
  );
}

class _Fact extends StatelessWidget {
  const _Fact(this.label, this.value);
  final String label, value;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: AppSpacing.xs),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(label, style: AppTextStyles.labelSmall),
        Text(value, style: AppTextStyles.bodySmall),
      ],
    ),
  );
}

class _WorkspaceMessage extends StatelessWidget {
  const _WorkspaceMessage({required this.message, required this.onRetry});
  final String message;
  final VoidCallback onRetry;
  @override
  Widget build(BuildContext context) => Center(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Text(message),
        const SizedBox(height: AppSpacing.md),
        OutlinedButton(
          onPressed: onRetry,
          child: Text(context.l10n.batch8Retry),
        ),
      ],
    ),
  );
}

String _money(PriceAmount value) =>
    CurrencyFormatter.formatMinorUnits(value.minorUnits);
String _catalogMoney(num? value) =>
    value == null ? '—' : CurrencyFormatter.format(value);
String _time(DateTime value) =>
    '${value.hour.toString().padLeft(2, '0')}:${value.minute.toString().padLeft(2, '0')}';
String _operationalLabel(dynamic l10n, OperationalAvailabilityStatus? status) =>
    switch (status) {
      OperationalAvailabilityStatus.available => l10n.batch8AvailableNow,
      OperationalAvailabilityStatus.soldOut => l10n.batch8SoldOut,
      OperationalAvailabilityStatus.temporarilyUnavailable =>
        l10n.batch8TemporarilyUnavailable,
      null => l10n.batch8Checking,
    };
String _priceSource(BuildContext context, EffectiveVariantPrice? price) {
  final l10n = context.l10n;
  if (price == null) return l10n.batch8PriceLoadingHelp;
  return switch (price.matchedScope) {
    'branch_channel' => l10n.batch8PriceFromBranchAndChannel,
    'branch' => l10n.batch8PriceFromBranch,
    'channel' => l10n.batch8PriceFromChannel,
    _ => l10n.batch8PriceFromBase,
  };
}

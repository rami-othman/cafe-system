import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

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
import '../models/availability_models.dart';
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
                message: l10n.batch8AvailabilityLoadError,
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
                              return IntrinsicHeight(
                                child: Row(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.stretch,
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
                                ),
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
      width: double.infinity,
      padding: AppSpacing.allLg,
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border.all(color: AppColors.border),
        borderRadius: BorderRadius.circular(12),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final fields = <Widget>[
            _ContextField(
              label: l10n.batch8Variant,
              child: DropdownButtonFormField<int>(
                key: const Key('availability-workspace-variant'),
                isExpanded: true,
                initialValue: state.selectedVariantId,
                decoration: _contextInputDecoration(),
                items: state.product!.variants
                    .map(
                      (item) => DropdownMenuItem(
                        value: item.id,
                        child: Text(
                          item.displayName(Localizations.localeOf(context)),
                          overflow: TextOverflow.ellipsis,
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
            _ContextField(
              label: l10n.batch8Branch,
              child: DropdownButtonFormField<int>(
                key: const Key('availability-workspace-branch'),
                isExpanded: true,
                initialValue: state.selectedBranchId,
                decoration: _contextInputDecoration(),
                items: state.branches
                    .where((item) => item.isActive)
                    .map(
                      (item) => DropdownMenuItem(
                        value: item.id,
                        child: Text(item.name, overflow: TextOverflow.ellipsis),
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
            _ContextField(
              label: l10n.batch8Channel,
              child: DropdownButtonFormField<String>(
                key: const Key('availability-workspace-channel'),
                isExpanded: true,
                initialValue: state.selectedChannel,
                decoration: _contextInputDecoration(),
                items: availabilityChannels
                    .map(
                      (item) => DropdownMenuItem(
                        value: item,
                        child: Text(
                          availabilityChannelLabel(item),
                          overflow: TextOverflow.ellipsis,
                        ),
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
          ];
          if (constraints.maxWidth < 680) {
            return Column(
              children: fields
                  .map(
                    (field) => Padding(
                      padding: const EdgeInsets.only(bottom: AppSpacing.md),
                      child: field,
                    ),
                  )
                  .toList(growable: false),
            );
          }
          return Row(
            children: <Widget>[
              for (var index = 0; index < fields.length; index++) ...<Widget>[
                Expanded(child: fields[index]),
                if (index < fields.length - 1)
                  const SizedBox(width: AppSpacing.md),
              ],
            ],
          );
        },
      ),
    );
  }
}

InputDecoration _contextInputDecoration() => InputDecoration(
  isDense: true,
  filled: true,
  fillColor: AppColors.background,
  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
  border: OutlineInputBorder(
    borderRadius: BorderRadius.circular(8),
    borderSide: const BorderSide(color: AppColors.border),
  ),
  enabledBorder: OutlineInputBorder(
    borderRadius: BorderRadius.circular(8),
    borderSide: const BorderSide(color: AppColors.border),
  ),
);

class _ContextField extends StatelessWidget {
  const _ContextField({required this.label, required this.child});
  final String label;
  final Widget child;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: <Widget>[
      Text(label, style: AppTextStyles.labelSmall),
      const SizedBox(height: AppSpacing.xs),
      child,
    ],
  );
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
      valueLabel: l10n.batch8EffectiveSellingPrice,
      facts: <Widget>[
        _Fact(
          l10n.batch8BasePrice,
          price == null
              ? _catalogMoney(variant?.basePrice)
              : _money(price.basePrice),
        ),
        _Fact(
          l10n.batch8Using,
          state.effectiveError == null
              ? _priceSource(context, price)
              : l10n.batch8AvailabilityLoadError,
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
    final detail = state.previewError == null
        ? (noRestriction
              ? l10n.batch8NoScheduleRestrictionsHelp
              : state.preview == null
              ? l10n.batch8ScheduleLoadingHelp
              : state.preview!.isScheduledAvailable
              ? l10n.batch8AvailableAccordingSchedule
              : l10n.batch8UnavailableAccordingSchedule)
        : l10n.batch8AvailabilityLoadError;
    return _SummaryCard(
      icon: Icons.schedule_outlined,
      title: l10n.batch8RegularAvailability,
      value: value,
      status:
          state.previewError == null &&
              !state.isPreviewLoading &&
              !noRestriction
          ? state.preview?.isScheduledAvailable
          : null,
      facts: <Widget>[
        _Fact(l10n.batch8Using, detail),
        if (state.exactRules.isNotEmpty)
          _Fact(
            l10n.batch8ScheduleRules,
            _scheduleSummary(context, state.exactRules),
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
    final detail = state.previewError == null
        ? (preview == null
              ? l10n.batch8CurrentLoadingHelp
              : preview.unavailableUntil == null
              ? preview.isFallback
                    ? l10n.batch8NoTemporaryRestriction
                    : l10n.batch8TemporaryRestrictionActive
              : l10n.batch8TemporaryUntil(_time(preview.unavailableUntil!)))
        : l10n.batch8AvailabilityLoadError;
    return _SummaryCard(
      icon: Icons.bolt_outlined,
      title: l10n.batch8CurrentAvailability,
      value: value,
      status:
          state.previewError == null &&
              state.previewStatus == OperationalAvailabilityPreviewStatus.loaded
          ? preview?.isOperationallyAvailable
          : null,
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
        color: AppColors.surface,
        border: Border.all(color: AppColors.border),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            l10n.batch8EffectiveSellingResult,
            style: AppTextStyles.titleMedium,
          ),
          const SizedBox(height: AppSpacing.md),
          Container(
            width: double.infinity,
            padding: AppSpacing.allMd,
            decoration: BoxDecoration(
              color: AppColors.background,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppColors.border),
            ),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final metrics = <Widget>[
                  _ResultMetric(
                    label: l10n.batch8EffectiveSellingPrice,
                    value: prices.effectiveError != null
                        ? l10n.batch8AvailabilityLoadError
                        : prices.effectivePrice == null
                        ? l10n.batch8Loading
                        : _money(prices.effectivePrice!.effectivePrice),
                  ),
                  _ResultMetric(
                    label: l10n.batch8Availability,
                    value: availability,
                    valueColor: _availabilityColor(operational, schedule),
                  ),
                ];
                if (constraints.maxWidth < 480) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      metrics.first,
                      const SizedBox(height: AppSpacing.md),
                      metrics.last,
                    ],
                  );
                }
                return Row(
                  children: <Widget>[
                    Expanded(child: metrics.first),
                    Container(width: 1, height: 36, color: AppColors.border),
                    const SizedBox(width: AppSpacing.lg),
                    Expanded(child: metrics.last),
                  ],
                );
              },
            ),
          ),
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
    this.valueLabel,
    this.status,
  });
  final IconData icon;
  final String title, value, action;
  final List<Widget> facts;
  final VoidCallback? onPressed;
  final VoidCallback? retry;
  final String? valueLabel;
  final bool? status;
  @override
  Widget build(BuildContext context) => Container(
    constraints: const BoxConstraints(minHeight: 266),
    decoration: BoxDecoration(
      color: AppColors.surface,
      border: Border.all(color: AppColors.border),
      borderRadius: BorderRadius.circular(12),
    ),
    child: Padding(
      padding: AppSpacing.allLg,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: AppColors.primarySoft,
                  borderRadius: BorderRadius.circular(9),
                ),
                child: Icon(icon, size: 18, color: AppColors.secondary),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(child: Text(title, style: AppTextStyles.titleMedium)),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          if (valueLabel != null) ...<Widget>[
            Text(valueLabel!, style: AppTextStyles.labelSmall),
            const SizedBox(height: AppSpacing.xs),
          ],
          if (status != null)
            _StatusPill(label: value, available: status!)
          else
            Text(value, style: AppTextStyles.titleLarge),
          const SizedBox(height: AppSpacing.md),
          const Divider(height: 1, color: AppColors.border),
          const SizedBox(height: AppSpacing.md),
          ...facts,
          const Spacer(),
          const SizedBox(height: AppSpacing.md),
          OutlinedButton(
            onPressed: onPressed,
            style: OutlinedButton.styleFrom(
              minimumSize: const Size(0, 36),
              padding: const EdgeInsets.symmetric(horizontal: 14),
              side: const BorderSide(color: AppColors.border),
            ),
            child: Text(action),
          ),
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
        Text(
          value,
          style: AppTextStyles.bodySmall,
          maxLines: 3,
          overflow: TextOverflow.ellipsis,
        ),
      ],
    ),
  );
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.label, required this.available});
  final String label;
  final bool available;

  @override
  Widget build(BuildContext context) {
    final Color background = available
        ? const Color(0xFFE3F5E8)
        : const Color(0xFFFFE6E3);
    final Color foreground = available ? AppColors.success : AppColors.danger;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: AppTextStyles.labelMedium.copyWith(color: foreground),
      ),
    );
  }
}

class _ResultMetric extends StatelessWidget {
  const _ResultMetric({
    required this.label,
    required this.value,
    this.valueColor,
  });
  final String label;
  final String value;
  final Color? valueColor;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: <Widget>[
      Text(label, style: AppTextStyles.labelSmall),
      const SizedBox(height: AppSpacing.xs),
      Text(value, style: AppTextStyles.titleMedium.copyWith(color: valueColor)),
    ],
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

String _scheduleSummary(
  BuildContext context,
  List<AvailabilityRuleDraft> rules,
) {
  return rules
      .take(2)
      .map((rule) {
        final day = DateFormat.E(
          Localizations.localeOf(context).toString(),
        ).format(DateTime(2024, 1, 7).add(Duration(days: rule.dayOfWeek ?? 0)));
        if (rule.startTime == null || rule.endTime == null) return day;
        return '$day ${_timeRange(rule.startTime!, rule.endTime!)}';
      })
      .join('\n');
}

String _timeRange(String start, String end) => '\u2066$start–$end\u2069';

Color? _availabilityColor(
  OperationalAvailabilityState operational,
  AvailabilityState schedule,
) {
  if (operational.previewStatus ==
      OperationalAvailabilityPreviewStatus.loaded) {
    return operational.preview?.isOperationallyAvailable == true
        ? AppColors.success
        : AppColors.danger;
  }
  if (schedule.preview != null) {
    return schedule.preview!.isScheduledAvailable
        ? AppColors.success
        : AppColors.danger;
  }
  return null;
}

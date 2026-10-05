import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';

import '../../../../app/localization/localization_extensions.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../shared/layouts/desktop_page_layout.dart';
import '../../../pos/models/branch.dart';
import '../../models/catalog_models.dart';
import '../controllers/operational_availability_cubit.dart';
import '../controllers/operational_availability_state.dart';
import '../models/operational_availability_models.dart';
import '../operational_availability_formatters.dart';
import '../widgets/operational_override_editor.dart';

/// A manager-facing, state-first operational availability workflow.
///
/// The authoritative preview is the only source of the final state shown on
/// this page. Stored records are consulted only for the exact-context actions.
class OperationalAvailabilityScreen extends StatefulWidget {
  const OperationalAvailabilityScreen({
    super.key,
    required this.productId,
    this.variantId,
    this.branchId,
    this.channel,
    this.returnToVariants = false,
  });

  final int productId;
  final int? variantId;
  final int? branchId;
  final String? channel;
  final bool returnToVariants;

  @override
  State<OperationalAvailabilityScreen> createState() =>
      _OperationalAvailabilityScreenState();
}

class _OperationalAvailabilityScreenState
    extends State<OperationalAvailabilityScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => context.read<OperationalAvailabilityCubit>().load(
        widget.productId,
        variantId: widget.variantId,
        branchId: widget.branchId,
        channel: widget.channel,
      ),
    );
  }

  @override
  Widget build(
    BuildContext context,
  ) => BlocListener<OperationalAvailabilityCubit, OperationalAvailabilityState>(
    listenWhen: (previous, current) =>
        current.successMessage != null &&
        current.successMessage != previous.successMessage,
    listener: (context, state) => ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          context.maybeL10n?.operationalAvailabilitySave ??
              'Availability status saved.',
        ),
      ),
    ),
    child:
        BlocBuilder<OperationalAvailabilityCubit, OperationalAvailabilityState>(
          builder: (context, state) {
            if (state.status == OperationalAvailabilityLoadStatus.loading &&
                state.product == null) {
              return const DesktopPageLayout(
                child: Center(child: CircularProgressIndicator()),
              );
            }
            if (state.product == null) {
              return _LoadFailure(
                retry: () => context.read<OperationalAvailabilityCubit>().load(
                  widget.productId,
                  variantId: widget.variantId,
                  branchId: widget.branchId,
                  channel: widget.channel,
                ),
              );
            }
            return _OperationalAvailabilityPage(
              state: state,
              chooseVariant: context
                  .read<OperationalAvailabilityCubit>()
                  .selectVariant,
              selectScope: context
                  .read<OperationalAvailabilityCubit>()
                  .selectScope,
              retryPreview: context
                  .read<OperationalAvailabilityCubit>()
                  .retryPreview,
              edit: _edit,
              makeAvailable: _makeAvailable,
              useDefault: _useDefault,
            );
          },
        ),
  );

  Future<void> _edit(
    OperationalAvailabilityOverride? existing, {
    OperationalAvailabilityStatus? initialStatus,
  }) => showDialog<void>(
    context: context,
    builder: (_) => BlocProvider.value(
      value: context.read<OperationalAvailabilityCubit>(),
      child: OperationalOverrideEditor(
        isVariant:
            context
                .read<OperationalAvailabilityCubit>()
                .state
                .selectedVariantId !=
            null,
        existing: existing,
        initialStatus: initialStatus,
      ),
    ),
  );

  Future<void> _makeAvailable(OperationalAvailabilityOverride? existing) async {
    final OperationalAvailabilityCubit cubit = context
        .read<OperationalAvailabilityCubit>();
    final OperationalAvailabilityState state = cubit.state;
    final int? branchId = state.selectedBranchId;
    final String? channel = state.selectedChannel;
    if (branchId == null || channel == null) return;
    final OperationalAvailabilityDraft draft = OperationalAvailabilityDraft(
      branchId: branchId,
      channel: channel,
      status: OperationalAvailabilityStatus.available,
      // Preserve existing persisted metadata; it is not inventory UI.
      remainingQuantity: existing?.remainingQuantity,
    );
    if (state.selectedVariantId == null) {
      await cubit.upsertProduct(draft, replacingScopeKey: existing?.scopeKey);
    } else {
      await cubit.upsertVariant(draft, replacingScopeKey: existing?.scopeKey);
    }
  }

  Future<void> _useDefault(OperationalAvailabilityOverride override) async {
    final l = context.maybeL10n;
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (dialog) => AlertDialog(
        title: Text(
          l?.operationalAvailabilityUseDefaultTitle ?? 'Use default status?',
        ),
        content: Text(
          l?.operationalAvailabilityUseDefaultMessage ??
              'This removes only the status set for this exact product context. The resulting availability will be checked again.',
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.pop(dialog, false),
            child: Text(l?.operationalAvailabilityCancel ?? 'Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialog, true),
            child: Text(
              l?.operationalAvailabilityDefaultAction ?? 'Use default',
            ),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    final cubit = context.read<OperationalAvailabilityCubit>();
    if (cubit.state.selectedVariantId == null) {
      await cubit.clearProduct(override);
    } else {
      await cubit.clearVariant(override);
    }
  }
}

class _OperationalAvailabilityPage extends StatelessWidget {
  const _OperationalAvailabilityPage({
    required this.state,
    required this.chooseVariant,
    required this.selectScope,
    required this.retryPreview,
    required this.edit,
    required this.makeAvailable,
    required this.useDefault,
  });

  final OperationalAvailabilityState state;
  final ValueChanged<int?> chooseVariant;
  final Future<void> Function({
    int? branchId,
    String? channel,
    bool clearBranch,
    bool clearChannel,
  })
  selectScope;
  final Future<void> Function() retryPreview;
  final Future<void> Function(
    OperationalAvailabilityOverride?, {
    OperationalAvailabilityStatus? initialStatus,
  })
  edit;
  final ValueChanged<OperationalAvailabilityOverride?> makeAvailable;
  final ValueChanged<OperationalAvailabilityOverride> useDefault;

  @override
  Widget build(BuildContext context) {
    final ProductDetail product = state.product!;
    final l = context.maybeL10n;
    return DesktopPageLayout(
      child: Align(
        alignment: AlignmentDirectional.topStart,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 720),
          child: SingleChildScrollView(
            padding: const EdgeInsets.only(bottom: 64),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(product.name, style: AppTextStyles.headlineMedium),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  l?.operationalAvailabilityTitle ?? 'Operational availability',
                  style: AppTextStyles.titleMedium.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  l?.operationalAvailabilityPurpose ??
                      'Can customers order this item right now? Temporary operational exceptions only.',
                  style: AppTextStyles.bodySmall,
                ),
                if (state.isProductArchived ||
                    state.isSelectedVariantArchived) ...<Widget>[
                  const SizedBox(height: AppSpacing.lg),
                  _InfoBanner(
                    message:
                        l?.operationalAvailabilityArchived ??
                        'This item is archived. Current availability is shown for reference and cannot be changed.',
                  ),
                ],
                const SizedBox(height: AppSpacing.xl),
                _ContextCard(
                  state: state,
                  chooseVariant: chooseVariant,
                  selectScope: selectScope,
                ),
                const SizedBox(height: AppSpacing.lg),
                _CurrentAvailabilityCard(
                  state: state,
                  retryPreview: retryPreview,
                  edit: edit,
                  makeAvailable: makeAvailable,
                  useDefault: useDefault,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ContextCard extends StatelessWidget {
  const _ContextCard({
    required this.state,
    required this.chooseVariant,
    required this.selectScope,
  });

  final OperationalAvailabilityState state;
  final ValueChanged<int?> chooseVariant;
  final Future<void> Function({
    int? branchId,
    String? channel,
    bool clearBranch,
    bool clearChannel,
  })
  selectScope;

  @override
  Widget build(BuildContext context) {
    final l = context.maybeL10n;
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
            l?.operationalAvailabilityContext ?? 'Current context',
            style: AppTextStyles.labelLarge,
          ),
          const SizedBox(height: AppSpacing.md),
          LayoutBuilder(
            builder: (context, constraints) {
              final double fieldWidth = constraints.maxWidth >= 650
                  ? (constraints.maxWidth - (AppSpacing.md * 2)) / 3
                  : constraints.maxWidth;
              return Wrap(
                spacing: AppSpacing.md,
                runSpacing: AppSpacing.md,
                children: <Widget>[
                  SizedBox(
                    width: fieldWidth,
                    child: DropdownButtonFormField<int>(
                      key: const Key('operational-variant-selector'),
                      initialValue: state.selectedVariantId,
                      isExpanded: true,
                      decoration: InputDecoration(
                        labelText:
                            l?.operationalAvailabilityProductVariant ??
                            'Product / Variant',
                      ),
                      items: <DropdownMenuItem<int>>[
                        DropdownMenuItem(
                          value: null,
                          child: Text(
                            l?.operationalAvailabilityProductOnly ?? 'Product',
                          ),
                        ),
                        ...state.product!.variants.map(
                          (item) => DropdownMenuItem(
                            value: item.id,
                            child: Text(item.name),
                          ),
                        ),
                      ],
                      onChanged: state.isMutating ? null : chooseVariant,
                    ),
                  ),
                  SizedBox(
                    width: fieldWidth,
                    child: DropdownButtonFormField<int>(
                      key: const Key('operational-branch-filter'),
                      initialValue: state.selectedBranchId,
                      isExpanded: true,
                      decoration: InputDecoration(
                        labelText: l?.operationalAvailabilityBranch ?? 'Branch',
                      ),
                      items: state.branches
                          .where((item) => item.isActive)
                          .map(
                            (Branch item) => DropdownMenuItem(
                              value: item.id,
                              child: Text(item.name),
                            ),
                          )
                          .toList(growable: false),
                      onChanged: state.isMutating
                          ? null
                          : (value) => selectScope(
                              branchId: value,
                              clearBranch: value == null,
                              clearChannel: false,
                            ),
                    ),
                  ),
                  SizedBox(
                    width: fieldWidth,
                    child: DropdownButtonFormField<String>(
                      key: const Key('operational-channel-filter'),
                      initialValue: state.selectedChannel,
                      isExpanded: true,
                      decoration: InputDecoration(
                        labelText:
                            l?.operationalAvailabilityChannel ??
                            'Sales channel',
                      ),
                      items: operationalSalesChannels
                          .map(
                            (item) => DropdownMenuItem(
                              value: item,
                              child: Text(operationalChannelLabel(item)),
                            ),
                          )
                          .toList(growable: false),
                      onChanged: state.isMutating
                          ? null
                          : (value) => selectScope(
                              channel: value,
                              clearBranch: false,
                              clearChannel: value == null,
                            ),
                    ),
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

class _CurrentAvailabilityCard extends StatelessWidget {
  const _CurrentAvailabilityCard({
    required this.state,
    required this.retryPreview,
    required this.edit,
    required this.makeAvailable,
    required this.useDefault,
  });

  final OperationalAvailabilityState state;
  final Future<void> Function() retryPreview;
  final Future<void> Function(
    OperationalAvailabilityOverride?, {
    OperationalAvailabilityStatus? initialStatus,
  })
  edit;
  final ValueChanged<OperationalAvailabilityOverride?> makeAvailable;
  final ValueChanged<OperationalAvailabilityOverride> useDefault;

  @override
  Widget build(BuildContext context) {
    final l = context.maybeL10n;
    if (state.previewStatus == OperationalAvailabilityPreviewStatus.initial) {
      return _NeutralStateCard(
        child: Text(
          l?.operationalAvailabilityNoContext ??
              'Choose an active branch and sales channel to view current availability.',
          style: AppTextStyles.bodyMedium,
        ),
      );
    }
    if (state.previewStatus == OperationalAvailabilityPreviewStatus.loading) {
      return _NeutralStateCard(
        child: Row(
          children: <Widget>[
            const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
            const SizedBox(width: AppSpacing.md),
            Text(
              l?.operationalAvailabilityLoadingCurrent ??
                  'Updating current availability…',
              style: AppTextStyles.bodyMedium,
            ),
          ],
        ),
      );
    }
    if (state.previewStatus == OperationalAvailabilityPreviewStatus.failure ||
        state.preview == null) {
      return _NeutralStateCard(
        child: Row(
          children: <Widget>[
            const Icon(Icons.error_outline, color: AppColors.danger),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Text(
                l?.operationalAvailabilityLoadError ??
                    'We couldn’t load current availability. Try again.',
              ),
            ),
            OutlinedButton(
              onPressed: retryPreview,
              child: Text(l?.commonRetry ?? 'Retry'),
            ),
          ],
        ),
      );
    }
    return _AvailabilityHero(
      state: state,
      preview: state.preview!,
      exactOverride: state.exactOverride,
      edit: edit,
      makeAvailable: makeAvailable,
      useDefault: useDefault,
    );
  }
}

class _AvailabilityHero extends StatelessWidget {
  const _AvailabilityHero({
    required this.state,
    required this.preview,
    required this.exactOverride,
    required this.edit,
    required this.makeAvailable,
    required this.useDefault,
  });

  final OperationalAvailabilityState state;
  final OperationalAvailabilityPreview preview;
  final OperationalAvailabilityOverride? exactOverride;
  final Future<void> Function(
    OperationalAvailabilityOverride?, {
    OperationalAvailabilityStatus? initialStatus,
  })
  edit;
  final ValueChanged<OperationalAvailabilityOverride?> makeAvailable;
  final ValueChanged<OperationalAvailabilityOverride> useDefault;

  @override
  Widget build(BuildContext context) {
    final l = context.maybeL10n;
    final _StateVisual visual = _StateVisual.forStatus(preview.status, l);
    final String? reason = _managerReason(preview.reason);
    final bool canMutate = state.selectedVariantId == null
        ? state.canMutateProduct
        : state.canMutateVariant;
    return Container(
      key: const Key('operational-current-state-card'),
      width: double.infinity,
      constraints: const BoxConstraints(minHeight: 218),
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: visual.background,
        border: Border.all(color: visual.border, width: 1.25),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Icon(visual.icon, color: visual.foreground, size: 22),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(
                  visual.headline,
                  key: const Key('operational-state-headline'),
                  style: AppTextStyles.titleLarge.copyWith(
                    color: visual.foreground,
                    letterSpacing: .25,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            preview.status == OperationalAvailabilityStatus.available
                ? (preview.isFallback
                      ? (l?.operationalAvailabilityNoRestriction ??
                            'No temporary restriction is active.')
                      : (l?.operationalAvailabilityExplicitAvailable ??
                            'Available for this selling context.'))
                : (l?.operationalAvailabilityActiveRestriction ??
                      'A temporary operational restriction is active.'),
            style: AppTextStyles.bodyMedium.copyWith(color: visual.supporting),
          ),
          if (preview.unavailableUntil != null) ...<Widget>[
            const SizedBox(height: AppSpacing.lg),
            Text(
              l?.operationalAvailabilityUntil(
                    _branchLocalDate(context, preview.unavailableUntil!),
                  ) ??
                  'Until: ${_branchLocalDate(context, preview.unavailableUntil!)}',
              style: AppTextStyles.labelLarge.copyWith(
                color: visual.supporting,
              ),
            ),
          ],
          if (preview.status != OperationalAvailabilityStatus.available &&
              reason != null) ...<Widget>[
            const SizedBox(height: AppSpacing.md),
            Text(
              l?.operationalAvailabilityReason ?? 'Reason',
              style: AppTextStyles.labelSmall.copyWith(
                color: visual.supporting,
              ),
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(reason, style: AppTextStyles.bodyMedium),
          ],
          const SizedBox(height: AppSpacing.xl),
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.sm,
            children: _actions(l, canMutate),
          ),
          if (exactOverride != null && canMutate) ...<Widget>[
            const SizedBox(height: AppSpacing.md),
            TextButton(
              key: const Key('operational-use-default'),
              onPressed: state.isMutating
                  ? null
                  : () => useDefault(exactOverride!),
              child: Text(
                l?.operationalAvailabilityUseDefault ?? 'Use default status',
              ),
            ),
          ],
          if (_impactText(l) case final String impact) ...<Widget>[
            const SizedBox(height: AppSpacing.lg),
            _InfoBanner(message: impact),
          ],
        ],
      ),
    );
  }

  List<Widget> _actions(dynamic l, bool canMutate) {
    final bool enabled = canMutate && !state.isMutating;
    return switch (preview.status) {
      OperationalAvailabilityStatus.available => <Widget>[
        FilledButton(
          key: const Key('operational-mark-temporary'),
          onPressed: enabled
              ? () => edit(
                  exactOverride,
                  initialStatus:
                      OperationalAvailabilityStatus.temporarilyUnavailable,
                )
              : null,
          child: Text(
            l?.operationalAvailabilityMarkUnavailable ??
                'Mark temporarily unavailable',
          ),
        ),
      ],
      OperationalAvailabilityStatus.soldOut => <Widget>[
        FilledButton(
          key: const Key('operational-make-available'),
          onPressed: enabled ? () => makeAvailable(exactOverride) : null,
          child: Text(
            l?.operationalAvailabilityMakeAvailable ?? 'Make available now',
          ),
        ),
        OutlinedButton(
          key: const Key('operational-edit-status'),
          onPressed: enabled ? () => edit(exactOverride) : null,
          child: Text(l?.operationalAvailabilityEditStatus ?? 'Edit status'),
        ),
      ],
      OperationalAvailabilityStatus.temporarilyUnavailable => <Widget>[
        FilledButton(
          key: const Key('operational-make-available'),
          onPressed: enabled ? () => makeAvailable(exactOverride) : null,
          child: Text(
            l?.operationalAvailabilityMakeAvailable ?? 'Make available now',
          ),
        ),
        OutlinedButton(
          key: const Key('operational-edit-temporary'),
          onPressed: enabled ? () => edit(exactOverride) : null,
          child: Text(
            l?.operationalAvailabilityEditTemporary ??
                'Edit temporary restriction',
          ),
        ),
      ],
    };
  }

  String? _impactText(dynamic l) {
    if (preview.matchedLevel == OperationalAvailabilityLevel.product) {
      return l?.operationalAvailabilityAllVariants ??
          'This status applies to all variants of this product.';
    }
    final String? variantName = state.selectedVariant?.name;
    if (preview.matchedLevel == OperationalAvailabilityLevel.variant &&
        variantName != null) {
      return l?.operationalAvailabilityOnlyVariant(variantName) ??
          'This status affects only $variantName.';
    }
    return null;
  }
}

class _NeutralStateCard extends StatelessWidget {
  const _NeutralStateCard({required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    constraints: const BoxConstraints(minHeight: 118),
    padding: const EdgeInsets.all(22),
    decoration: BoxDecoration(
      color: AppColors.surface,
      border: Border.all(color: AppColors.border),
      borderRadius: BorderRadius.circular(12),
    ),
    child: child,
  );
}

class _InfoBanner extends StatelessWidget {
  const _InfoBanner({required this.message});
  final String message;

  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: AppSpacing.allMd,
    decoration: BoxDecoration(
      color: const Color(0xFFFFF8F1),
      border: Border.all(color: const Color(0xFFF4E0C7)),
      borderRadius: BorderRadius.circular(10),
    ),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        const Icon(
          Icons.info_outline,
          size: 18,
          color: AppColors.discountOrangeText,
        ),
        const SizedBox(width: AppSpacing.sm),
        Expanded(child: Text(message, style: AppTextStyles.bodySmall)),
      ],
    ),
  );
}

class _LoadFailure extends StatelessWidget {
  const _LoadFailure({required this.retry});
  final VoidCallback retry;

  @override
  Widget build(BuildContext context) {
    final l = context.maybeL10n;
    return DesktopPageLayout(
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            const Icon(Icons.error_outline, color: AppColors.danger, size: 32),
            const SizedBox(height: AppSpacing.md),
            Text(
              l?.operationalAvailabilityLoadError ??
                  'We couldn’t load current availability. Try again.',
            ),
            const SizedBox(height: AppSpacing.md),
            FilledButton(
              onPressed: retry,
              child: Text(l?.commonRetry ?? 'Retry'),
            ),
          ],
        ),
      ),
    );
  }
}

class _StateVisual {
  const _StateVisual({
    required this.headline,
    required this.background,
    required this.border,
    required this.foreground,
    required this.supporting,
    required this.icon,
  });

  final String headline;
  final Color background;
  final Color border;
  final Color foreground;
  final Color supporting;
  final IconData icon;

  factory _StateVisual.forStatus(
    OperationalAvailabilityStatus status,
    dynamic l,
  ) => switch (status) {
    OperationalAvailabilityStatus.available => _StateVisual(
      headline: l?.operationalAvailabilityAvailableNow ?? 'AVAILABLE NOW',
      background: const Color(0xFFE3F5E8),
      border: const Color(0xFFB9E4C2),
      foreground: AppColors.success,
      supporting: const Color(0xFF256B2A),
      icon: Icons.check_circle_outline,
    ),
    OperationalAvailabilityStatus.soldOut => _StateVisual(
      headline: l?.operationalAvailabilitySoldOut ?? 'SOLD OUT',
      background: const Color(0xFFFFF1F0),
      border: const Color(0xFFFFC9C4),
      foreground: AppColors.danger,
      supporting: const Color(0xFF8A1F1F),
      icon: Icons.remove_shopping_cart_outlined,
    ),
    OperationalAvailabilityStatus.temporarilyUnavailable => _StateVisual(
      headline:
          l?.operationalAvailabilityTemporarilyUnavailable ??
          'TEMPORARILY UNAVAILABLE',
      background: const Color(0xFFFFF8F1),
      border: const Color(0xFFF4E0C7),
      foreground: AppColors.discountOrangeText,
      supporting: const Color(0xFF805437),
      icon: Icons.pause_circle_outline,
    ),
  };
}

String? _managerReason(String? value) {
  final String? reason = value?.trim();
  if (reason == null ||
      reason.isEmpty ||
      const <String>{
        'no_operational_override',
        'variant_override',
        'product_override',
      }.contains(reason)) {
    return null;
  }
  return reason;
}

String _branchLocalDate(BuildContext context, DateTime value) =>
    DateFormat.yMMMd(
      Localizations.localeOf(context).toLanguageTag(),
    ).add_jm().format(value);

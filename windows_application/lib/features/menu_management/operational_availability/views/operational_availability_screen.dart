import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

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
import '../widgets/clear_operational_override_dialog.dart';
import '../widgets/operational_override_editor.dart';

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
    listener: (context, state) => ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(state.successMessage!))),
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
              return _Failure(
                message: state.errorMessage ?? 'Product not found.',
                retry: () => context.read<OperationalAvailabilityCubit>().load(
                  widget.productId,
                  variantId: widget.variantId,
                ),
              );
            }
            return _Loaded(
              state: state,
              back: _back,
              refresh: () =>
                  context.read<OperationalAvailabilityCubit>().refresh(),
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
              clear: _clear,
            );
          },
        ),
  );

  void _back() => context.go(
    widget.returnToVariants
        ? '/menu-management/products/${widget.productId}/variants'
        : '/menu-management/products/${widget.productId}',
  );

  Future<void> _edit(bool isVariant, [OperationalAvailabilityOverride? item]) =>
      showDialog<void>(
        context: context,
        builder: (_) => BlocProvider.value(
          value: context.read<OperationalAvailabilityCubit>(),
          child: OperationalOverrideEditor(
            isVariant: isVariant,
            existing: item,
          ),
        ),
      );

  Future<void> _clear(
    bool isVariant,
    OperationalAvailabilityOverride item,
  ) async {
    if (await showClearOperationalOverrideDialog(context, override: item) !=
            true ||
        !mounted) {
      return;
    }
    final OperationalAvailabilityCubit cubit = context
        .read<OperationalAvailabilityCubit>();
    if (isVariant) {
      await cubit.clearVariant(item);
    } else {
      await cubit.clearProduct(item);
    }
  }
}

class _Loaded extends StatelessWidget {
  const _Loaded({
    required this.state,
    required this.back,
    required this.refresh,
    required this.chooseVariant,
    required this.selectScope,
    required this.retryPreview,
    required this.edit,
    required this.clear,
  });

  final OperationalAvailabilityState state;
  final VoidCallback back;
  final VoidCallback refresh;
  final ValueChanged<int?> chooseVariant;
  final Future<void> Function({
    int? branchId,
    String? channel,
    bool clearBranch,
    bool clearChannel,
  })
  selectScope;
  final Future<void> Function() retryPreview;
  final Future<void> Function(bool, [OperationalAvailabilityOverride?]) edit;
  final Future<void> Function(bool, OperationalAvailabilityOverride) clear;

  @override
  Widget build(BuildContext context) {
    final ProductDetail product = state.product!;
    return DesktopPageLayout(
      child: SingleChildScrollView(
        padding: const EdgeInsets.only(bottom: 96),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                TextButton.icon(
                  onPressed: back,
                  icon: const Icon(Icons.arrow_back),
                  label: const Text('Product detail'),
                ),
                const Spacer(),
                OutlinedButton.icon(
                  onPressed: state.isMutating ? null : refresh,
                  icon: const Icon(Icons.refresh),
                  label: const Text('Refresh'),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            Text(
              product.name,
              style: AppTextStyles.headlineMedium.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            Text(
              'Operational Availability',
              style: AppTextStyles.titleMedium.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
            if (state.isProductArchived) ...<Widget>[
              const SizedBox(height: AppSpacing.md),
              const _Banner(
                'This Product is archived. Operational overrides are shown diagnostically and cannot be changed.',
              ),
            ] else if (state.isSelectedVariantArchived) ...<Widget>[
              const SizedBox(height: AppSpacing.md),
              const _Banner(
                'This Variant is archived. Its overrides are shown diagnostically and cannot be changed. Product overrides remain editable.',
              ),
            ],
            if (state.errorMessage != null) ...<Widget>[
              const SizedBox(height: AppSpacing.md),
              _Banner(state.errorMessage!),
            ],
            const SizedBox(height: AppSpacing.lg),
            _ContextControls(
              state: state,
              chooseVariant: chooseVariant,
              selectScope: selectScope,
            ),
            const SizedBox(height: AppSpacing.lg),
            _ResolutionDiagnostic(state: state, retry: retryPreview),
            const SizedBox(height: AppSpacing.lg),
            _OverrideSection(
              title: 'Product Overrides',
              rows: state.visibleProductOverrides,
              canMutate: state.canMutateProduct,
              isVariant: false,
              busy: state.isMutating,
              add: () => edit(false),
              edit: (item) => edit(false, item),
              clear: (item) => clear(false, item),
            ),
            const SizedBox(height: AppSpacing.lg),
            _OverrideSection(
              title: 'Variant Overrides',
              rows: state.visibleVariantOverrides,
              canMutate: state.canMutateVariant,
              isVariant: true,
              busy: state.isMutating,
              noVariant: state.selectedVariantId == null,
              add: () => edit(true),
              edit: (item) => edit(true, item),
              clear: (item) => clear(true, item),
            ),
          ],
        ),
      ),
    );
  }
}

class _ContextControls extends StatelessWidget {
  const _ContextControls({
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
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: AppSpacing.allLg,
      child: Wrap(
        spacing: AppSpacing.md,
        runSpacing: AppSpacing.md,
        children: <Widget>[
          SizedBox(
            width: 280,
            child: DropdownButtonFormField<int>(
              key: const Key('operational-variant-selector'),
              initialValue: state.selectedVariantId,
              isExpanded: true,
              decoration: const InputDecoration(labelText: 'Product / Variant'),
              items: <DropdownMenuItem<int>>[
                const DropdownMenuItem(
                  value: null,
                  child: Text('Product only'),
                ),
                ...state.product!.variants.map(
                  (item) => DropdownMenuItem(
                    value: item.id,
                    child: Text(
                      '${item.name}${item.isArchived ? ' (Archived)' : ''}',
                    ),
                  ),
                ),
              ],
              onChanged: state.isMutating ? null : chooseVariant,
            ),
          ),
          SizedBox(
            width: 260,
            child: DropdownButtonFormField<int>(
              key: const Key('operational-branch-filter'),
              initialValue: state.selectedBranchId,
              isExpanded: true,
              decoration: const InputDecoration(labelText: 'Branch'),
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
            width: 240,
            child: DropdownButtonFormField<String>(
              key: const Key('operational-channel-filter'),
              initialValue: state.selectedChannel,
              isExpanded: true,
              decoration: const InputDecoration(labelText: 'Sales channel'),
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
      ),
    ),
  );
}

class _ResolutionDiagnostic extends StatelessWidget {
  const _ResolutionDiagnostic({required this.state, required this.retry});

  final OperationalAvailabilityState state;
  final Future<void> Function() retry;

  @override
  Widget build(BuildContext context) {
    final OperationalAvailabilityPreview? preview = state.preview;
    final Branch? branch = state.branches
        .where((item) => item.id == state.selectedBranchId)
        .firstOrNull;
    return Card(
      child: Padding(
        padding: AppSpacing.allLg,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text('Operational Resolution', style: AppTextStyles.titleLarge),
            const SizedBox(height: AppSpacing.xs),
            const Text(
              'Operational availability is evaluated separately from Scheduled Availability and publishing state.',
            ),
            const SizedBox(height: AppSpacing.md),
            Text(
              'Entity: ${state.selectedVariant == null ? 'Product' : 'Variant · ${state.selectedVariant!.name}'}',
            ),
            Text('Branch: ${branch?.name ?? 'Select an active Branch'}'),
            Text(
              'Sales channel: ${state.selectedChannel == null ? 'Select a sales channel' : operationalChannelLabel(state.selectedChannel!)}',
            ),
            const SizedBox(height: AppSpacing.md),
            if (state.previewStatus ==
                OperationalAvailabilityPreviewStatus.initial)
              const Text(
                'Select an active Branch and sales channel to evaluate operational availability.',
              )
            else if (state.previewStatus ==
                OperationalAvailabilityPreviewStatus.loading)
              const Row(
                children: <Widget>[
                  SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                  SizedBox(width: AppSpacing.sm),
                  Text('Evaluating authoritative operational resolution…'),
                ],
              )
            else if (state.previewStatus ==
                OperationalAvailabilityPreviewStatus.failure)
              Row(
                children: <Widget>[
                  Expanded(
                    child: Text(
                      state.previewError ??
                          'Unable to load operational resolution.',
                    ),
                  ),
                  OutlinedButton(onPressed: retry, child: const Text('Retry')),
                ],
              )
            else if (preview != null)
              _PreviewDetails(preview: preview),
          ],
        ),
      ),
    );
  }
}

class _PreviewDetails extends StatelessWidget {
  const _PreviewDetails({required this.preview});
  final OperationalAvailabilityPreview preview;

  @override
  Widget build(BuildContext context) {
    final String source = preview.isFallback
        ? 'No Operational Override'
        : '${operationalLevelLabel(preview.matchedLevel!)} · ${preview.matchedScope == 'exact_channel' ? 'Selected Channel' : 'All Channels'}';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Chip(label: Text(operationalStatusLabel(preview.status))),
        Text('Resolved status: ${operationalStatusLabel(preview.status)}'),
        Text('Reason: ${preview.reason ?? '—'}'),
        Text('Source: $source'),
        if (preview.isFallback)
          const Text(
            'Available fallback: no governing operational override exists.',
          )
        else ...<Widget>[
          Text('Matched override ID: ${preview.matchedRecordId}'),
          if (preview.isExplicitAvailable)
            const Text(
              'An explicit Available override won; broader overrides remain stored.',
            ),
        ],
        if (preview.remainingQuantity != null)
          Text(
            'Remaining quantity: ${operationalQuantity(preview.remainingQuantity)} (informational only)',
          ),
        if (preview.unavailableUntil != null)
          Text(
            'Temporary expiration: ${operationalDate(preview.unavailableUntil)}',
          ),
      ],
    );
  }
}

class _OverrideSection extends StatelessWidget {
  const _OverrideSection({
    required this.title,
    required this.rows,
    required this.canMutate,
    required this.isVariant,
    required this.busy,
    required this.add,
    required this.edit,
    required this.clear,
    this.noVariant = false,
  });
  final String title;
  final List<OperationalAvailabilityOverride> rows;
  final bool canMutate;
  final bool isVariant;
  final bool busy;
  final bool noVariant;
  final VoidCallback add;
  final ValueChanged<OperationalAvailabilityOverride> edit;
  final ValueChanged<OperationalAvailabilityOverride> clear;

  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: AppSpacing.allLg,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Text(title, style: AppTextStyles.titleLarge),
              const Spacer(),
              FilledButton.icon(
                key: Key(
                  isVariant
                      ? 'add-variant-operational-override'
                      : 'add-product-operational-override',
                ),
                onPressed: canMutate ? add : null,
                icon: const Icon(Icons.add),
                label: const Text('Add Override'),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          if (noVariant)
            const Text(
              'Select a Variant to view or manage its operational overrides.',
            )
          else if (rows.isEmpty)
            const Text(
              'No operational overrides are configured. Operational availability falls back to broader overrides or Available.',
            )
          else
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: DataTable(
                columns: const <DataColumn>[
                  DataColumn(label: Text('Entity')),
                  DataColumn(label: Text('Scope')),
                  DataColumn(label: Text('Status')),
                  DataColumn(label: Text('Reason')),
                  DataColumn(label: Text('Remaining quantity')),
                  DataColumn(label: Text('Mode')),
                  DataColumn(label: Text('Expiration')),
                  DataColumn(label: Text('Updated')),
                  DataColumn(label: Text('Actions')),
                ],
                rows: rows
                    .map(
                      (item) => DataRow(
                        cells: <DataCell>[
                          DataCell(Text(operationalLevelLabel(item.level))),
                          DataCell(Text(operationalScopeLabel(item))),
                          DataCell(
                            Wrap(
                              spacing: AppSpacing.xs,
                              children: <Widget>[
                                Chip(
                                  label: Text(
                                    operationalStatusLabel(item.status),
                                  ),
                                ),
                                if (item.isExpired)
                                  const Chip(label: Text('Expired')),
                              ],
                            ),
                          ),
                          DataCell(
                            SizedBox(
                              width: 180,
                              child: Text(
                                item.reason ?? '—',
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ),
                          DataCell(
                            Text(operationalQuantity(item.remainingQuantity)),
                          ),
                          DataCell(
                            Text(item.isTemporary ? 'Temporary' : 'Permanent'),
                          ),
                          DataCell(
                            Text(operationalDate(item.unavailableUntil)),
                          ),
                          DataCell(Text(operationalDate(item.updatedAt))),
                          DataCell(
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: <Widget>[
                                IconButton(
                                  tooltip: 'Edit Override',
                                  onPressed: canMutate && !busy
                                      ? () => edit(item)
                                      : null,
                                  icon: const Icon(Icons.edit_outlined),
                                ),
                                IconButton(
                                  tooltip: 'Clear Override',
                                  onPressed: canMutate && !busy
                                      ? () => clear(item)
                                      : null,
                                  icon: const Icon(Icons.delete_outline),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    )
                    .toList(growable: false),
              ),
            ),
        ],
      ),
    ),
  );
}

class _Failure extends StatelessWidget {
  const _Failure({required this.message, required this.retry});
  final String message;
  final VoidCallback retry;
  @override
  Widget build(BuildContext context) => DesktopPageLayout(
    child: Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Text(message),
          const SizedBox(height: AppSpacing.md),
          OutlinedButton(onPressed: retry, child: const Text('Retry')),
        ],
      ),
    ),
  );
}

class _Banner extends StatelessWidget {
  const _Banner(this.message);
  final String message;
  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: AppSpacing.allMd,
    color: AppColors.discountOrangeBadge,
    child: Text(message),
  );
}

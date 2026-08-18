import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/menu_management_route_locations.dart';
import '../../../../app/localization/localization_extensions.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/utils/currency_formatter.dart';
import '../../../../shared/layouts/desktop_page_layout.dart';
import '../../../pos/models/branch.dart';
import '../controllers/variant_price_overrides_cubit.dart';
import '../controllers/variant_price_overrides_state.dart';
import '../configured_price_validation.dart';
import '../models/variant_price_models.dart';

const List<String> salesChannels = <String>[
  'pos',
  'waiter_app',
  'kiosk',
  'qr_ordering',
  'delivery',
  'online_ordering',
];

String salesChannelLabel(String value) => switch (value) {
  'pos' => 'POS',
  'waiter_app' => 'Waiter App',
  'kiosk' => 'Kiosk',
  'qr_ordering' => 'QR Ordering',
  'delivery' => 'Delivery',
  'online_ordering' => 'Online Ordering',
  _ => value,
};

class VariantPriceOverridesScreen extends StatefulWidget {
  const VariantPriceOverridesScreen({
    super.key,
    required this.productId,
    required this.variantId,
  });
  final int productId;
  final int variantId;
  @override
  State<VariantPriceOverridesScreen> createState() =>
      _VariantPriceOverridesScreenState();
}

class _VariantPriceOverridesScreenState
    extends State<VariantPriceOverridesScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => context.read<VariantPriceOverridesCubit>().load(
        widget.productId,
        widget.variantId,
      ),
    );
  }

  Future<void> _back() async {
    final VariantPriceOverridesState state = context
        .read<VariantPriceOverridesCubit>()
        .state;
    if (state.isDirty && await _confirmLeave() != true) return;
    if (mounted) {
      if (context.canPop()) {
        context.pop();
      } else {
        context.go(
          MenuManagementRouteLocations.productWorkspace(
            widget.productId,
            tab: ProductWorkspaceTab.variants,
          ),
        );
      }
    }
  }

  Future<bool?> _confirmLeave() => showDialog<bool>(
    context: context,
    builder: (dialog) => AlertDialog(
      title: const Text('Unsaved price override changes'),
      content: const Text(
        'You have unsaved price override changes. Leave without saving?',
      ),
      actions: <Widget>[
        TextButton(
          onPressed: () => Navigator.pop(dialog, false),
          child: const Text('Stay'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(dialog, true),
          child: const Text('Leave'),
        ),
      ],
    ),
  );

  @override
  Widget build(BuildContext context) => PopScope<Object?>(
    canPop: false,
    onPopInvokedWithResult: (didPop, _) {
      if (!didPop) _back();
    },
    child: BlocBuilder<VariantPriceOverridesCubit, VariantPriceOverridesState>(
      builder: (context, state) {
        if (state.status == VariantPriceOverridesStatus.loading ||
            state.status == VariantPriceOverridesStatus.initial) {
          return const Center(child: CircularProgressIndicator());
        }
        if (state.status == VariantPriceOverridesStatus.failure) {
          return _Failure(
            message: state.errorMessage ?? 'Unable to load price overrides.',
            retry: () => context.read<VariantPriceOverridesCubit>().load(
              widget.productId,
              widget.variantId,
            ),
          );
        }
        return DesktopPageLayout(
          child: ListView(
            padding: AppSpacing.allLg,
            children: <Widget>[
              Row(
                children: <Widget>[
                  OutlinedButton.icon(
                    onPressed: state.isSaving ? null : _back,
                    icon: const Icon(Icons.arrow_back),
                    label: const Text('Back'),
                  ),
                  const Spacer(),
                  OutlinedButton.icon(
                    onPressed: state.isSaving
                        ? null
                        : () => context
                              .read<VariantPriceOverridesCubit>()
                              .refresh(),
                    icon: const Icon(Icons.refresh),
                    label: const Text('Refresh'),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.lg),
              Text(
                state.product!.name,
                style: AppTextStyles.headlineMedium.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              Text(
                '${state.variant!.name} · Price Overrides',
                style: AppTextStyles.titleMedium.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
              if (state.isReadOnly) ...<Widget>[
                const SizedBox(height: AppSpacing.md),
                const _Banner(
                  'This Product or Variant is archived. Overrides are shown for diagnosis and cannot be changed.',
                ),
              ],
              if (state.errorMessage != null) ...<Widget>[
                const SizedBox(height: AppSpacing.md),
                _Banner(state.errorMessage!),
              ],
              if (state.successMessage != null) ...<Widget>[
                const SizedBox(height: AppSpacing.md),
                _SuccessBanner(state.successMessage!),
              ],
              const SizedBox(height: AppSpacing.lg),
              _Summary(state: state),
              const SizedBox(height: AppSpacing.lg),
              _OverridesTable(
                onEdit: _edit,
                onRemove: (item) => context
                    .read<VariantPriceOverridesCubit>()
                    .remove(item.scopeKey),
              ),
              const SizedBox(height: AppSpacing.md),
              Wrap(
                spacing: AppSpacing.sm,
                runSpacing: AppSpacing.sm,
                children: <Widget>[
                  FilledButton.icon(
                    key: const Key('add-branch-override'),
                    onPressed: state.canEdit && state.branches.isNotEmpty
                        ? () => _edit(null, PriceOverrideScope.branch)
                        : null,
                    icon: const Icon(Icons.add),
                    label: const Text('Add Branch Override'),
                  ),
                  FilledButton.icon(
                    key: const Key('add-channel-override'),
                    onPressed: state.canEdit
                        ? () => _edit(null, PriceOverrideScope.channel)
                        : null,
                    icon: const Icon(Icons.add),
                    label: const Text('Add Channel Override'),
                  ),
                  FilledButton.icon(
                    key: const Key('add-branch-channel-override'),
                    onPressed: state.canEdit && state.branches.isNotEmpty
                        ? () => _edit(null, PriceOverrideScope.branchChannel)
                        : null,
                    icon: const Icon(Icons.add),
                    label: const Text('Add Branch + Channel Override'),
                  ),
                  if (state.isDirty)
                    FilledButton.icon(
                      key: const Key('save-price-overrides'),
                      onPressed: state.isSaving
                          ? null
                          : () => context
                                .read<VariantPriceOverridesCubit>()
                                .save(),
                      icon: const Icon(Icons.save_outlined),
                      label: Text(
                        state.isSaving ? 'Saving...' : 'Save changes',
                      ),
                    ),
                ],
              ),
              if (state.branchError != null) ...<Widget>[
                const SizedBox(height: AppSpacing.sm),
                Text(
                  state.branchError!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ],
              const SizedBox(height: AppSpacing.xl),
              const _EffectivePricePanel(),
            ],
          ),
        );
      },
    ),
  );

  Future<void> _edit([
    VariantPriceOverrideDraft? item,
    PriceOverrideScope? scope,
  ]) => showDialog<void>(
    context: context,
    builder: (_) => BlocProvider.value(
      value: context.read<VariantPriceOverridesCubit>(),
      child: _OverrideEditorDialog(existing: item, scope: scope),
    ),
  );
}

class _Summary extends StatelessWidget {
  const _Summary({required this.state});
  final VariantPriceOverridesState state;
  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: AppSpacing.allLg,
      child: Wrap(
        spacing: 48,
        runSpacing: AppSpacing.md,
        children: <Widget>[
          _Fact(label: 'Base Price', value: _money(state.basePrice!)),
          _Fact(label: 'Overrides', value: state.saved.length.toString()),
          const _Fact(
            label: 'Resolution precedence',
            value: 'Branch + Channel → Branch → Channel → Variant Base Price',
          ),
        ],
      ),
    ),
  );
}

class _Fact extends StatelessWidget {
  const _Fact({required this.label, required this.value});
  final String label;
  final String value;
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    mainAxisSize: MainAxisSize.min,
    children: <Widget>[
      Text(
        label,
        style: AppTextStyles.labelMedium.copyWith(
          color: AppColors.textSecondary,
        ),
      ),
      const SizedBox(height: 4),
      Text(value, style: AppTextStyles.titleMedium),
    ],
  );
}

class _OverridesTable extends StatelessWidget {
  const _OverridesTable({required this.onEdit, required this.onRemove});
  final ValueChanged<VariantPriceOverrideDraft> onEdit;
  final ValueChanged<VariantPriceOverrideDraft> onRemove;
  @override
  Widget build(
    BuildContext context,
  ) => BlocBuilder<VariantPriceOverridesCubit, VariantPriceOverridesState>(
    builder: (context, state) {
      if (state.saved.isEmpty && !state.isDirty) {
        return const Card(
          child: Padding(
            padding: AppSpacing.allLg,
            child: Text(
              'No price overrides are configured. This Variant uses its Base Price in every scope.',
            ),
          ),
        );
      }
      final Map<String, VariantPriceOverride> persisted =
          <String, VariantPriceOverride>{
            for (final item in state.saved) item.scopeKey: item,
          };
      return SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: DataTable(
          columns: const <DataColumn>[
            DataColumn(label: Text('Scope')),
            DataColumn(label: Text('Branch')),
            DataColumn(label: Text('Channel')),
            DataColumn(label: Text('Override Price')),
            DataColumn(label: Text('Difference from Base Price')),
            DataColumn(label: Text('Actions')),
          ],
          rows: state.draft
              .map((draft) {
                final VariantPriceOverride? source = persisted[draft.scopeKey];
                final Branch? branch = state.branches
                    .where((item) => item.id == draft.branchId)
                    .firstOrNull;
                final PriceAmount difference = draft.price - state.basePrice!;
                return DataRow(
                  cells: <DataCell>[
                    DataCell(Text(scopeLabel(draft.scope))),
                    DataCell(
                      Text(
                        branch?.name ??
                            source?.branchName ??
                            (draft.branchId?.toString() ?? '—'),
                      ),
                    ),
                    DataCell(
                      Text(
                        draft.channel == null
                            ? '—'
                            : salesChannelLabel(draft.channel!),
                      ),
                    ),
                    DataCell(Text(_money(draft.price))),
                    DataCell(Text(_difference(difference))),
                    DataCell(
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: <Widget>[
                          IconButton(
                            tooltip: 'Edit',
                            onPressed: state.canEdit
                                ? () => onEdit(draft)
                                : null,
                            icon: const Icon(Icons.edit_outlined),
                          ),
                          IconButton(
                            tooltip: 'Remove',
                            onPressed: state.canEdit
                                ? () => onRemove(draft)
                                : null,
                            icon: const Icon(Icons.delete_outline),
                          ),
                        ],
                      ),
                    ),
                  ],
                );
              })
              .toList(growable: false),
        ),
      );
    },
  );
}

class _OverrideEditorDialog extends StatefulWidget {
  const _OverrideEditorDialog({this.existing, this.scope});
  final VariantPriceOverrideDraft? existing;
  final PriceOverrideScope? scope;
  @override
  State<_OverrideEditorDialog> createState() => _OverrideEditorDialogState();
}

class _OverrideEditorDialogState extends State<_OverrideEditorDialog> {
  late PriceOverrideScope _scope;
  int? _branchId;
  String? _channel;
  late TextEditingController _price;
  @override
  void initState() {
    super.initState();
    final item = widget.existing;
    _scope = item?.scope ?? widget.scope!;
    _branchId = item?.branchId;
    _channel = item?.channel;
    _price = TextEditingController(text: item?.price.wireValue ?? '');
  }

  @override
  void dispose() {
    _price.dispose();
    super.dispose();
  }

  @override
  Widget build(
    BuildContext context,
  ) => BlocBuilder<VariantPriceOverridesCubit, VariantPriceOverridesState>(
    builder: (context, state) => AlertDialog(
      title: Text(
        widget.existing == null
            ? 'Add ${scopeLabel(_scope)} Override'
            : 'Edit Price Override',
      ),
      content: SizedBox(
        width: 440,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            if (_scope != PriceOverrideScope.channel)
              DropdownButtonFormField<int>(
                key: const Key('override-branch'),
                initialValue: _branchId,
                decoration: const InputDecoration(labelText: 'Branch *'),
                items: state.branches
                    .where((item) => item.isActive)
                    .map(
                      (item) => DropdownMenuItem(
                        value: item.id,
                        child: Text(item.name),
                      ),
                    )
                    .toList(),
                onChanged: state.isSaving
                    ? null
                    : (value) => setState(() => _branchId = value),
              ),
            if (_scope != PriceOverrideScope.branch) ...<Widget>[
              const SizedBox(height: AppSpacing.sm),
              DropdownButtonFormField<String>(
                key: const Key('override-channel'),
                initialValue: _channel,
                decoration: const InputDecoration(labelText: 'Sales channel *'),
                items: salesChannels
                    .map(
                      (item) => DropdownMenuItem(
                        value: item,
                        child: Text(salesChannelLabel(item)),
                      ),
                    )
                    .toList(),
                onChanged: state.isSaving
                    ? null
                    : (value) => setState(() => _channel = value),
              ),
            ],
            const SizedBox(height: AppSpacing.sm),
            TextField(
              key: const Key('override-price'),
              controller: _price,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              inputFormatters: <TextInputFormatter>[
                FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,2}')),
              ],
              decoration: InputDecoration(
                labelText: 'Override Price *',
                errorText: localizedConfiguredPriceError(
                  context,
                  state.fieldErrors['price'] ??
                      state.fieldErrors['overridePrice'] ??
                      state.fieldErrors['editor'] ??
                      state.fieldErrors['scopeType'],
                ),
              ),
            ),
          ],
        ),
      ),
      actions: <Widget>[
        TextButton(
          onPressed: state.isSaving ? null : () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: state.isSaving ? null : _submit,
          child: const Text('Apply'),
        ),
      ],
    ),
  );
  void _submit() {
    try {
      final draft = VariantPriceOverrideDraft(
        scope: _scope,
        branchId: _scope == PriceOverrideScope.channel ? null : _branchId,
        channel: _scope == PriceOverrideScope.branch ? null : _channel,
        price: PriceAmount.parse(_price.text),
        isActive: widget.existing?.isActive ?? true,
      );
      final bool saved = context.read<VariantPriceOverridesCubit>().addOrUpdate(
        draft,
        replacingScopeKey: widget.existing?.scopeKey,
      );
      if (saved) {
        Navigator.pop(context);
      }
    } on FormatException {
      context.read<VariantPriceOverridesCubit>().setEditorError(
        'Enter zero or a positive price with up to two decimal places.',
      );
    }
  }
}

class _EffectivePricePanel extends StatelessWidget {
  const _EffectivePricePanel();
  @override
  Widget build(
    BuildContext context,
  ) => BlocBuilder<VariantPriceOverridesCubit, VariantPriceOverridesState>(
    builder: (context, state) => Card(
      child: Padding(
        padding: AppSpacing.allLg,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text('Effective Price Diagnostic', style: AppTextStyles.titleLarge),
            const SizedBox(height: AppSpacing.sm),
            const Text(
              'The displayed result is resolved by the backend for the selected context.',
            ),
            const SizedBox(height: AppSpacing.md),
            Wrap(
              spacing: AppSpacing.md,
              runSpacing: AppSpacing.sm,
              children: <Widget>[
                SizedBox(
                  width: 240,
                  child: DropdownButtonFormField<int>(
                    isExpanded: true,
                    initialValue: state.effectiveBranchId,
                    decoration: const InputDecoration(labelText: 'Branch'),
                    items: <DropdownMenuItem<int>>[
                      const DropdownMenuItem(
                        value: null,
                        child: Text('No Branch'),
                      ),
                      ...state.branches
                          .where((item) => item.isActive)
                          .map(
                            (item) => DropdownMenuItem(
                              value: item.id,
                              child: Text(item.name),
                            ),
                          ),
                    ],
                    onChanged: (value) => context
                        .read<VariantPriceOverridesCubit>()
                        .selectEffectiveContext(
                          branchId: value,
                          channel: state.effectiveChannel,
                        ),
                  ),
                ),
                SizedBox(
                  width: 240,
                  child: DropdownButtonFormField<String>(
                    isExpanded: true,
                    initialValue: state.effectiveChannel,
                    decoration: const InputDecoration(
                      labelText: 'Sales channel',
                    ),
                    items: <DropdownMenuItem<String>>[
                      const DropdownMenuItem(
                        value: null,
                        child: Text('No Channel'),
                      ),
                      ...salesChannels.map(
                        (item) => DropdownMenuItem(
                          value: item,
                          child: Text(salesChannelLabel(item)),
                        ),
                      ),
                    ],
                    onChanged: (value) => context
                        .read<VariantPriceOverridesCubit>()
                        .selectEffectiveContext(
                          branchId: state.effectiveBranchId,
                          channel: value,
                        ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            if (state.isEffectiveLoading)
              const CircularProgressIndicator()
            else if (state.effectiveError != null)
              Text(
                state.effectiveError!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              )
            else if (state.effectivePrice != null)
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Wrap(
                    spacing: 40,
                    runSpacing: AppSpacing.sm,
                    children: <Widget>[
                      _Fact(
                        label: 'Base Price',
                        value: _money(state.effectivePrice!.basePrice),
                      ),
                      _Fact(
                        label: 'Effective Price',
                        value: _money(state.effectivePrice!.effectivePrice),
                      ),
                      _Fact(
                        label: 'Resolution source',
                        value: state.effectivePrice!.sourceLabel,
                      ),
                    ],
                  ),
                  ExpansionTile(
                    tilePadding: EdgeInsets.zero,
                    title: Text(
                      context.maybeL10n?.technicalDetails ??
                          'Technical details',
                    ),
                    children: <Widget>[
                      Align(
                        alignment: AlignmentDirectional.centerStart,
                        child: _Fact(
                          label: 'Matched Override ID',
                          value:
                              state.effectivePrice!.matchedOverrideId
                                  ?.toString() ??
                              'Base Price',
                        ),
                      ),
                    ],
                  ),
                ],
              ),
          ],
        ),
      ),
    ),
  );
}

class _Failure extends StatelessWidget {
  const _Failure({required this.message, required this.retry});
  final String message;
  final VoidCallback retry;
  @override
  Widget build(BuildContext context) => Center(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Text(message),
        const SizedBox(height: AppSpacing.md),
        OutlinedButton(onPressed: retry, child: const Text('Retry')),
      ],
    ),
  );
}

class _Banner extends StatelessWidget {
  const _Banner(this.message);
  final String message;
  @override
  Widget build(BuildContext context) => Container(
    padding: AppSpacing.allMd,
    color: AppColors.discountOrangeBadge,
    child: Text(message),
  );
}

class _SuccessBanner extends StatelessWidget {
  const _SuccessBanner(this.message);
  final String message;
  @override
  Widget build(BuildContext context) => Container(
    padding: AppSpacing.allMd,
    color: Colors.green.shade100,
    child: Text(message),
  );
}

String _money(PriceAmount value) =>
    CurrencyFormatter.formatMinorUnits(value.minorUnits);
String _difference(PriceAmount value) =>
    '${value.minorUnits > 0 ? '+' : ''}${CurrencyFormatter.formatMinorUnits(value.minorUnits)}';

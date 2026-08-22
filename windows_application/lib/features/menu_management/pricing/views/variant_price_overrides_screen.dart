// ignore_for_file: deprecated_member_use

import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/localization/localization_extensions.dart';
import '../../../../app/menu_management_route_locations.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/utils/currency_formatter.dart';
import '../../../../shared/layouts/desktop_page_layout.dart';
import '../../../pos/models/branch.dart';
import '../configured_price_validation.dart';
import '../controllers/variant_price_overrides_cubit.dart';
import '../controllers/variant_price_overrides_state.dart';
import '../models/variant_price_models.dart';

const List<String> salesChannels = <String>[
  'pos',
  'waiter_app',
  'kiosk',
  'qr_ordering',
  'delivery',
  'online_ordering',
];

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
    final state = context.read<VariantPriceOverridesCubit>().state;
    if (state.isDirty && await _confirmLeave() != true) return;
    if (!mounted) return;
    context.canPop()
        ? context.pop()
        : context.go(
            MenuManagementRouteLocations.productWorkspace(
              widget.productId,
              tab: ProductWorkspaceTab.variants,
            ),
          );
  }

  Future<bool?> _confirmLeave() => showDialog<bool>(
    context: context,
    builder: (dialog) => AlertDialog(
      title: Text(dialog.l10n.batch8UnsavedPriceChanges),
      content: Text(dialog.l10n.batch8UnsavedPriceChangesMessage),
      actions: <Widget>[
        TextButton(
          onPressed: () => Navigator.pop(dialog, false),
          child: Text(dialog.l10n.batch8Keep),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(dialog, true),
          child: Text(dialog.l10n.batch8Leave),
        ),
      ],
    ),
  );

  Future<void> _openEditor([VariantPriceOverrideDraft? existing]) =>
      showDialog<void>(
        context: context,
        builder: (_) => BlocProvider.value(
          value: context.read<VariantPriceOverridesCubit>(),
          child: _PriceSideSheet(existing: existing),
        ),
      );

  Future<void> _openCurrentContextEditor() {
    final state = context.read<VariantPriceOverridesCubit>().state;
    return _openEditor(_exactRuleForCurrentContext(state));
  }

  Future<void> _remove(VariantPriceOverrideDraft item) async {
    final l10n = context.l10n;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialog) => AlertDialog(
        title: Text(l10n.batch8RemovePriceTitle),
        content: Text(l10n.batch8RemovePriceMessage),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.pop(dialog, false),
            child: Text(l10n.batch8Keep),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialog, true),
            child: Text(l10n.batch8Remove),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    final cubit = context.read<VariantPriceOverridesCubit>();
    cubit.remove(item.scopeKey);
    await cubit.save();
  }

  @override
  Widget build(BuildContext context) => PopScope<Object?>(
    canPop: false,
    onPopInvokedWithResult: (didPop, _) {
      if (!didPop) _back();
    },
    child: BlocBuilder<VariantPriceOverridesCubit, VariantPriceOverridesState>(
      builder: (context, state) {
        final l10n = context.l10n;
        if (state.status == VariantPriceOverridesStatus.initial ||
            state.status == VariantPriceOverridesStatus.loading) {
          return const Center(
            child: Padding(
              padding: AppSpacing.allLg,
              child: CircularProgressIndicator(),
            ),
          );
        }
        if (state.status == VariantPriceOverridesStatus.failure) {
          return _Failure(
            message: l10n.batch8PricingLoadError,
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
              Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 920),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        state.product!.displayName(
                          Localizations.localeOf(context),
                        ),
                        style: AppTextStyles.headlineMedium,
                      ),
                      const SizedBox(height: AppSpacing.xs),
                      Text(
                        l10n.batch8PricingContext(
                          state.variant!.displayName(
                            Localizations.localeOf(context),
                          ),
                        ),
                        style: AppTextStyles.bodyMedium.copyWith(
                          color: AppColors.textSecondary,
                        ),
                      ),
                      if (state.isReadOnly) ...<Widget>[
                        const SizedBox(height: AppSpacing.md),
                        _Notice(
                          message: l10n.batch8PricingArchived,
                          color: AppColors.discountOrangeBadge,
                        ),
                      ],
                      const SizedBox(height: AppSpacing.lg),
                      _EffectivePricePanel(
                        onChangePrice: _openCurrentContextEditor,
                      ),
                      const SizedBox(height: AppSpacing.md),
                      _MorePriceRules(
                        onAdd: _openEditor,
                        onEdit: _openEditor,
                        onRemove: _remove,
                      ),
                      if (state.branchError != null) ...<Widget>[
                        const SizedBox(height: AppSpacing.sm),
                        _Notice(
                          message: l10n.batch8PricingLoadError,
                          color: AppColors.discountOrangeBadge,
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    ),
  );
}

class _EffectivePricePanel extends StatelessWidget {
  const _EffectivePricePanel({required this.onChangePrice});
  final VoidCallback onChangePrice;
  @override
  Widget build(BuildContext context) =>
      BlocBuilder<VariantPriceOverridesCubit, VariantPriceOverridesState>(
        builder: (context, state) {
          final l10n = context.l10n;
          final result = state.effectivePrice;
          final loading = state.isEffectiveLoading || result == null;
          return Container(
            key: const Key('effective-price-panel'),
            padding: AppSpacing.allXl,
            decoration: BoxDecoration(
              color: AppColors.surface,
              border: Border.all(color: AppColors.primary, width: 1.5),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  l10n.batch8EffectiveSellingPrice,
                  style: AppTextStyles.titleLarge,
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(l10n.batch8PricingHelp, style: AppTextStyles.bodySmall),
                const SizedBox(height: AppSpacing.lg),
                _ContextSelectors(state: state),
                const SizedBox(height: AppSpacing.xl),
                if (state.effectiveError != null)
                  _EffectiveError(
                    onRetry: () => context
                        .read<VariantPriceOverridesCubit>()
                        .selectEffectiveContext(
                          branchId: state.effectiveBranchId,
                          channel: state.effectiveChannel,
                        ),
                  )
                else if (loading)
                  const _EffectiveLoading()
                else ...<Widget>[
                  Text(
                    _money(result.effectivePrice),
                    textDirection: TextDirection.ltr,
                    style: AppTextStyles.displayMedium.copyWith(fontSize: 40),
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  LayoutBuilder(
                    builder: (context, constraints) {
                      final difference =
                          result.effectivePrice - result.basePrice;
                      final facts = <Widget>[
                        _PriceFact(
                          label: l10n.batch8BasePrice,
                          value: _money(result.basePrice),
                        ),
                        _PriceFact(
                          label: l10n.batch8Difference,
                          value: _difference(difference),
                          valueColor: _differenceColor(difference),
                        ),
                        _PriceFact(
                          label: l10n.batch8Using,
                          value: _effectiveSource(context, state, result),
                        ),
                      ];
                      return constraints.maxWidth < 560
                          ? Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: <Widget>[
                                facts[0],
                                const SizedBox(height: AppSpacing.md),
                                facts[1],
                                const SizedBox(height: AppSpacing.md),
                                facts[2],
                              ],
                            )
                          : Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: <Widget>[
                                Expanded(child: facts[0]),
                                Expanded(child: facts[1]),
                                Expanded(flex: 2, child: facts[2]),
                              ],
                            );
                    },
                  ),
                ],
                const SizedBox(height: AppSpacing.lg),
                FilledButton(
                  key: const Key('change-price'),
                  onPressed: _canChangeSelectedContextPrice(state)
                      ? onChangePrice
                      : null,
                  child: Text(l10n.batch8ChangePrice),
                ),
              ],
            ),
          );
        },
      );
}

class _ContextSelectors extends StatelessWidget {
  const _ContextSelectors({required this.state});
  final VariantPriceOverridesState state;
  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final cubit = context.read<VariantPriceOverridesCubit>();
    final branch = _SelectorField<int>(
      label: l10n.batch8Branch,
      child: DropdownButtonFormField<int>(
        key: const Key('effective-branch'),
        initialValue: state.effectiveBranchId,
        isExpanded: true,
        decoration: _selectorDecoration(),
        items: <DropdownMenuItem<int>>[
          DropdownMenuItem(value: null, child: Text(l10n.batch8NoBranch)),
          ...state.branches
              .where((item) => item.isActive)
              .map(
                (item) =>
                    DropdownMenuItem(value: item.id, child: Text(item.name)),
              ),
        ],
        onChanged: (value) => cubit.selectEffectiveContext(
          branchId: value,
          channel: state.effectiveChannel,
        ),
      ),
    );
    final channel = _SelectorField<String>(
      label: l10n.batch8SalesChannel,
      child: DropdownButtonFormField<String>(
        key: const Key('effective-channel'),
        initialValue: state.effectiveChannel,
        isExpanded: true,
        decoration: _selectorDecoration(),
        items: <DropdownMenuItem<String>>[
          DropdownMenuItem(value: null, child: Text(l10n.batch8NoChannel)),
          ...salesChannels.map(
            (item) => DropdownMenuItem(
              value: item,
              child: Text(_channelLabel(context, item)),
            ),
          ),
        ],
        onChanged: (value) => cubit.selectEffectiveContext(
          branchId: state.effectiveBranchId,
          channel: value,
        ),
      ),
    );
    return LayoutBuilder(
      builder: (context, constraints) => constraints.maxWidth < 520
          ? Column(
              children: <Widget>[
                branch,
                const SizedBox(height: AppSpacing.md),
                channel,
              ],
            )
          : Row(
              children: <Widget>[
                Expanded(child: branch),
                const SizedBox(width: AppSpacing.md),
                Expanded(child: channel),
              ],
            ),
    );
  }
}

InputDecoration _selectorDecoration() => InputDecoration(
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

class _SelectorField<T> extends StatelessWidget {
  const _SelectorField({required this.label, required this.child});
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

class _EffectiveLoading extends StatelessWidget {
  const _EffectiveLoading();
  @override
  Widget build(BuildContext context) => const SizedBox(
    height: 108,
    child: Align(
      alignment: AlignmentDirectional.centerStart,
      child: CircularProgressIndicator(),
    ),
  );
}

class _EffectiveError extends StatelessWidget {
  const _EffectiveError({required this.onRetry});
  final VoidCallback onRetry;
  @override
  Widget build(BuildContext context) => SizedBox(
    height: 108,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisAlignment: MainAxisAlignment.center,
      children: <Widget>[
        Text(context.l10n.batch8PricingLoadError),
        const SizedBox(height: AppSpacing.sm),
        TextButton(onPressed: onRetry, child: Text(context.l10n.batch8Retry)),
      ],
    ),
  );
}

class _PriceFact extends StatelessWidget {
  const _PriceFact({required this.label, required this.value, this.valueColor});
  final String label;
  final String value;
  final Color? valueColor;
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: <Widget>[
      Text(label, style: AppTextStyles.labelSmall),
      const SizedBox(height: AppSpacing.xs),
      Text(
        value,
        textDirection:
            value.startsWith('USD') ||
                value.startsWith('+') ||
                value.startsWith('-')
            ? TextDirection.ltr
            : null,
        style: AppTextStyles.titleMedium.copyWith(color: valueColor),
      ),
    ],
  );
}

class _MorePriceRules extends StatefulWidget {
  const _MorePriceRules({
    required this.onAdd,
    required this.onEdit,
    required this.onRemove,
  });
  final VoidCallback onAdd;
  final ValueChanged<VariantPriceOverrideDraft> onEdit;
  final ValueChanged<VariantPriceOverrideDraft> onRemove;
  @override
  State<_MorePriceRules> createState() => _MorePriceRulesState();
}

class _MorePriceRulesState extends State<_MorePriceRules> {
  bool expanded = false;
  @override
  Widget build(
    BuildContext context,
  ) => BlocBuilder<VariantPriceOverridesCubit, VariantPriceOverridesState>(
    builder: (context, state) {
      final l10n = context.l10n;
      final hasRules = state.draft.isNotEmpty;
      return Container(
        key: const Key('more-price-rules'),
        decoration: BoxDecoration(
          color: AppColors.surface,
          border: Border.all(color: AppColors.border),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          children: <Widget>[
            Padding(
              padding: AppSpacing.allLg,
              child: Row(
                children: <Widget>[
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          l10n.batch8MorePriceRules,
                          style: AppTextStyles.titleMedium,
                        ),
                        const SizedBox(height: AppSpacing.xs),
                        Text(
                          hasRules
                              ? l10n.batch8RulesConfigured(state.draft.length)
                              : l10n.batch8NoPriceAdjustments,
                          style: AppTextStyles.bodySmall,
                        ),
                      ],
                    ),
                  ),
                  TextButton(
                    key: const Key('toggle-price-rules'),
                    onPressed: () => setState(() => expanded = !expanded),
                    child: Text(expanded ? l10n.batch8Hide : l10n.batch8Show),
                  ),
                ],
              ),
            ),
            if (expanded) ...<Widget>[
              const Divider(height: 1, color: AppColors.border),
              if (!hasRules)
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.lg,
                    AppSpacing.lg,
                    AppSpacing.lg,
                    AppSpacing.xl,
                  ),
                  child: Align(
                    alignment: AlignmentDirectional.centerStart,
                    child: Text(
                      l10n.batch8BasePriceEverywhere,
                      style: AppTextStyles.bodySmall,
                    ),
                  ),
                )
              else
                ...state.draft.map(
                  (draft) => _RuleRow(
                    draft: draft,
                    branches: state.branches,
                    canEdit: state.canEdit,
                    onEdit: () => widget.onEdit(draft),
                    onRemove: () => widget.onRemove(draft),
                  ),
                ),
              if (state.canEdit)
                Align(
                  alignment: AlignmentDirectional.centerStart,
                  child: Padding(
                    padding: AppSpacing.allLg,
                    child: OutlinedButton.icon(
                      key: const Key('add-price'),
                      onPressed: widget.onAdd,
                      icon: const Icon(Icons.add, size: 18),
                      label: Text(l10n.batch8AddPrice),
                    ),
                  ),
                ),
            ],
          ],
        ),
      );
    },
  );
}

class _RuleRow extends StatelessWidget {
  const _RuleRow({
    required this.draft,
    required this.branches,
    required this.canEdit,
    required this.onEdit,
    required this.onRemove,
  });
  final VariantPriceOverrideDraft draft;
  final List<Branch> branches;
  final bool canEdit;
  final VoidCallback onEdit;
  final VoidCallback onRemove;
  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final branch = branches
        .where((item) => item.id == draft.branchId)
        .firstOrNull;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: AppColors.border)),
      ),
      child: ListTile(
        contentPadding: EdgeInsets.zero,
        title: Text(_ruleContext(context, draft, branch)),
        subtitle: Text(_scopeLabel(l10n, draft.scope)),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Text(
              _money(draft.price),
              textDirection: TextDirection.ltr,
              style: AppTextStyles.titleMedium,
            ),
            PopupMenuButton<_RuleAction>(
              enabled: canEdit,
              icon: const Icon(Icons.more_horiz),
              itemBuilder: (context) => <PopupMenuEntry<_RuleAction>>[
                PopupMenuItem(
                  value: _RuleAction.edit,
                  child: Text(l10n.batch8Edit),
                ),
                PopupMenuItem(
                  value: _RuleAction.remove,
                  child: Text(l10n.batch8Remove),
                ),
              ],
              onSelected: (action) {
                if (action == _RuleAction.edit) onEdit();
                if (action == _RuleAction.remove) onRemove();
              },
            ),
          ],
        ),
      ),
    );
  }
}

enum _RuleAction { edit, remove }

class _PriceSideSheet extends StatefulWidget {
  const _PriceSideSheet({this.existing});
  final VariantPriceOverrideDraft? existing;
  @override
  State<_PriceSideSheet> createState() => _PriceSideSheetState();
}

class _PriceSideSheetState extends State<_PriceSideSheet> {
  late PriceOverrideScope scope;
  int? branchId;
  String? channel;
  late final TextEditingController price;
  @override
  void initState() {
    super.initState();
    final state = context.read<VariantPriceOverridesCubit>().state;
    scope = widget.existing?.scope ?? _contextScope(state);
    branchId = widget.existing?.branchId ?? state.effectiveBranchId;
    channel = widget.existing?.channel ?? state.effectiveChannel;
    price = TextEditingController(text: widget.existing?.price.wireValue ?? '');
  }

  @override
  void dispose() {
    price.dispose();
    super.dispose();
  }

  @override
  Widget build(
    BuildContext context,
  ) => BlocBuilder<VariantPriceOverridesCubit, VariantPriceOverridesState>(
    builder: (context, state) {
      final l10n = context.l10n;
      final enteredPrice = _tryParsePrice(price.text);
      return Dialog(
        alignment: AlignmentDirectional.centerEnd,
        insetPadding: EdgeInsets.zero,
        child: SafeArea(
          child: SizedBox(
            width: math.min(480, MediaQuery.sizeOf(context).width),
            height: MediaQuery.sizeOf(context).height,
            child: Padding(
              padding: AppSpacing.allLg,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    l10n.batch8SetSellingPrice,
                    style: AppTextStyles.headlineMedium,
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  _SheetContext(
                    product: state.product!.displayName(
                      Localizations.localeOf(context),
                    ),
                    variant: state.variant!.displayName(
                      Localizations.localeOf(context),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xl),
                  Text(l10n.batch8AppliesTo, style: AppTextStyles.labelLarge),
                  _ScopeChoice(
                    value: PriceOverrideScope.branch,
                    groupValue: scope,
                    label: l10n.batch8ScopeBranch,
                    onChanged: state.isSaving ? null : _setScope,
                  ),
                  _ScopeChoice(
                    value: PriceOverrideScope.channel,
                    groupValue: scope,
                    label: l10n.batch8ScopeChannel,
                    onChanged: state.isSaving ? null : _setScope,
                  ),
                  _ScopeChoice(
                    value: PriceOverrideScope.branchChannel,
                    groupValue: scope,
                    label: l10n.batch8ScopeBranchChannel,
                    onChanged: state.isSaving ? null : _setScope,
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  if (scope != PriceOverrideScope.channel)
                    _SheetDropdown<int>(
                      label: l10n.batch8Branch,
                      fieldKey: const Key('override-branch'),
                      value: branchId,
                      items: state.branches
                          .where((item) => item.isActive)
                          .map(
                            (item) => DropdownMenuItem(
                              value: item.id,
                              child: Text(item.name),
                            ),
                          )
                          .toList(growable: false),
                      onChanged: state.isSaving
                          ? null
                          : (value) => setState(() => branchId = value),
                    ),
                  if (scope == PriceOverrideScope.branchChannel)
                    const SizedBox(height: AppSpacing.md),
                  if (scope != PriceOverrideScope.branch)
                    _SheetDropdown<String>(
                      label: l10n.batch8SalesChannel,
                      fieldKey: const Key('override-channel'),
                      value: channel,
                      items: salesChannels
                          .map(
                            (item) => DropdownMenuItem(
                              value: item,
                              child: Text(_channelLabel(context, item)),
                            ),
                          )
                          .toList(growable: false),
                      onChanged: state.isSaving
                          ? null
                          : (value) => setState(() => channel = value),
                    ),
                  const SizedBox(height: AppSpacing.lg),
                  TextField(
                    key: const Key('override-price'),
                    controller: price,
                    onChanged: (_) => setState(() {}),
                    textDirection: TextDirection.ltr,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    inputFormatters: <TextInputFormatter>[
                      FilteringTextInputFormatter.allow(
                        RegExp(r'^\d*\.?\d{0,2}'),
                      ),
                    ],
                    decoration: InputDecoration(
                      labelText: l10n.batch8Price,
                      errorText: localizedConfiguredPriceError(
                        context,
                        state.fieldErrors['price'] ??
                            state.fieldErrors['overridePrice'] ??
                            state.fieldErrors['editor'] ??
                            state.fieldErrors['scopeType'],
                      ),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  _PriceComparison(base: state.basePrice!, price: enteredPrice),
                  const Spacer(),
                  Row(
                    children: <Widget>[
                      Expanded(
                        child: OutlinedButton(
                          onPressed: state.isSaving
                              ? null
                              : () => Navigator.pop(context),
                          child: Text(l10n.batch8Cancel),
                        ),
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      Expanded(
                        child: FilledButton(
                          onPressed: state.isSaving ? null : _submit,
                          child: Text(l10n.batch8SavePrice),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    },
  );
  void _setScope(PriceOverrideScope? value) {
    if (value != null) setState(() => scope = value);
  }

  Future<void> _submit() async {
    try {
      final draft = VariantPriceOverrideDraft(
        scope: scope,
        branchId: scope == PriceOverrideScope.channel ? null : branchId,
        channel: scope == PriceOverrideScope.branch ? null : channel,
        price: PriceAmount.parse(price.text),
        isActive: widget.existing?.isActive ?? true,
      );
      final cubit = context.read<VariantPriceOverridesCubit>();
      if (!cubit.addOrUpdate(
        draft,
        replacingScopeKey: widget.existing?.scopeKey,
      )) {
        return;
      }
      if (await cubit.save() && mounted) {
        Navigator.pop(context);
      }
    } on FormatException {
      context.read<VariantPriceOverridesCubit>().setEditorError(
        configuredSellPriceMustBePositive,
      );
    }
  }
}

class _SheetContext extends StatelessWidget {
  const _SheetContext({required this.product, required this.variant});
  final String product;
  final String variant;
  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: AppSpacing.allMd,
    decoration: BoxDecoration(
      color: AppColors.background,
      border: Border.all(color: AppColors.border),
      borderRadius: BorderRadius.circular(10),
    ),
    child: Row(
      children: <Widget>[
        Expanded(
          child: _PriceFact(label: context.l10n.batch8Product, value: product),
        ),
        Expanded(
          child: _PriceFact(label: context.l10n.batch8Variant, value: variant),
        ),
      ],
    ),
  );
}

class _ScopeChoice extends StatelessWidget {
  const _ScopeChoice({
    required this.value,
    required this.groupValue,
    required this.label,
    required this.onChanged,
  });
  final PriceOverrideScope value;
  final PriceOverrideScope groupValue;
  final String label;
  final ValueChanged<PriceOverrideScope?>? onChanged;
  @override
  // RadioGroup is unavailable in the app's supported Flutter baseline.
  Widget build(BuildContext context) => RadioListTile<PriceOverrideScope>(
    dense: true,
    contentPadding: EdgeInsets.zero,
    value: value,
    groupValue: groupValue,
    onChanged: onChanged,
    title: Text(label, style: AppTextStyles.bodyMedium),
  );
}

class _SheetDropdown<T> extends StatelessWidget {
  const _SheetDropdown({
    required this.label,
    required this.fieldKey,
    required this.value,
    required this.items,
    required this.onChanged,
  });
  final String label;
  final Key fieldKey;
  final T? value;
  final List<DropdownMenuItem<T>> items;
  final ValueChanged<T?>? onChanged;
  @override
  Widget build(BuildContext context) => DropdownButtonFormField<T>(
    key: fieldKey,
    initialValue: value,
    isExpanded: true,
    decoration: InputDecoration(labelText: label),
    items: items,
    onChanged: onChanged,
  );
}

class _PriceComparison extends StatelessWidget {
  const _PriceComparison({required this.base, required this.price});
  final PriceAmount base;
  final PriceAmount? price;
  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final difference = price == null ? null : price! - base;
    final comparison = difference == null
        ? ''
        : difference.minorUnits > 0
        ? l10n.batch8PriceAboveBase(
            _money(
              PriceAmount.parse(
                (difference.minorUnits.abs() / 100).toStringAsFixed(2),
              ),
            ),
          )
        : difference.minorUnits < 0
        ? l10n.batch8PriceBelowBase(
            _money(
              PriceAmount.parse(
                (difference.minorUnits.abs() / 100).toStringAsFixed(2),
              ),
            ),
          )
        : l10n.batch8PriceSameAsBase;
    return Container(
      width: double.infinity,
      padding: AppSpacing.allMd,
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          _PriceFact(label: l10n.batch8BasePrice, value: _money(base)),
          if (comparison.isNotEmpty) ...<Widget>[
            const SizedBox(height: AppSpacing.sm),
            Text(comparison, style: AppTextStyles.bodySmall),
          ],
        ],
      ),
    );
  }
}

class _Notice extends StatelessWidget {
  const _Notice({required this.message, required this.color});
  final String message;
  final Color color;
  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: AppSpacing.allMd,
    decoration: BoxDecoration(
      color: color,
      borderRadius: BorderRadius.circular(8),
    ),
    child: Text(message, style: AppTextStyles.bodySmall),
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
        OutlinedButton(onPressed: retry, child: Text(context.l10n.batch8Retry)),
      ],
    ),
  );
}

PriceOverrideScope _contextScope(VariantPriceOverridesState state) =>
    state.effectiveBranchId != null && state.effectiveChannel != null
    ? PriceOverrideScope.branchChannel
    : state.effectiveChannel != null
    ? PriceOverrideScope.channel
    : PriceOverrideScope.branch;

bool _canChangeSelectedContextPrice(VariantPriceOverridesState state) {
  if (!state.canEdit || state.isEffectiveLoading) return false;
  final branchId = state.effectiveBranchId;
  if (branchId == null && state.effectiveChannel == null) return false;
  return branchId == null ||
      state.branches.any((branch) => branch.id == branchId && branch.isActive);
}

VariantPriceOverrideDraft? _exactRuleForCurrentContext(
  VariantPriceOverridesState state,
) {
  final branchId = state.effectiveBranchId;
  final channel = state.effectiveChannel;
  if (branchId == null && channel == null) return null;
  final scope = _contextScope(state);
  return state.draft
      .where(
        (rule) =>
            rule.scope == scope &&
            rule.branchId == branchId &&
            rule.channel == channel,
      )
      .firstOrNull;
}

PriceAmount? _tryParsePrice(String value) {
  try {
    return value.trim().isEmpty ? null : PriceAmount.parse(value);
  } on FormatException {
    return null;
  }
}

String _money(PriceAmount value) =>
    CurrencyFormatter.formatMinorUnits(value.minorUnits);
String _difference(PriceAmount value) {
  final absolute = CurrencyFormatter.formatMinorUnits(value.minorUnits.abs());
  return value.minorUnits > 0
      ? '+$absolute'
      : value.minorUnits < 0
      ? '-$absolute'
      : absolute;
}

Color? _differenceColor(PriceAmount value) => value.minorUnits > 0
    ? AppColors.success
    : value.minorUnits < 0
    ? AppColors.danger
    : null;
String _channelLabel(BuildContext context, String value) {
  final l10n = context.l10n;
  return switch (value) {
    'pos' => l10n.batch8ChannelPos,
    'waiter_app' => l10n.batch8ChannelWaiterApp,
    'kiosk' => l10n.batch8ChannelKiosk,
    'qr_ordering' => l10n.batch8ChannelQrOrdering,
    'delivery' => l10n.batch8ChannelDelivery,
    'online_ordering' => l10n.batch8ChannelOnlineOrdering,
    _ => value,
  };
}

String _scopeLabel(dynamic l10n, PriceOverrideScope scope) => switch (scope) {
  PriceOverrideScope.branch => l10n.batch8RuleBranchPrice,
  PriceOverrideScope.channel => l10n.batch8RuleChannelPrice,
  PriceOverrideScope.branchChannel => l10n.batch8RuleBranchChannelPrice,
};
String _ruleContext(
  BuildContext context,
  VariantPriceOverrideDraft draft,
  Branch? branch,
) {
  final branchName = branch?.name ?? draft.branchId?.toString() ?? '';
  final channel = draft.channel == null
      ? ''
      : _channelLabel(context, draft.channel!);
  return switch (draft.scope) {
    PriceOverrideScope.branch => branchName,
    PriceOverrideScope.channel => channel,
    PriceOverrideScope.branchChannel => '$branchName · $channel',
  };
}

String _effectiveSource(
  BuildContext context,
  VariantPriceOverridesState state,
  EffectiveVariantPrice result,
) {
  final l10n = context.l10n;
  final branch =
      state.branches
          .where((item) => item.id == result.branchId)
          .firstOrNull
          ?.name ??
      '';
  final channel = result.channel == null
      ? ''
      : _channelLabel(context, result.channel!);
  return switch (result.matchedScope) {
    'branch' => l10n.batch8BranchPriceFor(branch),
    'channel' => l10n.batch8ChannelPriceFor(channel),
    'branch_channel' => l10n.batch8BranchChannelPriceFor(branch, channel),
    _ => l10n.batch8PriceFromBase,
  };
}

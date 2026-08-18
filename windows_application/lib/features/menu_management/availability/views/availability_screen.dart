// ignore_for_file: curly_braces_in_flow_control_structures

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/menu_management_route_locations.dart';
import '../../../../app/localization/localization_extensions.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../shared/layouts/desktop_page_layout.dart';
import '../controllers/availability_cubit.dart';
import '../controllers/availability_state.dart';
import '../models/availability_models.dart';
import '../schedule_summary.dart';

class AvailabilityScreen extends StatefulWidget {
  const AvailabilityScreen({
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
  State<AvailabilityScreen> createState() => _AvailabilityScreenState();
}

class _AvailabilityScreenState extends State<AvailabilityScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final cubit = context.read<AvailabilityCubit>();
      await cubit.load(widget.productId, variantId: widget.variantId);
      if (!mounted) return;
      final state = cubit.state;
      final bool validVariant =
          widget.variantId != null &&
          state.product?.variants.any((item) => item.id == widget.variantId) ==
              true;
      final bool validBranch =
          widget.branchId != null &&
          state.branches.any(
            (item) => item.id == widget.branchId && item.isActive,
          );
      final bool validChannel =
          widget.channel != null &&
          availabilityChannels.contains(widget.channel);
      cubit.selectContext(
        variantId: validVariant ? widget.variantId : null,
        branchId: validBranch ? widget.branchId : null,
        channel: validChannel ? widget.channel : null,
        clearVariant: !validVariant,
        clearBranch: !validBranch,
        clearChannel: !validChannel,
      );
    });
  }

  Future<bool> _mayLeave() async {
    final state = context.read<AvailabilityCubit>().state;
    if (!state.isDirty || state.isSaving) return true;
    return await showDialog<bool>(
          context: context,
          builder: (dialog) => AlertDialog(
            title: const Text('Unsaved availability changes'),
            content: const Text(
              'You have unsaved availability changes. Leave without saving?',
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
        ) ??
        false;
  }

  Future<void> _back() async {
    if (!await _mayLeave() || !mounted) return;
    if (context.canPop()) {
      context.pop();
      return;
    }
    context.go(
      MenuManagementRouteLocations.productWorkspace(
        widget.productId,
        tab: ProductWorkspaceTab.variants,
      ),
    );
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !context.select<AvailabilityCubit, bool>((c) => c.state.isDirty),
    onPopInvokedWithResult: (didPop, _) async {
      if (!didPop && await _mayLeave() && context.mounted) context.pop();
    },
    child: BlocBuilder<AvailabilityCubit, AvailabilityState>(builder: _build),
  );
  Widget _build(BuildContext context, AvailabilityState state) {
    if (state.status == AvailabilityStatus.initial ||
        (state.status == AvailabilityStatus.loading && state.product == null))
      return const DesktopPageLayout(
        child: Center(child: CircularProgressIndicator()),
      );
    if (state.product == null)
      return DesktopPageLayout(
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Text(state.errorMessage ?? 'Product not found.'),
              const SizedBox(height: AppSpacing.md),
              OutlinedButton(
                onPressed: () => context.read<AvailabilityCubit>().load(
                  widget.productId,
                  variantId: widget.variantId,
                ),
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
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
                    : () => context.read<AvailabilityCubit>().refresh(),
                icon: const Icon(Icons.refresh),
                label: const Text('Refresh'),
              ),
              const SizedBox(width: AppSpacing.sm),
              FilledButton.icon(
                key: const Key('save-availability-rules'),
                onPressed: state.isDirty && state.canEdit
                    ? () => context.read<AvailabilityCubit>().save()
                    : null,
                icon: state.isSaving
                    ? const SizedBox.square(
                        dimension: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.save_outlined),
                label: Text(state.isSaving ? 'Saving…' : 'Save Changes'),
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
            'Scheduled Availability',
            style: AppTextStyles.titleMedium.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            context.maybeL10n?.managerAvailabilityScheduledHelp ??
                'When should this item normally be available?',
            style: AppTextStyles.bodySmall.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
          if (state.isReadOnly) ...<Widget>[
            const SizedBox(height: AppSpacing.md),
            const _Banner(
              'This Product or selected Variant is archived. Rules are shown for diagnosis and cannot be changed.',
            ),
          ],
          if (state.errorMessage != null) ...<Widget>[
            const SizedBox(height: AppSpacing.md),
            _Banner(state.errorMessage!),
          ],
          if (state.successMessage != null) ...<Widget>[
            const SizedBox(height: AppSpacing.md),
            _Success(state.successMessage!),
          ],
          const SizedBox(height: AppSpacing.lg),
          _ContextCard(onSwitch: _confirmSwitch),
          const SizedBox(height: AppSpacing.lg),
          _RulesCard(
            title: 'Exact Scope Rules',
            rules: state.exactRules,
            editable: state.canEdit,
            empty:
                'No scheduled availability rules are configured for this exact scope.',
            onEdit: _edit,
            onRemove: (item) =>
                context.read<AvailabilityCubit>().remove(item.identity),
          ),
          const SizedBox(height: AppSpacing.md),
          FilledButton.icon(
            key: const Key('add-availability-rule'),
            onPressed: state.canEdit ? () => _edit(null) : null,
            icon: const Icon(Icons.add),
            label: const Text('Add Rule'),
          ),
          const SizedBox(height: AppSpacing.lg),
          _InheritedCard(rules: state.inheritedRules),
          const SizedBox(height: AppSpacing.lg),
          _PreviewPanel(),
        ],
      ),
    );
  }

  Future<void> _confirmSwitch({
    int? variantId,
    int? branchId,
    String? channel,
    bool clearVariant = false,
    bool clearBranch = false,
    bool clearChannel = false,
  }) async {
    if (!await _mayLeave()) return;
    if (!mounted) return;
    context.read<AvailabilityCubit>().selectContext(
      variantId: variantId,
      branchId: branchId,
      channel: channel,
      clearVariant: clearVariant,
      clearBranch: clearBranch,
      clearChannel: clearChannel,
    );
  }

  Future<void> _edit(AvailabilityRuleDraft? existing) => showDialog<void>(
    context: context,
    builder: (_) => BlocProvider.value(
      value: context.read<AvailabilityCubit>(),
      child: _RuleEditor(existing: existing),
    ),
  );
}

class _ContextCard extends StatelessWidget {
  const _ContextCard({required this.onSwitch});
  final Future<void> Function({
    int? variantId,
    int? branchId,
    String? channel,
    bool clearVariant,
    bool clearBranch,
    bool clearChannel,
  })
  onSwitch;
  @override
  Widget build(
    BuildContext context,
  ) => BlocBuilder<AvailabilityCubit, AvailabilityState>(
    builder: (context, state) => Card(
      child: Padding(
        padding: AppSpacing.allLg,
        child: Wrap(
          spacing: AppSpacing.md,
          runSpacing: AppSpacing.sm,
          children: <Widget>[
            SizedBox(
              width: 300,
              child: DropdownButtonFormField<int>(
                key: const Key('availability-entity'),
                isExpanded: true,
                initialValue: state.selectedVariantId,
                decoration: const InputDecoration(labelText: 'Entity'),
                items: <DropdownMenuItem<int>>[
                  const DropdownMenuItem(
                    value: null,
                    child: Text('Product Rules'),
                  ),
                  ...state.product!.variants.map(
                    (v) => DropdownMenuItem(
                      value: v.id,
                      child: Text(
                        'Variant: ${v.name}${v.isArchived ? ' (Archived)' : ''}',
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ),
                ],
                onChanged: state.isSaving
                    ? null
                    : (v) => onSwitch(
                        variantId: v,
                        clearVariant: v == null,
                        branchId: state.selectedBranchId,
                        channel: state.selectedChannel,
                      ),
              ),
            ),
            SizedBox(
              width: 300,
              child: DropdownButtonFormField<int>(
                key: const Key('availability-branch'),
                isExpanded: true,
                initialValue: state.selectedBranchId,
                decoration: const InputDecoration(labelText: 'Branch context'),
                items: <DropdownMenuItem<int>>[
                  const DropdownMenuItem(
                    value: null,
                    child: Text(
                      'All branches / Global',
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  ...state.branches
                      .where((b) => b.isActive)
                      .map(
                        (b) => DropdownMenuItem(
                          value: b.id,
                          child: Text(b.name, overflow: TextOverflow.ellipsis),
                        ),
                      ),
                ],
                onChanged: state.isSaving
                    ? null
                    : (v) => onSwitch(
                        variantId: state.selectedVariantId,
                        branchId: v,
                        clearBranch: v == null,
                        channel: state.selectedChannel,
                      ),
              ),
            ),
            SizedBox(
              width: 300,
              child: DropdownButtonFormField<String>(
                key: const Key('availability-channel'),
                isExpanded: true,
                initialValue: state.selectedChannel,
                decoration: const InputDecoration(
                  labelText: 'Sales channel context',
                ),
                items: <DropdownMenuItem<String>>[
                  const DropdownMenuItem(
                    value: null,
                    child: Text(
                      'All channels / Global',
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  ...availabilityChannels.map(
                    (v) => DropdownMenuItem(
                      value: v,
                      child: Text(
                        availabilityChannelLabel(v),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ),
                ],
                onChanged: state.isSaving
                    ? null
                    : (v) => onSwitch(
                        variantId: state.selectedVariantId,
                        branchId: state.selectedBranchId,
                        channel: v,
                        clearChannel: v == null,
                      ),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

class _RulesCard extends StatelessWidget {
  const _RulesCard({
    required this.title,
    required this.rules,
    required this.editable,
    required this.empty,
    required this.onEdit,
    required this.onRemove,
  });
  final String title, empty;
  final List<AvailabilityRuleDraft> rules;
  final bool editable;
  final ValueChanged<AvailabilityRuleDraft> onEdit, onRemove;
  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: AppSpacing.allLg,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(title, style: AppTextStyles.titleLarge),
          const SizedBox(height: AppSpacing.sm),
          if (rules.isEmpty)
            Text(empty)
          else
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: DataTable(
                columns: const <DataColumn>[
                  DataColumn(label: Text('Days & time')),
                  DataColumn(label: Text('Date range')),
                  DataColumn(label: Text('Priority')),
                  DataColumn(label: Text('Status')),
                  DataColumn(label: Text('Actions')),
                ],
                rows: rules
                    .map(
                      (r) => DataRow(
                        cells: <DataCell>[
                          DataCell(Text(scheduleSummary(r))),
                          DataCell(
                            Text('${r.startDate ?? '—'} – ${r.endDate ?? '—'}'),
                          ),
                          DataCell(Text(r.priority.toString())),
                          DataCell(
                            Chip(
                              label: Text(r.isActive ? 'Active' : 'Inactive'),
                            ),
                          ),
                          DataCell(
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: <Widget>[
                                IconButton(
                                  tooltip: 'Edit',
                                  onPressed: editable ? () => onEdit(r) : null,
                                  icon: const Icon(Icons.edit_outlined),
                                ),
                                IconButton(
                                  tooltip: 'Remove',
                                  onPressed: editable
                                      ? () => onRemove(r)
                                      : null,
                                  icon: const Icon(Icons.delete_outline),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    )
                    .toList(),
              ),
            ),
        ],
      ),
    ),
  );
}

class _InheritedCard extends StatelessWidget {
  const _InheritedCard({required this.rules});
  final List<AvailabilityRule> rules;
  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: AppSpacing.allLg,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text('Inherited Rules', style: AppTextStyles.titleLarge),
          const SizedBox(height: AppSpacing.xs),
          const Text(
            'Read-only rules that may govern this context. Variant rules take precedence over Product rules; then Branch + Channel → Branch → Channel → Global.',
          ),
          const SizedBox(height: AppSpacing.sm),
          if (rules.isEmpty)
            const Text('No inherited rules apply to this context.')
          else
            ...rules.map(
              (r) => ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.lock_outline),
                title: Text(
                  '${r.productVariantId == null ? 'Inherited from Product' : 'Variant Override'} · ${availabilityScopeLabel(r.scope)}',
                ),
                subtitle: Text(scheduleSummary(r.toDraft())),
                trailing: Text(r.isActive ? 'Active' : 'Inactive'),
              ),
            ),
        ],
      ),
    ),
  );
}

class _PreviewPanel extends StatefulWidget {
  @override
  State<_PreviewPanel> createState() => _PreviewPanelState();
}

class _PreviewPanelState extends State<_PreviewPanel> {
  late DateTime _at;
  @override
  void initState() {
    super.initState();
    _at = DateTime.now();
  }

  @override
  Widget build(
    BuildContext context,
  ) => BlocBuilder<AvailabilityCubit, AvailabilityState>(
    builder: (context, state) => Card(
      child: Padding(
        padding: AppSpacing.allLg,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text('Availability Preview', style: AppTextStyles.titleLarge),
            const SizedBox(height: AppSpacing.xs),
            const Text(
              'This diagnostic is resolved authoritatively by the backend in the selected Branch timezone.',
            ),
            const SizedBox(height: AppSpacing.md),
            Wrap(
              spacing: AppSpacing.md,
              runSpacing: AppSpacing.sm,
              children: <Widget>[
                OutlinedButton.icon(
                  onPressed: state.isPreviewLoading
                      ? null
                      : () async {
                          final date = await showDatePicker(
                            context: context,
                            initialDate: _at,
                            firstDate: DateTime(2020),
                            lastDate: DateTime(2100),
                          );
                          if (date != null)
                            setState(
                              () => _at = DateTime(
                                date.year,
                                date.month,
                                date.day,
                                _at.hour,
                                _at.minute,
                              ),
                            );
                        },
                  icon: const Icon(Icons.calendar_today_outlined),
                  label: Text(
                    '${_at.year}-${_at.month.toString().padLeft(2, '0')}-${_at.day.toString().padLeft(2, '0')}',
                  ),
                ),
                OutlinedButton.icon(
                  onPressed: state.isPreviewLoading
                      ? null
                      : () async {
                          final time = await showTimePicker(
                            context: context,
                            initialTime: TimeOfDay.fromDateTime(_at),
                          );
                          if (time != null)
                            setState(
                              () => _at = DateTime(
                                _at.year,
                                _at.month,
                                _at.day,
                                time.hour,
                                time.minute,
                              ),
                            );
                        },
                  icon: const Icon(Icons.schedule),
                  label: Text(
                    '${_at.hour.toString().padLeft(2, '0')}:${_at.minute.toString().padLeft(2, '0')}',
                  ),
                ),
                FilledButton(
                  onPressed: state.isPreviewLoading
                      ? null
                      : () => context.read<AvailabilityCubit>().preview(_at),
                  child: const Text('Run Preview'),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            if (state.isPreviewLoading)
              const CircularProgressIndicator()
            else if (state.previewError != null)
              Text(
                state.previewError!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              )
            else if (state.preview != null)
              Wrap(
                spacing: 36,
                runSpacing: AppSpacing.sm,
                children: <Widget>[
                  _Fact('Result', state.preview!.statusLabel),
                  _Fact('Matched level', state.preview!.matchedLevel ?? '—'),
                  _Fact('Matched scope', state.preview!.matchedScope ?? '—'),
                  _Fact(
                    'Matched rule',
                    state.preview!.matchedRuleId?.toString() ?? '—',
                  ),
                  _Fact('Timezone', state.preview!.timezone),
                ],
              ),
          ],
        ),
      ),
    ),
  );
}

class _Fact extends StatelessWidget {
  const _Fact(this.label, this.value);
  final String label, value;
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

class _RuleEditor extends StatefulWidget {
  const _RuleEditor({this.existing});
  final AvailabilityRuleDraft? existing;
  @override
  State<_RuleEditor> createState() => _RuleEditorState();
}

class _RuleEditorState extends State<_RuleEditor> {
  late AvailabilityScope _scope;
  int? _branch;
  String? _channel;
  int? _day;
  late TextEditingController _start, _end, _startDate, _endDate, _priority;
  bool _active = true;
  @override
  void initState() {
    super.initState();
    final r = widget.existing;
    _scope = r?.scope ?? context.read<AvailabilityCubit>().state.selectedScope;
    _branch =
        r?.branchId ?? context.read<AvailabilityCubit>().state.selectedBranchId;
    _channel =
        r?.channel ?? context.read<AvailabilityCubit>().state.selectedChannel;
    _day = r?.dayOfWeek;
    _start = TextEditingController(text: r?.startTime ?? '');
    _end = TextEditingController(text: r?.endTime ?? '');
    _startDate = TextEditingController(text: r?.startDate ?? '');
    _endDate = TextEditingController(text: r?.endDate ?? '');
    _priority = TextEditingController(text: (r?.priority ?? 0).toString());
    _active = r?.isActive ?? true;
  }

  @override
  void dispose() {
    _start.dispose();
    _end.dispose();
    _startDate.dispose();
    _endDate.dispose();
    _priority.dispose();
    super.dispose();
  }

  @override
  Widget build(
    BuildContext context,
  ) => BlocBuilder<AvailabilityCubit, AvailabilityState>(
    builder: (context, state) => AlertDialog(
      title: Text(
        widget.existing == null ? 'Add Schedule Rule' : 'Edit Schedule Rule',
      ),
      content: SizedBox(
        width: 500,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              DropdownButtonFormField<AvailabilityScope>(
                initialValue: _scope,
                decoration: const InputDecoration(labelText: 'Scope type'),
                items: AvailabilityScope.values
                    .map(
                      (v) => DropdownMenuItem(
                        value: v,
                        child: Text(availabilityScopeLabel(v)),
                      ),
                    )
                    .toList(),
                onChanged: (v) => setState(() => _scope = v!),
              ),
              if (_scope == AvailabilityScope.branch ||
                  _scope == AvailabilityScope.branchChannel) ...<Widget>[
                const SizedBox(height: 8),
                DropdownButtonFormField<int>(
                  initialValue: _branch,
                  decoration: const InputDecoration(labelText: 'Branch *'),
                  items: state.branches
                      .where((b) => b.isActive)
                      .map(
                        (b) =>
                            DropdownMenuItem(value: b.id, child: Text(b.name)),
                      )
                      .toList(),
                  onChanged: (v) => setState(() => _branch = v),
                ),
              ],
              if (_scope == AvailabilityScope.channel ||
                  _scope == AvailabilityScope.branchChannel) ...<Widget>[
                const SizedBox(height: 8),
                DropdownButtonFormField<String>(
                  initialValue: _channel,
                  decoration: const InputDecoration(
                    labelText: 'Sales channel *',
                  ),
                  items: availabilityChannels
                      .map(
                        (v) => DropdownMenuItem(
                          value: v,
                          child: Text(availabilityChannelLabel(v)),
                        ),
                      )
                      .toList(),
                  onChanged: (v) => setState(() => _channel = v),
                ),
              ],
              const SizedBox(height: 8),
              DropdownButtonFormField<int>(
                initialValue: _day,
                decoration: const InputDecoration(
                  labelText: 'Weekday (optional)',
                ),
                items: <DropdownMenuItem<int>>[
                  const DropdownMenuItem(value: null, child: Text('Daily')),
                  for (int i = 0; i < 7; i++)
                    DropdownMenuItem(
                      value: i,
                      child: Text(availabilityDayLabel(i)),
                    ),
                ],
                onChanged: (v) => setState(() => _day = v),
              ),
              const SizedBox(height: 8),
              Row(
                children: <Widget>[
                  Expanded(
                    child: TextField(
                      controller: _start,
                      decoration: const InputDecoration(
                        labelText: 'Start time (HH:mm)',
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextField(
                      controller: _end,
                      decoration: const InputDecoration(
                        labelText: 'End time (HH:mm)',
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: <Widget>[
                  Expanded(
                    child: TextField(
                      controller: _startDate,
                      decoration: const InputDecoration(
                        labelText: 'Start date (YYYY-MM-DD)',
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextField(
                      controller: _endDate,
                      decoration: const InputDecoration(
                        labelText: 'End date (YYYY-MM-DD)',
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _priority,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: 'Priority',
                  errorText: state.fieldErrors['editor'],
                ),
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Active'),
                value: _active,
                onChanged: (v) => setState(() => _active = v),
              ),
            ],
          ),
        ),
      ),
      actions: <Widget>[
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(onPressed: _submit, child: const Text('Apply')),
      ],
    ),
  );
  void _submit() {
    final int? priority = int.tryParse(_priority.text.trim());
    if (priority == null) {
      context.read<AvailabilityCubit>().addOrUpdate(
        const AvailabilityRuleDraft(
          productVariantId: null,
          branchId: null,
          channel: null,
          dayOfWeek: null,
          startTime: 'bad',
          endTime: null,
          startDate: null,
          endDate: null,
          priority: 0,
          isActive: true,
        ),
      );
      return;
    }
    final r = AvailabilityRuleDraft(
      productVariantId: context
          .read<AvailabilityCubit>()
          .state
          .selectedVariantId,
      branchId:
          _scope == AvailabilityScope.branch ||
              _scope == AvailabilityScope.branchChannel
          ? _branch
          : null,
      channel:
          _scope == AvailabilityScope.channel ||
              _scope == AvailabilityScope.branchChannel
          ? _channel
          : null,
      dayOfWeek: _day,
      startTime: _empty(_start.text),
      endTime: _empty(_end.text),
      startDate: _empty(_startDate.text),
      endDate: _empty(_endDate.text),
      priority: priority,
      isActive: _active,
    );
    if (context.read<AvailabilityCubit>().addOrUpdate(
      r,
      replacingIdentity: widget.existing?.identity,
    ))
      Navigator.pop(context);
  }

  String? _empty(String value) {
    final text = value.trim();
    return text.isEmpty ? null : text;
  }
}

class _Banner extends StatelessWidget {
  const _Banner(this.message);
  final String message;
  @override
  Widget build(BuildContext context) => Card(
    color: Theme.of(context).colorScheme.errorContainer,
    child: Padding(padding: AppSpacing.allMd, child: Text(message)),
  );
}

class _Success extends StatelessWidget {
  const _Success(this.message);
  final String message;
  @override
  Widget build(BuildContext context) => Card(
    color: Colors.green.shade50,
    child: Padding(padding: AppSpacing.allMd, child: Text(message)),
  );
}

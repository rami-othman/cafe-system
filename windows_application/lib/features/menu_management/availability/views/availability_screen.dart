import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart' hide TextDirection;

import '../../../../app/localization/localization_extensions.dart';
import '../../../../app/menu_management_route_locations.dart';
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
  final int? variantId, branchId;
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
      final variant =
          widget.variantId != null &&
          state.product?.variants.any((v) => v.id == widget.variantId) == true;
      final branch =
          widget.branchId != null &&
          state.branches.any((b) => b.id == widget.branchId && b.isActive);
      final channel =
          widget.channel != null &&
          availabilityChannels.contains(widget.channel);
      cubit.selectContext(
        variantId: variant ? widget.variantId : null,
        branchId: branch ? widget.branchId : null,
        channel: channel ? widget.channel : null,
        clearVariant: !variant,
        clearBranch: !branch,
        clearChannel: !channel,
      );
    });
  }

  Future<bool> _mayLeave() async {
    final state = context.read<AvailabilityCubit>().state;
    if (!state.isDirty || state.isSaving) return true;
    final l = context.l10n;
    return await showDialog<bool>(
          context: context,
          builder: (c) => AlertDialog(
            title: Text(l.scheduledUnsavedChanges),
            content: Text(l.scheduledUnsavedChangesHelp),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(c, false),
                child: Text(l.scheduledStay),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(c, true),
                child: Text(l.scheduledLeave),
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

  Future<void> _context({
    int? variantId,
    int? branchId,
    String? channel,
    bool clearVariant = false,
    bool clearBranch = false,
    bool clearChannel = false,
  }) async {
    if (!await _mayLeave() || !mounted) return;
    context.read<AvailabilityCubit>().selectContext(
      variantId: variantId,
      branchId: branchId,
      channel: channel,
      clearVariant: clearVariant,
      clearBranch: clearBranch,
      clearChannel: clearChannel,
    );
  }

  Future<void> _edit([AvailabilityRuleDraft? rule]) => showDialog<void>(
    context: context,
    builder: (_) => BlocProvider.value(
      value: context.read<AvailabilityCubit>(),
      child: _SellingHoursSheet(existing: rule),
    ),
  );

  @override
  Widget build(BuildContext context) => PopScope<Object?>(
    canPop: false,
    onPopInvokedWithResult: (didPop, _) {
      if (!didPop) _back();
    },
    child: BlocBuilder<AvailabilityCubit, AvailabilityState>(
      builder: (context, state) {
        final l = context.l10n;
        if (state.status == AvailabilityStatus.initial ||
            (state.status == AvailabilityStatus.loading &&
                state.product == null)) {
          return const DesktopPageLayout(
            child: Center(child: CircularProgressIndicator()),
          );
        }
        if (state.product == null) {
          return DesktopPageLayout(
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(l.scheduledLoadError),
                  const SizedBox(height: AppSpacing.md),
                  OutlinedButton(
                    onPressed: () => context.read<AvailabilityCubit>().load(
                      widget.productId,
                      variantId: widget.variantId,
                    ),
                    child: Text(l.batch8Retry),
                  ),
                ],
              ),
            ),
          );
        }
        return DesktopPageLayout(
          child: ListView(
            padding: AppSpacing.allLg,
            children: [
              Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 920),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          OutlinedButton.icon(
                            onPressed: state.isSaving ? null : _back,
                            icon: const Icon(Icons.arrow_back),
                            label: Text(l.batch8PricingBack),
                          ),
                          const Spacer(),
                          IconButton(
                            tooltip: l.batch8PricingRefresh,
                            onPressed: state.isSaving
                                ? null
                                : () => context
                                      .read<AvailabilityCubit>()
                                      .refresh(),
                            icon: const Icon(Icons.refresh),
                          ),
                        ],
                      ),
                      const SizedBox(height: AppSpacing.lg),
                      Text(
                        state.product!.name,
                        style: AppTextStyles.headlineMedium,
                      ),
                      const SizedBox(height: AppSpacing.xs),
                      Text(
                        state.selectedVariant == null
                            ? l.scheduledRegularForProduct
                            : l.scheduledRegularForVariant(
                                state.selectedVariant!.name,
                              ),
                        style: AppTextStyles.bodyMedium.copyWith(
                          color: AppColors.textSecondary,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.xs),
                      Text(
                        l.managerAvailabilityScheduledHelp,
                        style: AppTextStyles.bodySmall.copyWith(
                          color: AppColors.textSecondary,
                        ),
                      ),
                      if (state.isReadOnly) ...[
                        const SizedBox(height: AppSpacing.md),
                        _Notice(l.scheduledArchived),
                      ],
                      if (state.errorMessage != null) ...[
                        const SizedBox(height: AppSpacing.md),
                        _Notice(l.scheduledSaveError),
                      ],
                      if (state.successMessage != null) ...[
                        const SizedBox(height: AppSpacing.md),
                        _Success(l.scheduledSaved),
                      ],
                      const SizedBox(height: AppSpacing.lg),
                      _Context(onChange: _context),
                      const SizedBox(height: AppSpacing.md),
                      _Hours(onEdit: _edit),
                      const SizedBox(height: AppSpacing.md),
                      _Advanced(onEdit: _edit),
                      const SizedBox(height: AppSpacing.md),
                      const _Check(),
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

class _Context extends StatelessWidget {
  const _Context({required this.onChange});
  final Future<void> Function({
    int? variantId,
    int? branchId,
    String? channel,
    bool clearVariant,
    bool clearBranch,
    bool clearChannel,
  })
  onChange;
  @override
  Widget build(BuildContext context) =>
      BlocBuilder<AvailabilityCubit, AvailabilityState>(
        builder: (context, s) {
          final l = context.l10n;
          final fields = <Widget>[
            _Fact(l.batch8Product, s.product!.name),
            _Select<int>(
              l.batch8Variant,
              DropdownButtonFormField<int>(
                key: const Key('availability-entity'),
                initialValue: s.selectedVariantId,
                isExpanded: true,
                decoration: _decoration(),
                items: [
                  DropdownMenuItem(
                    value: null,
                    child: Text(l.scheduledProduct),
                  ),
                  ...s.product!.variants.map(
                    (v) => DropdownMenuItem(value: v.id, child: Text(v.name)),
                  ),
                ],
                onChanged: s.isSaving
                    ? null
                    : (v) => onChange(
                        variantId: v,
                        clearVariant: v == null,
                        branchId: s.selectedBranchId,
                        channel: s.selectedChannel,
                      ),
              ),
            ),
            _Select<int>(
              l.batch8Branch,
              DropdownButtonFormField<int>(
                key: const Key('availability-branch'),
                initialValue: s.selectedBranchId,
                isExpanded: true,
                decoration: _decoration(),
                items: [
                  DropdownMenuItem(
                    value: null,
                    child: Text(l.scheduledAllBranches),
                  ),
                  ...s.branches
                      .where((b) => b.isActive)
                      .map(
                        (b) =>
                            DropdownMenuItem(value: b.id, child: Text(b.name)),
                      ),
                ],
                onChanged: s.isSaving
                    ? null
                    : (v) => onChange(
                        variantId: s.selectedVariantId,
                        branchId: v,
                        clearBranch: v == null,
                        channel: s.selectedChannel,
                      ),
              ),
            ),
            _Select<String>(
              l.batch8Channel,
              DropdownButtonFormField<String>(
                key: const Key('availability-channel'),
                initialValue: s.selectedChannel,
                isExpanded: true,
                decoration: _decoration(),
                items: [
                  DropdownMenuItem(
                    value: null,
                    child: Text(l.scheduledAllChannels),
                  ),
                  ...availabilityChannels.map(
                    (c) => DropdownMenuItem(
                      value: c,
                      child: Text(_channel(context, c)),
                    ),
                  ),
                ],
                onChanged: s.isSaving
                    ? null
                    : (v) => onChange(
                        variantId: s.selectedVariantId,
                        branchId: s.selectedBranchId,
                        channel: v,
                        clearChannel: v == null,
                      ),
              ),
            ),
          ];
          return _Panel(
            child: LayoutBuilder(
              builder: (context, box) => box.maxWidth < 700
                  ? Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        for (final item in fields) ...[
                          item,
                          const SizedBox(height: AppSpacing.md),
                        ],
                      ],
                    )
                  : Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        for (final item in fields) ...[
                          Expanded(child: item),
                          const SizedBox(width: AppSpacing.md),
                        ],
                      ].sublist(0, 7),
                    ),
            ),
          );
        },
      );
}

class _Hours extends StatelessWidget {
  const _Hours({required this.onEdit});
  final ValueChanged<AvailabilityRuleDraft?> onEdit;
  @override
  Widget build(
    BuildContext context,
  ) => BlocBuilder<AvailabilityCubit, AvailabilityState>(
    builder: (context, s) {
      final l = context.l10n;
      final custom = s.selectedVariantId != null && s.exactRules.isNotEmpty;
      final source = custom || s.selectedVariantId == null
          ? s.exactRules
          : s.inheritedRules.map((e) => e.toDraft()).toList();
      final weekly = _simple(source);
      final editable = _simple(s.exactRules).firstOrNull;
      return _Panel(
        key: const Key('regular-availability-panel'),
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.lg,
          AppSpacing.lg,
          AppSpacing.lg,
          AppSpacing.md,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(l.batch8RegularAvailability, style: AppTextStyles.titleLarge),
            const SizedBox(height: AppSpacing.sm),
            Row(
              children: [
                Icon(
                  custom ? Icons.tune_outlined : Icons.account_tree_outlined,
                  size: 18,
                  color: AppColors.textSecondary,
                ),
                const SizedBox(width: AppSpacing.xs),
                Expanded(
                  child: Text(
                    custom
                        ? l.scheduledCustomizedFor(s.selectedVariant!.name)
                        : s.selectedVariantId == null
                        ? l.scheduledProductSchedule
                        : l.scheduledUsingProduct,
                    style: AppTextStyles.bodySmall.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                ),
                if (!custom && s.selectedVariantId != null && s.canEdit)
                  TextButton(
                    onPressed: () => onEdit(null),
                    child: Text(
                      l.scheduledCustomizeFor(s.selectedVariant!.name),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            if (weekly.isEmpty)
              Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.md),
                child: Text(
                  source.isEmpty
                      ? l.batch8NoScheduleRestrictions
                      : l.scheduledWeeklyInAdvanced,
                ),
              )
            else
              for (var day = 0; day < 7; day++) _Week(day, weekly),
            const Divider(height: AppSpacing.lg),
            Wrap(
              alignment: WrapAlignment.end,
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.sm,
              children: [
                if (custom && s.canEdit)
                  TextButton(
                    key: const Key('use-product-schedule-again'),
                    onPressed: s.isSaving
                        ? null
                        : () => context
                              .read<AvailabilityCubit>()
                              .useProductScheduleAgain(),
                    child: Text(l.scheduledUseProductAgain),
                  ),
                FilledButton(
                  key: const Key('edit-selling-hours'),
                  onPressed: s.canEdit ? () => onEdit(editable) : null,
                  child: Text(l.scheduledEditSellingHours),
                ),
              ],
            ),
          ],
        ),
      );
    },
  );
}

class _Week extends StatelessWidget {
  const _Week(this.day, this.rules);
  final int day;
  final List<AvailabilityRuleDraft> rules;
  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final r =
        rules.where((e) => e.dayOfWeek == day).firstOrNull ??
        rules.where((e) => e.dayOfWeek == null).firstOrNull;
    return Container(
      key: Key('weekly-row-$day'),
      padding: const EdgeInsets.symmetric(vertical: 10),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: AppColors.border)),
      ),
      child: Row(
        children: [
          Expanded(child: Text(_day(context, day))),
          Text(
            r == null
                ? l.scheduledNoSpecificRestriction
                : r.startTime == null
                ? l.scheduledAvailableAllDay
                : '${r.startTime} — ${r.endTime}',
            textDirection: r?.startTime == null ? null : TextDirection.ltr,
            style: AppTextStyles.bodyMedium.copyWith(
              color: r == null ? AppColors.textSecondary : null,
            ),
          ),
        ],
      ),
    );
  }
}

class _Advanced extends StatefulWidget {
  const _Advanced({required this.onEdit});
  final ValueChanged<AvailabilityRuleDraft?> onEdit;
  @override
  State<_Advanced> createState() => _AdvancedState();
}

class _AdvancedState extends State<_Advanced> {
  bool open = false;
  @override
  Widget build(BuildContext context) =>
      BlocBuilder<AvailabilityCubit, AvailabilityState>(
        builder: (context, s) {
          final l = context.l10n;
          final rules = _advanced(s.exactRules);
          return _Panel(
            key: const Key('advanced-schedule-rules'),
            padding: EdgeInsets.zero,
            child: Column(
              children: [
                Padding(
                  padding: AppSpacing.allLg,
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              l.scheduledAdvancedRules,
                              style: AppTextStyles.titleMedium,
                            ),
                            const SizedBox(height: AppSpacing.xs),
                            Text(
                              rules.isEmpty
                                  ? l.scheduledNoAdvancedRules
                                  : l.batch8RulesConfigured(rules.length),
                              style: AppTextStyles.bodySmall.copyWith(
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                      TextButton(
                        key: const Key('toggle-advanced-schedule-rules'),
                        onPressed: () => setState(() => open = !open),
                        child: Text(open ? l.batch8Hide : l.scheduledViewRules),
                      ),
                    ],
                  ),
                ),
                if (open) ...[
                  const Divider(height: 1),
                  if (rules.isEmpty)
                    Padding(
                      padding: AppSpacing.allLg,
                      child: Align(
                        alignment: AlignmentDirectional.centerStart,
                        child: Text(l.scheduledNoAdvancedRules),
                      ),
                    )
                  else
                    for (final r in rules)
                      _AdvancedRow(
                        r,
                        s.canEdit,
                        () => widget.onEdit(r),
                        () => context.read<AvailabilityCubit>().remove(
                          r.identity,
                        ),
                      ),
                ],
              ],
            ),
          );
        },
      );
}

class _AdvancedRow extends StatelessWidget {
  const _AdvancedRow(this.rule, this.editable, this.edit, this.remove);
  final AvailabilityRuleDraft rule;
  final bool editable;
  final VoidCallback edit, remove;
  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final date = rule.startDate == null && rule.endDate == null
        ? _day(context, rule.dayOfWeek)
        : '${rule.startDate == null ? l.scheduledFrom : _date(context, rule.startDate!)} — ${rule.endDate == null ? l.scheduledUntil : _date(context, rule.endDate!)}';
    final time = rule.startTime == null
        ? l.scheduledAvailableAllDay
        : '${rule.startTime} — ${rule.endTime}';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: AppColors.border)),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
        title: Text(
          !rule.isActive
              ? l.scheduledInactiveRule
              : rule.priority != 0
              ? l.scheduledPriorityRule
              : l.scheduledDateBoundRule,
        ),
        subtitle: Text('$date · $time'),
        trailing: PopupMenuButton<_Action>(
          enabled: editable,
          icon: const Icon(Icons.more_horiz),
          onSelected: (a) {
            if (a == _Action.edit) {
              edit();
            } else {
              remove();
            }
          },
          itemBuilder: (_) => [
            PopupMenuItem(value: _Action.edit, child: Text(l.batch8Edit)),
            PopupMenuItem(value: _Action.remove, child: Text(l.batch8Remove)),
          ],
        ),
      ),
    );
  }
}

enum _Action { edit, remove }

class _Check extends StatefulWidget {
  const _Check();
  @override
  State<_Check> createState() => _CheckState();
}

class _CheckState extends State<_Check> {
  late DateTime at;
  @override
  void initState() {
    super.initState();
    at = DateTime.now();
  }

  @override
  Widget build(BuildContext context) =>
      BlocBuilder<AvailabilityCubit, AvailabilityState>(
        builder: (context, s) {
          final l = context.l10n;
          return _Panel(
            key: const Key('check-availability'),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l.scheduledCheckAvailability,
                  style: AppTextStyles.titleMedium,
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  l.scheduledCheckHelp,
                  style: AppTextStyles.bodySmall.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                LayoutBuilder(
                  builder: (context, box) {
                    final fields = [
                      _Picker(
                        l.scheduledDate,
                        DateFormat.yMMMd(
                          Localizations.localeOf(context).toString(),
                        ).format(at),
                        Icons.calendar_today_outlined,
                        _pickDate,
                      ),
                      _Picker(
                        l.scheduledTime,
                        _time(at),
                        Icons.schedule_outlined,
                        _pickTime,
                        direction: TextDirection.ltr,
                      ),
                      FilledButton(
                        onPressed: s.isPreviewLoading
                            ? null
                            : () =>
                                  context.read<AvailabilityCubit>().preview(at),
                        child: Text(l.scheduledCheck),
                      ),
                    ];
                    return box.maxWidth < 560
                        ? Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              fields[0],
                              const SizedBox(height: AppSpacing.md),
                              fields[1],
                              const SizedBox(height: AppSpacing.md),
                              fields[2],
                            ],
                          )
                        : Row(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Expanded(child: fields[0]),
                              const SizedBox(width: AppSpacing.md),
                              Expanded(child: fields[1]),
                              const SizedBox(width: AppSpacing.md),
                              fields[2],
                            ],
                          );
                  },
                ),
                const SizedBox(height: AppSpacing.md),
                if (s.isPreviewLoading)
                  const SizedBox(
                    height: 28,
                    child: Align(
                      alignment: AlignmentDirectional.centerStart,
                      child: CircularProgressIndicator(),
                    ),
                  )
                else if (s.previewError != null)
                  _Result(false, l.scheduledCheckError, neutral: true)
                else if (s.preview != null)
                  _Result(
                    s.preview!.isScheduledAvailable,
                    _preview(context, s),
                  ),
              ],
            ),
          );
        },
      );
  Future<void> _pickDate() async {
    final v = await showDatePicker(
      context: context,
      initialDate: at,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (v != null && mounted) {
      setState(() => at = DateTime(v.year, v.month, v.day, at.hour, at.minute));
    }
  }

  Future<void> _pickTime() async {
    final v = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(at),
    );
    if (v != null && mounted) {
      setState(
        () => at = DateTime(at.year, at.month, at.day, v.hour, v.minute),
      );
    }
  }
}

class _Result extends StatelessWidget {
  const _Result(this.ok, this.text, {this.neutral = false});
  final bool ok, neutral;
  final String text;
  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: AppSpacing.allMd,
    decoration: BoxDecoration(
      color: neutral
          ? AppColors.background
          : ok
          ? Colors.green.shade50
          : Colors.red.shade50,
      border: Border.all(
        color: neutral
            ? AppColors.border
            : ok
            ? Colors.green.shade200
            : Colors.red.shade200,
      ),
      borderRadius: BorderRadius.circular(8),
    ),
    child: Text(text),
  );
}

class _SellingHoursSheet extends StatefulWidget {
  const _SellingHoursSheet({this.existing});
  final AvailabilityRuleDraft? existing;
  @override
  State<_SellingHoursSheet> createState() => _SellingHoursSheetState();
}

class _SellingHoursSheetState extends State<_SellingHoursSheet> {
  late int? day;
  late bool allDay, active;
  late TextEditingController start, end, startDate, endDate, priority;
  bool dates = false, advanced = false;
  @override
  void initState() {
    super.initState();
    final r = widget.existing;
    day = r?.dayOfWeek;
    allDay = r?.startTime == null;
    active = r?.isActive ?? true;
    start = TextEditingController(text: r?.startTime ?? '09:00');
    end = TextEditingController(text: r?.endTime ?? '17:00');
    startDate = TextEditingController(text: r?.startDate ?? '');
    endDate = TextEditingController(text: r?.endDate ?? '');
    priority = TextEditingController(text: '${r?.priority ?? 0}');
    dates = startDate.text.isNotEmpty || endDate.text.isNotEmpty;
  }

  @override
  void dispose() {
    start.dispose();
    end.dispose();
    startDate.dispose();
    endDate.dispose();
    priority.dispose();
    super.dispose();
  }

  @override
  Widget build(
    BuildContext context,
  ) => BlocBuilder<AvailabilityCubit, AvailabilityState>(
    builder: (context, s) {
      final l = context.l10n;
      final overnight = !allDay && end.text.compareTo(start.text) < 0;
      final error =
          s.fieldErrors['editor'] ??
          s.fieldErrors['startTime'] ??
          s.fieldErrors['endTime'] ??
          s.fieldErrors['startDate'] ??
          s.fieldErrors['endDate'];
      return Dialog(
        alignment: AlignmentDirectional.centerEnd,
        insetPadding: EdgeInsets.zero,
        child: SafeArea(
          child: SizedBox(
            width: math.min(480, MediaQuery.sizeOf(context).width),
            height: MediaQuery.sizeOf(context).height,
            child: Column(
              children: [
                Padding(
                  padding: AppSpacing.allLg,
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          l.scheduledEditSellingHours,
                          style: AppTextStyles.headlineMedium,
                        ),
                      ),
                      IconButton(
                        onPressed: s.isSaving
                            ? null
                            : () => Navigator.pop(context),
                        icon: const Icon(Icons.close),
                      ),
                    ],
                  ),
                ),
                const Divider(height: 1),
                Expanded(
                  child: SingleChildScrollView(
                    padding: AppSpacing.allLg,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _SheetContext(s),
                        const SizedBox(height: AppSpacing.xl),
                        DropdownButtonFormField<int>(
                          key: const Key('selling-hours-day'),
                          initialValue: day,
                          decoration: InputDecoration(
                            labelText: l.scheduledDay,
                          ),
                          items: [
                            DropdownMenuItem(
                              value: null,
                              child: Text(l.scheduledEveryDay),
                            ),
                            for (var i = 0; i < 7; i++)
                              DropdownMenuItem(
                                value: i,
                                child: Text(_day(context, i)),
                              ),
                          ],
                          onChanged: s.isSaving
                              ? null
                              : (v) => setState(() => day = v),
                        ),
                        const SizedBox(height: AppSpacing.lg),
                        Text(
                          l.scheduledAvailability,
                          style: AppTextStyles.labelLarge,
                        ),
                        RadioGroup<bool>(
                          groupValue: allDay,
                          onChanged: (v) {
                            if (!s.isSaving) {
                              setState(() => allDay = v!);
                            }
                          },
                          child: Column(
                            children: [
                              _Choice(
                                true,
                                l.scheduledAvailableAllDay,
                                l.scheduledAvailableAllDayHelp,
                                enabled: !s.isSaving,
                              ),
                              _Choice(
                                false,
                                l.scheduledCustomHours,
                                l.scheduledCustomHoursHelp,
                                enabled: !s.isSaving,
                              ),
                            ],
                          ),
                        ),
                        if (!allDay) ...[
                          const SizedBox(height: AppSpacing.sm),
                          Row(
                            children: [
                              Expanded(
                                child: _Picker(
                                  l.scheduledStartTime,
                                  start.text,
                                  Icons.schedule_outlined,
                                  () => _pickTime(start),
                                  direction: TextDirection.ltr,
                                ),
                              ),
                              const SizedBox(width: AppSpacing.md),
                              Expanded(
                                child: _Picker(
                                  l.scheduledEndTime,
                                  end.text,
                                  Icons.schedule_outlined,
                                  () => _pickTime(end),
                                  direction: TextDirection.ltr,
                                ),
                              ),
                            ],
                          ),
                          if (overnight)
                            Padding(
                              padding: const EdgeInsets.only(
                                top: AppSpacing.sm,
                              ),
                              child: Text(
                                l.scheduledOvernightUntil(end.text),
                                style: AppTextStyles.bodySmall,
                              ),
                            ),
                        ],
                        const SizedBox(height: AppSpacing.lg),
                        _Disclosure(
                          l.scheduledDateLimits,
                          l.scheduledOptional,
                          dates,
                          () => setState(() => dates = !dates),
                          dates
                              ? Row(
                                  children: [
                                    Expanded(
                                      child: _Picker(
                                        l.scheduledStartDate,
                                        startDate.text.isEmpty
                                            ? l.scheduledSelectDate
                                            : _date(context, startDate.text),
                                        Icons.calendar_today_outlined,
                                        () => _pickDate(startDate),
                                      ),
                                    ),
                                    const SizedBox(width: AppSpacing.md),
                                    Expanded(
                                      child: _Picker(
                                        l.scheduledEndDate,
                                        endDate.text.isEmpty
                                            ? l.scheduledSelectDate
                                            : _date(context, endDate.text),
                                        Icons.calendar_today_outlined,
                                        () => _pickDate(endDate),
                                      ),
                                    ),
                                  ],
                                )
                              : null,
                        ),
                        _Disclosure(
                          l.scheduledAdvanced,
                          null,
                          advanced,
                          () => setState(() => advanced = !advanced),
                          advanced
                              ? Column(
                                  children: [
                                    TextField(
                                      key: const Key('selling-hours-priority'),
                                      controller: priority,
                                      keyboardType: TextInputType.number,
                                      decoration: InputDecoration(
                                        labelText: l.scheduledPriority,
                                      ),
                                    ),
                                    SwitchListTile(
                                      contentPadding: EdgeInsets.zero,
                                      title: Text(l.scheduledActive),
                                      value: active,
                                      onChanged: s.isSaving
                                          ? null
                                          : (v) => setState(() => active = v),
                                    ),
                                  ],
                                )
                              : null,
                        ),
                        if (error != null)
                          Padding(
                            padding: const EdgeInsets.only(top: AppSpacing.md),
                            child: Text(
                              error,
                              style: TextStyle(
                                color: Theme.of(context).colorScheme.error,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
                const Divider(height: 1),
                Padding(
                  padding: AppSpacing.allLg,
                  child: Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: s.isSaving
                              ? null
                              : () => Navigator.pop(context),
                          child: Text(l.batch8Cancel),
                        ),
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      Expanded(
                        child: FilledButton(
                          key: const Key('save-selling-hours'),
                          onPressed: s.isSaving ? null : _save,
                          child: Text(l.scheduledSaveSellingHours),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    },
  );
  Future<void> _save() async {
    final p = int.tryParse(priority.text.trim());
    if (p == null) {
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
    final s = context.read<AvailabilityCubit>().state;
    final rule = AvailabilityRuleDraft(
      productVariantId: s.selectedVariantId,
      branchId: s.selectedBranchId,
      channel: s.selectedChannel,
      dayOfWeek: day,
      startTime: allDay ? null : start.text,
      endTime: allDay ? null : end.text,
      startDate: _null(startDate.text),
      endDate: _null(endDate.text),
      priority: p,
      isActive: active,
    );
    final c = context.read<AvailabilityCubit>();
    if (!c.addOrUpdate(rule, replacingIdentity: widget.existing?.identity)) {
      return;
    }
    if (await c.save() && mounted) {
      Navigator.pop(context);
    }
  }

  String? _null(String v) => v.trim().isEmpty ? null : v.trim();
  Future<void> _pickTime(TextEditingController c) async {
    final p = c.text.split(':');
    final v = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(
        hour: int.tryParse(p.first) ?? 9,
        minute: p.length > 1 ? int.tryParse(p[1]) ?? 0 : 0,
      ),
    );
    if (v != null && mounted) {
      setState(
        () => c.text =
            '${v.hour.toString().padLeft(2, '0')}:${v.minute.toString().padLeft(2, '0')}',
      );
    }
  }

  Future<void> _pickDate(TextEditingController c) async {
    final v = await showDatePicker(
      context: context,
      initialDate: DateTime.tryParse(c.text) ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (v != null && mounted) {
      setState(() => c.text = DateFormat('yyyy-MM-dd').format(v));
    }
  }
}

class _SheetContext extends StatelessWidget {
  const _SheetContext(this.s);
  final AvailabilityState s;
  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final b = s.branches.where((e) => e.id == s.selectedBranchId).firstOrNull;
    return Container(
      width: double.infinity,
      padding: AppSpacing.allMd,
      decoration: BoxDecoration(
        color: AppColors.background,
        border: Border.all(color: AppColors.border),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Wrap(
        spacing: AppSpacing.lg,
        runSpacing: AppSpacing.md,
        children: [
          _Fact(l.batch8Product, s.product!.name),
          _Fact(l.batch8Variant, s.selectedVariant?.name ?? s.product!.name),
          _Fact(l.batch8Branch, b?.name ?? l.scheduledAllBranches),
          _Fact(
            l.batch8Channel,
            s.selectedChannel == null
                ? l.scheduledAllChannels
                : _channel(context, s.selectedChannel!),
          ),
        ],
      ),
    );
  }
}

class _Choice extends StatelessWidget {
  const _Choice(this.value, this.label, this.help, {required this.enabled});
  final bool value;
  final String label, help;
  final bool enabled;
  @override
  Widget build(BuildContext context) => RadioListTile<bool>(
    contentPadding: EdgeInsets.zero,
    dense: true,
    enabled: enabled,
    value: value,
    title: Text(label),
    subtitle: Text(help, style: AppTextStyles.bodySmall),
  );
}

class _Disclosure extends StatelessWidget {
  const _Disclosure(
    this.title,
    this.subtitle,
    this.open,
    this.toggle,
    this.child,
  );
  final String title;
  final String? subtitle;
  final bool open;
  final VoidCallback toggle;
  final Widget? child;
  @override
  Widget build(BuildContext context) => Column(
    children: [
      ListTile(
        contentPadding: EdgeInsets.zero,
        title: Text(title, style: AppTextStyles.titleMedium),
        subtitle: subtitle == null ? null : Text(subtitle!),
        trailing: Icon(open ? Icons.expand_less : Icons.expand_more),
        onTap: toggle,
      ),
      if (open && child != null)
        Padding(
          padding: const EdgeInsets.only(bottom: AppSpacing.md),
          child: child,
        ),
    ],
  );
}

class _Picker extends StatelessWidget {
  const _Picker(
    this.label,
    this.value,
    this.icon,
    this.press, {
    this.direction,
  });
  final String label, value;
  final IconData icon;
  final VoidCallback? press;
  final TextDirection? direction;
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(label, style: AppTextStyles.labelSmall),
      const SizedBox(height: AppSpacing.xs),
      OutlinedButton.icon(
        onPressed: press,
        icon: Icon(icon, size: 17),
        label: Align(
          alignment: AlignmentDirectional.centerStart,
          child: Text(value, textDirection: direction),
        ),
        style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(42)),
      ),
    ],
  );
}

class _Panel extends StatelessWidget {
  const _Panel({
    super.key,
    required this.child,
    this.padding = AppSpacing.allLg,
  });
  final Widget child;
  final EdgeInsetsGeometry padding;
  @override
  Widget build(BuildContext context) => Container(
    padding: padding,
    decoration: BoxDecoration(
      color: AppColors.surface,
      border: Border.all(color: AppColors.border),
      borderRadius: BorderRadius.circular(12),
    ),
    child: child,
  );
}

class _Select<T> extends StatelessWidget {
  const _Select(this.label, this.child);
  final String label;
  final Widget child;
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(label, style: AppTextStyles.labelSmall),
      const SizedBox(height: AppSpacing.xs),
      child,
    ],
  );
}

class _Fact extends StatelessWidget {
  const _Fact(this.label, this.value);
  final String label, value;
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    mainAxisSize: MainAxisSize.min,
    children: [
      Text(label, style: AppTextStyles.labelSmall),
      const SizedBox(height: AppSpacing.xs),
      Text(value, style: AppTextStyles.bodyMedium),
    ],
  );
}

class _Notice extends StatelessWidget {
  const _Notice(this.message);
  final String message;
  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: AppSpacing.allMd,
    decoration: BoxDecoration(
      color: Colors.orange.shade50,
      borderRadius: BorderRadius.circular(8),
      border: Border.all(color: Colors.orange.shade200),
    ),
    child: Text(message),
  );
}

class _Success extends StatelessWidget {
  const _Success(this.message);
  final String message;
  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: AppSpacing.allMd,
    decoration: BoxDecoration(
      color: Colors.green.shade50,
      borderRadius: BorderRadius.circular(8),
    ),
    child: Text(message),
  );
}

InputDecoration _decoration() => InputDecoration(
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
List<AvailabilityRuleDraft> _simple(List<AvailabilityRuleDraft> rules) {
  final a = rules
      .where(
        (r) =>
            r.isActive &&
            r.priority == 0 &&
            r.startDate == null &&
            r.endDate == null,
      )
      .toList();
  final n = <int?, int>{};
  for (final r in a) {
    n[r.dayOfWeek] = (n[r.dayOfWeek] ?? 0) + 1;
  }
  return a.where((r) => n[r.dayOfWeek] == 1).toList();
}

List<AvailabilityRuleDraft> _advanced(List<AvailabilityRuleDraft> rules) {
  final ids = _simple(rules).map((r) => r.identity).toSet();
  return rules.where((r) => !ids.contains(r.identity)).toList();
}

String _time(DateTime d) =>
    '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
String _date(BuildContext c, String v) {
  final d = DateTime.tryParse(v);
  return d == null
      ? v
      : DateFormat.yMMMd(Localizations.localeOf(c).toString()).format(d);
}

String _preview(BuildContext c, AvailabilityState s) {
  final l = c.l10n;
  if (!s.preview!.isScheduledAvailable) {
    return l.batch8UnavailableAccordingSchedule;
  }
  if (s.preview!.reason == 'no_schedule_restriction') {
    return l.batch8NoScheduleRestrictionsHelp;
  }
  return s.selectedVariantId != null && s.exactRules.isEmpty
      ? l.scheduledAvailableUsingProduct
      : l.batch8AvailableAccordingSchedule;
}

String _channel(BuildContext c, String v) {
  final l = c.l10n;
  return switch (v) {
    'pos' => l.batch8ChannelPos,
    'waiter_app' => l.batch8ChannelWaiterApp,
    'kiosk' => l.batch8ChannelKiosk,
    'qr_ordering' => l.batch8ChannelQrOrdering,
    'delivery' => l.batch8ChannelDelivery,
    'online_ordering' => l.batch8ChannelOnlineOrdering,
    _ => v,
  };
}

String _day(BuildContext c, int? d) {
  final l = c.l10n;
  return switch (d) {
    0 => l.scheduledSunday,
    1 => l.scheduledMonday,
    2 => l.scheduledTuesday,
    3 => l.scheduledWednesday,
    4 => l.scheduledThursday,
    5 => l.scheduledFriday,
    6 => l.scheduledSaturday,
    _ => l.scheduledEveryDay,
  };
}

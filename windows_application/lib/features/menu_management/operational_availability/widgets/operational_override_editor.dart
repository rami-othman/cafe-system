import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';

import '../../../../app/localization/localization_extensions.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../pos/models/branch.dart';
import '../controllers/operational_availability_cubit.dart';
import '../controllers/operational_availability_state.dart';
import '../models/operational_availability_models.dart';
import '../operational_availability_formatters.dart';

/// The focused editor for the currently selected operational context.
///
/// Scope controls intentionally do not appear here: changing product/variant,
/// Branch, or channel happens on the page before opening the sheet. This keeps
/// edits exact and prevents an accidental broader override.
class OperationalOverrideEditor extends StatefulWidget {
  const OperationalOverrideEditor({
    super.key,
    required this.isVariant,
    this.existing,
    this.initialStatus,
  });

  final bool isVariant;
  final OperationalAvailabilityOverride? existing;
  final OperationalAvailabilityStatus? initialStatus;

  @override
  State<OperationalOverrideEditor> createState() =>
      _OperationalOverrideEditorState();
}

class _OperationalOverrideEditorState extends State<OperationalOverrideEditor> {
  late int? _branchId;
  late String _channel;
  late OperationalAvailabilityStatus _status;
  late TextEditingController _reason;
  DateTime? _until;

  @override
  void initState() {
    super.initState();
    final state = context.read<OperationalAvailabilityCubit>().state;
    final OperationalAvailabilityOverride? item = widget.existing;
    _branchId = item?.branchId ?? state.selectedBranchId;
    _channel = item?.channel ?? state.selectedChannel ?? 'pos';
    _status =
        widget.initialStatus ??
        item?.status ??
        OperationalAvailabilityStatus.temporarilyUnavailable;
    _reason = TextEditingController(text: item?.reason ?? '');
    _until = item?.unavailableUntil;
  }

  @override
  void dispose() {
    _reason.dispose();
    super.dispose();
  }

  @override
  Widget build(
    BuildContext context,
  ) => BlocBuilder<OperationalAvailabilityCubit, OperationalAvailabilityState>(
    builder: (context, state) {
      final l = context.maybeL10n;
      final Branch? branch = state.branches
          .where((item) => item.id == _branchId)
          .firstOrNull;
      return Dialog(
        key: const Key('operational-override-editor'),
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
                  Expanded(
                    child: SingleChildScrollView(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Text(
                            widget.existing == null
                                ? (l?.operationalAvailabilitySetStatus ??
                                      'Set availability status')
                                : (l?.operationalAvailabilityEditStatusTitle ??
                                      'Edit availability status'),
                            style: AppTextStyles.headlineMedium,
                          ),
                          const SizedBox(height: AppSpacing.lg),
                          _EditorContext(
                            product: state.product?.name ?? '',
                            variant: widget.isVariant
                                ? state.selectedVariant?.name
                                : null,
                            branch:
                                branch?.name ??
                                (l?.operationalAvailabilitySelectBranch ??
                                    'Select an active branch'),
                            channel: operationalChannelLabel(_channel),
                          ),
                          const SizedBox(height: AppSpacing.xl),
                          Text(
                            l?.operationalAvailabilityStatus ?? 'Status',
                            style: AppTextStyles.labelLarge,
                          ),
                          const SizedBox(height: AppSpacing.sm),
                          DropdownButtonFormField<
                            OperationalAvailabilityStatus
                          >(
                            key: const Key('operational-override-status'),
                            initialValue: _status,
                            decoration: const InputDecoration(),
                            items: OperationalAvailabilityStatus.values
                                .map(
                                  (item) => DropdownMenuItem(
                                    value: item,
                                    child: Text(_statusLabel(context, item)),
                                  ),
                                )
                                .toList(growable: false),
                            onChanged: state.isMutating
                                ? null
                                : (value) => setState(() => _status = value!),
                          ),
                          if (_status ==
                              OperationalAvailabilityStatus
                                  .available) ...<Widget>[
                            const SizedBox(height: AppSpacing.sm),
                            Text(
                              l?.operationalAvailabilityExplicitAvailable ??
                                  'This explicitly makes the item available in the selected context.',
                              style: AppTextStyles.bodySmall,
                            ),
                          ],
                          if (_status !=
                              OperationalAvailabilityStatus
                                  .available) ...<Widget>[
                            const SizedBox(height: AppSpacing.lg),
                            TextField(
                              key: const Key('operational-override-reason'),
                              controller: _reason,
                              enabled: !state.isMutating,
                              maxLength: 1000,
                              maxLines: 3,
                              decoration: InputDecoration(
                                labelText:
                                    l?.operationalAvailabilityReason ??
                                    'Reason',
                              ),
                            ),
                          ],
                          if (_status ==
                              OperationalAvailabilityStatus
                                  .temporarilyUnavailable) ...<Widget>[
                            const SizedBox(height: AppSpacing.md),
                            Text(
                              l?.operationalAvailabilityDuration ?? 'Duration',
                              style: AppTextStyles.labelLarge,
                            ),
                            const SizedBox(height: AppSpacing.sm),
                            Text(
                              l?.operationalAvailabilitySpecificTime ??
                                  'Until a specific time',
                              style: AppTextStyles.bodyMedium,
                            ),
                            const SizedBox(height: AppSpacing.xs),
                            Text(
                              l?.operationalAvailabilityEndTimeRequired ??
                                  'Temporary restrictions need an end time.',
                              style: AppTextStyles.bodySmall,
                            ),
                            const SizedBox(height: AppSpacing.md),
                            OutlinedButton.icon(
                              key: const Key('operational-override-expiration'),
                              onPressed: state.isMutating ? null : _pickUntil,
                              icon: const Icon(Icons.event_outlined),
                              label: Text(
                                _until == null
                                    ? (l?.operationalAvailabilitySelectEndTime ??
                                          'Select end date and time')
                                    : _branchLocalDate(context, _until!),
                              ),
                            ),
                            const SizedBox(height: AppSpacing.xs),
                            Text(
                              l?.operationalAvailabilityBranchTime ??
                                  'The time is shown in the selected branch’s local time.',
                              style: AppTextStyles.bodySmall,
                            ),
                          ],
                          if (state.fieldErrors.isNotEmpty) ...<Widget>[
                            const SizedBox(height: AppSpacing.md),
                            Text(
                              state.fieldErrors['editor'] ??
                                  (l?.operationalAvailabilitySaveError ??
                                      'We couldn’t save this availability status. Review the details and try again.'),
                              style: AppTextStyles.bodySmall.copyWith(
                                color: AppColors.danger,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  Row(
                    key: const Key('operational-editor-footer'),
                    children: <Widget>[
                      Expanded(
                        child: OutlinedButton(
                          onPressed: state.isMutating
                              ? null
                              : () => Navigator.pop(context),
                          child: Text(
                            l?.operationalAvailabilityCancel ?? 'Cancel',
                          ),
                        ),
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      Expanded(
                        child: FilledButton(
                          key: const Key('operational-save-status'),
                          onPressed: state.isMutating ? null : _submit,
                          child: Text(
                            state.isMutating
                                ? (l?.operationalAvailabilitySaving ??
                                      'Saving…')
                                : (l?.operationalAvailabilitySave ??
                                      'Save status'),
                          ),
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

  Future<void> _pickUntil() async {
    final DateTime current =
        _until ?? DateTime.now().add(const Duration(hours: 1));
    final DateTime? date = await showDatePicker(
      context: context,
      initialDate: current,
      firstDate: DateTime.now().subtract(const Duration(days: 1)),
      lastDate: DateTime.now().add(const Duration(days: 3650)),
    );
    if (date == null || !mounted) return;
    final TimeOfDay? time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(current),
    );
    if (time == null || !mounted) return;
    setState(
      () => _until = DateTime(
        date.year,
        date.month,
        date.day,
        time.hour,
        time.minute,
      ),
    );
  }

  Future<void> _submit() async {
    if (_status == OperationalAvailabilityStatus.temporarilyUnavailable &&
        _until == null) {
      context.read<OperationalAvailabilityCubit>().setEditorError(
        context.maybeL10n?.operationalAvailabilityEndTimeRequired ??
            'Select when this temporary restriction should end.',
      );
      return;
    }
    final OperationalAvailabilityDraft draft = OperationalAvailabilityDraft(
      branchId: _branchId,
      channel: _channel,
      status: _status,
      // This screen does not edit quantity; preserve the supported persisted
      // field when an existing exact record is being changed.
      remainingQuantity: widget.existing?.remainingQuantity,
      unavailableUntil:
          _status == OperationalAvailabilityStatus.temporarilyUnavailable
          ? _until
          : null,
      reason: _status == OperationalAvailabilityStatus.available
          ? null
          : _reason.text,
    );
    final cubit = context.read<OperationalAvailabilityCubit>();
    final bool saved = widget.isVariant
        ? await cubit.upsertVariant(
            draft,
            replacingScopeKey: widget.existing?.scopeKey,
          )
        : await cubit.upsertProduct(
            draft,
            replacingScopeKey: widget.existing?.scopeKey,
          );
    if (saved && mounted) Navigator.pop(context);
  }
}

class _EditorContext extends StatelessWidget {
  const _EditorContext({
    required this.product,
    required this.variant,
    required this.branch,
    required this.channel,
  });

  final String product;
  final String? variant;
  final String branch;
  final String channel;

  @override
  Widget build(BuildContext context) {
    final l = context.maybeL10n;
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
        children: <Widget>[
          _ContextFact(
            l?.operationalAvailabilityProductVariant ?? 'Product / Variant',
            variant == null ? product : '$product · $variant',
          ),
          _ContextFact(l?.operationalAvailabilityBranch ?? 'Branch', branch),
          _ContextFact(
            l?.operationalAvailabilityChannel ?? 'Sales channel',
            channel,
          ),
        ],
      ),
    );
  }
}

class _ContextFact extends StatelessWidget {
  const _ContextFact(this.label, this.value);
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => SizedBox(
    width: 125,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(label, style: AppTextStyles.labelSmall),
        const SizedBox(height: AppSpacing.xs),
        Text(value, style: AppTextStyles.labelLarge),
      ],
    ),
  );
}

String _statusLabel(
  BuildContext context,
  OperationalAvailabilityStatus status,
) {
  final l = context.maybeL10n;
  return switch (status) {
    OperationalAvailabilityStatus.available =>
      l?.commonAvailable ?? 'Available',
    OperationalAvailabilityStatus.soldOut => l?.commonSoldOut ?? 'Sold out',
    OperationalAvailabilityStatus.temporarilyUnavailable =>
      l?.statusTemporarilyUnavailable ?? 'Temporarily unavailable',
  };
}

String _branchLocalDate(BuildContext context, DateTime value) =>
    DateFormat.yMMMd(
      Localizations.localeOf(context).toLanguageTag(),
    ).add_jm().format(value);

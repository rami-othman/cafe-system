import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/theme/app_spacing.dart';
import '../../../pos/models/branch.dart';
import '../controllers/operational_availability_cubit.dart';
import '../controllers/operational_availability_state.dart';
import '../models/operational_availability_models.dart';
import '../operational_availability_formatters.dart';

class OperationalOverrideEditor extends StatefulWidget {
  const OperationalOverrideEditor({
    super.key,
    required this.isVariant,
    this.existing,
  });

  final bool isVariant;
  final OperationalAvailabilityOverride? existing;

  @override
  State<OperationalOverrideEditor> createState() =>
      _OperationalOverrideEditorState();
}

class _OperationalOverrideEditorState extends State<OperationalOverrideEditor> {
  late int? _branchId;
  late String _channel;
  late OperationalAvailabilityStatus _status;
  late TextEditingController _reason;
  late TextEditingController _quantity;
  DateTime? _until;

  @override
  void initState() {
    super.initState();
    final OperationalAvailabilityOverride? item = widget.existing;
    _branchId = item?.branchId;
    _channel = item?.channel ?? 'all';
    _status = item?.status ?? OperationalAvailabilityStatus.soldOut;
    _reason = TextEditingController(text: item?.reason ?? '');
    _quantity = TextEditingController(
      text: item?.remainingQuantity?.toString() ?? '',
    );
    _until = item?.unavailableUntil;
  }

  @override
  void dispose() {
    _reason.dispose();
    _quantity.dispose();
    super.dispose();
  }

  @override
  Widget build(
    BuildContext context,
  ) => BlocBuilder<OperationalAvailabilityCubit, OperationalAvailabilityState>(
    builder: (context, state) {
      final List<Branch> branches = state.branches
          .where((item) => item.isActive)
          .toList();
      final String subject = widget.isVariant
          ? state.selectedVariant?.name ?? 'Variant'
          : 'Product';
      final String? branchTimezone = branches
          .where((item) => item.id == _branchId)
          .firstOrNull
          ?.timezone;
      return AlertDialog(
        title: Text(
          widget.existing == null
              ? 'Add $subject override'
              : 'Edit $subject override',
        ),
        content: SizedBox(
          width: 520,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                DropdownButtonFormField<int>(
                  key: const Key('operational-override-branch'),
                  initialValue: _branchId,
                  decoration: InputDecoration(
                    labelText: 'Branch *',
                    errorText: _error(state, 'branchId'),
                  ),
                  items: branches
                      .map(
                        (item) => DropdownMenuItem(
                          value: item.id,
                          child: Text(item.name),
                        ),
                      )
                      .toList(),
                  onChanged: state.isMutating
                      ? null
                      : (value) => setState(() => _branchId = value),
                ),
                const SizedBox(height: AppSpacing.sm),
                DropdownButtonFormField<String>(
                  key: const Key('operational-override-channel'),
                  initialValue: _channel,
                  decoration: InputDecoration(
                    labelText: 'Channel scope *',
                    errorText: _error(state, 'channel'),
                  ),
                  items: <String>['all', ...operationalSalesChannels]
                      .map(
                        (item) => DropdownMenuItem(
                          value: item,
                          child: Text(operationalChannelLabel(item)),
                        ),
                      )
                      .toList(),
                  onChanged: state.isMutating
                      ? null
                      : (value) => setState(() => _channel = value ?? 'all'),
                ),
                const SizedBox(height: AppSpacing.sm),
                DropdownButtonFormField<OperationalAvailabilityStatus>(
                  key: const Key('operational-override-status'),
                  initialValue: _status,
                  decoration: InputDecoration(
                    labelText: 'Operational status *',
                    errorText: _error(state, 'status'),
                  ),
                  items: OperationalAvailabilityStatus.values
                      .map(
                        (item) => DropdownMenuItem(
                          value: item,
                          child: Text(operationalStatusLabel(item)),
                        ),
                      )
                      .toList(),
                  onChanged: state.isMutating
                      ? null
                      : (value) => setState(() => _status = value!),
                ),
                if (_status ==
                    OperationalAvailabilityStatus.available) ...<Widget>[
                  const SizedBox(height: AppSpacing.sm),
                  const Text(
                    'Available is an explicit override. It can take precedence over a broader Sold Out override; it does not remove that broader record.',
                  ),
                ],
                const SizedBox(height: AppSpacing.sm),
                TextField(
                  key: const Key('operational-override-reason'),
                  controller: _reason,
                  enabled:
                      !state.isMutating &&
                      _status != OperationalAvailabilityStatus.available,
                  maxLength: 1000,
                  maxLines: 2,
                  decoration: InputDecoration(
                    labelText: 'Reason / operational note',
                    errorText: _error(state, 'reason'),
                  ),
                ),
                TextField(
                  key: const Key('operational-override-remaining-quantity'),
                  controller: _quantity,
                  enabled: !state.isMutating,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: InputDecoration(
                    labelText: 'Remaining quantity (optional)',
                    errorText: _error(state, 'remainingQuantity'),
                  ),
                ),
                const SizedBox(height: AppSpacing.xs),
                const Text(
                  'Remaining quantity is operational metadata and is not automatically synchronized with Inventory.',
                ),
                if (_status ==
                    OperationalAvailabilityStatus
                        .temporarilyUnavailable) ...<Widget>[
                  const SizedBox(height: AppSpacing.md),
                  OutlinedButton.icon(
                    key: const Key('operational-override-expiration'),
                    onPressed: state.isMutating ? null : _pickUntil,
                    icon: const Icon(Icons.event_outlined),
                    label: Text(
                      _until == null
                          ? 'Set unavailable-until *'
                          : operationalDate(_until),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    'The selected date and time is interpreted by the backend in the Branch timezone${branchTimezone == null || branchTimezone.isEmpty ? '' : ' ($branchTimezone)'}.',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  if (_error(state, 'unavailableUntil') != null)
                    Padding(
                      padding: const EdgeInsets.only(top: AppSpacing.xs),
                      child: Text(
                        _error(state, 'unavailableUntil')!,
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.error,
                        ),
                      ),
                    ),
                ],
                if (_error(state, 'editor') != null)
                  Padding(
                    padding: const EdgeInsets.only(top: AppSpacing.sm),
                    child: Text(
                      _error(state, 'editor')!,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
        actions: <Widget>[
          TextButton(
            onPressed: state.isMutating ? null : () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: state.isMutating ? null : _submit,
            child: Text(state.isMutating ? 'Saving...' : 'Save override'),
          ),
        ],
      );
    },
  );

  String? _error(OperationalAvailabilityState state, String field) =>
      state.fieldErrors[field] ?? state.fieldErrors['editor'];

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
    final double? quantity = _quantity.text.trim().isEmpty
        ? null
        : double.tryParse(_quantity.text.trim());
    if (_quantity.text.trim().isNotEmpty && quantity == null) {
      context.read<OperationalAvailabilityCubit>().setEditorError(
        'Remaining quantity must be a number that is zero or greater.',
      );
      return;
    }
    final OperationalAvailabilityDraft draft = OperationalAvailabilityDraft(
      branchId: _branchId,
      channel: _channel,
      status: _status,
      remainingQuantity: quantity,
      unavailableUntil: _until,
      reason: _reason.text,
    );
    final OperationalAvailabilityCubit cubit = context
        .read<OperationalAvailabilityCubit>();
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

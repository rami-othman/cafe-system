import 'package:flutter/material.dart';

import '../../../l10n/app_localizations.dart';
import '../controllers/customer_form_cubit.dart';
import '../controllers/customer_form_state.dart';
import '../models/customer_drafts.dart';
import '../models/customer_group_models.dart';
import '../models/customer_models.dart';

class CustomerFormSections extends StatelessWidget {
  const CustomerFormSections({
    super.key,
    required this.state,
    required this.cubit,
  });

  final CustomerFormState state;
  final CustomerFormCubit cubit;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Text(
          l10n.cmvpInformationSection,
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 8),
        TextFormField(
          key: const Key('customer-name-field'),
          initialValue: state.draft.name,
          decoration: InputDecoration(
            labelText: l10n.customerManagementCustomerName,
            errorText: _error(l10n, state.fieldErrors['name']),
          ),
          onChanged: (String value) =>
              cubit.updateDraft(state.draft.copyWith(name: value)),
        ),
        const SizedBox(height: 16),
        if (!state.isCreate) ...<Widget>[
          InputDecorator(
            key: const Key('customer-number'),
            decoration: InputDecoration(
              labelText: l10n.customerManagementCustomerNumber,
            ),
            child: Text(
              state.customerNumber ?? l10n.customerManagementNotAvailable,
            ),
          ),
          const SizedBox(height: 16),
        ],
        TextFormField(
          key: const Key('customer-email-field'),
          initialValue: state.draft.email ?? '',
          keyboardType: TextInputType.emailAddress,
          decoration: InputDecoration(labelText: l10n.customerManagementEmail),
          onChanged: (String value) => cubit.updateDraft(
            value.isEmpty
                ? state.draft.copyWith(clearEmail: true)
                : state.draft.copyWith(email: value),
          ),
        ),
        const SizedBox(height: 16),
        TextFormField(
          key: const Key('customer-birth-date-field'),
          initialValue: state.draft.birthDate == null
              ? ''
              : _date(state.draft.birthDate!),
          decoration: InputDecoration(
            labelText: l10n.customerManagementBirthDate,
            hintText: l10n.customerManagementDateHint,
          ),
          keyboardType: TextInputType.datetime,
          onChanged: (String value) {
            final DateTime? date = DateTime.tryParse(value);
            cubit.updateDraft(
              date == null
                  ? state.draft.copyWith(clearBirthDate: value.isEmpty)
                  : state.draft.copyWith(
                      birthDate: DateTime.utc(date.year, date.month, date.day),
                    ),
            );
          },
        ),
        const SizedBox(height: 16),
        Text(
          l10n.cmvpNotesSection,
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 8),
        TextFormField(
          key: const Key('customer-notes-field'),
          initialValue: state.draft.notes ?? '',
          minLines: 3,
          maxLines: 5,
          decoration: InputDecoration(labelText: l10n.customerManagementNotes),
          onChanged: (String value) => cubit.updateDraft(
            value.isEmpty
                ? state.draft.copyWith(clearNotes: true)
                : state.draft.copyWith(notes: value),
          ),
        ),
        const SizedBox(height: 24),
        Text(
          l10n.cmvpPhoneSection,
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 8),
        if (state.draft.phones.isEmpty)
          Text(l10n.customerManagementNoPhone)
        else
          for (int index = 0; index < state.draft.phones.length; index++)
            _PhoneRow(
              key: ValueKey<String>(state.draft.phones[index].rowId),
              index: index,
              phone: state.draft.phones[index],
              state: state,
              cubit: cubit,
            ),
        Align(
          alignment: AlignmentDirectional.centerStart,
          child: TextButton.icon(
            key: const Key('customer-add-phone'),
            onPressed: cubit.addPhone,
            icon: const Icon(Icons.add),
            label: Text(l10n.customerManagementAddPhone),
          ),
        ),
        const SizedBox(height: 24),
        Text(
          l10n.cmvpGroupsSection,
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 8),
        if (state.groupOptions.isEmpty)
          Text(l10n.customerManagementNoActiveGroups)
        else
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: state.groupOptions
                .map(
                  (CustomerGroup group) => FilterChip(
                    label: Text(group.name),
                    selected: state.draft.groupIds.contains(group.id),
                    onSelected: (bool selected) =>
                        cubit.setGroupSelected(group.id, selected),
                  ),
                )
                .toList(growable: false),
          ),
        if (state.archivedGroups.isNotEmpty) ...<Widget>[
          const SizedBox(height: 12),
          for (final CustomerGroupSummary group in state.archivedGroups)
            InputChip(
              label: Text(group.name),
              onDeleted: state.draft.groupIds.contains(group.id)
                  ? () => cubit.removeGroup(group.id)
                  : null,
            ),
          Text(
            l10n.customerManagementArchivedGroupRetained,
            key: const Key('archived-group-retained'),
          ),
        ],
      ],
    );
  }
}

class _PhoneRow extends StatelessWidget {
  const _PhoneRow({
    super.key,
    required this.index,
    required this.phone,
    required this.state,
    required this.cubit,
  });

  final int index;
  final CustomerPhoneDraft phone;
  final CustomerFormState state;
  final CustomerFormCubit cubit;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final String? phoneError =
        state.fieldErrors['phones.$index.rawNumber'] == null
        ? _error(l10n, state.fieldErrors['phones'])
        : _error(l10n, state.fieldErrors['phones.$index.rawNumber']);
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Card(
        key: Key('customer-phone-row-$index'),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              TextFormField(
                key: Key('customer-phone-$index-raw'),
                initialValue: phone.rawNumber,
                decoration: InputDecoration(
                  labelText: l10n.customerManagementPhone,
                  errorText: phoneError,
                ),
                onChanged: (String value) =>
                    cubit.updatePhone(phone.rowId, rawNumber: value),
              ),
              const SizedBox(height: 8),
              DropdownButtonFormField<String>(
                key: Key('customer-phone-$index-type'),
                initialValue: phone.type,
                decoration: InputDecoration(
                  labelText: l10n.customerManagementPhoneType,
                ),
                items: <DropdownMenuItem<String>>[
                  DropdownMenuItem(
                    value: 'mobile',
                    child: Text(l10n.customerManagementPhoneMobile),
                  ),
                  DropdownMenuItem(
                    value: 'home',
                    child: Text(l10n.customerManagementPhoneHome),
                  ),
                  DropdownMenuItem(
                    value: 'work',
                    child: Text(l10n.customerManagementPhoneWork),
                  ),
                  DropdownMenuItem(
                    value: 'other',
                    child: Text(l10n.customerManagementPhoneOther),
                  ),
                ],
                onChanged: (String? value) {
                  if (value != null) {
                    cubit.updatePhone(phone.rowId, type: value);
                  }
                },
              ),
              Row(
                children: <Widget>[
                  RadioGroup<bool>(
                    groupValue: phone.isPrimary ? true : null,
                    onChanged: (_) => cubit.setPrimaryPhone(phone.rowId),
                    child: Radio<bool>(
                      key: Key('customer-phone-$index-primary'),
                      value: true,
                    ),
                  ),
                  Text(l10n.customerManagementPrimary),
                  const Spacer(),
                  IconButton(
                    tooltip: l10n.customerManagementRemovePhone,
                    onPressed: () => cubit.removePhone(phone.rowId),
                    icon: const Icon(Icons.delete_outline),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

String? _error(AppLocalizations l10n, List<String>? errors) {
  if (errors == null || errors.isEmpty) return null;
  return switch (errors.first) {
    'required' => l10n.customerManagementRequiredName,
    'primaryRequired' => l10n.customerManagementPrimaryRequired,
    _ => l10n.customerManagementValidationFailed,
  };
}

String _date(DateTime value) =>
    '${value.year.toString().padLeft(4, '0')}-${value.month.toString().padLeft(2, '0')}-${value.day.toString().padLeft(2, '0')}';

import 'package:flutter/material.dart';

import '../../../app/customer_management_route_locations.dart';
import '../../../core/navigation/unsaved_navigation_guard.dart';
import '../../../core/theme/app_colors.dart';
import '../../../l10n/app_localizations.dart';
import '../controllers/customer_form_cubit.dart';
import '../controllers/customer_form_state.dart';
import '../models/customer_drafts.dart';
import '../models/customer_group_models.dart';
import '../models/customer_models.dart';
import '../repositories/customer_management_repository.dart';
import 'customer_lifecycle_actions.dart';
import 'customer_management_visual_tokens.dart';

class CustomerFormSections extends StatelessWidget {
  const CustomerFormSections({
    super.key,
    required this.state,
    required this.cubit,
    this.lifecycleRepository,
  });

  final CustomerFormState state;
  final CustomerFormCubit cubit;
  final CustomerManagementRepository? lifecycleRepository;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        _SectionHeading(label: l10n.cmvpInformationSection),
        const SizedBox(height: 16),
        Column(
          key: const Key('customer-form-information-fields'),
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            _LabeledField(
              label: l10n.customerManagementCustomerName,
              required: true,
              child: TextFormField(
                key: const Key('customer-name-field'),
                initialValue: state.draft.name,
                decoration: InputDecoration(
                  errorText: _error(l10n, state.fieldErrors['name']),
                ),
                onChanged: (String value) =>
                    cubit.updateDraft(state.draft.copyWith(name: value)),
              ),
            ),
            if (!state.isCreate) ...<Widget>[
              const SizedBox(height: 16),
              _LabeledField(
                label: l10n.customerManagementCustomerNumber,
                child: InputDecorator(
                  key: const Key('customer-number'),
                  decoration: const InputDecoration(),
                  child: Text(
                    state.customerNumber ?? l10n.customerManagementNotAvailable,
                    textDirection: TextDirection.ltr,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              _GeneratedNumberHint(message: l10n.cmvpGeneratedNumberHint),
            ],
            const SizedBox(height: 16),
            _ResponsiveFieldPair(
              first: _LabeledField(
                label: l10n.customerManagementEmail,
                child: TextFormField(
                  key: const Key('customer-email-field'),
                  initialValue: state.draft.email ?? '',
                  keyboardType: TextInputType.emailAddress,
                  decoration: const InputDecoration(),
                  onChanged: (String value) => cubit.updateDraft(
                    value.isEmpty
                        ? state.draft.copyWith(clearEmail: true)
                        : state.draft.copyWith(email: value),
                  ),
                ),
              ),
              second: _LabeledField(
                label: l10n.customerManagementBirthDate,
                child: TextFormField(
                  key: const Key('customer-birth-date-field'),
                  initialValue: state.draft.birthDate == null
                      ? ''
                      : _date(state.draft.birthDate!),
                  decoration: InputDecoration(
                    hintText: l10n.customerManagementDateHint,
                  ),
                  keyboardType: TextInputType.datetime,
                  onChanged: (String value) {
                    final DateTime? date = DateTime.tryParse(value);
                    cubit.updateDraft(
                      date == null
                          ? state.draft.copyWith(clearBirthDate: value.isEmpty)
                          : state.draft.copyWith(
                              birthDate: DateTime.utc(
                                date.year,
                                date.month,
                                date.day,
                              ),
                            ),
                    );
                  },
                ),
              ),
            ),
          ],
        ),
        const _SectionDivider(),
        _SectionHeading(label: l10n.cmvpPhoneSection, required: true),
        const SizedBox(height: 16),
        if (state.draft.phones.isEmpty)
          Text(
            state.fieldErrors['phones']?.isNotEmpty == true
                ? l10n.customerManagementRequiredPhone
                : l10n.customerManagementNoPhone,
            style: state.fieldErrors['phones']?.isNotEmpty == true
                ? TextStyle(color: Theme.of(context).colorScheme.error)
                : null,
          )
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
            icon: const Icon(Icons.add, size: 18),
            label: Text(l10n.customerManagementAddPhone),
          ),
        ),
        const _SectionDivider(),
        Row(
          children: <Widget>[
            Expanded(child: _SectionHeading(label: l10n.cmvpGroupsSection)),
            TextButton(
              onPressed: () =>
                  context.guardedGo(CustomerManagementRouteLocations.groups),
              child: Text(l10n.cmvpManageGroups),
            ),
          ],
        ),
        const SizedBox(height: 12),
        if (state.groupOptions.isEmpty)
          Text(l10n.customerManagementNoActiveGroups)
        else
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: state.groupOptions
                .map(
                  (CustomerGroup group) => FilterChip(
                    key: Key('customer-group-chip-${group.id}'),
                    label: Text(group.name),
                    selected: state.draft.groupIds.contains(group.id),
                    onSelected: (bool selected) =>
                        cubit.setGroupSelected(group.id, selected),
                    selectedColor: const Color(0xFFF4E7D3),
                    backgroundColor: AppColors.surface,
                    labelStyle: TextStyle(
                      color: state.draft.groupIds.contains(group.id)
                          ? AppColors.secondary
                          : AppColors.textSecondary,
                      fontWeight: FontWeight.w600,
                    ),
                    checkmarkColor: AppColors.secondary,
                    showCheckmark: false,
                    side: BorderSide(
                      color: state.draft.groupIds.contains(group.id)
                          ? CustomerManagementVisualTokens.focus
                          : AppColors.border,
                    ),
                    shape: const StadiumBorder(),
                  ),
                )
                .toList(growable: false),
          ),
        if (state.archivedGroups.isNotEmpty) ...<Widget>[
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: <Widget>[
              for (final CustomerGroupSummary group in state.archivedGroups)
                InputChip(
                  label: Text(group.name),
                  onDeleted: state.draft.groupIds.contains(group.id)
                      ? () => cubit.removeGroup(group.id)
                      : null,
                ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            l10n.customerManagementArchivedGroupRetained,
            key: const Key('archived-group-retained'),
          ),
        ],
        const _SectionDivider(),
        _SectionHeading(label: l10n.cmvpNotesSection),
        const SizedBox(height: 16),
        TextFormField(
          key: const Key('customer-notes-field'),
          initialValue: state.draft.notes ?? '',
          minLines: 3,
          maxLines: 5,
          decoration: InputDecoration(hintText: l10n.customerManagementNotes),
          onChanged: (String value) => cubit.updateDraft(
            value.isEmpty
                ? state.draft.copyWith(clearNotes: true)
                : state.draft.copyWith(notes: value),
          ),
        ),
        if (lifecycleRepository != null &&
            state.loadedCustomer != null) ...<Widget>[
          const _SectionDivider(),
          _SectionHeading(label: l10n.cmvpLifecycleSection),
          const SizedBox(height: 16),
          KeyedSubtree(
            key: const Key('customer-form-lifecycle-section'),
            child: CustomerLifecycleActions(
              repository: lifecycleRepository!,
              customer: state.loadedCustomer!,
              onCustomerReplaced: (Customer value) async =>
                  cubit.replaceCustomerLifecycle(value),
            ),
          ),
        ],
      ],
    );
  }
}

class _SectionHeading extends StatelessWidget {
  const _SectionHeading({required this.label, this.required = false});
  final String label;
  final bool required;

  @override
  Widget build(BuildContext context) {
    final TextStyle? style = Theme.of(context).textTheme.titleSmall?.copyWith(
      color: AppColors.primary,
      fontWeight: FontWeight.w700,
    );
    if (!required) return Text(label, style: style);
    return RichText(
      textAlign: TextAlign.start,
      text: TextSpan(
        style: style,
        children: <InlineSpan>[
          TextSpan(text: label),
          const TextSpan(text: ' *'),
        ],
      ),
    );
  }
}

class _SectionDivider extends StatelessWidget {
  const _SectionDivider();

  @override
  Widget build(BuildContext context) => const Padding(
    padding: EdgeInsets.symmetric(vertical: 20),
    child: Divider(),
  );
}

class _LabeledField extends StatelessWidget {
  const _LabeledField({
    required this.label,
    required this.child,
    this.required = false,
  });

  final String label;
  final Widget child;
  final bool required;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: <Widget>[
      RichText(
        textAlign: TextAlign.start,
        text: TextSpan(
          style: Theme.of(context).inputDecorationTheme.labelStyle,
          children: <InlineSpan>[
            TextSpan(text: label),
            if (required) const TextSpan(text: ' *'),
          ],
        ),
      ),
      const SizedBox(height: 6),
      child,
    ],
  );
}

class _ResponsiveFieldPair extends StatelessWidget {
  const _ResponsiveFieldPair({required this.first, required this.second});
  final Widget first;
  final Widget second;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (BuildContext context, BoxConstraints constraints) {
      if (constraints.maxWidth < 520) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[first, const SizedBox(height: 16), second],
        );
      }
      return Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Expanded(child: first),
          const SizedBox(width: 16),
          Expanded(child: second),
        ],
      );
    },
  );
}

class _GeneratedNumberHint extends StatelessWidget {
  const _GeneratedNumberHint({required this.message});
  final String message;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
    decoration: BoxDecoration(
      color: const Color(0xFFFFF1DD),
      border: Border.all(color: const Color(0xFFF3CE9B)),
      borderRadius: BorderRadius.circular(8),
    ),
    child: Row(
      children: <Widget>[
        const Icon(Icons.info_outline, size: 16, color: AppColors.secondary),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            message,
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: AppColors.secondary),
          ),
        ),
      ],
    ),
  );
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
    final Widget number = Expanded(
      flex: 4,
      child: TextFormField(
        key: Key('customer-phone-$index-raw'),
        initialValue: phone.rawNumber,
        decoration: InputDecoration(
          hintText: l10n.customerManagementPhone,
          errorText: _phoneError(l10n, phoneError),
        ),
        keyboardType: TextInputType.phone,
        onChanged: (String value) =>
            cubit.updatePhone(phone.rowId, rawNumber: value),
      ),
    );
    final Widget type = Expanded(
      flex: 3,
      child: DropdownButtonFormField<String>(
        key: Key('customer-phone-$index-type'),
        initialValue: phone.type,
        decoration: const InputDecoration(),
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
          if (value != null) cubit.updatePhone(phone.rowId, type: value);
        },
      ),
    );
    final Widget primary = Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        RadioGroup<bool>(
          groupValue: phone.isPrimary ? true : null,
          onChanged: (_) => cubit.setPrimaryPhone(phone.rowId),
          child: Radio<bool>(
            key: Key('customer-phone-$index-primary'),
            value: true,
            visualDensity: VisualDensity.compact,
          ),
        ),
        Text(l10n.customerManagementPrimary),
      ],
    );
    final Widget remove = IconButton(
      tooltip: l10n.customerManagementRemovePhone,
      onPressed: () => cubit.removePhone(phone.rowId),
      icon: const Icon(Icons.close, size: 18),
    );

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: LayoutBuilder(
        builder: (BuildContext context, BoxConstraints constraints) {
          if (constraints.maxWidth < 600) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                Row(
                  children: <Widget>[number, const SizedBox(width: 12), type],
                ),
                const SizedBox(height: 4),
                Row(children: <Widget>[primary, const Spacer(), remove]),
              ],
            );
          }
          return Row(
            children: <Widget>[
              number,
              const SizedBox(width: 8),
              type,
              const SizedBox(width: 8),
              primary,
              const SizedBox(width: 4),
              remove,
            ],
          );
        },
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

String? _phoneError(AppLocalizations l10n, String? error) => switch (error) {
  'required' => l10n.customerManagementRequiredPhone,
  _ => error,
};

String _date(DateTime value) =>
    '${value.year.toString().padLeft(4, '0')}-${value.month.toString().padLeft(2, '0')}-${value.day.toString().padLeft(2, '0')}';

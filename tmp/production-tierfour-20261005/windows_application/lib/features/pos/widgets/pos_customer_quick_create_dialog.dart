import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../l10n/app_localizations.dart';
import '../../../l10n/app_localizations_en.dart';
import '../controllers/pos_customer_quick_create_cubit.dart';
import '../controllers/pos_customer_quick_create_state.dart';
import '../models/pos_customer_group.dart';

class PosCustomerQuickCreateDialog extends StatefulWidget {
  const PosCustomerQuickCreateDialog({super.key, this.compact = false});

  final bool compact;

  @override
  State<PosCustomerQuickCreateDialog> createState() =>
      _PosCustomerQuickCreateDialogState();
}

class _PosCustomerQuickCreateDialogState
    extends State<PosCustomerQuickCreateDialog> {
  late final TextEditingController _nameController;
  late final TextEditingController _phoneController;
  late final TextEditingController _notesController;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController();
    _phoneController = TextEditingController();
    _notesController = TextEditingController();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) context.read<PosCustomerQuickCreateCubit>().loadGroups();
    });
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<
      PosCustomerQuickCreateCubit,
      PosCustomerQuickCreateState
    >(
      listener: (BuildContext context, PosCustomerQuickCreateState state) {
        if (state.result != null) {
          Navigator.of(context).pop(state.result);
        }
      },
      builder: (BuildContext context, PosCustomerQuickCreateState state) {
        final PosCustomerQuickCreateCubit cubit = context
            .read<PosCustomerQuickCreateCubit>();
        final AppLocalizations l10n =
            Localizations.of<AppLocalizations>(context, AppLocalizations) ??
            AppLocalizationsEn();
        return PopScope<void>(
          canPop: !state.isDirty && !state.isSubmitting,
          onPopInvokedWithResult: (bool didPop, _) async {
            if (didPop) return;
            if (state.isSubmitting) return;
            if (await _confirmDiscard(context) && context.mounted) {
              Navigator.of(context).pop();
            }
          },
          child: Column(
            mainAxisSize: widget.compact ? MainAxisSize.min : MainAxisSize.max,
            children: <Widget>[
              _Header(
                title: l10n.posCustomerCreateTitle,
                onClose: state.isSubmitting
                    ? null
                    : () => _dismiss(context, state.isDirty),
              ),
              if (widget.compact)
                Flexible(
                  fit: FlexFit.loose,
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(24),
                    child: _FormBody(
                      nameController: _nameController,
                      phoneController: _phoneController,
                      notesController: _notesController,
                      state: state,
                      cubit: cubit,
                      l10n: l10n,
                    ),
                  ),
                )
              else
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(24),
                    child: _FormBody(
                      nameController: _nameController,
                      phoneController: _phoneController,
                      notesController: _notesController,
                      state: state,
                      cubit: cubit,
                      l10n: l10n,
                    ),
                  ),
                ),
              _Footer(
                isSubmitting: state.isSubmitting,
                onCancel: () => _dismiss(context, state.isDirty),
                onSubmit: cubit.submit,
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _dismiss(BuildContext context, bool dirty) async {
    if (!dirty || await _confirmDiscard(context)) {
      if (context.mounted) Navigator.of(context).pop();
    }
  }

  Future<bool> _confirmDiscard(BuildContext context) async {
    final AppLocalizations l10n =
        Localizations.of<AppLocalizations>(context, AppLocalizations) ??
        AppLocalizationsEn();
    return await showDialog<bool>(
          context: context,
          builder: (BuildContext context) => AlertDialog(
            title: Text(l10n.customerManagementDiscardChanges),
            actions: <Widget>[
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: Text(l10n.customerManagementStay),
              ),
              FilledButton(
                onPressed: () => Navigator.of(context).pop(true),
                child: Text(l10n.customerManagementLeave),
              ),
            ],
          ),
        ) ??
        false;
  }
}

class _FormBody extends StatelessWidget {
  const _FormBody({
    required this.nameController,
    required this.phoneController,
    required this.notesController,
    required this.state,
    required this.cubit,
    required this.l10n,
  });

  final TextEditingController nameController;
  final TextEditingController phoneController;
  final TextEditingController notesController;
  final PosCustomerQuickCreateState state;
  final PosCustomerQuickCreateCubit cubit;
  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) => AutofillGroup(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        _CustomerTextField(
          key: const Key('pos-customer-name'),
          controller: nameController,
          label: l10n.customerManagementName,
          enabled: !state.isSubmitting,
          autofocus: true,
          textInputAction: TextInputAction.next,
          errorText: _fieldError(
            state.fieldErrors,
            'name',
            l10n.customerManagementRequiredName,
            l10n,
          ),
          onChanged: cubit.updateName,
        ),
        const SizedBox(height: 16),
        _CustomerTextField(
          key: const Key('pos-customer-phone'),
          controller: phoneController,
          label: l10n.customerManagementPhone,
          enabled: !state.isSubmitting,
          keyboardType: TextInputType.phone,
          textInputAction: TextInputAction.next,
          errorText: _fieldError(
            state.fieldErrors,
            'phone',
            l10n.customerManagementRequiredPhone,
            l10n,
          ),
          onChanged: cubit.updatePhone,
        ),
        const SizedBox(height: 16),
        _CustomerTextField(
          key: const Key('pos-customer-notes'),
          controller: notesController,
          label: l10n.customerManagementNotes,
          enabled: !state.isSubmitting,
          maxLines: 3,
          textInputAction: TextInputAction.newline,
          onChanged: cubit.updateNotes,
        ),
        const SizedBox(height: 24),
        Text(
          l10n.customerManagementActiveGroups,
          style: Theme.of(context).textTheme.titleSmall,
        ),
        const SizedBox(height: 8),
        _GroupsBody(state: state, onRetry: cubit.loadGroups),
        if (state.submitFailure != null) ...<Widget>[
          const SizedBox(height: 16),
          _Message(
            state.submitFailure == PosCustomerFailureKind.forbidden
                ? l10n.posCustomerCreateForbidden
                : l10n.posCustomerCreateFailed,
          ),
        ],
      ],
    ),
  );
}

class _Header extends StatelessWidget {
  const _Header({required this.title, required this.onClose});

  final String title;
  final VoidCallback? onClose;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n =
        Localizations.of<AppLocalizations>(context, AppLocalizations) ??
        AppLocalizationsEn();
    return Semantics(
      container: true,
      header: true,
      label: title,
      child: ListTile(
        title: Text(title),
        trailing: IconButton(
          key: const Key('pos-customer-close'),
          onPressed: onClose,
          tooltip: l10n.posCloseCustomerSelector,
          icon: const Icon(Icons.close),
        ),
      ),
    );
  }
}

class _CustomerTextField extends StatelessWidget {
  const _CustomerTextField({
    super.key,
    required this.controller,
    required this.label,
    required this.onChanged,
    this.enabled = true,
    this.errorText,
    this.autofocus = false,
    this.keyboardType,
    this.textInputAction,
    this.maxLines = 1,
  });

  final TextEditingController controller;
  final String label;
  final ValueChanged<String> onChanged;
  final bool enabled;
  final String? errorText;
  final bool autofocus;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final int maxLines;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      enabled: enabled,
      autofocus: autofocus,
      keyboardType: keyboardType,
      textInputAction: textInputAction,
      maxLines: maxLines,
      onChanged: onChanged,
      decoration: InputDecoration(
        labelText: label,
        border: const OutlineInputBorder(),
        errorText: errorText,
      ),
    );
  }
}

class _GroupsBody extends StatelessWidget {
  const _GroupsBody({required this.state, required this.onRetry});

  final PosCustomerQuickCreateState state;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n =
        Localizations.of<AppLocalizations>(context, AppLocalizations) ??
        AppLocalizationsEn();
    return switch (state.groupStatus) {
      PosCustomerGroupStatus.loading => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 12),
            child: Center(child: CircularProgressIndicator()),
          ),
          Text(l10n.posCustomerGroupsLoading),
        ],
      ),
      PosCustomerGroupStatus.empty => Text(l10n.posCustomerGroupsEmpty),
      PosCustomerGroupStatus.failure => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          _Message(
            state.groupFailure == PosCustomerFailureKind.forbidden
                ? l10n.posCustomerGroupsForbidden
                : l10n.posCustomerGroupsRetry,
          ),
          if (state.groupFailure != PosCustomerFailureKind.forbidden)
            TextButton(
              onPressed: onRetry,
              child: Text(l10n.customerManagementRetry),
            ),
        ],
      ),
      PosCustomerGroupStatus.ready => Wrap(
        spacing: 8,
        runSpacing: 8,
        children: <Widget>[
          for (final PosCustomerGroup group in state.groups)
            FilterChip(
              key: ValueKey<String>('pos-customer-group-${group.id}'),
              label: Text(group.name),
              selected: state.groupIds.contains(group.id),
              onSelected: state.isSubmitting
                  ? null
                  : (bool selected) => context
                        .read<PosCustomerQuickCreateCubit>()
                        .toggleGroup(group.id, selected),
            ),
        ],
      ),
    };
  }
}

class _Message extends StatelessWidget {
  const _Message(this.message);

  final String message;

  @override
  Widget build(BuildContext context) => Text(
    message,
    style: TextStyle(color: Theme.of(context).colorScheme.error),
  );
}

class _Footer extends StatelessWidget {
  const _Footer({
    required this.isSubmitting,
    required this.onCancel,
    required this.onSubmit,
  });

  final bool isSubmitting;
  final VoidCallback onCancel;
  final VoidCallback onSubmit;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n =
        Localizations.of<AppLocalizations>(context, AppLocalizations) ??
        AppLocalizationsEn();
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: <Widget>[
          TextButton(
            key: const Key('pos-customer-cancel'),
            onPressed: isSubmitting ? null : onCancel,
            child: Text(l10n.customerManagementCancel),
          ),
          const SizedBox(width: 12),
          FilledButton(
            key: const Key('pos-customer-save'),
            onPressed: isSubmitting ? null : onSubmit,
            child: isSubmitting
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Text(l10n.customerManagementSave),
          ),
        ],
      ),
    );
  }
}

String? _fieldError(
  Map<String, List<String>> errors,
  String field,
  String requiredMessage,
  AppLocalizations l10n,
) {
  final List<String>? messages = errors[field];
  if (messages == null || messages.isEmpty) return null;
  return messages.first == 'required'
      ? requiredMessage
      : l10n.posCustomerCreateFailed;
}

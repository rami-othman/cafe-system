import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../app/customer_management_route_locations.dart';
import '../../../core/navigation/unsaved_navigation_guard.dart';
import '../../../core/theme/app_radius.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../l10n/app_localizations.dart';
import '../controllers/customer_group_form_cubit.dart';
import '../controllers/customer_group_form_state.dart';
import '../widgets/customer_management_page_header.dart';
import '../widgets/customer_management_surface.dart';
import '../widgets/customer_management_state_panel.dart';
import '../widgets/customer_management_visual_tokens.dart';

/// The editor remains a page; creation uses the same small form in a dialog.
class CustomerGroupFormScreen extends StatefulWidget {
  const CustomerGroupFormScreen({super.key, this.groupId});
  final int? groupId;

  @override
  State<CustomerGroupFormScreen> createState() =>
      _CustomerGroupFormScreenState();
}

class _CustomerGroupFormScreenState extends State<CustomerGroupFormScreen> {
  final _nameController = TextEditingController();
  final _nameFocus = FocusNode();
  bool _started = false;
  bool _registered = false;
  bool _allowCreateRoutePop = false;
  late VoidCallback _unregister;

  bool get _isCreate => widget.groupId == null;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_registered) {
      final navigation = UnsavedNavigationScope.maybeOf(context);
      if (navigation != null) {
        _registered = true;
        _unregister = navigation.register(
          UnsavedNavigationGuard(
            isDirty: () => context.read<CustomerGroupFormCubit>().state.isDirty,
            confirmLeave: () => _canLeave(context),
          ),
        );
      }
    }
    if (!_started) {
      _started = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        final cubit = context.read<CustomerGroupFormCubit>();
        _isCreate
            ? cubit.initializeCreate()
            : cubit.loadForEdit(widget.groupId!);
      });
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _nameFocus.dispose();
    if (_registered) _unregister();
    super.dispose();
  }

  @override
  Widget build(
    BuildContext context,
  ) => BlocConsumer<CustomerGroupFormCubit, CustomerGroupFormState>(
    listener: (context, state) {
      final id = state.savedGroup?.id;
      if (state.status == CustomerGroupFormStatus.success && id != null) {
        context.go(CustomerManagementRouteLocations.group(id));
      }
    },
    builder: (context, state) {
      if (state.status == CustomerGroupFormStatus.loading) {
        return const CustomerManagementStatePanel(
          loadingGeometry: CustomerManagementLoadingGeometry.form,
        );
      }
      if (!_nameFocus.hasFocus && _nameController.text != state.draft.name) {
        _nameController.value = TextEditingValue(
          text: state.draft.name,
          selection: TextSelection.collapsed(offset: state.draft.name.length),
        );
      }
      return _isCreate
          ? _createDialog(context, state)
          : _editPage(context, state);
    },
  );

  Widget _createDialog(BuildContext context, CustomerGroupFormState state) {
    final l10n = AppLocalizations.of(context);
    return PopScope<void>(
      canPop: _allowCreateRoutePop,
      onPopInvokedWithResult: (didPop, _) async {
        if (!didPop) await _dismissCreateRoute(context);
      },
      child: FocusTraversalGroup(
        child: Center(
          child: Dialog(
            key: const Key('customer-group-create-dialog'),
            insetPadding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              key: const Key('customer-group-create-content'),
              constraints: const BoxConstraints(maxWidth: 480),
              child: SingleChildScrollView(
                padding: const EdgeInsetsDirectional.fromSTEB(24, 22, 24, 20),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: <Widget>[
                    Text(
                      l10n.customerManagementCreateGroup,
                      style: CustomerManagementVisualTokens.pageTitle,
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      l10n.cmvpGroupFormDescription,
                      style: CustomerManagementVisualTokens.pageDescription,
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    _GroupNameFormContent(
                      controller: _nameController,
                      focusNode: _nameFocus,
                      state: state,
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    _GroupFormActions(
                      state: state,
                      onCancel: () => _dismissCreateRoute(context),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _dismissCreateRoute(BuildContext context) async {
    if (!await _canLeave(context) || !context.mounted) return;
    setState(() => _allowCreateRoutePop = true);
    Navigator.of(context, rootNavigator: true).pop();
  }

  Widget _editPage(BuildContext context, CustomerGroupFormState state) {
    final l10n = AppLocalizations.of(context);
    return PopScope<void>(
      canPop: !state.isDirty,
      onPopInvokedWithResult: (didPop, _) async {
        if (!didPop) await _leave(context);
      },
      child: Column(
        children: <Widget>[
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 720),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: <Widget>[
                      CustomerManagementPageHeader(
                        title: l10n.customerManagementEdit,
                        description: l10n.cmvpGroupFormDescription,
                        breadcrumbs: <String>[
                          l10n.cmvpBreadcrumbGroups,
                          l10n.cmvpBreadcrumbEdit,
                        ],
                      ),
                      const SizedBox(height: 24),
                      CustomerManagementSurface(
                        key: const Key('customer-group-form-surface'),
                        body: Padding(
                          padding: const EdgeInsets.all(20),
                          child: _GroupNameFormContent(
                            controller: _nameController,
                            focusNode: _nameFocus,
                            state: state,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: _GroupFormActions(
                state: state,
                onCancel: () => _leave(context),
                alignment: WrapAlignment.end,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _leave(BuildContext context) async {
    if (UnsavedNavigationScope.maybeOf(context) != null) {
      context.guardedGo(CustomerManagementRouteLocations.groups);
      return;
    }
    if (await _canLeave(context) && context.mounted) {
      context.go(CustomerManagementRouteLocations.groups);
    }
  }
}

class _GroupNameFormContent extends StatelessWidget {
  const _GroupNameFormContent({
    required this.controller,
    required this.focusNode,
    required this.state,
  });
  final TextEditingController controller;
  final FocusNode focusNode;
  final CustomerGroupFormState state;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final cubit = context.read<CustomerGroupFormCubit>();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Text(
          '${l10n.cmvpGroupName} *',
          style: CustomerManagementVisualTokens.tableHeading,
        ),
        const SizedBox(height: 6),
        Semantics(
          label: '${l10n.cmvpGroupName} *',
          child: TextField(
            key: const Key('customer-group-name'),
            controller: controller,
            focusNode: focusNode,
            autofocus: state.isCreate,
            textInputAction: TextInputAction.done,
            onSubmitted: (_) {
              if (state.status != CustomerGroupFormStatus.submitting) {
                cubit.submit();
              }
            },
            decoration: InputDecoration(
              errorText: state.fieldErrors['name'] == null
                  ? null
                  : l10n.customerManagementRequiredName,
            ),
            onChanged: cubit.setName,
          ),
        ),
        if (state.failure != null) ...<Widget>[
          const SizedBox(height: AppSpacing.md),
          Semantics(
            liveRegion: true,
            child: Text(
              l10n.customerManagementRequestFailed,
              key: const Key('customer-group-error'),
              style: CustomerManagementVisualTokens.pageDescription.copyWith(
                color: CustomerManagementVisualTokens.error,
              ),
            ),
          ),
        ],
      ],
    );
  }
}

class _GroupFormActions extends StatelessWidget {
  const _GroupFormActions({
    required this.state,
    required this.onCancel,
    this.alignment = WrapAlignment.end,
  });
  final CustomerGroupFormState state;
  final VoidCallback onCancel;
  final WrapAlignment alignment;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final cubit = context.read<CustomerGroupFormCubit>();
    return Wrap(
      alignment: alignment,
      spacing: AppSpacing.md,
      runSpacing: AppSpacing.sm,
      children: <Widget>[
        TextButton(
          key: const Key('customer-group-form-cancel'),
          onPressed: onCancel,
          style: TextButton.styleFrom(
            minimumSize: const Size(
              0,
              CustomerManagementVisualTokens.minimumInteractiveSize,
            ),
            shape: const RoundedRectangleBorder(
              borderRadius: AppRadius.control,
              side: CustomerManagementVisualTokens.surfaceBorder,
            ),
          ),
          child: Text(l10n.customerManagementCancel),
        ),
        FilledButton(
          key: const Key('customer-group-save'),
          onPressed: state.status == CustomerGroupFormStatus.submitting
              ? null
              : cubit.submit,
          style: FilledButton.styleFrom(
            minimumSize: const Size(
              0,
              CustomerManagementVisualTokens.minimumInteractiveSize,
            ),
            shape: const RoundedRectangleBorder(
              borderRadius: AppRadius.control,
            ),
          ),
          child: state.status == CustomerGroupFormStatus.submitting
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              : Text(l10n.customerManagementSave),
        ),
      ],
    );
  }
}

Future<bool> _canLeave(BuildContext context) async {
  if (!context.read<CustomerGroupFormCubit>().state.isDirty) return true;
  final l10n = AppLocalizations.of(context);
  return await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(l10n.customerManagementDiscardChanges),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text(l10n.customerManagementStay),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: Text(l10n.customerManagementLeave),
            ),
          ],
        ),
      ) ??
      false;
}

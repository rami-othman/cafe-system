import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../app/customer_management_route_locations.dart';
import '../../../core/navigation/unsaved_navigation_guard.dart';
import '../../../l10n/app_localizations.dart';
import '../controllers/customer_group_form_cubit.dart';
import '../controllers/customer_group_form_state.dart';
import '../widgets/customer_management_state_panel.dart';
import '../widgets/customer_management_page_header.dart';
import '../widgets/customer_management_surface.dart';

class CustomerGroupFormScreen extends StatefulWidget {
  const CustomerGroupFormScreen({super.key, this.groupId});
  final int? groupId;

  @override
  State<CustomerGroupFormScreen> createState() =>
      _CustomerGroupFormScreenState();
}

class _CustomerGroupFormScreenState extends State<CustomerGroupFormScreen> {
  final TextEditingController _nameController = TextEditingController();
  final FocusNode _nameFocus = FocusNode();
  bool _started = false;
  bool _registered = false;
  late VoidCallback _unregister;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_registered) {
      final UnsavedNavigationController? navigation =
          UnsavedNavigationScope.maybeOf(context);
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
        final CustomerGroupFormCubit cubit = context
            .read<CustomerGroupFormCubit>();
        if (widget.groupId == null) {
          cubit.initializeCreate();
        } else {
          cubit.loadForEdit(widget.groupId!);
        }
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
    listener: (BuildContext context, CustomerGroupFormState state) {
      final int? id = state.savedGroup?.id;
      if (state.status == CustomerGroupFormStatus.success && id != null) {
        context.go(CustomerManagementRouteLocations.group(id));
      }
    },
    builder: (BuildContext context, CustomerGroupFormState state) {
      if (state.status == CustomerGroupFormStatus.loading) {
        return const CustomerManagementStatePanel(
          loadingGeometry: CustomerManagementLoadingGeometry.form,
        );
      }
      final AppLocalizations l10n = AppLocalizations.of(context);
      final CustomerGroupFormCubit cubit = context
          .read<CustomerGroupFormCubit>();
      if (!_nameFocus.hasFocus && _nameController.text != state.draft.name) {
        _nameController.value = TextEditingValue(
          text: state.draft.name,
          selection: TextSelection.collapsed(offset: state.draft.name.length),
        );
      }
      return PopScope<void>(
        canPop: !state.isDirty,
        onPopInvokedWithResult: (bool didPop, _) async {
          if (!didPop && await _canLeave(context) && context.mounted) {
            context.go(CustomerManagementRouteLocations.groups);
          }
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
                          title: state.isCreate
                              ? l10n.customerManagementCreateGroup
                              : l10n.customerManagementEdit,
                          description: l10n.cmvpGroupFormDescription,
                          breadcrumbs: <String>[
                            l10n.cmvpBreadcrumbGroups,
                            state.isCreate
                                ? l10n.cmvpBreadcrumbCreate
                                : l10n.cmvpBreadcrumbEdit,
                          ],
                        ),
                        const SizedBox(height: 24),
                        CustomerManagementSurface(
                          key: const Key('customer-group-form-surface'),
                          body: Padding(
                            padding: const EdgeInsets.all(20),
                            child: TextField(
                              key: const Key('customer-group-name'),
                              controller: _nameController,
                              focusNode: _nameFocus,
                              decoration: InputDecoration(
                                labelText: l10n.cmvpGroupName,
                                errorText: state.fieldErrors['name'] == null
                                    ? null
                                    : l10n.customerManagementRequiredName,
                              ),
                              onChanged: cubit.setName,
                            ),
                          ),
                        ),
                        if (state.failure != null) ...<Widget>[
                          const SizedBox(height: 12),
                          Text(
                            l10n.customerManagementRequestFailed,
                            key: const Key('customer-group-error'),
                          ),
                        ],
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
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: <Widget>[
                    TextButton(
                      onPressed: () => _leave(context),
                      child: Text(l10n.customerManagementCancel),
                    ),
                    const SizedBox(width: 12),
                    FilledButton(
                      key: const Key('customer-group-save'),
                      onPressed:
                          state.status == CustomerGroupFormStatus.submitting
                          ? null
                          : cubit.submit,
                      child: state.status == CustomerGroupFormStatus.submitting
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : Text(l10n.customerManagementSave),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      );
    },
  );

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

Future<bool> _canLeave(BuildContext context) async {
  if (!context.read<CustomerGroupFormCubit>().state.isDirty) return true;
  final AppLocalizations l10n = AppLocalizations.of(context);
  return await showDialog<bool>(
        context: context,
        builder: (BuildContext context) => AlertDialog(
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

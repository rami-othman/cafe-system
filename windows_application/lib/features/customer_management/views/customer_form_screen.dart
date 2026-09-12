import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../app/customer_management_route_locations.dart';
import '../../../core/navigation/unsaved_navigation_guard.dart';
import '../../../l10n/app_localizations.dart';
import '../controllers/customer_form_cubit.dart';
import '../controllers/customer_form_state.dart';
import '../models/customer_models.dart';
import '../repositories/customer_management_repository.dart';
import '../widgets/customer_form_sections.dart';
import '../widgets/customer_lifecycle_actions.dart';
import '../widgets/customer_management_page_header.dart';
import '../widgets/customer_management_state_panel.dart';
import '../widgets/customer_management_surface.dart';

class CustomerFormScreen extends StatefulWidget {
  const CustomerFormScreen({
    super.key,
    this.customerId,
    this.lifecycleRepository,
  });

  final int? customerId;
  final CustomerManagementRepository? lifecycleRepository;

  @override
  State<CustomerFormScreen> createState() => _CustomerFormScreenState();
}

class _CustomerFormScreenState extends State<CustomerFormScreen> {
  bool _started = false;
  bool _registeredNavigation = false;
  late VoidCallback _unregisterNavigation;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_registeredNavigation) {
      final UnsavedNavigationController? navigation =
          UnsavedNavigationScope.maybeOf(context);
      if (navigation != null) {
        _registeredNavigation = true;
        _unregisterNavigation = navigation.register(
          UnsavedNavigationGuard(
            isDirty: () => context.read<CustomerFormCubit>().state.isDirty,
            confirmLeave: () => _canLeave(context),
          ),
        );
      }
    }
    if (!_started) {
      _started = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        final CustomerFormCubit cubit = context.read<CustomerFormCubit>();
        if (widget.customerId == null) {
          cubit.initializeCreate();
        } else {
          cubit.loadForEdit(widget.customerId!);
        }
      });
    }
  }

  @override
  void dispose() {
    if (_registeredNavigation) _unregisterNavigation();
    super.dispose();
  }

  @override
  Widget build(
    BuildContext context,
  ) => BlocConsumer<CustomerFormCubit, CustomerFormState>(
    listener: (BuildContext context, CustomerFormState state) {
      final int? savedId = state.savedCustomer?.id;
      if (state.status == CustomerFormStatus.success && savedId != null) {
        context.go(CustomerManagementRouteLocations.customer(savedId));
      }
    },
    builder: (BuildContext context, CustomerFormState state) {
      final CustomerFormCubit cubit = context.read<CustomerFormCubit>();
      if (state.status == CustomerFormStatus.loading) {
        return const CustomerManagementStatePanel(
          loadingGeometry: CustomerManagementLoadingGeometry.form,
        );
      }
      if (state.status == CustomerFormStatus.failure &&
          state.customerId != null &&
          state.customerNumber == null) {
        return CustomerManagementStatePanel(
          failure: state.failure,
          onRetry: () => cubit.loadForEdit(state.customerId!),
        );
      }
      final AppLocalizations l10n = AppLocalizations.of(context);
      return PopScope<void>(
        canPop: !state.isDirty,
        onPopInvokedWithResult: (bool didPop, _) async {
          if (didPop) return;
          if (await _canLeave(context) && context.mounted) {
            context.go(CustomerManagementRouteLocations.customers);
          }
        },
        child: Column(
          children: <Widget>[
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 900),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: <Widget>[
                        CustomerManagementPageHeader(
                          title: state.isCreate
                              ? l10n.customerManagementCreateTitle
                              : l10n.customerManagementEditTitle,
                          description: l10n.cmvpCustomerFormDescription,
                          breadcrumbs: <String>[
                            l10n.cmvpBreadcrumbCustomers,
                            state.isCreate
                                ? l10n.cmvpBreadcrumbCreate
                                : l10n.cmvpBreadcrumbEdit,
                          ],
                          actions:
                              widget.lifecycleRepository != null &&
                                  state.loadedCustomer != null
                              ? CustomerLifecycleActions(
                                  repository: widget.lifecycleRepository!,
                                  customer: state.loadedCustomer!,
                                  onCustomerReplaced: (Customer value) async =>
                                      cubit.replaceCustomerLifecycle(value),
                                )
                              : null,
                        ),
                        if (state.fieldErrors.isNotEmpty) ...<Widget>[
                          const SizedBox(height: 12),
                          Text(
                            l10n.customerManagementValidationFailed,
                            key: const Key('customer-form-general-error'),
                            style: TextStyle(
                              color: Theme.of(context).colorScheme.error,
                            ),
                          ),
                        ],
                        const SizedBox(height: 24),
                        CustomerManagementSurface(
                          key: const Key('customer-form-surface'),
                          readable: true,
                          body: Padding(
                            padding: const EdgeInsets.all(20),
                            child: CustomerFormSections(
                              state: state,
                              cubit: cubit,
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
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: <Widget>[
                    TextButton(
                      key: const Key('customer-form-cancel'),
                      onPressed: () => _leaveToList(context),
                      child: Text(l10n.customerManagementCancel),
                    ),
                    const SizedBox(width: 12),
                    FilledButton(
                      key: const Key('customer-form-save'),
                      onPressed: state.status == CustomerFormStatus.submitting
                          ? null
                          : cubit.submit,
                      child: state.status == CustomerFormStatus.submitting
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

  Future<void> _leaveToList(BuildContext context) async {
    if (UnsavedNavigationScope.maybeOf(context) != null) {
      context.guardedGo(CustomerManagementRouteLocations.customers);
      return;
    }
    if (await _canLeave(context) && context.mounted) {
      context.go(CustomerManagementRouteLocations.customers);
    }
  }
}

Future<bool> _canLeave(BuildContext context) async {
  if (!context.read<CustomerFormCubit>().state.isDirty) return true;
  final AppLocalizations l10n = AppLocalizations.of(context);
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

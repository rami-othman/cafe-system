import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../l10n/app_localizations.dart';
import '../controllers/customer_lifecycle_cubit.dart';
import '../controllers/customer_lifecycle_state.dart';
import '../models/customer_models.dart';
import '../repositories/customer_management_repository.dart';
import 'customer_confirmation_dialog.dart';
import 'customer_lifecycle_badge.dart';

class CustomerLifecycleActions extends StatefulWidget {
  const CustomerLifecycleActions({
    super.key,
    required this.repository,
    required this.customer,
    this.showBadge = true,
    this.onCustomerReplaced,
    this.onCollectionsRefresh,
  });

  final CustomerManagementRepository repository;
  final Customer customer;
  final bool showBadge;
  final Future<void> Function(Customer customer)? onCustomerReplaced;
  final Future<void> Function()? onCollectionsRefresh;

  @override
  State<CustomerLifecycleActions> createState() =>
      _CustomerLifecycleActionsState();
}

class _CustomerLifecycleActionsState extends State<CustomerLifecycleActions> {
  late final CustomerLifecycleCubit _cubit;
  final Map<String, FocusNode> _focusNodes = <String, FocusNode>{};

  @override
  void initState() {
    super.initState();
    _cubit = CustomerLifecycleCubit(
      widget.repository,
      initialCustomer: widget.customer,
      onCustomerReplaced: widget.onCustomerReplaced,
      onCollectionsRefresh: widget.onCollectionsRefresh,
    );
  }

  @override
  void didUpdateWidget(covariant CustomerLifecycleActions oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.customer != widget.customer) {
      _cubit.replaceCustomer(widget.customer);
    }
  }

  @override
  void dispose() {
    for (final FocusNode node in _focusNodes.values) {
      node.dispose();
    }
    _cubit.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) =>
      BlocConsumer<CustomerLifecycleCubit, CustomerLifecycleState>(
        bloc: _cubit,
        listenWhen:
            (CustomerLifecycleState previous, CustomerLifecycleState next) =>
                next.status == CustomerLifecycleStatus.failure &&
                previous.status != CustomerLifecycleStatus.failure,
        listener: (BuildContext context, CustomerLifecycleState state) {
          final FocusNode? node = _focusNodes[state.action];
          if (node != null) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted) node.requestFocus();
            });
          }
        },
        builder: (BuildContext context, CustomerLifecycleState state) {
          final AppLocalizations l10n = AppLocalizations.of(context);
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Row(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  if (widget.showBadge)
                    CustomerLifecycleBadge(lifecycle: state.customer.lifecycle),
                  if (state.isSubmitting) ...<Widget>[
                    const SizedBox(width: 12),
                    const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _visibleActions(state.customer)
                    .map((String action) {
                      final FocusNode focusNode = _focusNodes.putIfAbsent(
                        action,
                        () =>
                            FocusNode(debugLabel: 'customer-lifecycle-$action'),
                      );
                      return OutlinedButton(
                        key: Key('customer-lifecycle-$action'),
                        focusNode: focusNode,
                        onPressed: state.isSubmitting
                            ? null
                            : () => _selectAction(context, action),
                        child: Text(_label(l10n, action)),
                      );
                    })
                    .toList(growable: false),
              ),
              if (state.status == CustomerLifecycleStatus.failure) ...<Widget>[
                const SizedBox(height: 8),
                Semantics(
                  liveRegion: true,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(l10n.customerManagementRequestFailed),
                      Text(l10n.customerManagementMutationFailed),
                      if (state.action != null)
                        OutlinedButton(
                          key: const Key('customer-lifecycle-retry'),
                          onPressed: () => _cubit.perform(state.action!),
                          child: Text(l10n.customerManagementRetry),
                        ),
                    ],
                  ),
                ),
              ],
              if (state.status == CustomerLifecycleStatus.success)
                Semantics(
                  liveRegion: true,
                  child: Text(_label(l10n, state.customer.lifecycle.name)),
                ),
            ],
          );
        },
      );

  Future<void> _selectAction(BuildContext context, String action) async {
    if (action == 'activate') {
      await _cubit.perform(action);
      return;
    }
    final AppLocalizations l10n = AppLocalizations.of(context);
    final bool confirmed =
        await showDialog<bool>(
          context: context,
          builder: (BuildContext context) => CustomerConfirmationDialog(
            title: _confirmTitle(l10n, action, _cubit.state.customer.name),
            message: _consequence(l10n, action),
            confirmLabel: _label(l10n, action),
            confirmButtonKey: const Key('customer-lifecycle-confirm'),
          ),
        ) ??
        false;
    if (confirmed && mounted) await _cubit.perform(action);
  }
}

List<String> _visibleActions(Customer customer) {
  final Set<String> valid = switch (customer.lifecycle) {
    CustomerLifecycle.active => <String>{'deactivate', 'archive'},
    CustomerLifecycle.inactive => <String>{'activate', 'archive'},
    CustomerLifecycle.archived => <String>{'restore'},
  };
  return valid.where(customer.allowedActions.contains).toList(growable: false);
}

String _label(AppLocalizations l10n, String action) => switch (action) {
  'activate' => l10n.customerManagementActivate,
  'deactivate' => l10n.customerManagementDeactivate,
  'archive' => l10n.customerManagementArchive,
  'restore' => l10n.customerManagementRestore,
  'active' => l10n.customerManagementActive,
  'inactive' => l10n.customerManagementInactive,
  'archived' => l10n.customerManagementArchived,
  _ => action,
};

String _confirmTitle(AppLocalizations l10n, String action, String name) =>
    switch (action) {
      'deactivate' => l10n.customerManagementDeactivateConfirm(name),
      'archive' => l10n.customerManagementArchiveConfirm(name),
      'restore' => l10n.customerManagementRestoreConfirm(name),
      _ => l10n.customerManagementConfirm,
    };

String _consequence(AppLocalizations l10n, String action) => switch (action) {
  'deactivate' => l10n.customerManagementDeactivateConsequence,
  'archive' => l10n.customerManagementArchiveConsequence,
  'restore' => l10n.customerManagementRestoreConsequence,
  _ => l10n.customerManagementRequestFailed,
};

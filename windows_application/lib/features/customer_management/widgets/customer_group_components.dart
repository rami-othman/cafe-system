import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../l10n/app_localizations.dart';
import '../controllers/customer_group_detail_cubit.dart';
import '../controllers/customer_group_detail_state.dart';
import '../controllers/customer_group_membership_cubit.dart';
import '../controllers/customer_group_membership_state.dart';
import '../models/customer_group_models.dart';
import '../models/customer_models.dart';
import '../repositories/customer_management_repository.dart';
import 'customer_confirmation_dialog.dart';
import 'customer_bidi_value.dart';
import 'customer_lifecycle_badge.dart';
import 'customer_management_surface.dart';
import 'customer_management_state_panel.dart';
import 'customer_management_visual_tokens.dart';
import 'customer_pagination.dart';

class CustomerGroupLifecycleActions extends StatefulWidget {
  const CustomerGroupLifecycleActions({
    super.key,
    required this.repository,
    required this.group,
    this.onAction,
    this.isMutating = false,
    this.onGroupReplaced,
    this.onRefresh,
  });

  final CustomerManagementRepository repository;
  final CustomerGroup group;
  final Future<void> Function(String action)? onAction;
  final bool isMutating;
  final Future<void> Function(CustomerGroup group)? onGroupReplaced;
  final Future<void> Function()? onRefresh;

  @override
  State<CustomerGroupLifecycleActions> createState() =>
      _CustomerGroupLifecycleActionsState();
}

class _CustomerGroupLifecycleActionsState
    extends State<CustomerGroupLifecycleActions> {
  late final CustomerGroupDetailCubit _cubit;

  @override
  void initState() {
    super.initState();
    _cubit = CustomerGroupDetailCubit(
      widget.repository,
      initialGroup: widget.group,
    );
  }

  @override
  void didUpdateWidget(covariant CustomerGroupLifecycleActions oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.group != widget.group) _cubit.replaceGroup(widget.group);
  }

  @override
  void dispose() {
    _cubit.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) =>
      BlocConsumer<CustomerGroupDetailCubit, CustomerGroupDetailState>(
        bloc: _cubit,
        listener: (BuildContext context, CustomerGroupDetailState state) async {
          if (state.group != null &&
              state.status == CustomerGroupDetailStatus.success) {
            await widget.onGroupReplaced?.call(state.group!);
            await widget.onRefresh?.call();
          }
        },
        builder: (BuildContext context, CustomerGroupDetailState state) {
          final AppLocalizations l10n = AppLocalizations.of(context);
          final bool archived =
              state.group?.lifecycle == CustomerLifecycle.archived;
          final String action = archived ? 'restore' : 'archive';
          return Wrap(
            spacing: 8,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: <Widget>[
              CustomerLifecycleBadge(
                lifecycle: state.group?.lifecycle ?? widget.group.lifecycle,
              ),
              OutlinedButton(
                key: Key('customer-group-$action'),
                onPressed: widget.isMutating || state.isMutating
                    ? null
                    : () => _confirm(context, action),
                child: widget.isMutating || state.isMutating
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Text(
                        action == 'archive'
                            ? l10n.customerManagementArchive
                            : l10n.customerManagementRestore,
                      ),
              ),
              if (state.failure != null)
                Semantics(
                  liveRegion: true,
                  child: Text(l10n.customerManagementRequestFailed),
                ),
            ],
          );
        },
      );

  Future<void> _confirm(BuildContext context, String action) async {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final bool confirmed =
        await showDialog<bool>(
          context: context,
          builder: (BuildContext context) => CustomerConfirmationDialog(
            title: action == 'archive'
                ? l10n.customerManagementArchiveConfirm(widget.group.name)
                : l10n.customerManagementRestoreConfirm(widget.group.name),
            message: action == 'archive'
                ? l10n.customerManagementArchiveConsequence
                : l10n.customerManagementRestoreConsequence,
            confirmLabel: action == 'archive'
                ? l10n.customerManagementArchive
                : l10n.customerManagementRestore,
            confirmButtonKey: const Key('customer-group-lifecycle-confirm'),
          ),
        ) ??
        false;
    if (!confirmed || !mounted) return;
    if (widget.onAction != null) {
      await widget.onAction!(action);
    } else {
      await _cubit.changeLifecycle(action);
    }
  }
}

class CustomerGroupStatusBadge extends StatelessWidget {
  const CustomerGroupStatusBadge({super.key, required this.lifecycle});
  final CustomerLifecycle lifecycle;

  @override
  Widget build(BuildContext context) =>
      CustomerLifecycleBadge(lifecycle: lifecycle);
}

class CustomerGroupTable extends StatelessWidget {
  const CustomerGroupTable({
    super.key,
    required this.groups,
    required this.onView,
    required this.onEdit,
    this.onLifecycleRefresh,
    this.repository,
  });

  final List<CustomerGroup> groups;
  final ValueChanged<CustomerGroup> onView;
  final ValueChanged<CustomerGroup> onEdit;
  final Future<void> Function()? onLifecycleRefresh;
  final CustomerManagementRepository? repository;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final Widget content;
        if (constraints.maxWidth <
            CustomerManagementVisualTokens.collectionBreakpoint) {
          content = ListView.separated(
            itemCount: groups.length,
            padding: const EdgeInsets.all(16),
            separatorBuilder: (_, _) => const Divider(height: 1),
            itemBuilder: (BuildContext context, int index) => Material(
              type: MaterialType.transparency,
              child: ListTile(
                key: Key('customer-group-row-${groups[index].id}'),
                title: Semantics(
                  label: groups[index].name,
                  child: Tooltip(
                    message: groups[index].name,
                    child: Text(
                      groups[index].name,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
                subtitle: Text(
                  '${l10n.customerManagementMemberCount(groups[index].memberCount)}'
                  '${l10n.customerManagementValueSeparator}'
                  '${_status(l10n, groups[index].lifecycle)}',
                ),
                onTap: () => onView(groups[index]),
                trailing: _actions(context, groups[index]),
              ),
            ),
          );
        } else {
          content = Card(
            clipBehavior: Clip.antiAlias,
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: SizedBox(
                width: constraints.maxWidth,
                child: DataTable(
                  columns: <DataColumn>[
                    DataColumn(label: Text(l10n.customerManagementName)),
                    DataColumn(label: Text(l10n.customerManagementMembers)),
                    DataColumn(label: Text(l10n.customerManagementStatus)),
                    DataColumn(label: Text(l10n.customerManagementView)),
                  ],
                  rows: groups
                      .map(
                        (CustomerGroup group) => DataRow(
                          cells: <DataCell>[
                            DataCell(
                              Tooltip(
                                message: group.name,
                                child: Text(
                                  group.name,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              onTap: () => onView(group),
                            ),
                            DataCell(Text('${group.memberCount}')),
                            DataCell(
                              CustomerGroupStatusBadge(
                                lifecycle: group.lifecycle,
                              ),
                            ),
                            DataCell(_actions(context, group)),
                          ],
                        ),
                      )
                      .toList(growable: false),
                ),
              ),
            ),
          );
        }
        return CustomerManagementSurface(
          expandBody: constraints.hasBoundedHeight,
          body: content,
        );
      },
    );
  }

  Widget _actions(BuildContext context, CustomerGroup group) => Wrap(
    spacing: 2,
    children: <Widget>[
      IconButton(
        tooltip: AppLocalizations.of(context).customerManagementView,
        onPressed: () => onView(group),
        icon: const Icon(Icons.visibility_outlined),
      ),
      IconButton(
        tooltip: AppLocalizations.of(context).customerManagementEdit,
        onPressed: () => onEdit(group),
        icon: const Icon(Icons.edit_outlined),
      ),
      if (repository != null)
        CustomerGroupLifecycleActions(
          repository: repository!,
          group: group,
          onRefresh: onLifecycleRefresh,
        ),
    ],
  );
}

class CustomerGroupMemberTable extends StatelessWidget {
  const CustomerGroupMemberTable({
    super.key,
    required this.members,
    required this.onView,
    required this.onRemove,
    this.onPageChanged,
    this.surfaceKey,
  });
  final List<Customer> members;
  final ValueChanged<Customer> onView;
  final ValueChanged<Customer> onRemove;
  final ValueChanged<int>? onPageChanged;
  final Key? surfaceKey;

  @override
  Widget build(BuildContext context) {
    final Widget content = Column(
      children: <Widget>[
        ...members.map(
          (Customer customer) => ListTile(
            key: Key('customer-group-member-${customer.id}'),
            title: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                CustomerBidiValue(value: customer.customerNumber),
                Text(customer.name, overflow: TextOverflow.ellipsis),
              ],
            ),
            subtitle: CustomerBidiValue(
              value:
                  customer.phones
                      .where((CustomerPhone phone) => phone.isPrimary)
                      .firstOrNull
                      ?.rawNumber ??
                  AppLocalizations.of(context).customerManagementNoPhone,
            ),
            leading: CustomerGroupStatusBadge(lifecycle: customer.lifecycle),
            trailing: Wrap(
              children: <Widget>[
                IconButton(
                  tooltip: AppLocalizations.of(context).customerManagementView,
                  onPressed: () => onView(customer),
                  icon: const Icon(Icons.visibility_outlined),
                ),
                IconButton(
                  tooltip: AppLocalizations.of(
                    context,
                  ).customerManagementRemoveMember,
                  onPressed: () => onRemove(customer),
                  icon: const Icon(Icons.person_remove_outlined),
                ),
              ],
            ),
          ),
        ),
        if (members.isEmpty)
          Text(AppLocalizations.of(context).customerManagementNoResults),
      ],
    );
    return CustomerManagementSurface(key: surfaceKey, body: content);
  }
}

class CustomerGroupCandidateDialog extends StatelessWidget {
  const CustomerGroupCandidateDialog({
    super.key,
    required this.cubit,
    required this.onDone,
  });
  final CustomerGroupMembershipCubit cubit;
  final VoidCallback onDone;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final Size viewport = MediaQuery.sizeOf(context);
    final double dialogWidth = math.min(
      560,
      math.max(280, viewport.width - 96),
    );
    final double dialogHeight = math.min(
      420,
      math.max(240, viewport.height - 300),
    );
    return AlertDialog(
      key: const Key('customer-group-candidate-dialog'),
      title: Text(l10n.cmvpAddMembersDialogTitle),
      content: SizedBox(
        width: dialogWidth,
        height: dialogHeight,
        child:
            BlocBuilder<
              CustomerGroupMembershipCubit,
              CustomerGroupMembershipState
            >(
              bloc: cubit,
              builder:
                  (BuildContext context, CustomerGroupMembershipState state) {
                    return Column(
                      children: <Widget>[
                        TextField(
                          key: const Key('customer-group-candidate-search'),
                          decoration: InputDecoration(
                            labelText: l10n.cmvpCandidateSearch,
                          ),
                          autofocus: true,
                          onChanged: cubit.candidateSearchChanged,
                          onSubmitted: cubit.submitCandidateSearch,
                        ),
                        const SizedBox(height: 12),
                        Expanded(
                          child:
                              state.status ==
                                  CustomerGroupMembershipStatus.loading
                              ? Semantics(
                                  label: l10n.cmvpLoadingCustomers,
                                  liveRegion: true,
                                  child: const Center(
                                    child: CircularProgressIndicator(),
                                  ),
                                )
                              : state.candidates == null
                              ? CustomerManagementStatePanel(
                                  loadingGeometry:
                                      CustomerManagementLoadingGeometry.dialog,
                                  failure: state.failure,
                                  onRetry: cubit.loadCandidates,
                                )
                              : state.candidates!.items.isEmpty
                              ? Center(child: Text(l10n.cmvpNoCandidates))
                              : ListView(
                                  children: state.candidates!.items
                                      .map(
                                        (Customer customer) => CheckboxListTile(
                                          value: state.selectedCustomerIds
                                              .contains(customer.id),
                                          title: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: <Widget>[
                                              CustomerBidiValue(
                                                value: customer.customerNumber,
                                              ),
                                              Text(
                                                customer.name,
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            ],
                                          ),
                                          onChanged: (_) =>
                                              cubit.toggleSelected(customer.id),
                                        ),
                                      )
                                      .toList(growable: false),
                                ),
                        ),
                        if (state.candidates != null)
                          CustomerPagination(
                            meta: state.candidates!.meta,
                            onPageChanged: cubit.setCandidatePage,
                          ),
                      ],
                    );
                  },
            ),
      ),
      actions: <Widget>[
        TextButton(onPressed: onDone, child: Text(l10n.cmvpDialogCancel)),
        BlocBuilder<CustomerGroupMembershipCubit, CustomerGroupMembershipState>(
          bloc: cubit,
          builder: (BuildContext context, CustomerGroupMembershipState state) =>
              FilledButton(
                key: const Key('customer-group-add-confirm'),
                onPressed: state.selectedCustomerIds.isEmpty || state.isMutating
                    ? null
                    : () async {
                        await cubit.addSelected();
                        if (context.mounted) onDone();
                      },
                child: state.isMutating
                    ? Row(
                        mainAxisSize: MainAxisSize.min,
                        children: <Widget>[
                          const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                          const SizedBox(width: 8),
                          Text(l10n.cmvpAddingMembers),
                        ],
                      )
                    : Text(
                        l10n.cmvpSelectedCount(
                          state.selectedCustomerIds.length,
                        ),
                      ),
              ),
        ),
      ],
    );
  }
}

String _status(AppLocalizations l10n, CustomerLifecycle lifecycle) =>
    switch (lifecycle) {
      CustomerLifecycle.active => l10n.customerManagementActive,
      CustomerLifecycle.inactive => l10n.customerManagementInactive,
      CustomerLifecycle.archived => l10n.customerManagementArchived,
    };

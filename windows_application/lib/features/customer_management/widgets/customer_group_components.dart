import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
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
import 'customer_management_overflow_menu.dart';
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
    this.showBadge = true,
    this.compact = false,
    this.compactActions = const <CustomerManagementMenuEntry>[],
  });

  final CustomerManagementRepository repository;
  final CustomerGroup group;
  final Future<void> Function(String action)? onAction;
  final bool isMutating;
  final Future<void> Function(CustomerGroup group)? onGroupReplaced;
  final Future<void> Function()? onRefresh;
  final bool showBadge;
  final bool compact;
  final List<CustomerManagementMenuEntry> compactActions;

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
          if (widget.compact) {
            return CustomerManagementOverflowMenu(
              tooltip: l10n.cmvpOpenActions,
              actions: <CustomerManagementMenuEntry>[
                ...widget.compactActions,
                CustomerManagementMenuEntry(
                  label: action == 'archive'
                      ? l10n.customerManagementArchive
                      : l10n.customerManagementRestore,
                  icon: action == 'archive'
                      ? Icons.archive_outlined
                      : Icons.restore_outlined,
                  destructive: action == 'archive',
                  enabled: !widget.isMutating && !state.isMutating,
                  onPressed: () => _confirm(context, action),
                ),
              ],
            );
          }
          return Wrap(
            spacing: 8,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: <Widget>[
              if (widget.showBadge)
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
    this.scrollController,
    this.meta,
    this.onPageChanged,
  });

  final List<CustomerGroup> groups;
  final ValueChanged<CustomerGroup> onView;
  final ValueChanged<CustomerGroup> onEdit;
  final Future<void> Function()? onLifecycleRefresh;
  final CustomerManagementRepository? repository;
  final ScrollController? scrollController;
  final CustomerPageMeta? meta;
  final ValueChanged<int>? onPageChanged;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final Widget content;
        if (constraints.maxWidth <
            CustomerManagementVisualTokens.collectionBreakpoint) {
          content = ListView.separated(
            key: const Key('customer-group-list-scroll'),
            controller: scrollController,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: groups.length,
            padding: const EdgeInsets.all(16),
            separatorBuilder: (_, _) => const Divider(height: 1),
            itemBuilder: (BuildContext context, int index) => Material(
              type: MaterialType.transparency,
              child: Column(
                children: <Widget>[
                  Semantics(
                    button: true,
                    label: groups[index].name,
                    child: InkWell(
                      key: Key('customer-group-card-${groups[index].id}'),
                      onTap: () => onView(groups[index]),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: <Widget>[
                            Tooltip(
                              message: groups[index].name,
                              child: Text(
                                groups[index].name,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '${l10n.customerManagementMemberCount(groups[index].memberCount)}'
                              '${l10n.customerManagementValueSeparator}'
                              '${_status(l10n, groups[index].lifecycle)}',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            if (groups[index].createdAt != null) ...<Widget>[
                              const SizedBox(height: 4),
                              CustomerBidiValue(
                                key: Key(
                                  'customer-group-created-at-${groups[index].id}',
                                ),
                                value: _groupDate(groups[index].createdAt!),
                                isolate: true,
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsetsDirectional.only(
                      start: 16,
                      end: 16,
                      bottom: 8,
                    ),
                    child: Align(
                      alignment: AlignmentDirectional.centerEnd,
                      child: _actions(context, groups[index]),
                    ),
                  ),
                ],
              ),
            ),
          );
        } else {
          content = SizedBox(
            height: math.min(42 + (groups.length * 58), 500),
            child: Material(
              color: Colors.transparent,
              child: SingleChildScrollView(
                key: const Key('customer-group-list-scroll'),
                controller: scrollController,
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: SizedBox(
                    width: constraints.maxWidth,
                    child: DataTable(
                      showCheckboxColumn: false,
                      headingRowHeight: 42,
                      dataRowMinHeight: 58,
                      dataRowMaxHeight: 58,
                      horizontalMargin: 20,
                      columnSpacing: 20,
                      dividerThickness: 1,
                      headingTextStyle:
                          CustomerManagementVisualTokens.tableHeading,
                      dataTextStyle: CustomerManagementVisualTokens.tableCell,
                      headingRowColor: const WidgetStatePropertyAll<Color>(
                        CustomerManagementVisualTokens.warmHeader,
                      ),
                      columns: <DataColumn>[
                        DataColumn(label: Text(l10n.customerManagementName)),
                        DataColumn(label: Text(l10n.customerManagementMembers)),
                        DataColumn(label: Text(l10n.customerManagementStatus)),
                        DataColumn(label: Text(l10n.cmvpCreatedAt)),
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
                                DataCell(
                                  group.createdAt == null
                                      ? Text(l10n.cmvpAbsenceValue)
                                      : CustomerBidiValue(
                                          key: Key(
                                            'customer-group-created-at-${group.id}',
                                          ),
                                          value: _groupDate(group.createdAt!),
                                          isolate: true,
                                        ),
                                ),
                                DataCell(_desktopActions(context, group)),
                              ],
                            ),
                          )
                          .toList(growable: false),
                    ),
                  ),
                ),
              ),
            ),
          );
        }
        return CustomerManagementSurface(
          body: content,
          footer: meta == null || onPageChanged == null || meta!.lastPage <= 1
              ? null
              : CustomerPagination(meta: meta!, onPageChanged: onPageChanged!),
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
          showBadge: false,
          compact: true,
          compactActions: <CustomerManagementMenuEntry>[
            CustomerManagementMenuEntry(
              label: AppLocalizations.of(context).customerManagementView,
              icon: Icons.visibility_outlined,
              onPressed: () => onView(group),
            ),
            CustomerManagementMenuEntry(
              label: AppLocalizations.of(context).customerManagementEdit,
              icon: Icons.edit_outlined,
              onPressed: () => onEdit(group),
            ),
          ],
        ),
    ],
  );

  Widget _desktopActions(BuildContext context, CustomerGroup group) =>
      repository == null
      ? CustomerManagementOverflowMenu(
          tooltip: AppLocalizations.of(context).cmvpOpenActions,
          actions: <CustomerManagementMenuEntry>[
            CustomerManagementMenuEntry(
              label: AppLocalizations.of(context).customerManagementView,
              icon: Icons.visibility_outlined,
              onPressed: () => onView(group),
            ),
            CustomerManagementMenuEntry(
              label: AppLocalizations.of(context).customerManagementEdit,
              icon: Icons.edit_outlined,
              onPressed: () => onEdit(group),
            ),
          ],
        )
      : CustomerGroupLifecycleActions(
          repository: repository!,
          group: group,
          onRefresh: onLifecycleRefresh,
          showBadge: false,
          compact: true,
          compactActions: <CustomerManagementMenuEntry>[
            CustomerManagementMenuEntry(
              label: AppLocalizations.of(context).customerManagementView,
              icon: Icons.visibility_outlined,
              onPressed: () => onView(group),
            ),
            CustomerManagementMenuEntry(
              label: AppLocalizations.of(context).customerManagementEdit,
              icon: Icons.edit_outlined,
              onPressed: () => onEdit(group),
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
    this.meta,
    this.isFiltered = false,
    this.isMutating = false,
    this.onPageChanged,
    this.surfaceKey,
  });
  final List<Customer> members;
  final ValueChanged<Customer> onView;
  final ValueChanged<Customer> onRemove;
  final CustomerPageMeta? meta;
  final bool isFiltered;
  final bool isMutating;
  final ValueChanged<int>? onPageChanged;
  final Key? surfaceKey;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final bool useCards =
            CustomerManagementVisualTokens.usesCollectionCards(
              constraints.maxWidth,
            );
        final Widget content = members.isEmpty
            ? _MemberCollectionEmptyState(isFiltered: isFiltered)
            : useCards
            ? _MemberCards(
                members: members,
                onView: onView,
                onRemove: onRemove,
                isMutating: isMutating,
              )
            : _MemberDesktopTable(
                members: members,
                onView: onView,
                onRemove: onRemove,
                l10n: l10n,
                minWidth: constraints.maxWidth,
                isMutating: isMutating,
              );
        final Widget? footer =
            meta == null || onPageChanged == null || meta!.lastPage <= 1
            ? null
            : CustomerPagination(meta: meta!, onPageChanged: onPageChanged!);
        return CustomerManagementSurface(
          key: surfaceKey,
          body: content,
          footer: footer,
        );
      },
    );
  }
}

class _MemberDesktopTable extends StatelessWidget {
  const _MemberDesktopTable({
    required this.members,
    required this.onView,
    required this.onRemove,
    required this.l10n,
    required this.minWidth,
    required this.isMutating,
  });

  final List<Customer> members;
  final ValueChanged<Customer> onView;
  final ValueChanged<Customer> onRemove;
  final AppLocalizations l10n;
  final double minWidth;
  final bool isMutating;

  @override
  Widget build(BuildContext context) => SingleChildScrollView(
    scrollDirection: Axis.horizontal,
    child: ConstrainedBox(
      constraints: BoxConstraints(minWidth: minWidth),
      child: DataTable(
        showCheckboxColumn: false,
        headingRowHeight: 42,
        dataRowMinHeight: 56,
        dataRowMaxHeight: 56,
        horizontalMargin: 20,
        columnSpacing: 20,
        dividerThickness: 1,
        headingTextStyle: CustomerManagementVisualTokens.tableHeading,
        dataTextStyle: CustomerManagementVisualTokens.tableCell,
        headingRowColor: const WidgetStatePropertyAll<Color>(
          CustomerManagementVisualTokens.warmHeader,
        ),
        columns: <DataColumn>[
          DataColumn(label: Text(l10n.customerManagementCustomerNumber)),
          DataColumn(label: Text(l10n.customerManagementName)),
          DataColumn(label: Text(l10n.customerManagementPhone)),
          DataColumn(label: Text(l10n.customerManagementStatus)),
          DataColumn(label: Text(l10n.cmvpMoreActions)),
        ],
        rows: members
            .map(
              (Customer customer) => DataRow(
                onSelectChanged: (_) => onView(customer),
                cells: <DataCell>[
                  DataCell(CustomerBidiValue(value: customer.customerNumber)),
                  DataCell(
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 220),
                      child: Text(
                        customer.name,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF231005),
                          fontFamilyFallback:
                              CustomerManagementVisualTokens.fontFamilyFallback,
                        ),
                      ),
                    ),
                  ),
                  DataCell(
                    CustomerBidiValue(
                      value: _primaryMemberPhone(context, customer),
                    ),
                  ),
                  DataCell(
                    CustomerGroupStatusBadge(lifecycle: customer.lifecycle),
                  ),
                  DataCell(
                    _MemberActions(
                      customer: customer,
                      onView: onView,
                      onRemove: onRemove,
                      isMutating: isMutating,
                    ),
                  ),
                ],
              ),
            )
            .toList(growable: false),
      ),
    ),
  );
}

class _MemberCards extends StatelessWidget {
  const _MemberCards({
    required this.members,
    required this.onView,
    required this.onRemove,
    required this.isMutating,
  });

  final List<Customer> members;
  final ValueChanged<Customer> onView;
  final ValueChanged<Customer> onRemove;
  final bool isMutating;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.all(12),
    child: Column(
      children: <Widget>[
        for (int index = 0; index < members.length; index++) ...<Widget>[
          _MemberCard(
            customer: members[index],
            onView: onView,
            onRemove: onRemove,
            isMutating: isMutating,
          ),
          if (index < members.length - 1) const SizedBox(height: 8),
        ],
      ],
    ),
  );
}

class _MemberCard extends StatelessWidget {
  const _MemberCard({
    required this.customer,
    required this.onView,
    required this.onRemove,
    required this.isMutating,
  });

  final Customer customer;
  final ValueChanged<Customer> onView;
  final ValueChanged<Customer> onRemove;
  final bool isMutating;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      container: true,
      label: '${customer.customerNumber} ${customer.name}',
      child: Container(
        key: Key('customer-group-member-card-${customer.id}'),
        decoration: BoxDecoration(
          color: CustomerManagementVisualTokens.surface,
          border: Border.all(color: CustomerManagementVisualTokens.border),
          borderRadius: BorderRadius.circular(10),
        ),
        padding: const EdgeInsetsDirectional.fromSTEB(12, 10, 8, 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        customer.name,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF231005),
                          fontFamilyFallback:
                              CustomerManagementVisualTokens.fontFamilyFallback,
                        ),
                      ),
                      const SizedBox(height: 4),
                      CustomerBidiValue(value: customer.customerNumber),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                CustomerGroupStatusBadge(lifecycle: customer.lifecycle),
              ],
            ),
            const SizedBox(height: 6),
            Row(
              children: <Widget>[
                Expanded(
                  child: CustomerBidiValue(
                    value: _primaryMemberPhone(context, customer),
                  ),
                ),
                _MemberActions(
                  customer: customer,
                  onView: onView,
                  onRemove: onRemove,
                  isMutating: isMutating,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _MemberActions extends StatelessWidget {
  const _MemberActions({
    required this.customer,
    required this.onView,
    required this.onRemove,
    required this.isMutating,
  });

  final Customer customer;
  final ValueChanged<Customer> onView;
  final ValueChanged<Customer> onRemove;
  final bool isMutating;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    return Wrap(
      spacing: 0,
      children: <Widget>[
        IconButton(
          tooltip: l10n.customerManagementView,
          onPressed: () => onView(customer),
          icon: const Icon(Icons.visibility_outlined),
          color: CustomerManagementVisualTokens.rowText,
          constraints: const BoxConstraints(
            minWidth: CustomerManagementVisualTokens.minimumInteractiveSize,
            minHeight: CustomerManagementVisualTokens.minimumInteractiveSize,
          ),
        ),
        TextButton(
          onPressed: isMutating ? null : () => onRemove(customer),
          style: TextButton.styleFrom(
            foregroundColor: CustomerManagementVisualTokens.error,
            minimumSize: const Size(
              CustomerManagementVisualTokens.minimumInteractiveSize,
              CustomerManagementVisualTokens.minimumInteractiveSize,
            ),
            padding: const EdgeInsets.symmetric(horizontal: 4),
            textStyle: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              fontFamilyFallback:
                  CustomerManagementVisualTokens.fontFamilyFallback,
            ),
          ),
          child: Tooltip(
            message: l10n.customerManagementRemoveMember,
            child: Text(l10n.customerManagementRemoveMember),
          ),
        ),
      ],
    );
  }
}

class _MemberCollectionEmptyState extends StatelessWidget {
  const _MemberCollectionEmptyState({required this.isFiltered});

  final bool isFiltered;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 48),
      child: Semantics(
        liveRegion: true,
        container: true,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(
              isFiltered ? Icons.search_off_outlined : Icons.groups_outlined,
              size: 30,
              color: CustomerManagementVisualTokens.mutedText,
            ),
            const SizedBox(height: 10),
            Text(
              isFiltered ? l10n.cmvpNoResultsTitle : l10n.cmvpNoMembers,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: CustomerManagementVisualTokens.rowText,
                fontSize: 15,
                fontWeight: FontWeight.w700,
                fontFamilyFallback:
                    CustomerManagementVisualTokens.fontFamilyFallback,
              ),
            ),
            if (isFiltered) ...<Widget>[
              const SizedBox(height: 6),
              Text(
                l10n.cmvpNoResultsMessage,
                textAlign: TextAlign.center,
                style: CustomerManagementVisualTokens.pageDescription,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

String _primaryMemberPhone(BuildContext context, Customer customer) =>
    customer.phones
        .where((CustomerPhone phone) => phone.isPrimary)
        .firstOrNull
        ?.rawNumber ??
    AppLocalizations.of(context).customerManagementNoPhone;

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

String _groupDate(DateTime value) =>
    DateFormat('dd/MM/yyyy', 'en').format(value);

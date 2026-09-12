import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../app/customer_management_route_locations.dart';
import '../../../l10n/app_localizations.dart';
import '../controllers/customer_group_detail_cubit.dart';
import '../controllers/customer_group_detail_state.dart';
import '../controllers/customer_group_membership_cubit.dart';
import '../models/customer_models.dart';
import '../repositories/customer_management_repository.dart';
import '../widgets/customer_bidi_value.dart';
import '../widgets/customer_confirmation_dialog.dart';
import '../widgets/customer_group_components.dart';
import '../widgets/customer_management_page_header.dart';
import '../widgets/customer_management_state_panel.dart';
import '../widgets/customer_management_surface.dart';
import '../widgets/customer_pagination.dart';

class CustomerGroupDetailScreen extends StatefulWidget {
  const CustomerGroupDetailScreen({
    super.key,
    required this.groupId,
    required this.repository,
  });
  final int groupId;
  final CustomerManagementRepository repository;

  @override
  State<CustomerGroupDetailScreen> createState() =>
      _CustomerGroupDetailScreenState();
}

class _CustomerGroupDetailScreenState extends State<CustomerGroupDetailScreen> {
  late final CustomerGroupMembershipCubit _membership;
  final TextEditingController _search = TextEditingController();

  @override
  void initState() {
    super.initState();
    _membership = CustomerGroupMembershipCubit(
      widget.repository,
      groupId: widget.groupId,
      onChanged: () => context.read<CustomerGroupDetailCubit>().refresh(),
    );
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => context.read<CustomerGroupDetailCubit>().load(widget.groupId),
    );
  }

  @override
  void didUpdateWidget(covariant CustomerGroupDetailScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.groupId != widget.groupId) {
      context.read<CustomerGroupDetailCubit>().load(widget.groupId);
    }
  }

  @override
  void dispose() {
    _search.dispose();
    _membership.close();
    super.dispose();
  }

  @override
  Widget build(
    BuildContext context,
  ) => BlocBuilder<CustomerGroupDetailCubit, CustomerGroupDetailState>(
    builder: (BuildContext context, CustomerGroupDetailState state) {
      if ((state.status == CustomerGroupDetailStatus.initial ||
              state.status == CustomerGroupDetailStatus.loading) &&
          state.group == null) {
        return const CustomerManagementStatePanel(
          loadingGeometry: CustomerManagementLoadingGeometry.detail,
        );
      }
      if (state.status == CustomerGroupDetailStatus.failure &&
          state.group == null) {
        return CustomerManagementStatePanel(
          failure: state.failure,
          onRetry: context.read<CustomerGroupDetailCubit>().refresh,
        );
      }
      final group = state.group;
      if (group == null) {
        return CustomerManagementStatePanel(
          failure: state.failure,
          onRetry: context.read<CustomerGroupDetailCubit>().refresh,
        );
      }
      final AppLocalizations l10n = AppLocalizations.of(context);
      return Stack(
        children: <Widget>[
          Positioned.fill(
            child: ListView(
              padding: const EdgeInsets.all(24),
              children: <Widget>[
                CustomerManagementPageHeader(
                  title: group.name,
                  description: l10n.cmvpGroupDetailDescription,
                  breadcrumbs: <String>[
                    l10n.cmvpBreadcrumbGroups,
                    l10n.cmvpBreadcrumbDetails,
                    group.name,
                  ],
                  identity: CustomerBidiValue(
                    value: l10n.customerManagementMemberCount(
                      group.memberCount,
                    ),
                  ),
                  actions: Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: <Widget>[
                      CustomerGroupLifecycleActions(
                        repository: widget.repository,
                        group: group,
                        onAction: context
                            .read<CustomerGroupDetailCubit>()
                            .changeLifecycle,
                        isMutating: state.isMutating,
                      ),
                      IconButton(
                        tooltip: l10n.customerManagementEdit,
                        onPressed: () => context.go(
                          CustomerManagementRouteLocations.editGroup(group.id),
                        ),
                        icon: const Icon(Icons.edit_outlined),
                      ),
                    ],
                  ),
                ),
                const Divider(height: 32),
                CustomerManagementSurface(
                  key: const Key('customer-group-identity-surface'),
                  body: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Wrap(
                      spacing: 32,
                      runSpacing: 16,
                      children: <Widget>[
                        _GroupSummary(
                          label: l10n.customerManagementMembers,
                          value: CustomerBidiValue(
                            value: l10n.cmvpMembersCount(group.memberCount),
                          ),
                        ),
                        KeyedSubtree(
                          key: const Key('customer-group-created-at'),
                          child: _GroupSummary(
                            label: l10n.cmvpCreatedAt,
                            value: CustomerBidiValue(
                              value: group.createdAt == null
                                  ? l10n.cmvpAbsenceValue
                                  : MaterialLocalizations.of(
                                      context,
                                    ).formatCompactDate(
                                      group.createdAt!.toLocal(),
                                    ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                CustomerManagementSurface(
                  key: const Key('customer-group-member-controls'),
                  body: Padding(
                    padding: const EdgeInsets.all(20),
                    child: LayoutBuilder(
                      builder:
                          (BuildContext context, BoxConstraints constraints) {
                            final Widget search = TextField(
                              controller: _search,
                              decoration: InputDecoration(
                                labelText: l10n.cmvpMemberSearch,
                                prefixIcon: const Icon(Icons.search),
                              ),
                              onChanged: context
                                  .read<CustomerGroupDetailCubit>()
                                  .memberSearchChanged,
                              onSubmitted: context
                                  .read<CustomerGroupDetailCubit>()
                                  .submitMemberSearch,
                            );
                            final Widget add = FilledButton.icon(
                              key: const Key('customer-group-add-members'),
                              onPressed:
                                  group.lifecycle == CustomerLifecycle.archived
                                  ? null
                                  : _openAddMembers,
                              icon: const Icon(Icons.person_add_outlined),
                              label: Text(l10n.customerManagementAddMembers),
                            );
                            return constraints.maxWidth < 640
                                ? Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.stretch,
                                    children: <Widget>[search, add],
                                  )
                                : Row(
                                    children: <Widget>[
                                      Expanded(child: search),
                                      add,
                                    ],
                                  );
                          },
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                if (state.memberFailure != null)
                  CustomerManagementStatePanel(
                    failure: state.memberFailure,
                    onRetry: context
                        .read<CustomerGroupDetailCubit>()
                        .loadMembers,
                  )
                else if (state.failure != null)
                  CustomerManagementStatePanel(
                    failure: state.failure,
                    onRetry: context.read<CustomerGroupDetailCubit>().refresh,
                  )
                else ...<Widget>[
                  CustomerGroupMemberTable(
                    surfaceKey: const Key('customer-group-members-surface'),
                    members: state.members?.items ?? const <Customer>[],
                    onView: (customer) => context.go(
                      CustomerManagementRouteLocations.customer(customer.id),
                    ),
                    onRemove: (customer) =>
                        _confirmRemove(group.name, customer),
                    onPageChanged: context
                        .read<CustomerGroupDetailCubit>()
                        .setMemberPage,
                  ),
                  if (state.members != null)
                    CustomerPagination(
                      meta: state.members!.meta,
                      onPageChanged: context
                          .read<CustomerGroupDetailCubit>()
                          .setMemberPage,
                    ),
                ],
              ],
            ),
          ),
          if (state.status == CustomerGroupDetailStatus.loading)
            Semantics(
              label: l10n.cmvpLoadingRecord,
              liveRegion: true,
              child: const LinearProgressIndicator(),
            ),
        ],
      );
    },
  );

  Future<void> _openAddMembers() async {
    await _membership.loadCandidates();
    if (!mounted) return;
    await showDialog<void>(
      context: context,
      builder: (BuildContext context) => CustomerGroupCandidateDialog(
        cubit: _membership,
        onDone: () => Navigator.of(context).pop(),
      ),
    );
  }

  Future<void> _confirmRemove(String groupName, Customer customer) async {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final bool confirmed =
        await showDialog<bool>(
          context: context,
          builder: (BuildContext context) => CustomerConfirmationDialog(
            title: l10n.customerManagementRemoveMemberConfirm(
              customer.name,
              groupName,
            ),
            message: l10n.customerManagementRemoveMemberConfirm(
              customer.name,
              groupName,
            ),
            confirmLabel: l10n.customerManagementRemoveMember,
            confirmButtonKey: const Key('customer-group-remove-confirm'),
          ),
        ) ??
        false;
    if (confirmed && mounted) await _membership.remove(customer.id);
  }
}

class _GroupSummary extends StatelessWidget {
  const _GroupSummary({required this.label, required this.value});

  final String label;
  final Widget value;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: <Widget>[
      Text(label, style: Theme.of(context).textTheme.labelMedium),
      const SizedBox(height: 4),
      value,
    ],
  );
}

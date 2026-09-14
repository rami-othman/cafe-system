import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../app/customer_management_route_locations.dart';
import '../../../l10n/app_localizations.dart';
import '../controllers/customer_group_detail_cubit.dart';
import '../controllers/customer_group_detail_state.dart';
import '../controllers/customer_group_membership_cubit.dart';
import '../controllers/customer_group_membership_state.dart';
import '../models/customer_failure.dart';
import '../models/customer_group_models.dart';
import '../models/customer_models.dart';
import '../repositories/customer_management_repository.dart';
import '../widgets/customer_bidi_value.dart';
import '../widgets/customer_confirmation_dialog.dart';
import '../widgets/customer_group_components.dart';
import '../widgets/customer_lifecycle_badge.dart';
import '../widgets/customer_management_overflow_menu.dart';
import '../widgets/customer_management_state_panel.dart';
import '../widgets/customer_management_visual_tokens.dart';

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
        return Padding(
          padding: _groupDetailPagePadding,
          child: const CustomerManagementStatePanel(
            loadingGeometry: CustomerManagementLoadingGeometry.detail,
          ),
        );
      }
      if (state.status == CustomerGroupDetailStatus.failure &&
          state.group == null) {
        return Padding(
          padding: _groupDetailPagePadding,
          child: CustomerManagementStatePanel(
            failure: state.failure,
            onRetry: context.read<CustomerGroupDetailCubit>().refresh,
          ),
        );
      }
      final group = state.group;
      if (group == null) {
        return Padding(
          padding: _groupDetailPagePadding,
          child: CustomerManagementStatePanel(
            failure: state.failure,
            onRetry: context.read<CustomerGroupDetailCubit>().refresh,
          ),
        );
      }
      final AppLocalizations l10n = AppLocalizations.of(context);
      final CustomerGroupDetailCubit cubit = context
          .read<CustomerGroupDetailCubit>();
      return BlocBuilder<
        CustomerGroupMembershipCubit,
        CustomerGroupMembershipState
      >(
        bloc: _membership,
        builder:
            (
              BuildContext context,
              CustomerGroupMembershipState membershipState,
            ) {
              final bool hasRefreshFailure =
                  state.status == CustomerGroupDetailStatus.failure &&
                  state.failure != null &&
                  state.memberFailure == null;
              final bool hasMutationFailure =
                  state.failure != null &&
                  state.status != CustomerGroupDetailStatus.failure &&
                  !state.isMutating;
              return Stack(
                children: <Widget>[
                  Positioned.fill(
                    child: ListView(
                      padding: _groupDetailPagePadding,
                      children: <Widget>[
                        KeyedSubtree(
                          key: const Key('customer-group-identity-surface'),
                          child: _GroupDetailHeader(
                            group: group,
                            l10n: l10n,
                            isMutating: state.isMutating,
                            onEdit: () => context.go(
                              CustomerManagementRouteLocations.editGroup(
                                group.id,
                              ),
                            ),
                            onAddMembers:
                                group.lifecycle == CustomerLifecycle.archived
                                ? null
                                : _openAddMembers,
                            onLifecycle: (String action) =>
                                _confirmLifecycle(group, action),
                          ),
                        ),
                        if (hasRefreshFailure)
                          _GroupDetailFailureBanner(
                            failure: state.failure!,
                            onRetry: cubit.refresh,
                          ),
                        if (hasMutationFailure)
                          _GroupDetailMutationFailure(
                            message: l10n.customerManagementRequestFailed,
                          ),
                        if (membershipState.failure != null &&
                            membershipState.status ==
                                CustomerGroupMembershipStatus.failure)
                          _GroupDetailMembershipFailure(
                            message: l10n.customerManagementRequestFailed,
                          ),
                        const SizedBox(height: 8),
                        _MemberCollectionToolbar(
                          key: const Key('customer-group-member-controls'),
                          controller: _search,
                          l10n: l10n,
                          total: state.members?.meta.total,
                          onChanged: cubit.memberSearchChanged,
                          onSubmitted: cubit.submitMemberSearch,
                        ),
                        const SizedBox(height: 16),
                        if (state.memberFailure != null)
                          CustomerManagementStatePanel(
                            failure: state.memberFailure,
                            onRetry: cubit.loadMembers,
                            collectionSurface: true,
                          )
                        else if (state.members == null)
                          const CustomerManagementStatePanel(
                            loadingGeometry:
                                CustomerManagementLoadingGeometry.collection,
                            collectionSurface: true,
                          )
                        else ...<Widget>[
                          CustomerGroupMemberTable(
                            surfaceKey: const Key(
                              'customer-group-members-surface',
                            ),
                            members: state.members?.items ?? const <Customer>[],
                            meta: state.members!.meta,
                            isFiltered: state.memberQuery.search
                                .trim()
                                .isNotEmpty,
                            isMutating: membershipState.isMutating,
                            onView: (customer) => context.go(
                              CustomerManagementRouteLocations.customer(
                                customer.id,
                              ),
                            ),
                            onRemove: (customer) =>
                                _confirmRemove(group.name, customer),
                            onPageChanged: cubit.setMemberPage,
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
                  if (membershipState.isMutating)
                    Semantics(
                      label: l10n.cmvpLoadingRecord,
                      liveRegion: true,
                      child: const LinearProgressIndicator(),
                    ),
                ],
              );
            },
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

  Future<void> _confirmLifecycle(CustomerGroup group, String action) async {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final bool confirmed =
        await showDialog<bool>(
          context: context,
          builder: (BuildContext context) => CustomerConfirmationDialog(
            title: action == 'archive'
                ? l10n.customerManagementArchiveConfirm(group.name)
                : l10n.customerManagementRestoreConfirm(group.name),
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
    if (confirmed && mounted) {
      await context.read<CustomerGroupDetailCubit>().changeLifecycle(action);
    }
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

class _GroupDetailHeader extends StatelessWidget {
  const _GroupDetailHeader({
    required this.group,
    required this.l10n,
    required this.isMutating,
    required this.onEdit,
    required this.onAddMembers,
    required this.onLifecycle,
  });

  final CustomerGroup group;
  final AppLocalizations l10n;
  final bool isMutating;
  final VoidCallback onEdit;
  final VoidCallback? onAddMembers;
  final ValueChanged<String> onLifecycle;

  @override
  Widget build(BuildContext context) {
    final String lifecycleAction = group.lifecycle == CustomerLifecycle.archived
        ? 'restore'
        : 'archive';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        _Breadcrumbs(
          values: <String>[
            l10n.cmvpBreadcrumbGroups,
            l10n.cmvpBreadcrumbDetails,
            group.name,
          ],
        ),
        const SizedBox(height: 22),
        LayoutBuilder(
          builder: (BuildContext context, BoxConstraints constraints) {
            final Widget actions = Wrap(
              spacing: 8,
              runSpacing: 8,
              alignment: WrapAlignment.end,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: <Widget>[
                OutlinedButton.icon(
                  key: const Key('customer-group-detail-edit'),
                  onPressed: onEdit,
                  icon: const Icon(Icons.edit_outlined, size: 17),
                  label: Text(l10n.customerManagementEdit),
                  style: _detailSecondaryButtonStyle,
                ),
                CustomerManagementOverflowMenu(
                  key: const Key('customer-group-detail-lifecycle'),
                  actions: <CustomerManagementMenuEntry>[
                    CustomerManagementMenuEntry(
                      label: lifecycleAction == 'archive'
                          ? l10n.customerManagementArchive
                          : l10n.customerManagementRestore,
                      icon: lifecycleAction == 'archive'
                          ? Icons.archive_outlined
                          : Icons.restore_outlined,
                      destructive: lifecycleAction == 'archive',
                      enabled: !isMutating,
                      onPressed: () => onLifecycle(lifecycleAction),
                    ),
                  ],
                  tooltip: l10n.cmvpMoreActions,
                  semanticLabel: l10n.cmvpOpenActions,
                ),
                if (isMutating)
                  Semantics(
                    label: l10n.cmvpLoadingRecord,
                    liveRegion: true,
                    child: const SizedBox(
                      key: Key('customer-group-lifecycle-progress'),
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  ),
                FilledButton.icon(
                  key: const Key('customer-group-add-members'),
                  onPressed: onAddMembers,
                  icon: const Icon(Icons.person_add_outlined, size: 17),
                  label: Text(l10n.customerManagementAddMembers),
                  style: _detailPrimaryButtonStyle,
                ),
              ],
            );
            final Widget identity = Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Wrap(
                  spacing: 10,
                  runSpacing: 6,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: <Widget>[
                    Text(
                      group.name,
                      key: const ValueKey<String>(
                        'customer-management-page-title',
                      ),
                      overflow: TextOverflow.ellipsis,
                      style: CustomerManagementVisualTokens.pageTitle.copyWith(
                        fontSize: 20,
                      ),
                    ),
                    CustomerLifecycleBadge(
                      key: const Key('customer-group-detail-status'),
                      lifecycle: group.lifecycle,
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                _GroupMeta(group: group, l10n: l10n),
              ],
            );
            if (constraints.maxWidth < 640) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  identity,
                  const SizedBox(height: 16),
                  Align(
                    alignment: AlignmentDirectional.centerStart,
                    child: actions,
                  ),
                ],
              );
            }
            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              textDirection: Directionality.of(context),
              children: <Widget>[
                Expanded(child: identity),
                const SizedBox(width: 16),
                Flexible(child: actions),
              ],
            );
          },
        ),
      ],
    );
  }
}

class _Breadcrumbs extends StatelessWidget {
  const _Breadcrumbs({required this.values});

  final List<String> values;

  @override
  Widget build(BuildContext context) => Wrap(
    spacing: 6,
    runSpacing: 4,
    crossAxisAlignment: WrapCrossAlignment.center,
    children: <Widget>[
      for (int index = 0; index < values.length; index++) ...<Widget>[
        if (index > 0)
          Icon(
            Directionality.of(context) == TextDirection.rtl
                ? Icons.chevron_left
                : Icons.chevron_right,
            size: 15,
            color: CustomerManagementVisualTokens.mutedText,
          ),
        Text(
          values[index],
          overflow: TextOverflow.ellipsis,
          style: CustomerManagementVisualTokens.pageDescription,
        ),
      ],
    ],
  );
}

class _GroupMeta extends StatelessWidget {
  const _GroupMeta({required this.group, required this.l10n});

  final CustomerGroup group;
  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    final List<Widget> items = <Widget>[
      CustomerBidiValue(value: l10n.cmvpMembersCount(group.memberCount)),
    ];
    if (group.createdAt != null) {
      items.add(
        KeyedSubtree(
          key: const Key('customer-group-created-at'),
          child: Wrap(
            spacing: 6,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: <Widget>[
              const Icon(
                Icons.circle,
                size: 4,
                color: CustomerManagementVisualTokens.mutedText,
              ),
              Text(
                l10n.cmvpCreatedAt,
                style: CustomerManagementVisualTokens.pageDescription,
              ),
              _LtrDateValue(
                value: MaterialLocalizations.of(
                  context,
                ).formatCompactDate(group.createdAt!.toLocal()),
              ),
            ],
          ),
        ),
      );
    }
    return Wrap(
      spacing: 6,
      runSpacing: 4,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: items,
    );
  }
}

class _LtrDateValue extends StatelessWidget {
  const _LtrDateValue({required this.value});

  final String value;

  @override
  Widget build(BuildContext context) => Directionality(
    textDirection: TextDirection.ltr,
    child: Text(
      '\u2066$value\u2069',
      key: const Key('customer-group-created-at-value'),
      textDirection: TextDirection.ltr,
      style: CustomerManagementVisualTokens.pageDescription,
    ),
  );
}

class _MemberCollectionToolbar extends StatelessWidget {
  const _MemberCollectionToolbar({
    super.key,
    required this.controller,
    required this.l10n,
    required this.total,
    required this.onChanged,
    required this.onSubmitted,
  });

  final TextEditingController controller;
  final AppLocalizations l10n;
  final int? total;
  final ValueChanged<String> onChanged;
  final ValueChanged<String> onSubmitted;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (BuildContext context, BoxConstraints constraints) {
      final Widget search = SizedBox(
        width: constraints.maxWidth < 640 ? double.infinity : 300,
        height: 40,
        child: TextField(
          key: const Key('customer-group-member-search'),
          controller: controller,
          onChanged: onChanged,
          onSubmitted: onSubmitted,
          textInputAction: TextInputAction.search,
          decoration: InputDecoration(
            hintText: l10n.cmvpMemberSearch,
            prefixIcon: const Icon(Icons.search_outlined, size: 18),
            prefixIconConstraints: const BoxConstraints(
              minWidth: 40,
              minHeight: 40,
            ),
            isDense: true,
            filled: true,
            fillColor: CustomerManagementVisualTokens.surface,
            contentPadding: const EdgeInsets.symmetric(horizontal: 12),
            border: const OutlineInputBorder(
              borderSide: CustomerManagementVisualTokens.surfaceBorder,
              borderRadius: BorderRadius.all(Radius.circular(8)),
            ),
            enabledBorder: const OutlineInputBorder(
              borderSide: CustomerManagementVisualTokens.surfaceBorder,
              borderRadius: BorderRadius.all(Radius.circular(8)),
            ),
            focusedBorder: const OutlineInputBorder(
              borderSide: BorderSide(
                color: CustomerManagementVisualTokens.focus,
                width: 1.5,
              ),
              borderRadius: BorderRadius.all(Radius.circular(8)),
            ),
          ),
        ),
      );
      final Widget count = total == null
          ? const SizedBox.shrink()
          : Text(
              l10n.customerManagementMemberCount(total!),
              key: const Key('customer-group-member-result-count'),
              style: CustomerManagementVisualTokens.pageDescription,
            );
      if (constraints.maxWidth < 640) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            search,
            const SizedBox(height: 8),
            Align(alignment: AlignmentDirectional.centerEnd, child: count),
          ],
        );
      }
      return Row(
        textDirection: Directionality.of(context),
        children: <Widget>[search, const Spacer(), count],
      );
    },
  );
}

class _GroupDetailFailureBanner extends StatelessWidget {
  const _GroupDetailFailureBanner({
    required this.failure,
    required this.onRetry,
  });

  final CustomerFailure failure;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final bool retryable =
        failure.kind != CustomerFailureKind.forbidden &&
        failure.kind != CustomerFailureKind.notFound;
    return Container(
      key: const Key('customer-group-detail-refresh-failure'),
      padding: const EdgeInsetsDirectional.fromSTEB(12, 8, 8, 8),
      decoration: BoxDecoration(
        color: CustomerManagementVisualTokens.error.withAlpha(18),
        border: Border.all(
          color: CustomerManagementVisualTokens.error.withAlpha(64),
        ),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: <Widget>[
          Icon(
            Icons.warning_amber_outlined,
            size: 18,
            color: CustomerManagementVisualTokens.error,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              AppLocalizations.of(context).customerManagementRequestFailed,
              style: CustomerManagementVisualTokens.pageDescription.copyWith(
                color: CustomerManagementVisualTokens.error,
              ),
            ),
          ),
          if (retryable)
            TextButton(
              onPressed: onRetry,
              child: Text(AppLocalizations.of(context).customerManagementRetry),
            ),
        ],
      ),
    );
  }
}

class _GroupDetailMutationFailure extends StatelessWidget {
  const _GroupDetailMutationFailure({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) => Semantics(
    liveRegion: true,
    child: Align(
      alignment: AlignmentDirectional.centerStart,
      child: Text(
        message,
        key: const Key('customer-group-lifecycle-error'),
        style: CustomerManagementVisualTokens.pageDescription.copyWith(
          color: CustomerManagementVisualTokens.error,
        ),
      ),
    ),
  );
}

class _GroupDetailMembershipFailure extends StatelessWidget {
  const _GroupDetailMembershipFailure({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) => Semantics(
    liveRegion: true,
    child: Align(
      alignment: AlignmentDirectional.centerStart,
      child: Text(
        message,
        key: const Key('customer-group-membership-error'),
        style: CustomerManagementVisualTokens.pageDescription.copyWith(
          color: CustomerManagementVisualTokens.error,
        ),
      ),
    ),
  );
}

const EdgeInsetsDirectional _groupDetailPagePadding =
    EdgeInsetsDirectional.fromSTEB(8, 0, 8, 24);

const ButtonStyle _detailPrimaryButtonStyle = ButtonStyle(
  minimumSize: WidgetStatePropertyAll<Size>(
    Size(0, CustomerManagementVisualTokens.minimumInteractiveSize),
  ),
  padding: WidgetStatePropertyAll<EdgeInsetsGeometry>(
    EdgeInsets.symmetric(horizontal: 16),
  ),
  backgroundColor: WidgetStatePropertyAll<Color>(
    CustomerManagementVisualTokens.accent,
  ),
  foregroundColor: WidgetStatePropertyAll<Color>(Colors.white),
  shape: WidgetStatePropertyAll<RoundedRectangleBorder>(
    RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(8))),
  ),
);

const ButtonStyle _detailSecondaryButtonStyle = ButtonStyle(
  minimumSize: WidgetStatePropertyAll<Size>(
    Size(0, CustomerManagementVisualTokens.minimumInteractiveSize),
  ),
  padding: WidgetStatePropertyAll<EdgeInsetsGeometry>(
    EdgeInsets.symmetric(horizontal: 16),
  ),
  foregroundColor: WidgetStatePropertyAll<Color>(
    CustomerManagementVisualTokens.accent,
  ),
  side: WidgetStatePropertyAll<BorderSide>(
    CustomerManagementVisualTokens.surfaceBorder,
  ),
  shape: WidgetStatePropertyAll<RoundedRectangleBorder>(
    RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(8))),
  ),
);

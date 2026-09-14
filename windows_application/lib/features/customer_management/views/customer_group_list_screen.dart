import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../app/customer_management_route_locations.dart';
import '../../../l10n/app_localizations.dart';
import '../controllers/customer_group_list_cubit.dart';
import '../controllers/customer_group_list_state.dart';
import '../models/customer_queries.dart';
import '../repositories/customer_management_repository.dart';
import '../widgets/customer_group_components.dart';
import '../widgets/customer_management_page_header.dart';
import '../widgets/customer_management_state_panel.dart';

class CustomerGroupListScreen extends StatefulWidget {
  const CustomerGroupListScreen({super.key, required this.repository});
  final CustomerManagementRepository repository;

  @override
  State<CustomerGroupListScreen> createState() =>
      _CustomerGroupListScreenState();
}

class _CustomerGroupListScreenState extends State<CustomerGroupListScreen> {
  final TextEditingController _search = TextEditingController();
  final FocusNode _createFocus = FocusNode(debugLabel: 'customer-group-create');
  final ScrollController _collectionScroll = ScrollController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => context.read<CustomerGroupListCubit>().load(),
    );
  }

  @override
  void dispose() {
    _search.dispose();
    _createFocus.dispose();
    _collectionScroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) =>
      BlocBuilder<CustomerGroupListCubit, CustomerGroupListState>(
        builder: (BuildContext context, CustomerGroupListState state) {
          final AppLocalizations l10n = AppLocalizations.of(context);
          final CustomerGroupListCubit cubit = context
              .read<CustomerGroupListCubit>();
          return Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                CustomerManagementPageHeader(
                  title: l10n.customerManagementGroups,
                  description: l10n.cmvpGroupsDescription,
                  breadcrumbs: <String>[l10n.cmvpBreadcrumbGroups],
                  primaryAction: Focus(
                    focusNode: _createFocus,
                    child: FilledButton.icon(
                      key: const Key('customer-group-create'),
                      onPressed: () async {
                        await context.push<void>(
                          CustomerManagementRouteLocations.groupCreate,
                        );
                        if (mounted) _createFocus.requestFocus();
                      },
                      icon: const Icon(Icons.group_add_outlined),
                      label: Text(l10n.customerManagementCreateGroup),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                LayoutBuilder(
                  builder: (BuildContext context, BoxConstraints constraints) {
                    final Widget search = TextField(
                      controller: _search,
                      decoration: InputDecoration(
                        labelText: l10n.customerManagementSearch,
                        prefixIcon: const Icon(Icons.search),
                        suffixIcon: _search.text.isEmpty
                            ? null
                            : IconButton(
                                tooltip: l10n.customerManagementClearFilters,
                                onPressed: () {
                                  _search.clear();
                                  cubit.searchChanged('');
                                  setState(() {});
                                },
                                icon: const Icon(Icons.clear),
                              ),
                      ),
                      onChanged: (String value) {
                        setState(() {});
                        cubit.searchChanged(value);
                      },
                      onSubmitted: cubit.submitSearch,
                    );
                    final Widget status = _GroupLifecycleSegments(
                      selected: state.query.status,
                      onChanged: cubit.setStatus,
                    );
                    return constraints.maxWidth < 640
                        ? Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: <Widget>[
                              search,
                              const SizedBox(height: 12),
                              status,
                            ],
                          )
                        : Row(
                            // `start` follows Directionality: left in LTR and
                            // right in RTL. These filters belong at the
                            // logical start of the desktop row.
                            mainAxisAlignment: MainAxisAlignment.start,
                            children: <Widget>[
                              SizedBox(width: 300, child: search),
                              const SizedBox(width: 12),
                              status,
                            ],
                          );
                  },
                ),
                const SizedBox(height: 16),
                if (state.page != null)
                  Align(
                    alignment: AlignmentDirectional.centerStart,
                    child: Text(
                      l10n.cmvpGroupsCount(state.page!.meta.total),
                      key: const Key('customer-management-result-count'),
                    ),
                  ),
                if (state.page != null) const SizedBox(height: 8),
                Expanded(child: _body(context, state)),
              ],
            ),
          );
        },
      );

  Widget _body(BuildContext context, CustomerGroupListState state) {
    final CustomerGroupListCubit cubit = context.read<CustomerGroupListCubit>();
    final AppLocalizations l10n = AppLocalizations.of(context);
    if (state.status == CustomerGroupListStatus.initial ||
        (state.status == CustomerGroupListStatus.loading &&
            state.page == null)) {
      return const CustomerManagementStatePanel(
        loadingGeometry: CustomerManagementLoadingGeometry.collection,
      );
    }
    if (state.status == CustomerGroupListStatus.failure) {
      return CustomerManagementStatePanel(
        failure: state.failure,
        onRetry: cubit.refresh,
      );
    }
    final items = state.page?.items ?? const [];
    if (items.isEmpty) {
      return CustomerManagementStatePanel(
        empty: !state.hasCriteria,
        noResults: state.hasCriteria,
        emptyMessage: l10n.customerManagementEmptyGroups,
        onClear: state.hasCriteria ? cubit.clearFilters : null,
        onCreate: !state.hasCriteria
            ? () => context.push(CustomerManagementRouteLocations.groupCreate)
            : null,
        onCreateLabel: l10n.customerManagementCreateGroup,
      );
    }
    final Widget content = Align(
      alignment: AlignmentDirectional.topCenter,
      child: CustomerGroupTable(
        groups: items,
        repository: widget.repository,
        scrollController: _collectionScroll,
        meta: state.page!.meta,
        onPageChanged: cubit.setPage,
        onLifecycleRefresh: cubit.refresh,
        onView: (group) =>
            context.go(CustomerManagementRouteLocations.group(group.id)),
        onEdit: (group) =>
            context.go(CustomerManagementRouteLocations.editGroup(group.id)),
      ),
    );
    return state.status == CustomerGroupListStatus.loading
        ? Stack(
            children: <Widget>[
              content,
              Semantics(
                label: AppLocalizations.of(context).cmvpLoadingGroups,
                liveRegion: true,
                child: const LinearProgressIndicator(),
              ),
            ],
          )
        : content;
  }
}

class _GroupLifecycleSegments extends StatelessWidget {
  const _GroupLifecycleSegments({
    required this.selected,
    required this.onChanged,
  });

  final CustomerStatusFilter? selected;
  final ValueChanged<CustomerStatusFilter?> onChanged;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    return Semantics(
      label: l10n.customerManagementStatus,
      child: Container(
        key: const Key('customer-group-lifecycle-filter'),
        height: 54,
        padding: const EdgeInsets.all(3),
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border.all(color: const Color(0xFFE4DDD5)),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            _GroupLifecycleSegment(
              key: const Key('customer-group-status-all'),
              label: l10n.customerManagementAll,
              selected: selected == null,
              onPressed: () => onChanged(null),
            ),
            _GroupLifecycleSegment(
              key: const Key('customer-group-status-active'),
              label: l10n.customerManagementActive,
              selected: selected == CustomerStatusFilter.active,
              onPressed: () => onChanged(CustomerStatusFilter.active),
            ),
            _GroupLifecycleSegment(
              key: const Key('customer-group-status-archived'),
              label: l10n.customerManagementArchived,
              selected: selected == CustomerStatusFilter.archived,
              onPressed: () => onChanged(CustomerStatusFilter.archived),
            ),
          ],
        ),
      ),
    );
  }
}

class _GroupLifecycleSegment extends StatelessWidget {
  const _GroupLifecycleSegment({
    super.key,
    required this.label,
    required this.selected,
    required this.onPressed,
  });

  final String label;
  final bool selected;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) => TextButton(
    onPressed: selected ? null : onPressed,
    style: TextButton.styleFrom(
      minimumSize: const Size(0, 48),
      padding: const EdgeInsets.symmetric(horizontal: 13),
      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      backgroundColor: selected ? const Color(0xFF3B2417) : Colors.transparent,
      foregroundColor: selected ? Colors.white : const Color(0xFF50443F),
      disabledForegroundColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
      textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
    ),
    child: Text(label),
  );
}

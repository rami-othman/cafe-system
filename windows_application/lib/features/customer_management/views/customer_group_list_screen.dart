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
import '../widgets/customer_management_surface.dart';
import '../widgets/customer_pagination.dart';

class CustomerGroupListScreen extends StatefulWidget {
  const CustomerGroupListScreen({super.key, required this.repository});
  final CustomerManagementRepository repository;

  @override
  State<CustomerGroupListScreen> createState() =>
      _CustomerGroupListScreenState();
}

class _CustomerGroupListScreenState extends State<CustomerGroupListScreen> {
  final TextEditingController _search = TextEditingController();

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
    super.dispose();
  }

  @override
  Widget build(
    BuildContext context,
  ) => BlocBuilder<CustomerGroupListCubit, CustomerGroupListState>(
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
              primaryAction: FilledButton.icon(
                key: const Key('customer-group-create'),
                onPressed: () =>
                    context.go(CustomerManagementRouteLocations.groupCreate),
                icon: const Icon(Icons.group_add_outlined),
                label: Text(l10n.customerManagementCreateGroup),
              ),
            ),
            const SizedBox(height: 20),
            CustomerManagementSurface(
              body: LayoutBuilder(
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
                  final Widget status =
                      DropdownButtonFormField<CustomerStatusFilter?>(
                        initialValue: state.query.status,
                        decoration: InputDecoration(
                          labelText: l10n.customerManagementStatus,
                        ),
                        items: <DropdownMenuItem<CustomerStatusFilter?>>[
                          DropdownMenuItem(
                            value: null,
                            child: Text(l10n.customerManagementAll),
                          ),
                          DropdownMenuItem(
                            value: CustomerStatusFilter.active,
                            child: Text(l10n.customerManagementActive),
                          ),
                          DropdownMenuItem(
                            value: CustomerStatusFilter.archived,
                            child: Text(l10n.customerManagementArchived),
                          ),
                        ],
                        onChanged: cubit.setStatus,
                      );
                  return constraints.maxWidth < 640
                      ? Column(
                          children: <Widget>[
                            search,
                            const SizedBox(height: 12),
                            status,
                          ],
                        )
                      : Row(
                          children: <Widget>[
                            Expanded(child: search),
                            const SizedBox(width: 12),
                            SizedBox(width: 190, child: status),
                          ],
                        );
                },
              ),
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
            ? () => context.go(CustomerManagementRouteLocations.groupCreate)
            : null,
        onCreateLabel: l10n.customerManagementCreateGroup,
      );
    }
    final Widget content = Column(
      children: <Widget>[
        Expanded(
          child: CustomerGroupTable(
            groups: items,
            repository: widget.repository,
            onLifecycleRefresh: cubit.refresh,
            onView: (group) =>
                context.go(CustomerManagementRouteLocations.group(group.id)),
            onEdit: (group) => context.go(
              CustomerManagementRouteLocations.editGroup(group.id),
            ),
          ),
        ),
        CustomerPagination(
          meta: state.page!.meta,
          onPageChanged: cubit.setPage,
        ),
      ],
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

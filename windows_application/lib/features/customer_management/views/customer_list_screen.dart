import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../app/customer_management_route_locations.dart';
import '../../../l10n/app_localizations.dart';
import '../controllers/customer_list_cubit.dart';
import '../controllers/customer_list_state.dart';
import '../models/customer_queries.dart';
import '../repositories/customer_management_repository.dart';
import '../widgets/customer_collection.dart';
import '../widgets/customer_management_page_header.dart';
import '../widgets/customer_management_state_panel.dart';
import '../widgets/customer_management_surface.dart';
import '../widgets/customer_pagination.dart';

class CustomerListScreen extends StatefulWidget {
  const CustomerListScreen({super.key, this.lifecycleRepository});
  final CustomerManagementRepository? lifecycleRepository;
  @override
  State<CustomerListScreen> createState() => _CustomerListScreenState();
}

class _CustomerListScreenState extends State<CustomerListScreen> {
  final TextEditingController _search = TextEditingController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<CustomerListCubit>().load();
      context.read<CustomerListCubit>().loadGroupOptions();
    });
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    return BlocBuilder<CustomerListCubit, CustomerListState>(
      builder: (BuildContext context, CustomerListState state) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            CustomerManagementPageHeader(
              title: l10n.customerManagementCustomers,
              description: l10n.cmvpCustomersDescription,
              breadcrumbs: <String>[l10n.cmvpBreadcrumbCustomers],
              primaryAction: FilledButton.icon(
                key: const Key('customer-create'),
                onPressed: () =>
                    context.go(CustomerManagementRouteLocations.customerCreate),
                icon: const Icon(Icons.person_add_outlined),
                label: Text(l10n.customerManagementCreateCustomer),
              ),
            ),
            const SizedBox(height: 20),
            CustomerManagementSurface(
              body: LayoutBuilder(
                builder: (BuildContext context, BoxConstraints constraints) {
                  final Widget search = TextField(
                    controller: _search,
                    decoration: InputDecoration(
                      prefixIcon: const Icon(Icons.search),
                      labelText: l10n.customerManagementSearch,
                      suffixIcon: _search.text.isEmpty
                          ? null
                          : IconButton(
                              tooltip: l10n.customerManagementClearFilters,
                              icon: const Icon(Icons.clear),
                              onPressed: () {
                                _search.clear();
                                context.read<CustomerListCubit>().searchChanged(
                                  '',
                                );
                              },
                            ),
                    ),
                    onChanged: (String value) {
                      setState(() {});
                      context.read<CustomerListCubit>().searchChanged(value);
                    },
                    onSubmitted: context.read<CustomerListCubit>().submitSearch,
                  );
                  final Widget filter =
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
                          ...CustomerStatusFilter.values
                              .where(
                                (CustomerStatusFilter value) =>
                                    value != CustomerStatusFilter.all,
                              )
                              .map(
                                (CustomerStatusFilter value) =>
                                    DropdownMenuItem(
                                      value: value,
                                      child: Text(_status(l10n, value)),
                                    ),
                              ),
                        ],
                        onChanged: context.read<CustomerListCubit>().setStatus,
                      );
                  final Widget groupFilter = DropdownButtonFormField<int?>(
                    initialValue: state.query.groupId,
                    isExpanded: true,
                    decoration: InputDecoration(
                      labelText: l10n.customerManagementGroupsLabel,
                    ),
                    items: <DropdownMenuItem<int?>>[
                      DropdownMenuItem(
                        value: null,
                        child: Text(l10n.customerManagementAll),
                      ),
                      ...state.groupOptions.map(
                        (group) => DropdownMenuItem<int?>(
                          value: group.id,
                          child: Text(
                            group.name,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ),
                    ],
                    onChanged: context.read<CustomerListCubit>().setGroup,
                  );
                  return constraints.maxWidth < 640
                      ? Column(
                          children: <Widget>[
                            search,
                            const SizedBox(height: 12),
                            filter,
                            const SizedBox(height: 12),
                            groupFilter,
                          ],
                        )
                      : Wrap(
                          spacing: 12,
                          runSpacing: 12,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: <Widget>[
                            SizedBox(
                              width: constraints.maxWidth - 404,
                              child: search,
                            ),
                            SizedBox(width: 190, child: filter),
                            SizedBox(width: 190, child: groupFilter),
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
                  l10n.cmvpCustomersCount(state.page!.meta.total),
                  key: const Key('customer-management-result-count'),
                ),
              ),
            if (state.page != null) const SizedBox(height: 8),
            Expanded(child: _body(context, state)),
          ],
        ),
      ),
    );
  }

  Widget _body(BuildContext context, CustomerListState state) {
    if (state.status == CustomerListStatus.initial ||
        (state.status == CustomerListStatus.loading && state.page == null)) {
      return const CustomerManagementStatePanel(
        loadingGeometry: CustomerManagementLoadingGeometry.collection,
      );
    }
    if (state.status == CustomerListStatus.failure) {
      return CustomerManagementStatePanel(
        failure: state.failure,
        onRetry: context.read<CustomerListCubit>().refresh,
      );
    }
    final items = state.page?.items ?? const [];
    if (items.isEmpty) {
      return CustomerManagementStatePanel(
        empty: !state.hasCriteria,
        noResults: state.hasCriteria,
        onClear: state.hasCriteria
            ? () {
                _search.clear();
                context.read<CustomerListCubit>().clearFilters();
              }
            : null,
        onCreate: !state.hasCriteria
            ? () => context.go(CustomerManagementRouteLocations.customerCreate)
            : null,
        onCreateLabel: AppLocalizations.of(
          context,
        ).customerManagementCreateCustomer,
      );
    }
    final Widget content = Column(
      children: <Widget>[
        Expanded(
          child: CustomerCollection(
            customers: items,
            onSelected: (customer) => context.go(
              CustomerManagementRouteLocations.customer(customer.id),
            ),
            onEdit: (customer) => context.go(
              CustomerManagementRouteLocations.editCustomer(customer.id),
            ),
            lifecycleRepository: widget.lifecycleRepository,
            onLifecycleRefresh: context.read<CustomerListCubit>().refresh,
          ),
        ),
        CustomerPagination(
          meta: state.page!.meta,
          onPageChanged: context.read<CustomerListCubit>().setPage,
        ),
      ],
    );
    return state.status == CustomerListStatus.loading
        ? Stack(
            children: <Widget>[
              content,
              Semantics(
                label: AppLocalizations.of(context).cmvpLoadingCustomers,
                liveRegion: true,
                child: const LinearProgressIndicator(),
              ),
            ],
          )
        : content;
  }
}

String _status(AppLocalizations l10n, CustomerStatusFilter status) =>
    switch (status) {
      CustomerStatusFilter.active => l10n.customerManagementActive,
      CustomerStatusFilter.inactive => l10n.customerManagementInactive,
      CustomerStatusFilter.archived => l10n.customerManagementArchived,
      CustomerStatusFilter.all => l10n.customerManagementAll,
    };

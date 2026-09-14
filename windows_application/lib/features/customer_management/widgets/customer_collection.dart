import 'package:flutter/material.dart';

import '../../../l10n/app_localizations.dart';
import '../models/customer_models.dart';
import '../repositories/customer_management_repository.dart';
import 'customer_bidi_value.dart';
import 'customer_lifecycle_actions.dart';
import 'customer_lifecycle_badge.dart';
import 'customer_management_overflow_menu.dart';
import 'customer_management_surface.dart';
import 'customer_management_visual_tokens.dart';
import 'customer_pagination.dart';

class CustomerCollection extends StatelessWidget {
  const CustomerCollection({
    super.key,
    required this.customers,
    required this.onSelected,
    this.onEdit,
    this.onOrders,
    this.lifecycleRepository,
    this.onLifecycleRefresh,
    this.paginationMeta,
    this.onPageChanged,
  });

  final List<Customer> customers;
  final ValueChanged<Customer> onSelected;
  final ValueChanged<Customer>? onEdit;
  final ValueChanged<Customer>? onOrders;
  final CustomerManagementRepository? lifecycleRepository;
  final Future<void> Function()? onLifecycleRefresh;
  final CustomerPageMeta? paginationMeta;
  final ValueChanged<int>? onPageChanged;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (BuildContext context, BoxConstraints constraints) {
      final bool useCards = CustomerManagementVisualTokens.usesCollectionCards(
        constraints.maxWidth,
      );
      final Widget content = useCards
          ? ListView.separated(
              itemCount: customers.length,
              padding: const EdgeInsets.all(16),
              separatorBuilder: (_, _) => const SizedBox(height: 8),
              itemBuilder: (_, int index) => _CustomerCard(
                customer: customers[index],
                onSelected: onSelected,
                onEdit: onEdit,
                onOrders: onOrders,
                lifecycleRepository: lifecycleRepository,
                onLifecycleRefresh: onLifecycleRefresh,
              ),
            )
          : SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: ConstrainedBox(
                constraints: BoxConstraints(minWidth: constraints.maxWidth),
                child: DataTable(
                  showCheckboxColumn: false,
                  headingRowHeight: 42,
                  dataRowMinHeight: 60,
                  dataRowMaxHeight: 60,
                  horizontalMargin: 20,
                  columnSpacing: 20,
                  dividerThickness: 1,
                  headingTextStyle: CustomerManagementVisualTokens.tableHeading,
                  dataTextStyle: CustomerManagementVisualTokens.tableCell,
                  headingRowColor: WidgetStatePropertyAll<Color>(
                    CustomerManagementVisualTokens.warmHeader,
                  ),
                  columns: <DataColumn>[
                    DataColumn(
                      label: Text(
                        AppLocalizations.of(
                          context,
                        ).customerManagementCustomerNumber,
                      ),
                    ),
                    DataColumn(
                      label: Text(
                        AppLocalizations.of(context).customerManagementName,
                      ),
                    ),
                    DataColumn(
                      label: Text(
                        AppLocalizations.of(context).customerManagementPhone,
                      ),
                    ),
                    DataColumn(
                      label: Text(
                        AppLocalizations.of(
                          context,
                        ).customerManagementGroupsLabel,
                      ),
                    ),
                    DataColumn(
                      label: Text(
                        AppLocalizations.of(context).customerManagementStatus,
                      ),
                    ),
                    DataColumn(
                      label: Text(AppLocalizations.of(context).cmvpMoreActions),
                    ),
                  ],
                  rows: customers
                      .map(
                        (Customer customer) => DataRow(
                          onSelectChanged: (_) => onSelected(customer),
                          cells: <DataCell>[
                            DataCell(
                              CustomerBidiValue(value: customer.customerNumber),
                            ),
                            DataCell(
                              ConstrainedBox(
                                constraints: const BoxConstraints(
                                  maxWidth: 190,
                                ),
                                child: Text(
                                  customer.name,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                    color: Color(0xFF231005),
                                    fontFamilyFallback:
                                        CustomerManagementVisualTokens
                                            .fontFamilyFallback,
                                  ),
                                ),
                              ),
                            ),
                            DataCell(
                              CustomerBidiValue(
                                value: _primaryPhone(context, customer),
                              ),
                            ),
                            DataCell(_GroupSummary(customer: customer)),
                            DataCell(
                              CustomerLifecycleBadge(
                                lifecycle: customer.lifecycle,
                              ),
                            ),
                            DataCell(_rowActions(context, customer)),
                          ],
                        ),
                      )
                      .toList(growable: false),
                ),
              ),
            );
      final Widget? footer = paginationMeta == null || onPageChanged == null
          ? null
          : CustomerPagination(
              meta: paginationMeta!,
              onPageChanged: onPageChanged!,
            );
      return CustomerManagementSurface(
        expandBody: constraints.hasBoundedHeight,
        body: content,
        footer: footer,
      );
    },
  );

  Widget _rowActions(BuildContext context, Customer customer) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final List<CustomerManagementMenuEntry> commonActions =
        <CustomerManagementMenuEntry>[
          CustomerManagementMenuEntry(
            label: l10n.customerManagementView,
            icon: Icons.visibility_outlined,
            onPressed: () => onSelected(customer),
          ),
          if (customer.allowedActions.contains('update') && onEdit != null)
            CustomerManagementMenuEntry(
              label: l10n.customerManagementEdit,
              icon: Icons.edit_outlined,
              onPressed: () => onEdit!(customer),
            ),
          if (onOrders != null)
            CustomerManagementMenuEntry(
              label: l10n.cmvpOrders,
              icon: Icons.receipt_long_outlined,
              onPressed: () => onOrders!(customer),
            ),
        ];
    if (lifecycleRepository != null) {
      return CustomerLifecycleActions(
        repository: lifecycleRepository!,
        customer: customer,
        showBadge: false,
        compact: true,
        compactActions: commonActions,
        onCollectionsRefresh: onLifecycleRefresh,
      );
    }
    return CustomerManagementOverflowMenu(
      actions: commonActions,
      tooltip: customer.allowedActions.contains('update')
          ? l10n.customerManagementEdit
          : l10n.cmvpOpenActions,
      semanticLabel: l10n.cmvpOpenActions,
    );
  }
}

class _CustomerCard extends StatelessWidget {
  const _CustomerCard({
    required this.customer,
    required this.onSelected,
    this.onEdit,
    this.onOrders,
    this.lifecycleRepository,
    this.onLifecycleRefresh,
  });

  final Customer customer;
  final ValueChanged<Customer> onSelected;
  final ValueChanged<Customer>? onEdit;
  final ValueChanged<Customer>? onOrders;
  final CustomerManagementRepository? lifecycleRepository;
  final Future<void> Function()? onLifecycleRefresh;

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    label: '${customer.customerNumber} ${customer.name}',
    child: Card(
      color: CustomerManagementVisualTokens.surface,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: const BorderSide(color: CustomerManagementVisualTokens.border),
      ),
      child: ListTile(
        onTap: () => onSelected(customer),
        contentPadding: const EdgeInsetsDirectional.fromSTEB(16, 8, 8, 8),
        title: Text(
          customer.name,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            fontFamilyFallback:
                CustomerManagementVisualTokens.fontFamilyFallback,
          ),
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              CustomerBidiValue(value: customer.customerNumber),
              CustomerBidiValue(value: _primaryPhone(context, customer)),
              _GroupSummary(customer: customer),
            ],
          ),
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            CustomerLifecycleBadge(lifecycle: customer.lifecycle),
            const SizedBox(width: 4),
            _actionsForCard(context),
          ],
        ),
      ),
    ),
  );

  Widget _actionsForCard(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final List<CustomerManagementMenuEntry> actions =
        <CustomerManagementMenuEntry>[
          CustomerManagementMenuEntry(
            label: l10n.customerManagementView,
            icon: Icons.visibility_outlined,
            onPressed: () => onSelected(customer),
          ),
          if (customer.allowedActions.contains('update') && onEdit != null)
            CustomerManagementMenuEntry(
              label: l10n.customerManagementEdit,
              icon: Icons.edit_outlined,
              onPressed: () => onEdit!(customer),
            ),
          if (onOrders != null)
            CustomerManagementMenuEntry(
              label: l10n.cmvpOrders,
              icon: Icons.receipt_long_outlined,
              onPressed: () => onOrders!(customer),
            ),
        ];
    if (lifecycleRepository != null) {
      return CustomerLifecycleActions(
        repository: lifecycleRepository!,
        customer: customer,
        showBadge: false,
        compact: true,
        compactActions: actions,
        onCollectionsRefresh: onLifecycleRefresh,
      );
    }
    return CustomerManagementOverflowMenu(
      actions: actions,
      tooltip: customer.allowedActions.contains('update')
          ? l10n.customerManagementEdit
          : l10n.cmvpOpenActions,
      semanticLabel: l10n.cmvpOpenActions,
    );
  }
}

class _GroupSummary extends StatelessWidget {
  const _GroupSummary({required this.customer});

  final Customer customer;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    if (customer.groups.isEmpty) {
      return Text(
        l10n.customerManagementNotAvailable,
        style: CustomerManagementVisualTokens.tableCell.copyWith(
          color: CustomerManagementVisualTokens.mutedText,
        ),
      );
    }
    final int extraCount = customer.groups.length - 1;
    return Wrap(
      spacing: 6,
      runSpacing: 4,
      children: <Widget>[
        _GroupChip(label: customer.groups.first.name),
        if (extraCount > 0) _GroupChip(label: '+$extraCount', muted: true),
      ],
    );
  }
}

class _GroupChip extends StatelessWidget {
  const _GroupChip({required this.label, this.muted = false});

  final String label;
  final bool muted;

  @override
  Widget build(BuildContext context) => Tooltip(
    message: label,
    child: Container(
      constraints: const BoxConstraints(maxWidth: 150),
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: muted
            ? CustomerManagementVisualTokens.inactiveBadgeBackground
            : const Color(0xFFF4E7D3),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          color: muted
              ? CustomerManagementVisualTokens.rowText
              : const Color(0xFF805437),
          fontSize: 11,
          height: 1.2,
          fontWeight: FontWeight.w700,
          fontFamilyFallback: CustomerManagementVisualTokens.fontFamilyFallback,
        ),
      ),
    ),
  );
}

String _primaryPhone(BuildContext context, Customer customer) {
  final Iterable<CustomerPhone> primary = customer.phones.where(
    (CustomerPhone phone) => phone.isPrimary,
  );
  return primary.isEmpty
      ? AppLocalizations.of(context).customerManagementNoPhone
      : primary.first.rawNumber;
}

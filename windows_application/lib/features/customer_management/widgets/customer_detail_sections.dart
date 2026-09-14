import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../l10n/app_localizations.dart';
import '../models/customer_models.dart';
import 'customer_bidi_value.dart';
import 'customer_lifecycle_badge.dart';
import 'customer_management_surface.dart';
import 'customer_management_visual_tokens.dart';

String customerOverviewLabel(BuildContext context) =>
    _detailText(context, _DetailText.overview);

enum CustomerDetailTab { overview, orders }

/// The customer identity, tab switcher, and actions are intentionally shared by
/// the overview and order-history routes so moving between them does not make
/// the customer context visually jump.
class CustomerDetailHeader extends StatelessWidget {
  const CustomerDetailHeader({
    super.key,
    required this.customer,
    required this.selectedTab,
    required this.onOverviewPressed,
    required this.onOrdersPressed,
    this.actions,
  });

  final Customer customer;
  final CustomerDetailTab selectedTab;
  final VoidCallback onOverviewPressed;
  final VoidCallback onOrdersPressed;
  final Widget? actions;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l = AppLocalizations.of(context);
    final Widget identity = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        _CustomerDetailTabs(
          selectedTab: selectedTab,
          onOverviewPressed: onOverviewPressed,
          onOrdersPressed: onOrdersPressed,
        ),
        const SizedBox(height: 18),
        Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: <Widget>[
            Flexible(
              child: Text(
                customer.name,
                key: const ValueKey<String>('customer-management-page-title'),
                overflow: TextOverflow.ellipsis,
                style: CustomerManagementVisualTokens.pageTitle,
              ),
            ),
            const SizedBox(width: 8),
            CustomerLifecycleBadge(lifecycle: customer.lifecycle),
          ],
        ),
        const SizedBox(height: 4),
        CustomerBidiValue(value: customer.customerNumber),
      ],
    );
    return Semantics(
      key: const Key('customer-detail-header'),
      container: true,
      header: true,
      label: customer.name,
      child: Padding(
        padding: const EdgeInsetsDirectional.only(bottom: 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Wrap(
              spacing: 6,
              runSpacing: 4,
              children: <Widget>[
                Text(
                  l.cmvpBreadcrumbCustomers,
                  style: CustomerManagementVisualTokens.pageDescription,
                ),
                Text(
                  l.cmvpBreadcrumbDetails,
                  style: CustomerManagementVisualTokens.pageDescription,
                ),
                Text(
                  customer.name,
                  style: CustomerManagementVisualTokens.pageDescription,
                ),
              ],
            ),
            const SizedBox(height: 16),
            LayoutBuilder(
              builder: (BuildContext context, BoxConstraints constraints) {
                if (actions == null || constraints.maxWidth < 640) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: <Widget>[
                      identity,
                      if (actions != null) ...<Widget>[
                        const SizedBox(height: 16),
                        Align(
                          alignment: AlignmentDirectional.topEnd,
                          child: actions,
                        ),
                      ],
                    ],
                  );
                }
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  textDirection: Directionality.of(context),
                  children: <Widget>[
                    Expanded(child: identity),
                    const SizedBox(width: 24),
                    Flexible(
                      child: Align(
                        alignment: AlignmentDirectional.topEnd,
                        child: actions,
                      ),
                    ),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _CustomerDetailTabs extends StatelessWidget {
  const _CustomerDetailTabs({
    required this.selectedTab,
    required this.onOverviewPressed,
    required this.onOrdersPressed,
  });

  final CustomerDetailTab selectedTab;
  final VoidCallback onOverviewPressed;
  final VoidCallback onOrdersPressed;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l = AppLocalizations.of(context);
    return Semantics(
      container: true,
      label: l.cmvpBreadcrumbDetails,
      child: Container(
        key: const Key('customer-detail-tabs'),
        height: CustomerManagementVisualTokens.minimumInteractiveSize,
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: CustomerManagementVisualTokens.surface,
          border: Border.fromBorderSide(
            CustomerManagementVisualTokens.surfaceBorder,
          ),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Wrap(
          children: <Widget>[
            _CustomerDetailTab(
              key: const Key('customer-detail-overview-tab'),
              label: customerOverviewLabel(context),
              selected: selectedTab == CustomerDetailTab.overview,
              onPressed: onOverviewPressed,
            ),
            _CustomerDetailTab(
              key: const Key('customer-detail-orders-tab'),
              label: l.cmvpOrders,
              selected: selectedTab == CustomerDetailTab.orders,
              onPressed: onOrdersPressed,
            ),
          ],
        ),
      ),
    );
  }
}

class _CustomerDetailTab extends StatelessWidget {
  const _CustomerDetailTab({
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
      minimumSize: const Size(88, 40),
      foregroundColor: CustomerManagementVisualTokens.rowText,
      disabledForegroundColor: CustomerManagementVisualTokens.rowText,
      backgroundColor: selected ? const Color(0xFFFEC29E) : Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
    ),
    child: Text(label),
  );
}

class CustomerDetailSections extends StatelessWidget {
  const CustomerDetailSections({
    super.key,
    required this.customer,
    this.overview,
    required this.onViewAllOrders,
  });
  final Customer customer;
  final CustomerOverview? overview;
  final VoidCallback onViewAllOrders;

  @override
  Widget build(BuildContext context) {
    final CustomerOrderSummary summary =
        overview?.summary ?? const CustomerOrderSummary(totalOrders: 0);
    final List<CustomerOrder> orders =
        overview?.recentOrders ?? const <CustomerOrder>[];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        _SummaryCards(summary: summary),
        const SizedBox(height: 16),
        _ProfileCards(customer: customer),
        const SizedBox(height: 16),
        _RecentOrders(orders: orders, onViewAllOrders: onViewAllOrders),
      ],
    );
  }
}

/// Reference detail panels use a white title strip. Keeping that treatment
/// local avoids changing the warm collection headers used elsewhere.
class _DetailSurface extends StatelessWidget {
  const _DetailSurface({super.key, required this.header, required this.body});

  final Widget header;
  final Widget body;

  @override
  Widget build(BuildContext context) => CustomerManagementSurface(
    body: Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Padding(
          padding: CustomerManagementVisualTokens.surfacePadding,
          child: DefaultTextStyle.merge(
            style: const TextStyle(fontWeight: FontWeight.w700),
            child: header,
          ),
        ),
        const Divider(height: 1, color: CustomerManagementVisualTokens.border),
        body,
      ],
    ),
  );
}

class _SummaryCards extends StatelessWidget {
  const _SummaryCards({required this.summary});
  final CustomerOrderSummary summary;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final List<_SummaryCard> cards = <_SummaryCard>[
      _SummaryCard(
        key: const Key('customer-detail-total-orders'),
        label: _detailText(context, _DetailText.totalOrders),
        value: CustomerBidiValue(
          value: summary.totalOrders.toString(),
          isolate: true,
        ),
      ),
      _SummaryCard(
        key: const Key('customer-detail-total-spending'),
        label: _detailText(context, _DetailText.totalSpending),
        value: _MoneyValue(
          money: summary.totalSpending,
          absent: l.cmvpAbsenceValue,
        ),
      ),
      _SummaryCard(
        key: const Key('customer-detail-average-order'),
        label: _detailText(context, _DetailText.averageOrderValue),
        value: _MoneyValue(
          money: summary.averageOrderValue,
          absent: l.cmvpAbsenceValue,
        ),
      ),
      _SummaryCard(
        key: const Key('customer-detail-last-visit'),
        label: _detailText(context, _DetailText.lastVisit),
        value: CustomerBidiValue(
          value: summary.lastOrderAt == null
              ? l.cmvpAbsenceValue
              : DateFormat('dd/MM/yyyy', 'en_US').format(summary.lastOrderAt!),
          isolate: summary.lastOrderAt != null,
        ),
      ),
    ];
    return LayoutBuilder(
      builder: (context, constraints) {
        final int columns = constraints.maxWidth >= 1120
            ? 4
            : constraints.maxWidth >=
                  CustomerManagementVisualTokens.collectionBreakpoint
            ? 2
            : 1;
        final double width =
            (constraints.maxWidth - 16 * (columns - 1)) / columns;
        return Wrap(
          spacing: 16,
          runSpacing: 16,
          children: cards
              .map((card) => SizedBox(width: width, child: card))
              .toList(growable: false),
        );
      },
    );
  }
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({super.key, required this.label, required this.value});
  final String label;
  final Widget value;
  @override
  Widget build(BuildContext context) => Semantics(
    container: true,
    label: label,
    child: Container(
      constraints: const BoxConstraints(minHeight: 84),
      padding: const EdgeInsetsDirectional.fromSTEB(18, 14, 18, 14),
      decoration: BoxDecoration(
        color: CustomerManagementVisualTokens.surface,
        border: Border.fromBorderSide(
          CustomerManagementVisualTokens.surfaceBorder,
        ),
        borderRadius: CustomerManagementVisualTokens.surfaceRadius,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: <Widget>[
          Text(label, style: CustomerManagementVisualTokens.pageDescription),
          const SizedBox(height: 12),
          DefaultTextStyle.merge(
            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 18),
            child: value,
          ),
        ],
      ),
    ),
  );
}

class _ProfileCards extends StatelessWidget {
  const _ProfileCards({required this.customer});
  final Customer customer;
  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final Widget information = _InformationCard(customer: customer);
      final Widget groups = _GroupsCard(customer: customer);
      final Widget phonesAndNotes = Column(
        children: <Widget>[
          _PhonesCard(customer: customer),
          const SizedBox(height: 16),
          _NotesCard(customer: customer),
        ],
      );
      if (constraints.maxWidth <
          CustomerManagementVisualTokens.collectionBreakpoint) {
        return Column(
          children: <Widget>[
            information,
            const SizedBox(height: 16),
            groups,
            const SizedBox(height: 16),
            phonesAndNotes,
          ],
        );
      }
      return Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Expanded(
            flex: 7,
            child: Column(
              children: <Widget>[
                information,
                const SizedBox(height: 16),
                phonesAndNotes,
              ],
            ),
          ),
          const SizedBox(width: 16),
          Expanded(flex: 5, child: groups),
        ],
      );
    },
  );
}

class _InformationCard extends StatelessWidget {
  const _InformationCard({required this.customer});
  final Customer customer;
  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final unavailable = l.cmvpAbsenceValue;
    return _DetailSurface(
      key: const Key('customer-detail-information'),
      header: Text(l.cmvpInformationSection),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final double width = (constraints.maxWidth - 16) / 2;
            return Wrap(
              spacing: 16,
              runSpacing: 16,
              children: <Widget>[
                SizedBox(
                  width: width,
                  child: _Field(
                    l.customerManagementCustomerNumber,
                    CustomerBidiValue(
                      key: const Key('customer-detail-raw-number'),
                      value: customer.customerNumber,
                      isolate: true,
                    ),
                  ),
                ),
                SizedBox(
                  width: width,
                  child: _Field(l.customerManagementName, Text(customer.name)),
                ),
                SizedBox(
                  width: width,
                  child: _Field(
                    l.customerManagementEmail,
                    CustomerBidiValue(
                      value: customer.email ?? unavailable,
                      isolate: customer.email != null,
                    ),
                  ),
                ),
                SizedBox(
                  width: width,
                  child: _Field(
                    l.customerManagementBirthDate,
                    CustomerBidiValue(
                      value: customer.birthDate == null
                          ? unavailable
                          : DateFormat(
                              'dd/MM/yyyy',
                              'en_US',
                            ).format(customer.birthDate!),
                      isolate: customer.birthDate != null,
                    ),
                  ),
                ),
                SizedBox(
                  width: width,
                  child: _Field(
                    l.customerManagementStatus,
                    CustomerLifecycleBadge(lifecycle: customer.lifecycle),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _GroupsCard extends StatelessWidget {
  const _GroupsCard({required this.customer});
  final Customer customer;
  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return _DetailSurface(
      key: const Key('customer-detail-groups'),
      header: Text(l.cmvpGroupsSection),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: customer.groups.isEmpty
            ? Text(l.cmvpAbsenceValue)
            : Wrap(
                spacing: 8,
                runSpacing: 8,
                children: customer.groups
                    .map((group) => _GroupChip(group: group))
                    .toList(growable: false),
              ),
      ),
    );
  }
}

class _GroupChip extends StatelessWidget {
  const _GroupChip({required this.group});
  final CustomerGroupSummary group;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsetsDirectional.symmetric(horizontal: 10, vertical: 6),
    decoration: BoxDecoration(
      color: CustomerManagementVisualTokens.warmHeader,
      borderRadius: BorderRadius.circular(14),
    ),
    child: Text(
      group.name,
      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
    ),
  );
}

class _PhonesCard extends StatelessWidget {
  const _PhonesCard({required this.customer});
  final Customer customer;
  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return _DetailSurface(
      key: const Key('customer-detail-phones'),
      header: Text(l.cmvpPhoneSection),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: customer.phones.isEmpty
            ? Text(l.customerManagementNoPhone)
            : Column(
                children: customer.phones
                    .map(
                      (phone) => Padding(
                        padding: const EdgeInsetsDirectional.only(bottom: 12),
                        child: Row(
                          children: <Widget>[
                            const Icon(Icons.phone_outlined, size: 18),
                            const SizedBox(width: 8),
                            Expanded(
                              child: CustomerBidiValue(
                                value: phone.rawNumber,
                                isolate: true,
                              ),
                            ),
                            Text(
                              _phoneTypeLabel(l, phone.type),
                              style: CustomerManagementVisualTokens
                                  .pageDescription,
                            ),
                            if (phone.isPrimary) ...<Widget>[
                              const SizedBox(width: 8),
                              _PrimaryBadge(label: l.customerManagementPrimary),
                            ],
                          ],
                        ),
                      ),
                    )
                    .toList(growable: false),
              ),
      ),
    );
  }
}

class _PrimaryBadge extends StatelessWidget {
  const _PrimaryBadge({required this.label});
  final String label;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsetsDirectional.symmetric(horizontal: 8, vertical: 4),
    decoration: BoxDecoration(
      color: CustomerManagementVisualTokens.warmHeader,
      borderRadius: BorderRadius.circular(12),
    ),
    child: Text(
      label,
      style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700),
    ),
  );
}

class _NotesCard extends StatelessWidget {
  const _NotesCard({required this.customer});
  final Customer customer;
  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return _DetailSurface(
      key: const Key('customer-detail-notes'),
      header: Text(l.cmvpNotesSection),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Text(
          customer.notes?.isNotEmpty == true
              ? customer.notes!
              : l.cmvpAbsenceValue,
        ),
      ),
    );
  }
}

class _RecentOrders extends StatelessWidget {
  const _RecentOrders({required this.orders, required this.onViewAllOrders});
  final List<CustomerOrder> orders;
  final VoidCallback onViewAllOrders;
  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return _DetailSurface(
      key: const Key('customer-detail-recent-orders'),
      header: Row(
        children: <Widget>[
          Expanded(child: Text(_detailText(context, _DetailText.recentOrders))),
          TextButton(
            key: const Key('customer-detail-view-all-orders'),
            onPressed: onViewAllOrders,
            style: TextButton.styleFrom(minimumSize: const Size(48, 48)),
            child: Text(_detailText(context, _DetailText.viewAllOrders)),
          ),
        ],
      ),
      body: orders.isEmpty
          ? Padding(
              padding: const EdgeInsets.all(16),
              child: Text(l.cmvpNoOrders),
            )
          : LayoutBuilder(
              builder: (context, constraints) =>
                  constraints.maxWidth <
                      CustomerManagementVisualTokens.collectionBreakpoint
                  ? _OrderCards(orders: orders)
                  : _OrderTable(orders: orders),
            ),
    );
  }
}

class _OrderTable extends StatelessWidget {
  const _OrderTable({required this.orders});
  final List<CustomerOrder> orders;
  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return Semantics(
      container: true,
      label: _detailText(context, _DetailText.recentOrders),
      child: Table(
        key: const Key('customer-detail-recent-orders-table'),
        border: const TableBorder(
          horizontalInside: BorderSide(
            color: CustomerManagementVisualTokens.border,
          ),
        ),
        columnWidths: const <int, TableColumnWidth>{
          0: FlexColumnWidth(1.3),
          1: FlexColumnWidth(1.2),
          2: FlexColumnWidth(1.2),
          3: FlexColumnWidth(1.1),
          4: FlexColumnWidth(1.1),
        },
        children: <TableRow>[
          TableRow(
            decoration: const BoxDecoration(
              color: CustomerManagementVisualTokens.warmHeader,
            ),
            children: <Widget>[
              _TableCell(Text(l.cmvpOrderNumber), heading: true),
              _TableCell(Text(l.cmvpBranch), heading: true),
              _TableCell(Text(l.cmvpOrderDateTime), heading: true),
              _TableCell(Text(l.cmvpOrderStatus), heading: true),
              _TableCell(Text(l.cmvpOrderTotal), heading: true),
            ],
          ),
          ...orders.map(
            (order) => TableRow(
              children: <Widget>[
                _TableCell(
                  CustomerBidiValue(value: order.orderNumber, isolate: true),
                ),
                _TableCell(Text(order.branchName)),
                _TableCell(
                  CustomerBidiValue(
                    value: DateFormat(
                      'dd/MM/yyyy',
                      'en_US',
                    ).format(order.createdAt),
                    isolate: true,
                  ),
                ),
                _TableCell(_OrderBadge(status: order.status)),
                _TableCell(
                  _MoneyValue(
                    money: CustomerMoney(
                      amount: order.totalAmount,
                      currency: order.currency,
                    ),
                    absent: l.cmvpAbsenceValue,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _TableCell extends StatelessWidget {
  const _TableCell(this.child, {this.heading = false});
  final Widget child;
  final bool heading;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsetsDirectional.symmetric(
      horizontal: 14,
      vertical: 12,
    ),
    child: DefaultTextStyle.merge(
      style: heading
          ? CustomerManagementVisualTokens.tableHeading
          : CustomerManagementVisualTokens.tableCell,
      child: child,
    ),
  );
}

class _OrderCards extends StatelessWidget {
  const _OrderCards({required this.orders});
  final List<CustomerOrder> orders;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.all(12),
    child: Column(
      children: orders
          .map(
            (order) => Container(
              margin: const EdgeInsetsDirectional.only(bottom: 10),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                border: Border.all(
                  color: CustomerManagementVisualTokens.border,
                ),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  _MobileOrderRow(
                    label: AppLocalizations.of(context).cmvpOrderNumber,
                    value: CustomerBidiValue(
                      value: order.orderNumber,
                      isolate: true,
                    ),
                  ),
                  _MobileOrderRow(
                    label: AppLocalizations.of(context).cmvpBranch,
                    value: Text(order.branchName),
                  ),
                  _MobileOrderRow(
                    label: AppLocalizations.of(context).cmvpOrderDateTime,
                    value: CustomerBidiValue(
                      value: DateFormat(
                        'dd/MM/yyyy',
                        'en_US',
                      ).format(order.createdAt),
                      isolate: true,
                    ),
                  ),
                  _MobileOrderRow(
                    label: AppLocalizations.of(context).cmvpOrderStatus,
                    value: _OrderBadge(status: order.status),
                  ),
                  _MobileOrderRow(
                    label: AppLocalizations.of(context).cmvpOrderTotal,
                    value: _MoneyValue(
                      money: CustomerMoney(
                        amount: order.totalAmount,
                        currency: order.currency,
                      ),
                      absent: AppLocalizations.of(context).cmvpAbsenceValue,
                    ),
                  ),
                ],
              ),
            ),
          )
          .toList(growable: false),
    ),
  );
}

class _MobileOrderRow extends StatelessWidget {
  const _MobileOrderRow({required this.label, required this.value});
  final String label;
  final Widget value;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsetsDirectional.only(bottom: 8),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(label, style: CustomerManagementVisualTokens.tableHeading),
        const SizedBox(height: 2),
        value,
      ],
    ),
  );
}

class _MoneyValue extends StatelessWidget {
  const _MoneyValue({required this.money, required this.absent});
  final CustomerMoney? money;
  final String absent;
  @override
  Widget build(BuildContext context) => CustomerBidiValue(
    value: money == null
        ? absent
        : NumberFormat.currency(
            locale: Localizations.localeOf(context).toString(),
            name: money!.currency,
            decimalDigits: 2,
          ).format(num.tryParse(money!.amount) ?? 0),
    isolate: money != null,
  );
}

class _OrderBadge extends StatelessWidget {
  const _OrderBadge({required this.status});
  final String status;
  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final (String label, Color color) = switch (status) {
      'paid' => (l.cmvpOrderStatusCompleted, const Color(0xFF2E7D32)),
      'held' => (l.cmvpOrderStatusHeld, const Color(0xFF9A6518)),
      'cancelled' => (l.cmvpOrderStatusCancelled, const Color(0xFFC62828)),
      _ => (l.cmvpOrderStatusDraft, const Color(0xFF6E625C)),
    };
    return Semantics(
      label: label,
      child: Container(
        padding: const EdgeInsetsDirectional.symmetric(
          horizontal: 9,
          vertical: 5,
        ),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.13),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: color,
          ),
        ),
      ),
    );
  }
}

class _Field extends StatelessWidget {
  const _Field(this.label, this.value);
  final String label;
  final Widget value;
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: <Widget>[
      Text(label, style: CustomerManagementVisualTokens.pageDescription),
      const SizedBox(height: 5),
      value,
    ],
  );
}

String _phoneTypeLabel(AppLocalizations l, String type) => switch (type) {
  'mobile' => l.customerManagementPhoneMobile,
  'home' => l.customerManagementPhoneHome,
  'work' => l.customerManagementPhoneWork,
  'other' => l.customerManagementPhoneOther,
  _ => type,
};

enum _DetailText {
  overview,
  totalOrders,
  totalSpending,
  averageOrderValue,
  lastVisit,
  recentOrders,
  viewAllOrders,
}

String _detailText(BuildContext context, _DetailText text) {
  final bool ar = Localizations.localeOf(context).languageCode == 'ar';
  return switch ((ar, text)) {
    (false, _DetailText.overview) => 'Overview',
    (false, _DetailText.totalOrders) => 'Total orders',
    (false, _DetailText.totalSpending) => 'Total spending',
    (false, _DetailText.averageOrderValue) => 'Average order value',
    (false, _DetailText.lastVisit) => 'Last visit',
    (false, _DetailText.recentOrders) => 'Recent orders',
    (false, _DetailText.viewAllOrders) => 'View all orders',
    (true, _DetailText.overview) => 'نظرة عامة',
    (true, _DetailText.totalOrders) => 'إجمالي الطلبات',
    (true, _DetailText.totalSpending) => 'إجمالي الإنفاق',
    (true, _DetailText.averageOrderValue) => 'متوسط قيمة الطلب',
    (true, _DetailText.lastVisit) => 'آخر زيارة',
    (true, _DetailText.recentOrders) => 'آخر الطلبات',
    (true, _DetailText.viewAllOrders) => 'عرض جميع الطلبات',
  };
}

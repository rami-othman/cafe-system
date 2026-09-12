import 'package:flutter/material.dart';

import '../../../l10n/app_localizations.dart';
import '../models/customer_models.dart';
import 'customer_bidi_value.dart';
import 'customer_lifecycle_badge.dart';
import 'customer_management_surface.dart';

class CustomerDetailSections extends StatelessWidget {
  const CustomerDetailSections({super.key, required this.customer});
  final Customer customer;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final String unavailable = l10n.cmvpAbsenceValue;
    final Widget information = CustomerManagementSurface(
      key: const Key('customer-detail-information'),
      header: Text(l10n.cmvpInformationSection),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            _Section(
              l10n.customerManagementCustomerNumber,
              CustomerBidiValue(
                key: const Key('customer-detail-raw-number'),
                value: customer.customerNumber,
              ),
            ),
            _Section(
              l10n.customerManagementStatus,
              CustomerLifecycleBadge(lifecycle: customer.lifecycle),
            ),
            _Section(
              l10n.customerManagementEmail,
              CustomerBidiValue(value: customer.email ?? unavailable),
            ),
            _Section(
              l10n.customerManagementBirthDate,
              CustomerBidiValue(
                value:
                    customer.birthDate?.toIso8601String().split('T').first ??
                    unavailable,
              ),
            ),
          ],
        ),
      ),
    );
    final Widget phones = CustomerManagementSurface(
      key: const Key('customer-detail-phones'),
      header: Text(l10n.cmvpPhoneSection),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: customer.phones.isEmpty
            ? Text(l10n.customerManagementNoPhone)
            : Column(
                children: customer.phones
                    .map(
                      (CustomerPhone phone) => ListTile(
                        contentPadding: EdgeInsets.zero,
                        title: CustomerBidiValue(value: phone.rawNumber),
                        subtitle: Text(_phoneTypeLabel(l10n, phone.type)),
                        trailing: phone.isPrimary
                            ? Text(l10n.customerManagementPrimary)
                            : null,
                      ),
                    )
                    .toList(growable: false),
              ),
      ),
    );
    final Widget groups = CustomerManagementSurface(
      key: const Key('customer-detail-groups'),
      header: Text(l10n.cmvpGroupsSection),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: customer.groups.isEmpty
            ? Text(unavailable)
            : Wrap(
                spacing: 8,
                runSpacing: 8,
                children: customer.groups
                    .map(
                      (CustomerGroupSummary group) => Chip(
                        avatar: Icon(
                          group.lifecycle == CustomerLifecycle.archived
                              ? Icons.archive_outlined
                              : Icons.group_outlined,
                        ),
                        label: Text(group.name),
                      ),
                    )
                    .toList(growable: false),
              ),
      ),
    );
    final Widget notes = CustomerManagementSurface(
      key: const Key('customer-detail-notes'),
      header: Text(l10n.cmvpNotesSection),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Text(
          customer.notes?.isNotEmpty == true ? customer.notes! : unavailable,
        ),
      ),
    );
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final double width = constraints.maxWidth < 760
            ? constraints.maxWidth
            : (constraints.maxWidth - 16) / 2;
        return Wrap(
          spacing: 16,
          runSpacing: 16,
          children: <Widget>[
            SizedBox(width: width, child: information),
            SizedBox(width: width, child: phones),
            SizedBox(width: width, child: groups),
            SizedBox(width: width, child: notes),
          ],
        );
      },
    );
  }
}

String _phoneTypeLabel(AppLocalizations l10n, String type) => switch (type) {
  'mobile' => l10n.customerManagementPhoneMobile,
  'home' => l10n.customerManagementPhoneHome,
  'work' => l10n.customerManagementPhoneWork,
  'other' => l10n.customerManagementPhoneOther,
  _ => type,
};

class _Section extends StatelessWidget {
  const _Section(this.title, this.child);
  final String title;
  final Widget child;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 20),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
        const SizedBox(height: 6),
        child,
      ],
    ),
  );
}

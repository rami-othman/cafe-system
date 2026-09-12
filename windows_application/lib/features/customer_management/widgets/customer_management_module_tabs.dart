import 'package:flutter/material.dart';

import '../../../l10n/app_localizations.dart';

class CustomerManagementModuleTabs extends StatelessWidget {
  const CustomerManagementModuleTabs({
    super.key,
    required this.groupsSelected,
    this.onSelectionChanged,
  });

  final bool groupsSelected;
  final ValueChanged<bool>? onSelectionChanged;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    return Align(
      alignment: AlignmentDirectional.centerStart,
      child: Semantics(
        container: true,
        label: l10n.customerManagementTitle,
        child: SegmentedButton<bool>(
          segments: <ButtonSegment<bool>>[
            ButtonSegment<bool>(
              value: false,
              label: Text(l10n.customerManagementCustomers),
            ),
            ButtonSegment<bool>(
              value: true,
              label: Text(l10n.customerManagementGroups),
            ),
          ],
          selected: <bool>{groupsSelected},
          showSelectedIcon: false,
          onSelectionChanged: onSelectionChanged == null
              ? null
              : (Set<bool> values) => onSelectionChanged!(values.single),
        ),
      ),
    );
  }
}

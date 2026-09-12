import 'package:flutter/material.dart';

import '../../../l10n/app_localizations.dart';
import '../models/customer_models.dart';

class CustomerLifecycleBadge extends StatelessWidget {
  const CustomerLifecycleBadge({super.key, required this.lifecycle});
  final CustomerLifecycle lifecycle;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final String label = switch (lifecycle) {
      CustomerLifecycle.active => l10n.customerManagementActive,
      CustomerLifecycle.inactive => l10n.customerManagementInactive,
      CustomerLifecycle.archived => l10n.customerManagementArchived,
    };
    final Color color = switch (lifecycle) {
      CustomerLifecycle.active => Colors.green,
      CustomerLifecycle.inactive => Colors.orange,
      CustomerLifecycle.archived => Colors.grey,
    };
    return Chip(
      label: Text(label),
      backgroundColor: color.withValues(alpha: .12),
      side: BorderSide(color: color.withValues(alpha: .35)),
    );
  }
}

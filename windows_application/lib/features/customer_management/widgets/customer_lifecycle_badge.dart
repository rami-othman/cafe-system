import 'package:flutter/material.dart';

import '../../../l10n/app_localizations.dart';
import '../models/customer_models.dart';
import 'customer_management_visual_tokens.dart';

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
    final (Color background, Color foreground) = switch (lifecycle) {
      CustomerLifecycle.active => (
        CustomerManagementVisualTokens.activeBadgeBackground,
        CustomerManagementVisualTokens.activeBadgeForeground,
      ),
      CustomerLifecycle.inactive => (
        CustomerManagementVisualTokens.inactiveBadgeBackground,
        CustomerManagementVisualTokens.inactiveBadgeForeground,
      ),
      CustomerLifecycle.archived => (
        CustomerManagementVisualTokens.archivedBadgeBackground,
        CustomerManagementVisualTokens.archivedBadgeForeground,
      ),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: foreground,
          fontSize: 11,
          height: 1.2,
          fontWeight: FontWeight.w700,
          fontFamilyFallback: CustomerManagementVisualTokens.fontFamilyFallback,
        ),
      ),
    );
  }
}

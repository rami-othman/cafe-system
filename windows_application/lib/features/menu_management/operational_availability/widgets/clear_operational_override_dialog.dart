import 'package:flutter/material.dart';

import '../models/operational_availability_models.dart';
import '../operational_availability_formatters.dart';

Future<bool?> showClearOperationalOverrideDialog(
  BuildContext context, {
  required OperationalAvailabilityOverride override,
}) => showDialog<bool>(
  context: context,
  builder: (dialog) => AlertDialog(
    title: const Text('Clear operational override?'),
    content: Text(
      'Clear the ${operationalLevelLabel(override.level).toLowerCase()} override for ${operationalScopeLabel(override)}?\n\nScheduled Availability, Product configuration, and historical Published Versions will not be changed.',
    ),
    actions: <Widget>[
      TextButton(
        onPressed: () => Navigator.pop(dialog, false),
        child: const Text('Cancel'),
      ),
      FilledButton(
        onPressed: () => Navigator.pop(dialog, true),
        child: const Text('Clear override'),
      ),
    ],
  ),
);

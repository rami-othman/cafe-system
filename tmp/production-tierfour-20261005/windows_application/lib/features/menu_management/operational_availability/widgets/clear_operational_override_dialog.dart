import 'package:flutter/material.dart';

import '../../../../app/localization/localization_extensions.dart';
import '../models/operational_availability_models.dart';
import '../operational_availability_formatters.dart';

Future<bool?> showClearOperationalOverrideDialog(
  BuildContext context, {
  required OperationalAvailabilityOverride override,
}) => showDialog<bool>(
  context: context,
  builder: (dialog) => AlertDialog(
    title: Text(context.l10n.operationalOverrideClearTitle),
    content: Text(
      context.l10n.operationalOverrideClearMessage(
        operationalLevelLabel(override.level).toLowerCase(),
        operationalScopeLabel(override),
      ),
    ),
    actions: <Widget>[
      TextButton(
        onPressed: () => Navigator.pop(dialog, false),
        child: Text(context.l10n.commonCancel),
      ),
      FilledButton(
        onPressed: () => Navigator.pop(dialog, true),
        child: Text(context.l10n.operationalOverrideClearAction),
      ),
    ],
  ),
);

import 'package:flutter/material.dart';

import '../models/finance_setup_models.dart';
import 'finance_design.dart';

/// Shared cash-source UI for any flow settling in cash (Purchase, Expense,
/// Customer Refund, Vouchers, Manual Sales…): resolves to the backend's
/// `finance/cash-source-options` contract (`CashSourceOptions`).
///
/// - `mode == 'shift'`: the actor's drawer is fixed by their open shift —
///   shown read-only, never editable client-side (backend re-resolves and
///   rejects a client-supplied location in this mode regardless).
/// - `mode == 'selectable'`: manager/owner pick from `allowed`.
class CashSourceField extends StatelessWidget {
  const CashSourceField({
    super.key,
    required this.options,
    required this.selectedLocationId,
    required this.onChanged,
    this.label = 'الصندوق النقدي',
    this.resolvedLabel = 'صندوق الوردية',
  });

  final CashSourceOptions? options;
  final int? selectedLocationId;
  final ValueChanged<int?> onChanged;
  final String label;
  final String resolvedLabel;

  @override
  Widget build(BuildContext context) {
    final CashSourceOptions? current = options;
    if (current == null) return const SizedBox.shrink();
    if (current.mode == 'shift') {
      return Padding(
        padding: const EdgeInsets.only(top: 6),
        child: Text(
          '$resolvedLabel: ${current.resolved?.name ?? 'غير محدد'}',
          style: FinanceText.small,
        ),
      );
    }
    return DropdownButtonFormField<int>(
      initialValue: selectedLocationId,
      isExpanded: true,
      decoration: InputDecoration(labelText: label),
      items: current.allowed
          .map((location) => DropdownMenuItem<int>(
                value: location.id,
                child: Text(location.name, overflow: TextOverflow.ellipsis),
              ))
          .toList(growable: false),
      onChanged: onChanged,
    );
  }
}

/// True when `options` describes a resolvable cash source for submission:
/// an open shift with a valid drawer in `shift` mode, or an explicit pick
/// among `allowed` in `selectable` mode.
bool cashSourceIsResolved(CashSourceOptions? options, int? selectedLocationId) {
  if (options == null) return false;
  if (options.mode == 'shift') return options.resolved != null;
  return selectedLocationId != null;
}

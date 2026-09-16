import 'package:flutter/material.dart';

import '../../../l10n/app_localizations.dart';
import 'customer_management_visual_tokens.dart';

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
        child: Container(
          height: 44,
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: CustomerManagementVisualTokens.surface,
            border: Border.fromBorderSide(
              CustomerManagementVisualTokens.surfaceBorder,
            ),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              _ModuleTab(
                label: l10n.customerManagementCustomers,
                selected: !groupsSelected,
                onPressed: onSelectionChanged == null
                    ? null
                    : () => onSelectionChanged!(false),
              ),
              _ModuleTab(
                label: l10n.customerManagementGroups,
                selected: groupsSelected,
                onPressed: onSelectionChanged == null
                    ? null
                    : () => onSelectionChanged!(true),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ModuleTab extends StatelessWidget {
  const _ModuleTab({
    required this.label,
    required this.selected,
    required this.onPressed,
  });

  final String label;
  final bool selected;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final TextStyle? textStyle = Theme.of(
      context,
    ).textTheme.labelLarge?.copyWith(fontSize: 13, fontWeight: FontWeight.w700);
    return TextButton(
      onPressed: selected ? null : onPressed,
      style: TextButton.styleFrom(
        foregroundColor: selected
            ? CustomerManagementVisualTokens.rowText
            : CustomerManagementVisualTokens.mutedText,
        backgroundColor: selected
            ? const Color(0xFFFEC29E)
            : Colors.transparent,
        disabledForegroundColor: CustomerManagementVisualTokens.rowText,
        padding: const EdgeInsets.symmetric(horizontal: 18),
        minimumSize: const Size(0, 34),
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        textStyle: textStyle,
      ),
      child: Text(label),
    );
  }
}

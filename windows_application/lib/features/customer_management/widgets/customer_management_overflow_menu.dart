import 'package:flutter/material.dart';

import 'customer_management_visual_tokens.dart';

class CustomerManagementMenuEntry {
  const CustomerManagementMenuEntry({
    required this.label,
    required this.onPressed,
    this.icon,
    this.enabled = true,
    this.destructive = false,
  });

  final String label;
  final VoidCallback onPressed;
  final IconData? icon;
  final bool enabled;
  final bool destructive;
}

class CustomerManagementOverflowMenu extends StatelessWidget {
  const CustomerManagementOverflowMenu({
    super.key,
    required this.actions,
    required this.tooltip,
    this.semanticLabel,
  });

  final List<CustomerManagementMenuEntry> actions;
  final String tooltip;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: () {},
    behavior: HitTestBehavior.opaque,
    child: Semantics(
      button: true,
      label: semanticLabel ?? tooltip,
      child: PopupMenuButton<int>(
        tooltip: tooltip,
        padding: EdgeInsets.zero,
        constraints: const BoxConstraints(minWidth: 180),
        icon: const Icon(Icons.more_vert),
        iconSize: 22,
        splashRadius: CustomerManagementVisualTokens.minimumInteractiveSize / 2,
        itemBuilder: (BuildContext context) => <PopupMenuEntry<int>>[
          for (int index = 0; index < actions.length; index++)
            PopupMenuItem<int>(
              value: index,
              enabled: actions[index].enabled,
              child: Row(
                children: <Widget>[
                  if (actions[index].icon != null) ...<Widget>[
                    Icon(
                      actions[index].icon,
                      size: 20,
                      color: actions[index].destructive
                          ? Theme.of(context).colorScheme.error
                          : null,
                    ),
                    const SizedBox(width: 12),
                  ],
                  Flexible(
                    child: Text(
                      actions[index].label,
                      style: actions[index].destructive
                          ? TextStyle(
                              color: Theme.of(context).colorScheme.error,
                            )
                          : null,
                    ),
                  ),
                ],
              ),
            ),
        ],
        onSelected: (int index) => actions[index].onPressed(),
      ),
    ),
  );
}

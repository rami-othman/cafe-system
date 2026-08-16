import 'package:flutter/material.dart';

import '../../../core/constants/app_sizes.dart';
import '../../../core/theme/app_spacing.dart';

class MenuOverflowAction {
  const MenuOverflowAction({
    required this.label,
    required this.onSelected,
    this.icon,
  });

  final String label;
  final VoidCallback onSelected;
  final IconData? icon;
}

class MenuPageHeader extends StatelessWidget {
  const MenuPageHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.primaryAction,
    this.secondaryActions = const <Widget>[],
    this.overflowActions = const <MenuOverflowAction>[],
  });

  final String title;
  final String? subtitle;
  final Widget? primaryAction;
  final List<Widget> secondaryActions;
  final List<MenuOverflowAction> overflowActions;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final bool stackActions =
            constraints.maxWidth < AppSizes.menuHeaderInlineBreakpoint;
        final Widget actions = Wrap(
          spacing: AppSpacing.sm,
          runSpacing: AppSpacing.sm,
          alignment: WrapAlignment.end,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: <Widget>[
            ...secondaryActions,
            if (overflowActions.isNotEmpty)
              PopupMenuButton<MenuOverflowAction>(
                tooltip: 'More actions for $title',
                icon: const Icon(Icons.more_horiz),
                onSelected: (MenuOverflowAction action) => action.onSelected(),
                itemBuilder: (BuildContext context) => overflowActions
                    .map(
                      (MenuOverflowAction action) =>
                          PopupMenuItem<MenuOverflowAction>(
                            value: action,
                            child: Row(
                              children: <Widget>[
                                if (action.icon != null) ...<Widget>[
                                  Icon(action.icon, size: 18),
                                  const SizedBox(width: AppSpacing.sm),
                                ],
                                Text(action.label),
                              ],
                            ),
                          ),
                    )
                    .toList(),
              ),
            ?primaryAction,
          ],
        );

        final Widget heading = Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(title, style: Theme.of(context).textTheme.headlineSmall),
            if (subtitle != null) ...<Widget>[
              const SizedBox(height: AppSpacing.xs),
              Text(subtitle!, style: Theme.of(context).textTheme.bodyMedium),
            ],
          ],
        );

        if (stackActions) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              heading,
              const SizedBox(height: AppSpacing.lg),
              actions,
            ],
          );
        }
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Expanded(child: heading),
            actions,
          ],
        );
      },
    );
  }
}

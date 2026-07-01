import 'package:flutter/material.dart';

import '../controllers/menu_state.dart';

class MenuTabs extends StatelessWidget {
  const MenuTabs({
    super.key,
    required this.selectedTab,
    required this.onSelected,
  });

  final MenuTab selectedTab;
  final ValueChanged<MenuTab> onSelected;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      children: MenuTab.values
          .map(
            (MenuTab tab) => TextButton(
              onPressed: () => onSelected(tab),
              child: Text(tab.name),
            ),
          )
          .toList(growable: false),
    );
  }
}

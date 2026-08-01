import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class MenuManagementTabs extends StatelessWidget {
  const MenuManagementTabs({super.key, required this.selected});
  final String selected;
  @override
  Widget build(BuildContext context) => Wrap(
    spacing: 8,
    children: <Widget>[
      ChoiceChip(
        label: const Text('Products'),
        selected: selected == 'products',
        onSelected: (_) => context.go('/menu-management/products'),
      ),
      ChoiceChip(
        label: const Text('Modifier Library'),
        selected: selected == 'modifiers',
        onSelected: (_) => context.go('/menu-management/modifiers'),
      ),
      ChoiceChip(
        label: const Text('Menus'),
        selected: selected == 'menus',
        onSelected: (_) => context.go('/menu-management/menus'),
      ),
      ChoiceChip(
        label: const Text('Assignments & Schedules'),
        selected: selected == 'assignments',
        onSelected: (_) => context.go('/menu-management/assignments'),
      ),
      ChoiceChip(
        label: const Text('Review & Preview'),
        selected: selected == 'review',
        onSelected: (_) => context.go('/menu-management/review'),
      ),
    ],
  );
}

import 'package:flutter/material.dart';

class MenuFilterBar extends StatelessWidget {
  const MenuFilterBar({super.key, required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Wrap(spacing: 8, runSpacing: 8, children: children);
  }
}

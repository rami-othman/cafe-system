import 'package:flutter/material.dart';

import '../../../shared/widgets/app_card.dart';

class MenuKpiCard extends StatelessWidget {
  const MenuKpiCard({super.key, required this.label, required this.value});

  final String label;
  final int value;

  @override
  Widget build(BuildContext context) {
    return AppCard(child: Text('$label: $value'));
  }
}

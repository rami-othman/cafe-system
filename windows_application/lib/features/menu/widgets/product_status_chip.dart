import 'package:flutter/material.dart';

import '../models/menu_enums.dart';

class ProductStatusChip extends StatelessWidget {
  const ProductStatusChip({super.key, required this.status});

  final ProductStatus status;

  @override
  Widget build(BuildContext context) => Chip(label: Text(status.name));
}

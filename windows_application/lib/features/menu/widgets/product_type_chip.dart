import 'package:flutter/material.dart';

import '../models/menu_enums.dart';

class ProductTypeChip extends StatelessWidget {
  const ProductTypeChip({super.key, required this.type});

  final ProductType type;

  @override
  Widget build(BuildContext context) => Chip(label: Text(type.name));
}

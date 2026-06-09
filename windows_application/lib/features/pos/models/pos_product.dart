import 'package:flutter/material.dart';

class PosProduct {
  const PosProduct({
    required this.name,
    required this.size,
    required this.price,
    required this.available,
    required this.icon,
  });

  final String name;
  final String size;
  final String price;
  final bool available;
  final IconData icon;
}

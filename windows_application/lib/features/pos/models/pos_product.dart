import 'package:equatable/equatable.dart';
import 'package:flutter/material.dart';

class PosProduct extends Equatable {
  const PosProduct({
    required this.id,
    required this.name,
    required this.category,
    required this.size,
    required this.price,
    required this.isAvailable,
    this.icon,
  });

  final String id;
  final String name;
  final String category;
  final String size;
  final double price;
  final bool isAvailable;
  final IconData? icon;

  @override
  List<Object?> get props => <Object?>[
    id,
    name,
    category,
    size,
    price,
    isAvailable,
    icon,
  ];
}

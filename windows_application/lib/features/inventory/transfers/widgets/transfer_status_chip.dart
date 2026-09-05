import 'package:flutter/material.dart';
import '../../models/inventory_models.dart';

class TransferStatusChip extends StatelessWidget {
  const TransferStatusChip({super.key, required this.status});
  final String status;
  @override
  Widget build(BuildContext context) {
    final TransferStatus value = TransferStatus.fromValue(status);
    return Chip(label: Text(value.arabicLabel));
  }
}

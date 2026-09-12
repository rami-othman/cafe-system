import 'package:flutter/material.dart';

class CustomerBidiValue extends StatelessWidget {
  const CustomerBidiValue({super.key, required this.value});
  final String value;
  @override
  Widget build(BuildContext context) => Directionality(
    textDirection: TextDirection.ltr,
    child: Text(value, textDirection: TextDirection.ltr),
  );
}

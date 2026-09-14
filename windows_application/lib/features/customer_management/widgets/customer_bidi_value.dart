import 'package:flutter/material.dart';

class CustomerBidiValue extends StatelessWidget {
  const CustomerBidiValue({
    super.key,
    required this.value,
    this.isolate = false,
  });
  final String value;
  final bool isolate;
  @override
  Widget build(BuildContext context) => Directionality(
    textDirection: TextDirection.ltr,
    child: Text(
      isolate ? '\u2066$value\u2069' : value,
      textDirection: TextDirection.ltr,
    ),
  );
}

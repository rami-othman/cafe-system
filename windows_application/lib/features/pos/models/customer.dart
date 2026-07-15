import 'package:equatable/equatable.dart';

class Customer extends Equatable {
  const Customer({
    required this.id,
    required this.name,
    required this.phone,
    required this.tier,
    required this.points,
    this.backendId,
  });

  final String id;
  final int? backendId;
  final String name;
  final String phone;
  final String tier;
  final int points;

  String get initials {
    final List<String> parts = name
        .trim()
        .split(RegExp(r'\s+'))
        .where((String part) => part.isNotEmpty)
        .toList(growable: false);

    if (parts.isEmpty) {
      return '?';
    }

    final String first = parts.first.substring(0, 1);
    final String second = parts.length > 1 ? parts.last.substring(0, 1) : '';

    return '$first$second'.toUpperCase();
  }

  @override
  List<Object?> get props => <Object?>[
    id,
    backendId,
    name,
    phone,
    tier,
    points,
  ];
}

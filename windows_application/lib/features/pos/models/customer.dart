import 'package:equatable/equatable.dart';

class Customer extends Equatable {
  const Customer({
    required this.id,
    required this.name,
    required this.phone,
    this.tier,
    this.points,
    this.backendId,
    this.walletBalance,
  });

  final String id;
  final int? backendId;
  final String name;
  final String phone;
  final String? tier;
  final int? points;

  /// Funds the customer holds on their account (negative = they owe). Null when the server did not report it.
  final double? walletBalance;

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
    walletBalance,
  ];
}

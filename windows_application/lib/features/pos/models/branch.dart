import 'package:equatable/equatable.dart';

import 'json_helpers.dart';

class Branch extends Equatable {
  const Branch({
    required this.id,
    required this.name,
    required this.currency,
    required this.timezone,
    required this.isActive,
  });

  factory Branch.fromJson(Map<String, dynamic> json) {
    return Branch(
      id: readInt(json['id']) ?? 0,
      name: readString(json['name']),
      currency: readString(json['currency'], fallback: 'SYP'),
      timezone: readString(json['timezone']),
      isActive: readBool(json['isActive'], fallback: true),
    );
  }

  final int id;
  final String name;
  final String currency;
  final String timezone;
  final bool isActive;

  @override
  List<Object?> get props => <Object?>[id, name, currency, timezone, isActive];
}

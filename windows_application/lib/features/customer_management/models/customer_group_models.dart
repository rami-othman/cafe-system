import 'package:equatable/equatable.dart';

import 'customer_models.dart';

class CustomerGroup extends Equatable {
  const CustomerGroup({
    required this.id,
    required this.name,
    required this.lifecycle,
    required this.memberCount,
    this.createdAt,
  });

  factory CustomerGroup.fromJson(Map<String, dynamic> json) {
    final int? id = (json['id'] as num?)?.toInt();
    final String? name = json['name'] as String?;
    final int? memberCount = (json['memberCount'] as num?)?.toInt();
    final CustomerLifecycle lifecycle = switch (json['status']) {
      'active' => CustomerLifecycle.active,
      'inactive' => CustomerLifecycle.inactive,
      'archived' => CustomerLifecycle.archived,
      _ => throw FormatException(
        'Customer group response has an invalid status.',
      ),
    };
    if (id == null ||
        id <= 0 ||
        name == null ||
        name.trim().isEmpty ||
        memberCount == null ||
        memberCount < 0) {
      throw FormatException(
        'Customer group response is missing required identity.',
      );
    }
    return CustomerGroup(
      id: id,
      name: name,
      lifecycle: lifecycle,
      memberCount: memberCount,
      createdAt: DateTime.tryParse(json['createdAt'] as String? ?? '')?.toUtc(),
    );
  }

  final int id;
  final String name;
  final CustomerLifecycle lifecycle;
  final int memberCount;
  final DateTime? createdAt;

  @override
  List<Object?> get props => <Object?>[
    id,
    name,
    lifecycle,
    memberCount,
    createdAt,
  ];
}

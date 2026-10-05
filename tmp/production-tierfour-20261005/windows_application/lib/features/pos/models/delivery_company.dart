import 'package:equatable/equatable.dart';

/// A delivery company the cashier can settle a delivery order through. It is a
/// Finance payment method of type `delivery_app`, so its ledger account is the
/// one the manager linked to it.
class DeliveryCompany extends Equatable {
  const DeliveryCompany({required this.id, required this.name});

  factory DeliveryCompany.fromJson(Map<String, dynamic> json) {
    return DeliveryCompany(
      id: (json['id'] as num).toInt(),
      name: (json['name'] ?? '').toString(),
    );
  }

  final int id;
  final String name;

  @override
  List<Object?> get props => <Object?>[id, name];
}

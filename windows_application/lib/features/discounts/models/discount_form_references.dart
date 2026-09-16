import '../../pos/models/json_helpers.dart';

/// Tenant-owned entities that can be selected by a Discount V1 policy.
///
/// This intentionally carries only the identity and display name needed by
/// the form. The backend remains the authority for target eligibility.
class DiscountFormReference {
  const DiscountFormReference({
    required this.id,
    required this.name,
    required this.isActive,
  });

  final int id;
  final String name;
  final bool isActive;

  factory DiscountFormReference.fromJson(Map<String, dynamic> json) =>
      DiscountFormReference(
        id: readInt(json['id']) ?? 0,
        name: readString(json['name']),
        isActive: readBool(json['isActive'], fallback: true),
      );
}

class DiscountFormReferences {
  const DiscountFormReferences({
    this.products = const <DiscountFormReference>[],
    this.categories = const <DiscountFormReference>[],
    this.customerGroups = const <DiscountFormReference>[],
    this.paymentMethods = const <DiscountFormReference>[],
  });

  final List<DiscountFormReference> products;
  final List<DiscountFormReference> categories;
  final List<DiscountFormReference> customerGroups;
  final List<DiscountFormReference> paymentMethods;
}

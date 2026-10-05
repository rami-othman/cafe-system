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
    this.subtitle,
  });

  final int id;
  final String name;
  final bool isActive;

  /// Secondary identifying information, such as a customer's phone number.
  final String? subtitle;

  factory DiscountFormReference.fromJson(Map<String, dynamic> json) =>
      DiscountFormReference(
        id: readInt(json['id']) ?? 0,
        name: readString(json['name']),
        isActive: readBool(json['isActive'], fallback: true),
        subtitle: _nullable(json['subtitle']),
      );

  static String? _nullable(dynamic value) {
    final String result = readString(value).trim();
    return result.isEmpty ? null : result;
  }
}

class DiscountFormReferences {
  const DiscountFormReferences({
    this.products = const <DiscountFormReference>[],
    this.categories = const <DiscountFormReference>[],
    this.customerGroups = const <DiscountFormReference>[],
    this.customers = const <DiscountFormReference>[],
    this.paymentMethods = const <DiscountFormReference>[],
  });

  final List<DiscountFormReference> products;
  final List<DiscountFormReference> categories;
  final List<DiscountFormReference> customerGroups;
  final List<DiscountFormReference> customers;
  final List<DiscountFormReference> paymentMethods;
}

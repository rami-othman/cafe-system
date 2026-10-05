import 'package:flutter_test/flutter_test.dart';
import 'package:windows_application/features/menu_management/models/catalog_models.dart';

void main() {
  ProductVariant variant({required bool active, String? archivedAt}) =>
      ProductVariant.fromJson(<String, dynamic>{
        'id': 1,
        'name': 'Regular',
        'basePrice': 3,
        'costPrice': 0,
        'isDefault': false,
        'isActive': active,
        'sortOrder': 0,
        'archivedAt': archivedAt,
      });

  test('variant lifecycle gives archive precedence over isActive', () {
    expect(variant(active: true).lifecycle, LifecycleStatus.active);
    expect(variant(active: false).lifecycle, LifecycleStatus.inactive);
    expect(
      variant(active: true, archivedAt: '2026-08-17T12:00:00Z').lifecycle,
      LifecycleStatus.archived,
    );
    expect(
      variant(active: false, archivedAt: '2026-08-17T12:00:00Z').lifecycle,
      LifecycleStatus.archived,
    );
  });
}

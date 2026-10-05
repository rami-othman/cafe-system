import 'package:flutter_test/flutter_test.dart';
import 'package:windows_application/features/customer_management/models/customer_queries.dart';

void main() {
  test('serializes only supported customer order filters and pagination', () {
    final CustomerOrderQuery query = CustomerOrderQuery(
      from: DateTime(2026, 9, 1),
      to: DateTime(2026, 9, 10),
      branchId: 7,
      status: CustomerOrderStatusFilter.paid,
      paymentStatus: CustomerPaymentStatusFilter.partiallyRefunded,
      page: 2,
      perPage: 25,
    );
    expect(query.toQueryParameters(), <String, dynamic>{
      'from': '2026-09-01', 'to': '2026-09-10', 'branchId': 7,
      'status': 'paid', 'paymentStatus': 'partially_refunded', 'page': 2,
      'perPage': 25,
    });
  });
}

import 'package:flutter_test/flutter_test.dart';
import 'package:windows_application/features/discounts/models/discount_upsert_request.dart';

void main() {
  test('all branches serializes an empty integer branch ID list', () {
    final Map<String, dynamic> json = _request(
      appliesToAllBranches: true,
    ).toJson();
    expect(json['appliesToAllBranches'], isTrue);
    expect(json['branchIds'], isEmpty);
    expect(json.containsKey('branchId'), isFalse);
  });

  test('selected branches serialize real integer IDs and never labels', () {
    final Map<String, dynamic> json = _request(
      appliesToAllBranches: false,
      branchIds: const <int>[41, 43],
    ).toJson();
    expect(json['appliesToAllBranches'], isFalse);
    expect(json['branchIds'], <int>[41, 43]);
    expect(json['branchIds'], isNot(contains('Downtown')));
  });
}

DiscountUpsertRequest _request({
  required bool appliesToAllBranches,
  List<int> branchIds = const <int>[],
}) => DiscountUpsertRequest(
  name: 'Branch test',
  applicationMode: 'code',
  type: 'percentage',
  scope: 'order',
  value: 10,
  isActive: true,
  appliesToAllBranches: appliesToAllBranches,
  branchIds: branchIds,
);

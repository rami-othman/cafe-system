import 'package:flutter_test/flutter_test.dart';
import 'package:windows_application/features/discounts/controllers/discounts_cubit.dart';
import 'package:windows_application/features/discounts/models/discount_list_item.dart';
import 'package:windows_application/features/discounts/models/discount_upsert_request.dart';
import 'package:windows_application/features/discounts/repositories/discounts_repository.dart';
import 'package:windows_application/features/pos/models/branch.dart';

void main() {
  test(
    'loads, creates, changes status, and deletes through the repository',
    () async {
      final _Repository repository = _Repository();
      final DiscountsCubit cubit = DiscountsCubit(repository: repository);
      await cubit.loadDiscounts();
      expect(cubit.state.discounts, hasLength(1));

      await cubit.createDiscount(_request);
      expect(cubit.state.discounts, hasLength(2));
      await cubit.setStatus('2', false);
      expect(cubit.state.discounts.first.status, DiscountStatus.inactive);
      await cubit.deleteDiscount('2');
      expect(cubit.state.discounts, hasLength(1));
    },
  );
}

const DiscountUpsertRequest _request = DiscountUpsertRequest(
  name: 'Created',
  applicationMode: 'code',
  type: 'percentage',
  scope: 'order',
  value: 10,
  isActive: true,
  appliesToAllBranches: true,
);

class _Repository implements DiscountsRepository {
  final List<DiscountListItem> _items = <DiscountListItem>[
    _item('1', 'Existing', true),
  ];
  @override
  Future<List<DiscountListItem>> getDiscounts() async =>
      List<DiscountListItem>.of(_items);
  @override
  Future<List<Branch>> getBranches() async => const <Branch>[
    Branch(
      id: 41,
      name: 'Downtown',
      currency: 'SYP',
      timezone: 'Asia/Damascus',
      isActive: true,
    ),
  ];
  @override
  Future<DiscountListItem> createDiscount(DiscountUpsertRequest request) async {
    final DiscountListItem item = _item('2', request.name, request.isActive);
    _items.insert(0, item);
    return item;
  }

  @override
  Future<DiscountListItem> setStatus(String id, bool active) async {
    final int index = _items.indexWhere(
      (DiscountListItem item) => item.id == id,
    );
    final DiscountListItem updated = _item(id, _items[index].name, active);
    _items[index] = updated;
    return updated;
  }

  @override
  Future<void> deleteDiscount(String id) async =>
      _items.removeWhere((DiscountListItem item) => item.id == id);
  @override
  Future<DiscountListItem> updateDiscount(
    String id,
    DiscountUpsertRequest request,
  ) async => setStatus(id, request.isActive);
}

DiscountListItem _item(String id, String name, bool active) => DiscountListItem(
  id: id,
  name: name,
  secondaryLabel: 'Code: TEST',
  type: 'Percentage',
  displayValue: '10% off',
  conditions: 'None',
  validPeriodPrimary: 'Always Valid',
  status: active ? DiscountStatus.active : DiscountStatus.inactive,
  usageCount: 0,
  estimatedSavedValue: '0 SYP',
  isActive: active,
);

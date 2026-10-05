import 'package:flutter_test/flutter_test.dart';
import 'package:windows_application/features/inventory/models/inventory_models.dart';

void main() {
  test('parses paged stock count data, status summary, and creator filters', () {
    final InventoryCountsPage page = InventoryCountsPage.fromJson(
      <String, dynamic>{
        'data': <Map<String, dynamic>>[
          <String, dynamic>{
            'id': 1038,
            'number': 'SC-01038',
            'warehouseId': 7,
            'warehouseName': 'المستودع الرئيسي',
            'countDate': '2026-08-19',
            'countType': 'full',
            'status': 'draft',
            'totalItems': 8,
            'countedItems': 5,
            'createdByName': 'مدير الفرع',
          },
        ],
        'meta': <String, dynamic>{
          'currentPage': 2,
          'lastPage': 3,
          'total': 21,
          'summary': <String, dynamic>{
            'drafts': 4,
            'inProgress': 3,
            'submitted': 2,
            'approved': 1,
          },
          'filterOptions': <String, dynamic>{
            'createdBy': <Map<String, dynamic>>[
              <String, dynamic>{'id': 9, 'name': 'مدير الفرع'},
            ],
          },
        },
      },
    );

    expect(page.items.single.number, 'SC-01038');
    expect(page.items.single.countedItems, 5);
    expect(page.currentPage, 2);
    expect(page.lastPage, 3);
    expect(page.total, 21);
    expect(page.summary.drafts, 4);
    expect(page.summary.inProgress, 3);
    expect(page.creators.single.id, 9);
    expect(page.creators.single.name, 'مدير الفرع');
  });
}

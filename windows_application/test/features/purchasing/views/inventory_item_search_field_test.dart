import 'dart:async';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:windows_application/core/network/dio_api_client.dart';
import 'package:windows_application/features/inventory/models/inventory_models.dart';
import 'package:windows_application/features/inventory/repositories/inventory_repository.dart';
import 'package:windows_application/features/purchasing/widgets/inventory_item_search_field.dart';

final bean = InventoryItem.fromJson({
  'id': 184,
  'displayName': 'بن',
  'sku': 'BEAN',
  'unit': 'kg',
});
final tea = InventoryItem.fromJson({
  'id': 185,
  'displayName': 'شاي',
  'sku': 'TEA',
  'unit': 'kg',
});
final field = find.byType(TextField).first;

class SearchRepository extends InventoryRepository {
  SearchRepository() : super(DioApiClient(dio: Dio()));
  final queries = <String>[];
  final pending = <Completer<List<InventoryItem>>>[];
  @override
  Future<List<InventoryItem>> items({
    String? search,
    String? type,
    String? category,
    String? status,
    int? warehouseId,
    int? branchId,
    bool activeOnly = false,
  }) {
    expect(activeOnly, isTrue);
    queries.add(search!);
    final response = Completer<List<InventoryItem>>();
    pending.add(response);
    return response.future;
  }
}

Future<void> pump(WidgetTester tester, SearchRepository repo) async {
  InventoryItem? selected;
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: Directionality(
          textDirection: TextDirection.rtl,
          child: StatefulBuilder(
            builder: (context, setState) => Column(
              children: [
                InventoryItemSearchField(
                  repository: repo,
                  selected: selected,
                  onSelected: (value) => setState(() => selected = value),
                ),
                const TextField(key: ValueKey('other')),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}

Future<void> search(WidgetTester tester, String query) async {
  await tester.enterText(field, query);
  await tester.pump(const Duration(milliseconds: 400));
}

void main() {
  testWidgets('clear cancels debounce and ignores in-flight response', (
    tester,
  ) async {
    final repo = SearchRepository();
    await pump(tester, repo);
    await tester.enterText(field, 'بن');
    await tester.pump(const Duration(milliseconds: 100));
    await tester.enterText(field, '');
    await tester.pump(const Duration(milliseconds: 400));
    expect(repo.queries, isEmpty);
    await search(tester, 'بن');
    await tester.enterText(field, '');
    repo.pending.single.complete([bean]);
    await tester.pumpAndSettle();
    expect(find.byType(ListTile), findsNothing);
  });
  testWidgets('replacement query survives parent clearing selection', (
    tester,
  ) async {
    final repo = SearchRepository();
    await pump(tester, repo);
    await search(tester, 'بن');
    repo.pending.last.complete([bean]);
    await tester.pumpAndSettle();
    await tester.tap(find.text('بن').last);
    await tester.pumpAndSettle();
    expect(find.byIcon(Icons.check_circle), findsOneWidget);
    await tester.enterText(field, 'شاي');
    await tester.pump();
    expect(tester.widget<TextField>(field).controller!.text, 'شاي');
    expect(find.byIcon(Icons.check_circle), findsNothing);
    await tester.pump(const Duration(milliseconds: 400));
    repo.pending.last.complete([tea]);
    await tester.pumpAndSettle();
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pumpAndSettle();
    expect(tester.widget<TextField>(field).controller!.text, 'شاي');
    expect(find.byIcon(Icons.check_circle), findsOneWidget);
  });
  testWidgets('old response cannot flash during newer debounce', (
    tester,
  ) async {
    final repo = SearchRepository();
    await pump(tester, repo);
    await search(tester, 'بن');
    await tester.enterText(field, 'شاي');
    repo.pending.first.complete([bean]);
    await tester.pump();
    expect(find.byType(ListTile), findsNothing);
    await tester.pump(const Duration(milliseconds: 400));
    repo.pending.last.complete([tea]);
    await tester.pumpAndSettle();
    expect(find.text('TEA'), findsOneWidget);
    expect(find.text('BEAN'), findsNothing);
  });
  for (final dismiss in ['escape', 'blur', 'outside', 'dispose']) {
    testWidgets('$dismiss prevents delayed popup', (tester) async {
      final repo = SearchRepository();
      await pump(tester, repo);
      await search(tester, 'بن');
      if (dismiss == 'escape') {
        await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      }
      if (dismiss == 'blur') {
        await tester.tap(find.byKey(const ValueKey('other')));
      }
      if (dismiss == 'outside') await tester.tapAt(const Offset(500, 400));
      if (dismiss == 'dispose') await tester.pumpWidget(const SizedBox());
      repo.pending.single.complete([bean]);
      await tester.pumpAndSettle();
      expect(find.byType(ListTile), findsNothing);
      expect(tester.takeException(), isNull);
    });
  }
  testWidgets('error has retry and is distinct from empty results', (
    tester,
  ) async {
    final repo = SearchRepository();
    await pump(tester, repo);
    await search(tester, '12345');
    repo.pending.last.completeError(Exception('offline'));
    await tester.pumpAndSettle();
    expect(find.text('إعادة المحاولة'), findsOneWidget);
    expect(find.text('لا توجد نتائج مطابقة للبحث'), findsNothing);
    await tester.tap(find.text('إعادة المحاولة'));
    await tester.pump(const Duration(milliseconds: 400));
    expect(repo.queries, ['12345', '12345']);
    repo.pending.last.complete([]);
    await tester.pumpAndSettle();
    expect(find.text('لا توجد نتائج مطابقة للبحث'), findsOneWidget);
  });
  testWidgets('arrows highlight and enter selects highlighted result', (
    tester,
  ) async {
    final repo = SearchRepository();
    await pump(tester, repo);
    await search(tester, '  BE  ');
    expect(repo.queries.single, 'BE');
    repo.pending.last.complete([bean, tea]);
    await tester.pumpAndSettle();
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.pump();
    expect(
      tester.widget<ListTile>(find.byType(ListTile).last).selected,
      isTrue,
    );
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pumpAndSettle();
    expect(tester.widget<TextField>(field).controller!.text, 'شاي');
    expect(find.byType(ListTile), findsNothing);
  });
  testWidgets('mouse click selects the correct result and closes the popup', (
    tester,
  ) async {
    final repo = SearchRepository();
    await pump(tester, repo);
    await search(tester, 'BE');
    repo.pending.single.complete([bean, tea]);
    await tester.pumpAndSettle();
    expect(find.byType(ListTile), findsNWidgets(2));
    final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await mouse.addPointer(
      location: tester.getCenter(find.byType(ListTile).last),
    );
    await mouse.down(tester.getCenter(find.byType(ListTile).last));
    await tester.pump();
    expect(find.byType(ListTile), findsNWidgets(2));
    await mouse.up();
    await mouse.removePointer();
    await tester.pumpAndSettle();
    expect(tester.widget<TextField>(field).controller!.text, tea.name);
    expect(find.byIcon(Icons.check_circle), findsOneWidget);
    expect(find.byType(ListTile), findsNothing);
  });
  testWidgets('scrolling the popup still allows a mouse selection', (
    tester,
  ) async {
    final repo = SearchRepository();
    await pump(tester, repo);
    await search(tester, 'B');
    final items = List<InventoryItem>.generate(
      12,
      (index) => InventoryItem.fromJson({
        'id': 100 + index,
        'displayName': 'Item $index',
        'sku': 'SKU-$index',
        'unit': 'kg',
      }),
    );
    repo.pending.single.complete(items);
    await tester.pumpAndSettle();
    await tester.drag(find.byType(ListView), const Offset(0, -500));
    await tester.pumpAndSettle();
    final visible = find.ancestor(
      of: find.text('Item 8'),
      matching: find.byType(ListTile),
    );
    final chosen = tester.widget<ListTile>(visible).title! as Text;
    await tester.tap(visible);
    await tester.pumpAndSettle();
    expect(tester.widget<TextField>(field).controller!.text, chosen.data);
    expect(find.byIcon(Icons.check_circle), findsOneWidget);
  });
  testWidgets('two rows keep independent selections', (tester) async {
    final repo = SearchRepository();
    InventoryItem? first;
    InventoryItem? second;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: StatefulBuilder(
            builder: (context, rebuild) => Column(
              children: [
                InventoryItemSearchField(
                  key: const ValueKey('first'),
                  repository: repo,
                  selected: first,
                  onSelected: (item) => rebuild(() => first = item),
                ),
                InventoryItemSearchField(
                  key: const ValueKey('second'),
                  repository: repo,
                  selected: second,
                  onSelected: (item) => rebuild(() => second = item),
                ),
              ],
            ),
          ),
        ),
      ),
    );
    await tester.enterText(find.byType(TextField).first, 'BE');
    await tester.pump(const Duration(milliseconds: 400));
    repo.pending.last.complete([bean]);
    await tester.pumpAndSettle();
    await tester.tap(find.byType(ListTile));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).last, 'TE');
    await tester.pump(const Duration(milliseconds: 400));
    repo.pending.last.complete([tea]);
    await tester.pumpAndSettle();
    await tester.tap(find.byType(ListTile));
    await tester.pumpAndSettle();
    expect(first?.id, bean.id);
    expect(second?.id, tea.id);
    expect(find.byIcon(Icons.check_circle), findsNWidgets(2));
  });
}

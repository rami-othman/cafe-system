import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:windows_application/core/theme/app_colors.dart';
import 'package:windows_application/features/menu_management/widgets/menu_content_components.dart';
import 'package:windows_application/features/menu_management/widgets/menu_context_and_filters.dart';
import 'package:windows_application/features/menu_management/widgets/menu_module_scaffold.dart';
import 'package:windows_application/features/menu_management/widgets/menu_page_header.dart';
import 'package:windows_application/features/menu_management/widgets/sticky_form_actions.dart';

import '../../support/menu_management_test_harness.dart';

void main() {
  testWidgets(
    'module scaffold constrains the workspace at every target desktop width',
    (WidgetTester tester) async {
      for (final MenuDesktopViewport viewport in MenuDesktopViewport.values) {
        await pumpMenuManagementHarness(
          tester,
          viewport: viewport,
          child: MenuModuleScaffold(
            navigationSlot: const SizedBox(width: 64),
            breadcrumbs: const <MenuBreadcrumb>[
              MenuBreadcrumb(label: 'Products'),
              MenuBreadcrumb(label: 'Iced Latte'),
              MenuBreadcrumb(label: 'Recipe'),
            ],
            child: const SizedBox.expand(
              child: ColoredBox(color: AppColors.surface),
            ),
          ),
        );

        expect(find.text('Products'), findsOneWidget);
        expect(find.text('Recipe'), findsOneWidget);
        expectNoMenuLayoutOverflow(tester);
      }
    },
  );

  testWidgets(
    'page header keeps one primary action and moves extras to overflow',
    (WidgetTester tester) async {
      var archived = false;
      await pumpMenuManagementHarness(
        tester,
        viewport: MenuDesktopViewport.desktop1280,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: MenuPageHeader(
            title: 'Iced Latte with a long manager-facing title',
            subtitle: 'Product configuration',
            secondaryActions: <Widget>[
              OutlinedButton(onPressed: () {}, child: const Text('Preview')),
            ],
            overflowActions: <MenuOverflowAction>[
              MenuOverflowAction(
                label: 'Archive product',
                onSelected: () => archived = true,
                icon: Icons.archive_outlined,
              ),
            ],
            primaryAction: ElevatedButton(
              onPressed: () {},
              child: const Text('Save Changes'),
            ),
          ),
        ),
      );

      expect(find.byType(ElevatedButton), findsOneWidget);
      expect(find.byType(OutlinedButton), findsOneWidget);
      await tester.tap(
        find.byTooltip(
          'More actions for Iced Latte with a long manager-facing title',
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Archive product'));
      expect(archived, isTrue);
      expectNoMenuLayoutOverflow(tester);
    },
  );

  testWidgets(
    'context bar protects context changes and keeps technical values LTR',
    (WidgetTester tester) async {
      final ValueNotifier<bool> mayLeave = ValueNotifier<bool>(false);
      var switches = 0;
      await pumpMenuManagementHarness(
        tester,
        viewport: MenuDesktopViewport.desktop1440,
        child: ValueListenableBuilder<bool>(
          valueListenable: mayLeave,
          builder: (BuildContext context, bool _, Widget? child) => Padding(
            padding: const EdgeInsets.all(16),
            child: ContextBar(
              items: const <MenuContextItem>[
                MenuContextItem(
                  label: 'Product',
                  value: 'Extra-long iced pistachio latte',
                ),
                MenuContextItem(label: 'Branch', value: 'Downtown'),
                MenuContextItem(
                  label: 'SKU',
                  value: 'LATTE-618-AR',
                  isTechnical: true,
                ),
              ],
              changeContextLabel: 'Change context',
              onBeforeContextChange: () async => mayLeave.value,
              onRequestContextChange: (_) async => switches++,
            ),
          ),
        ),
      );

      await tester.tap(find.text('Change context'));
      expect(switches, 0);
      mayLeave.value = true;
      await tester.pump();
      await tester.tap(find.text('Change context'));
      expect(switches, 1);
      expect(
        tester.widget<Text>(find.text('LATTE-618-AR')).textDirection,
        TextDirection.ltr,
      );
      expectNoMenuLayoutOverflow(tester);
    },
  );

  testWidgets(
    'compact filter bar exposes filters, removable chips, and sorting',
    (WidgetTester tester) async {
      final TextEditingController controller = TextEditingController(
        text: 'latte',
      );
      var removed = false;
      var moreFilters = false;
      await pumpMenuManagementHarness(
        tester,
        viewport: MenuDesktopViewport.desktop1280,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: CompactFilterBar(
            searchLabel: 'Search products',
            searchController: controller,
            onSearchChanged: (_) {},
            quickFilters: <Widget>[
              FilterChip(
                label: const Text('Active'),
                selected: true,
                onSelected: (_) {},
              ),
            ],
            onMoreFilters: () => moreFilters = true,
            activeFilters: <ActiveMenuFilter>[
              ActiveMenuFilter(label: 'Coffee', onRemove: () => removed = true),
            ],
            sortAction: IconButton(
              tooltip: 'Sort products',
              onPressed: () {},
              icon: const Icon(Icons.sort),
            ),
          ),
        ),
      );

      await tester.tap(find.text('More filters'));
      await tester.tap(
        find.descendant(
          of: find.byType(InputChip),
          matching: find.byIcon(Icons.close),
        ),
      );
      expect(moreFilters, isTrue);
      expect(removed, isTrue);
      expect(find.text('Search products'), findsOneWidget);
      expectNoMenuLayoutOverflow(tester);
    },
  );

  testWidgets('entity rows reduce metrics at 1280 and retain them at 1440', (
    WidgetTester tester,
  ) async {
    final EntityListRow row = EntityListRow(
      leading: const CircleAvatar(child: Icon(Icons.local_cafe)),
      title: 'Iced Latte',
      summary: 'Coffee · Station bar · 3 variants',
      metrics: const <EntityMetric>[
        EntityMetric(label: 'Base price', value: '3.50 SYP'),
      ],
      status: const EntityStatus(
        label: 'Active',
        icon: Icons.check_circle,
        color: AppColors.success,
      ),
      actions: <EntityRowAction>[
        EntityRowAction(
          label: 'Edit',
          onSelected: () {},
          icon: Icons.edit_outlined,
        ),
      ],
    );
    await pumpMenuManagementHarness(
      tester,
      viewport: MenuDesktopViewport.desktop1280,
      child: Padding(padding: const EdgeInsets.all(16), child: row),
    );
    expect(find.text('Base price'), findsNothing);
    expect(find.text('Active'), findsOneWidget);
    expectNoMenuLayoutOverflow(tester);

    await pumpMenuManagementHarness(
      tester,
      viewport: MenuDesktopViewport.desktop1440,
      child: Padding(padding: const EdgeInsets.all(16), child: row),
    );
    expect(find.text('Base price'), findsOneWidget);
    expectNoMenuLayoutOverflow(tester);
  });

  testWidgets(
    'sections, disclosure, empty state, and sticky actions expose clear states',
    (WidgetTester tester) async {
      var saved = 0;
      var recovered = false;
      await pumpMenuManagementHarness(
        tester,
        viewport: MenuDesktopViewport.desktop1920,
        child: Column(
          children: <Widget>[
            ContentSection(
              title: 'Selling and preparation',
              description: 'Core product settings',
              trailingAction: TextButton(
                onPressed: () {},
                child: const Text('Manage'),
              ),
              child: const Text('Base price'),
            ),
            const SizedBox(height: 12),
            const DetailsDisclosure(
              title: 'Technical Details',
              child: Text('Checksum: A1B2C3'),
            ),
            Expanded(
              child: EmptyState(
                title: 'No products found',
                message: 'Try clearing filters or create a product.',
                recoveryAction: EmptyStateAction(
                  label: 'Clear filters',
                  onPressed: () => recovered = true,
                ),
                primaryAction: EmptyStateAction(
                  label: 'Create Product',
                  onPressed: () {},
                ),
              ),
            ),
            StickyFormActions(
              cancelLabel: 'Cancel',
              onCancel: () {},
              primaryLabel: 'Save Changes',
              onSave: () async => saved++,
              isDirty: true,
              validationSummary: const <String>['Name is required.'],
            ),
          ],
        ),
      );

      await tester.tap(find.text('Technical Details'));
      await tester.pumpAndSettle();
      expect(find.text('Checksum: A1B2C3'), findsOneWidget);
      await tester.tap(find.text('Clear filters'));
      await tester.tap(find.text('Save Changes'));
      expect(recovered, isTrue);
      expect(saved, 1);
      expect(find.text('Unsaved changes'), findsOneWidget);
      expectNoMenuLayoutOverflow(tester);
    },
  );

  testWidgets('content sections keep interactive list tiles visible', (
    WidgetTester tester,
  ) async {
    var tapped = false;
    await pumpMenuManagementHarness(
      tester,
      viewport: MenuDesktopViewport.desktop1280,
      child: ContentSection(
        title: 'Usage',
        child: ListTile(
          title: const Text('Downtown menu'),
          onTap: () => tapped = true,
        ),
      ),
    );

    expect(tester.takeException(), isNull);
    await tester.tap(find.text('Downtown menu'));
    expect(tapped, isTrue);
    expectNoMenuLayoutOverflow(tester);
  });

  testWidgets('foundations mirror Arabic RTL content with long labels', (
    WidgetTester tester,
  ) async {
    await pumpMenuManagementHarness(
      tester,
      viewport: MenuDesktopViewport.desktop1280,
      locale: const Locale('ar'),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            MenuPageHeader(
              title: 'إدارة منتج القهوة المثلجة بالحليب النباتي',
              subtitle: 'إعدادات المنتج والفرع وقناة البيع',
              primaryAction: ElevatedButton(
                onPressed: () {},
                child: const Text('حفظ التغييرات'),
              ),
            ),
            const SizedBox(height: 16),
            const ContextBar(
              items: <MenuContextItem>[
                MenuContextItem(
                  label: 'المنتج',
                  value: 'لاتيه مثلج بالفستق مع حليب الشوفان',
                ),
                MenuContextItem(
                  label: 'رمز الصنف',
                  value: 'SKU-618-AR',
                  isTechnical: true,
                ),
              ],
            ),
            const SizedBox(height: 16),
            const DetailsDisclosure(
              title: 'التفاصيل التقنية',
              child: Text('المعرف: 618-AR'),
            ),
          ],
        ),
      ),
    );

    expectMenuTextDirection(tester, find.byType(ContextBar), TextDirection.rtl);
    expect(
      tester.widget<Text>(find.text('SKU-618-AR')).textDirection,
      TextDirection.ltr,
    );
    expect(find.text('حفظ التغييرات'), findsOneWidget);
    expectNoMenuLayoutOverflow(tester);
  });
}

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:windows_application/core/theme/app_theme.dart';
import 'package:windows_application/features/menu_management/models/catalog_models.dart';
import 'package:windows_application/features/menu_management/models/product_catalog_filter.dart';
import 'package:windows_application/features/menu_management/modifiers/controllers/modifier_group_detail_cubit.dart';
import 'package:windows_application/features/menu_management/modifiers/models/modifier_editor_drafts.dart';
import 'package:windows_application/features/menu_management/modifiers/models/modifier_models.dart';
import 'package:windows_application/features/menu_management/modifiers/views/modifier_group_detail_screen.dart';
import 'package:windows_application/features/menu_management/repositories/menu_catalog_repository.dart';
import 'package:windows_application/features/menu_management/products/models/product_editor_draft.dart';
import 'package:windows_application/l10n/app_localizations.dart';

void main() {
  testWidgets('Add Option accepts a negative price adjustment', (tester) async {
    tester.view.physicalSize = const Size(1280, 900);
    tester.view.devicePixelRatio = 1;
    final _OptionRepository repository = _OptionRepository();
    await tester.pumpWidget(_app(repository));
    await tester.pumpAndSettle();

    final Finder addOption = find.byKey(
      const Key('add-modifier-option-action'),
    );
    await tester.ensureVisible(addOption);
    await tester.tap(addOption);
    await tester.pump();
    await tester.enterText(find.byType(TextFormField).first, 'Discounted side');
    await tester.enterText(find.byType(TextFormField).at(1), '-0.50');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    expect(repository.createdDraft?.priceDelta, '-0.50');
    expect(find.text('Enter a valid price adjustment.'), findsNothing);
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });

  testWidgets('Edit Option accepts a negative price adjustment', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1280, 900);
    tester.view.devicePixelRatio = 1;
    final _OptionRepository repository = _OptionRepository();
    await tester.pumpWidget(_app(repository));
    await tester.pumpAndSettle();

    final Finder optionMenu = find.byType(PopupMenuButton<String>);
    await tester.ensureVisible(optionMenu);
    await tester.tap(optionMenu);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Edit Option'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField).at(1), '-0.50');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    expect(repository.updatedDraft?.priceDelta, '-0.50');
    expect(find.text('Enter a valid price adjustment.'), findsNothing);
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });
}

Widget _app(_OptionRepository repository) => MaterialApp(
  theme: AppTheme.lightTheme,
  supportedLocales: AppLocalizations.supportedLocales,
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  home: Scaffold(
    body: BlocProvider(
      create: (_) => ModifierGroupDetailCubit(repository: repository),
      child: const ModifierGroupDetailScreen(groupId: 1),
    ),
  ),
);

class _OptionRepository extends MenuCatalogRepository {
  _OptionRepository()
    : group = ModifierGroupRecord.fromJson(<String, dynamic>{
        'id': 1,
        'name': 'Milk choices',
        'groupType': 'choice',
        'selectionType': 'single',
        'isRequired': false,
        'minSelections': 0,
        'maxSelections': 1,
        'allowQuantity': false,
        'isActive': true,
        'sortOrder': 0,
        'optionCount': 1,
        'options': <Map<String, dynamic>>[
          <String, dynamic>{
            'id': 11,
            'modifierGroupId': 1,
            'name': 'Existing',
            'priceDelta': 0.75,
            'isDefault': false,
            'isActive': true,
            'isAvailable': true,
            'sortOrder': 0,
          },
        ],
      });

  ModifierGroupRecord group;
  ModifierOptionDraft? createdDraft;
  ModifierOptionDraft? updatedDraft;

  @override
  Future<CatalogPage<ProductSummary>> listProducts({
    required ProductCatalogFilter filter,
    required int page,
    int perPage = 20,
  }) => throw UnimplementedError();

  @override
  Future<ProductDetail> getProduct(
    int productId, {
    bool includeArchived = false,
  }) => throw UnimplementedError();

  @override
  Future<ProductDetail> createProduct(ProductEditorDraft draft) =>
      throw UnimplementedError();

  @override
  Future<ProductDetail> updateProductGeneral(
    int productId,
    ProductEditorDraft draft,
  ) => throw UnimplementedError();

  @override
  Future<CatalogPage<CatalogCategory>> listCategories({int perPage = 100}) =>
      throw UnimplementedError();

  @override
  Future<CatalogPage<ReportingCategory>> listReportingCategories({
    int perPage = 100,
  }) => throw UnimplementedError();

  @override
  Future<CatalogPage<KitchenStation>> listKitchenStations({
    int perPage = 100,
  }) => throw UnimplementedError();

  @override
  Future<ModifierGroupRecord> getModifierGroup(
    int groupId, {
    bool includeArchived = false,
  }) async => group;

  @override
  Future<ModifierOptionRecord> createModifierOption(
    int groupId,
    ModifierOptionDraft draft,
  ) async {
    createdDraft = draft;
    return _option(12, draft);
  }

  @override
  Future<ModifierOptionRecord> updateModifierOption(
    int optionId,
    ModifierOptionDraft draft,
  ) async {
    updatedDraft = draft;
    return _option(optionId, draft);
  }

  ModifierOptionRecord _option(int id, ModifierOptionDraft draft) =>
      ModifierOptionRecord.fromJson(<String, dynamic>{
        'id': id,
        'modifierGroupId': 1,
        'name': draft.name,
        'priceDelta': draft.priceDelta,
        'isDefault': draft.isDefault,
        'isActive': draft.isActive,
        'isAvailable': draft.isAvailable,
        'sortOrder': draft.sortOrder,
      });
}

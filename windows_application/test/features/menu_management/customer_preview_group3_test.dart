import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:windows_application/app/localization/app_locale_cubit.dart';
import 'package:windows_application/core/network/dio_api_client.dart';
import 'package:windows_application/features/menu_management/assignments/models/menu_assignment_models.dart';
import 'package:windows_application/features/menu_management/menus/models/menu_models.dart';
import 'package:windows_application/features/menu_management/repositories/menu_catalog_repository.dart';
import 'package:windows_application/features/menu_management/review/controllers/menu_review_cubit.dart';
import 'package:windows_application/features/menu_management/review/models/review_models.dart';
import 'package:windows_application/features/menu_management/review/views/menu_review_screen.dart';
import 'package:windows_application/features/pos/models/branch.dart';
import 'package:windows_application/l10n/app_localizations.dart';

void main() {
  test('preview request uses only the supported collection contract', () {
    final ReviewContext context = ReviewContext(
      branchId: 7,
      channel: 'pos',
      language: 'ar',
      includeHidden: true,
      includeUnavailable: false,
      evaluationAt: DateTime.utc(2026, 8, 27, 9),
    );

    expect(context.previewJson(), <String, dynamic>{
      'branchId': 7,
      'channel': 'pos',
      'language': 'ar',
      'includeHidden': true,
      'includeUnavailable': false,
      'at': '2026-08-27T09:00:00.000Z',
    });
    expect(context.previewJson().keys, isNot(contains('timezone')));
    expect(context.previewJson().keys, isNot(contains('versionId')));
    expect(context.previewJson().keys, isNot(contains('assignmentIds')));
  });

  testWidgets('Preview is lazy and control changes make one bounded request', (
    WidgetTester tester,
  ) async {
    final _PreviewRepository repository = _PreviewRepository();
    final MenuReviewCubit cubit = MenuReviewCubit(repository: repository);
    await _pumpReview(tester, cubit);

    expect(repository.previewContexts, isEmpty);
    await tester.tap(find.text('Preview'));
    await tester.pump();
    expect(repository.previewContexts, hasLength(1));
    await tester.pumpAndSettle();

    expect(find.text('Breakfast Menu'), findsOneWidget);
    expect(find.text('Main Menu'), findsOneWidget);
    expect(find.text('Espresso'), findsOneWidget);
    expect(find.text('Iced Latte'), findsOneWidget);

    await tester.tap(find.byKey(const Key('preview-hidden-toggle')));
    await tester.pump();
    expect(repository.previewContexts, hasLength(2));
    expect(repository.previewContexts.last.includeHidden, isTrue);
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('preview-unavailable-toggle')));
    await tester.pump();
    expect(repository.previewContexts, hasLength(3));
    expect(repository.previewContexts.last.includeUnavailable, isFalse);

    cubit.setLanguage('ar');
    await cubit.preview();
    expect(repository.previewContexts, hasLength(4));
    expect(repository.previewContexts.last.language, 'ar');
    expect(repository.productDetailCalls, 0);
    expect(repository.variantDetailCalls, 0);
    expect(repository.availabilityCalls, 0);
  });

  testWidgets('Preview renders backend hierarchy and compact disclosures', (
    WidgetTester tester,
  ) async {
    final _PreviewRepository repository = _PreviewRepository();
    final MenuReviewCubit cubit = MenuReviewCubit(repository: repository);
    await _pumpReview(tester, cubit);
    await tester.tap(find.text('Preview'));
    await tester.pumpAndSettle();

    expect(find.text('Sold out'), findsOneWidget);
    expect(find.textContaining('12'), findsAtLeastNWidgets(1));
    await tester.tap(find.byKey(const Key('preview-product-10-101')));
    await tester.pumpAndSettle();
    expect(find.text('Large'), findsOneWidget);
    expect(find.text('Modifiers'), findsOneWidget);
    await tester.tap(find.text('Modifiers'));
    await tester.pumpAndSettle();
    expect(find.text('Extra shot'), findsOneWidget);
  });

  testWidgets('Preview no-menu and local error states do not replace Review', (
    WidgetTester tester,
  ) async {
    final _PreviewRepository repository = _PreviewRepository()..noMenus = true;
    final MenuReviewCubit cubit = MenuReviewCubit(repository: repository);
    await _pumpReview(tester, cubit);
    await tester.tap(find.text('Preview'));
    await tester.pumpAndSettle();

    expect(find.text('No Menus to preview'), findsOneWidget);
    expect(find.text('Go to Assignments'), findsOneWidget);
    expect(find.text('Readiness'), findsOneWidget);
  });

  testWidgets('Preview failure is local and Retry makes one new request', (
    WidgetTester tester,
  ) async {
    final _PreviewRepository repository = _PreviewRepository()
      ..failNextPreview = true;
    final MenuReviewCubit cubit = MenuReviewCubit(repository: repository);
    await _pumpReview(tester, cubit);
    await tester.tap(find.text('Preview'));
    await tester.pumpAndSettle();

    expect(find.text('Could not load Preview.'), findsOneWidget);
    expect(find.text('Readiness'), findsOneWidget);
    await tester.tap(find.text('Retry'));
    await tester.pumpAndSettle();

    expect(repository.previewContexts, hasLength(2));
    expect(find.text('Breakfast Menu'), findsOneWidget);
  });

  testWidgets('Preview fits the supported desktop widths', (
    WidgetTester tester,
  ) async {
    final MenuReviewCubit cubit = MenuReviewCubit(
      repository: _PreviewRepository(),
    );
    await _pumpReview(tester, cubit);
    await tester.tap(find.text('Preview'));
    await tester.pumpAndSettle();

    for (final Size size in <Size>[
      const Size(1280, 900),
      const Size(1440, 900),
      const Size(1920, 1080),
    ]) {
      await tester.binding.setSurfaceSize(size);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    }
  });
}

Future<void> _pumpReview(WidgetTester tester, MenuReviewCubit cubit) async {
  await tester.binding.setSurfaceSize(const Size(1280, 900));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.pumpWidget(
    MaterialApp(
      locale: AppLocaleCubit.english,
      supportedLocales: AppLocaleCubit.supportedLocales,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      home: BlocProvider<MenuReviewCubit>.value(
        value: cubit,
        child: const Scaffold(body: MenuReviewScreen()),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

class _PreviewRepository extends BackendMenuCatalogRepository {
  _PreviewRepository() : super(DioApiClient(dio: Dio(BaseOptions())));

  final List<ReviewContext> previewContexts = <ReviewContext>[];
  bool noMenus = false;
  bool failNextPreview = false;
  int productDetailCalls = 0;
  int variantDetailCalls = 0;
  int availabilityCalls = 0;

  @override
  Future<List<Branch>> listAssignmentBranches() async => const <Branch>[
    Branch(
      id: 1,
      name: 'Downtown',
      currency: 'SYP',
      timezone: 'Asia/Damascus',
      isActive: true,
    ),
  ];

  @override
  Future<List<MenuAssignment>> listMenuAssignments({
    required int branchId,
    required String channel,
  }) async => <MenuAssignment>[
    MenuAssignment(
      id: 1,
      menuId: 10,
      branchId: branchId,
      channel: channel,
      priority: 0,
      isActive: true,
      createdAt: null,
      updatedAt: null,
      menu: MenuRecord.fromJson(<String, dynamic>{
        'id': 10,
        'name': 'Breakfast Menu',
      }),
    ),
  ];

  @override
  Future<MenuValidationResult> validateMenuCollection(
    ReviewContext context,
  ) async => MenuValidationResult.fromJson(<String, dynamic>{
    'isValid': true,
    'errorCount': 0,
    'warningCount': 0,
    'informationCount': 0,
    'errors': const <Object>[],
    'warnings': const <Object>[],
    'information': const <Object>[],
  });

  @override
  Future<ResolvedPreview> previewMenuCollection(ReviewContext context) async {
    previewContexts.add(context);
    if (failNextPreview) {
      failNextPreview = false;
      throw StateError('Preview failed.');
    }
    return ResolvedPreview.fromJson(_previewJson(noMenus: noMenus));
  }

  @override
  Future<ResolvedPreview> previewMenu(int menuId, ReviewContext context) =>
      previewMenuCollection(context);

  @override
  Future<PublishedMenuVersion?> getCurrentPublishedVersion(
    ReviewContext context,
  ) async => null;
}

Map<String, dynamic> _previewJson({required bool noMenus}) => <String, dynamic>{
  'canPublish': true,
  'context': <String, dynamic>{
    'branchId': 1,
    'channel': 'pos',
    'language': 'default',
    'evaluatedAt': '2026-08-27T09:00:00+03:00',
    'timezone': 'Asia/Damascus',
  },
  'validation': <String, dynamic>{
    'errorCount': noMenus ? 1 : 0,
    'warnings': const <Object>[],
    'information': const <Object>[],
    'errors': noMenus
        ? <Map<String, dynamic>>[
            <String, dynamic>{
              'code': 'NO_ASSIGNED_MENU',
              'severity': 'error',
              'message': 'No Menu is assigned.',
              'entityType': 'scope',
              'menuId': 0,
            },
          ]
        : const <Object>[],
  },
  'menus': noMenus
      ? const <Object>[]
      : <Map<String, dynamic>>[
          _menu(
            id: 10,
            name: 'Breakfast Menu',
            priority: 0,
            section: 'Hot Drinks',
            product: 'Espresso',
            placementId: 101,
            sellable: true,
          ),
          _menu(
            id: 20,
            name: 'Main Menu',
            priority: 1,
            section: 'Cold Drinks',
            product: 'Iced Latte',
            placementId: 201,
            sellable: false,
          ),
        ],
};

Map<String, dynamic> _menu({
  required int id,
  required String name,
  required int priority,
  required String section,
  required String product,
  required int placementId,
  required bool sellable,
}) => <String, dynamic>{
  'id': id,
  'name': name,
  'description': '$name description',
  'coverImageUrl': null,
  'priority': priority,
  'isAssigned': true,
  'isScheduledAvailable': true,
  'scheduleReason': 'matched_rule',
  'sections': <Map<String, dynamic>>[
    <String, dynamic>{
      'id': id * 10,
      'name': section,
      'description': '',
      'imageUrl': null,
      'sortOrder': 0,
      'products': <Map<String, dynamic>>[
        <String, dynamic>{
          'placementId': placementId,
          'productId': placementId + 1000,
          'name': product,
          'description': '',
          'imageUrl': null,
          'sortOrder': 0,
          'isFeatured': false,
          'isVisible': true,
          'isScheduledAvailable': true,
          'isOperationallyAvailable': sellable,
          'isSellable': sellable,
          'unavailabilityReasons': sellable
              ? const <Object>[]
              : <String>['product_sold_out'],
          'variants': <Map<String, dynamic>>[
            _variant(
              id: placementId + 1,
              name: 'Regular',
              isDefault: true,
              sellable: sellable,
            ),
            _variant(
              id: placementId + 2,
              name: 'Large',
              isDefault: false,
              sellable: sellable,
            ),
          ],
          'modifierGroups': <Map<String, dynamic>>[
            <String, dynamic>{
              'id': placementId + 10,
              'name': 'Extras',
              'groupType': 'single',
              'selectionType': 'multiple',
              'isRequired': false,
              'minSelections': 0,
              'maxSelections': 2,
              'allowQuantity': false,
              'sortOrder': 0,
              'options': <Map<String, dynamic>>[
                <String, dynamic>{
                  'id': placementId + 11,
                  'name': 'Extra shot',
                  'priceDelta': 2000,
                  'isDefault': false,
                  'isAvailable': true,
                  'sortOrder': 0,
                },
              ],
            },
          ],
        },
      ],
    },
  ],
};

Map<String, dynamic> _variant({
  required int id,
  required String name,
  required bool isDefault,
  required bool sellable,
}) => <String, dynamic>{
  'id': id,
  'name': name,
  'sku': null,
  'barcode': null,
  'sortOrder': id,
  'isDefault': isDefault,
  'basePrice': 10000,
  'effectivePrice': 12000,
  'matchedPriceScope': 'branch',
  'isScheduledAvailable': true,
  'isOperationallyAvailable': sellable,
  'isSellable': sellable,
  'unavailabilityReasons': sellable
      ? const <Object>[]
      : <String>['product_sold_out'],
  'recipeConfigured': true,
  'recipeComponentCount': 2,
};

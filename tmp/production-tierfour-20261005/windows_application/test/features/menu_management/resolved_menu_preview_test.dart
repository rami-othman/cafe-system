import 'dart:async';

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
  test(
    'review context sanitizes unsupported input and handles no assigned menus',
    () async {
      final _ReviewRepository repository = _ReviewRepository()
        ..assignments = const <MenuAssignment>[];
      final MenuReviewCubit cubit = MenuReviewCubit(repository: repository);

      await cubit.load(
        branchId: 999,
        channel: 'not-a-channel',
        menuId: 999,
        evaluationAt: DateTime.parse('2026-08-01T10:00:00Z'),
      );

      expect(cubit.state.contextStatus, ReviewLoadStatus.ready);
      expect(cubit.state.selectedBranch?.id, 1);
      expect(cubit.state.channel, 'pos');
      expect(cubit.state.menuId, 999);
      expect(cubit.state.eligibleMenus, isEmpty);
      expect(cubit.state.context?.validationJson(), <String, dynamic>{
        'branchId': 1,
        'channel': 'pos',
        'at': '2026-08-01T10:00:00.000Z',
      });
    },
  );

  test(
    'review requests are deduplicated, stale responses are ignored, and failures remain independent',
    () async {
      final _ReviewRepository repository = _ReviewRepository();
      final MenuReviewCubit cubit = MenuReviewCubit(repository: repository);
      await cubit.load(menuId: 10);

      repository.validationCalls = 0;
      final Completer<MenuValidationResult> validation =
          Completer<MenuValidationResult>();
      repository.validationLoader = (_) => validation.future;
      final Future<void> firstValidation = cubit.validate();
      await cubit.validate();
      expect(repository.validationCalls, 1);
      validation.complete(_validation(canPublish: false));
      await firstValidation;
      expect(cubit.state.validation?.canPublish, isFalse);

      final Completer<ResolvedPreview> stalePreview =
          Completer<ResolvedPreview>();
      repository.previewLoader = (_) => stalePreview.future;
      final Future<void> firstPreview = cubit.preview();
      cubit.setLanguage('ar');
      stalePreview.complete(_preview());
      await firstPreview;
      expect(cubit.state.preview, isNull);
      expect(cubit.state.previewStatus, ReviewRequestStatus.idle);

      repository.previewLoader = (_) =>
          Future<ResolvedPreview>.error(StateError('backend unavailable'));
      await cubit.preview();
      expect(cubit.state.previewStatus, ReviewRequestStatus.failure);
      expect(cubit.state.validation?.canPublish, isFalse);

      repository.previewLoader = (_) =>
          Future<ResolvedPreview>.value(_preview());
      await cubit.preview();
      expect(cubit.state.previewStatus, ReviewRequestStatus.loaded);
      expect(
        cubit.state.preview?.menus.single.sections.single.products.single.name,
        'Latte',
      );
    },
  );

  test(
    'validation filters retain unknown codes and filter by severity, entity, and search',
    () async {
      final _ReviewRepository repository = _ReviewRepository()
        ..validationLoader = (_) => Future<MenuValidationResult>.value(
          MenuValidationResult.fromJson(<String, dynamic>{
            'isValid': true,
            'errorCount': 0,
            'warningCount': 1,
            'informationCount': 1,
            'errors': const <Object>[],
            'warnings': <Map<String, dynamic>>[
              _issue('warning', 'FUTURE_CODE'),
            ],
            'information': <Map<String, dynamic>>[
              _issue('information', 'DETAIL'),
            ],
          }),
        );
      final MenuReviewCubit cubit = MenuReviewCubit(repository: repository);
      await cubit.load(menuId: 10);
      await cubit.validate();

      cubit.setIssueFilters(
        severity: ValidationSeverity.warning,
        entityType: 'placement',
        search: 'future',
      );
      expect(cubit.state.filteredIssues.single.code, 'FUTURE_CODE');
      expect(cubit.state.validation?.canPublish, isTrue);
    },
  );

  testWidgets(
    'review screen remains stable in Arabic RTL without a live backend',
    (WidgetTester tester) async {
      final MenuReviewCubit cubit = MenuReviewCubit(
        repository: _ReviewRepository(),
      );
      await tester.pumpWidget(
        MaterialApp(
          locale: AppLocaleCubit.arabic,
          supportedLocales: AppLocaleCubit.supportedLocales,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          home: BlocProvider<MenuReviewCubit>.value(
            value: cubit,
            child: const Scaffold(body: MenuReviewScreen()),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(
        Directionality.of(tester.element(find.byType(MenuReviewScreen))),
        TextDirection.rtl,
      );
      expect(find.text('مراجعة ونشر'), findsAtLeastNWidgets(1));
      expect(tester.takeException(), isNull);
    },
  );
}

class _ReviewRepository extends BackendMenuCatalogRepository {
  _ReviewRepository() : super(_client());

  List<MenuAssignment> assignments = <MenuAssignment>[_assignment()];
  Future<MenuValidationResult> Function(ReviewContext context)?
  validationLoader;
  Future<ResolvedPreview> Function(ReviewContext context)? previewLoader;
  int validationCalls = 0;

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
  }) async => assignments;

  @override
  Future<MenuValidationResult> validateMenu(int id, ReviewContext context) {
    validationCalls++;
    return validationLoader?.call(context) ??
        Future<MenuValidationResult>.value(_validation());
  }

  @override
  Future<MenuValidationResult> validateMenuCollection(ReviewContext context) {
    validationCalls++;
    return validationLoader?.call(context) ??
        Future<MenuValidationResult>.value(_validation());
  }

  @override
  Future<ResolvedPreview> previewMenu(int id, ReviewContext context) =>
      previewLoader?.call(context) ?? Future<ResolvedPreview>.value(_preview());

  @override
  Future<ResolvedPreview> previewMenuCollection(ReviewContext context) =>
      previewLoader?.call(context) ?? Future<ResolvedPreview>.value(_preview());

  @override
  Future<PublishedMenuVersion?> getCurrentPublishedVersion(
    ReviewContext context,
  ) => Future<PublishedMenuVersion?>.value(null);
}

MenuAssignment _assignment() => MenuAssignment(
  id: 5,
  menuId: 10,
  branchId: 1,
  channel: 'pos',
  priority: 0,
  isActive: true,
  createdAt: null,
  updatedAt: null,
  menu: MenuRecord.fromJson(<String, dynamic>{'id': 10, 'name': 'Main'}),
);

MenuValidationResult _validation({bool canPublish = true}) =>
    MenuValidationResult.fromJson(<String, dynamic>{
      'isValid': canPublish,
      'errorCount': canPublish ? 0 : 1,
      'warningCount': 0,
      'informationCount': 0,
      'errors': canPublish
          ? const <Object>[]
          : <Map<String, dynamic>>[_issue('error', 'BLOCKED')],
      'warnings': const <Object>[],
      'information': const <Object>[],
    });

ResolvedPreview _preview() => ResolvedPreview.fromJson(<String, dynamic>{
  'canPublish': false,
  'context': <String, dynamic>{
    'timezone': 'Asia/Damascus',
    'evaluatedAt': '2026-08-01T10:00:00+03:00',
  },
  'menus': <Map<String, dynamic>>[
    <String, dynamic>{
      'id': 10,
      'name': 'Main',
      'priority': 0,
      'isAssigned': true,
      'isScheduledAvailable': true,
      'scheduleReason': 'matched_rule',
      'sections': <Map<String, dynamic>>[
        <String, dynamic>{
          'name': 'Coffee',
          'sortOrder': 0,
          'products': <Map<String, dynamic>>[
            <String, dynamic>{
              'productId': 11,
              'name': 'Latte',
              'isVisible': true,
              'isScheduledAvailable': true,
              'isOperationallyAvailable': true,
              'isSellable': true,
              'variants': const <Object>[],
              'modifierGroups': const <Object>[],
            },
          ],
        },
      ],
    },
  ],
});

Map<String, dynamic> _issue(String severity, String code) => <String, dynamic>{
  'severity': severity,
  'code': code,
  'message': 'Message',
  'entityType': 'placement',
  'menuId': 10,
};

DioApiClient _client() =>
    DioApiClient(dio: Dio(BaseOptions(baseUrl: 'http://localhost/api/v1/')));

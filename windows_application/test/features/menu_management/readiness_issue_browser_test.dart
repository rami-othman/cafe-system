import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:windows_application/core/network/dio_api_client.dart';
import 'package:windows_application/features/menu_management/repositories/menu_catalog_repository.dart';
import 'package:windows_application/features/menu_management/review/controllers/menu_review_cubit.dart';
import 'package:windows_application/features/menu_management/review/models/review_models.dart';
import 'package:windows_application/features/menu_management/review/presentation/readiness_issue_filters.dart';
import 'package:windows_application/features/menu_management/review/presentation/validation_issue_presentation.dart';
import 'package:windows_application/features/pos/models/branch.dart';

void main() {
  final List<ValidationIssue> issues = <ValidationIssue>[
    _issue(
      code: 'MENU_NO_ACTIVE_SECTION',
      severity: 'error',
      entityType: 'menu',
      menuId: 10,
      message: 'Main Menu needs an active section.',
    ),
    _issue(
      code: 'PRODUCT_MISSING_ACTIVE_VARIANT',
      severity: 'error',
      entityType: 'product',
      entityId: 20,
      menuId: 10,
      message: 'Espresso needs an active variant.',
    ),
    _issue(
      code: 'PRODUCT_OUTSIDE_SCHEDULE',
      severity: 'warning',
      entityType: 'product',
      entityId: 21,
      menuId: 10,
      message: 'Latte is outside its schedule.',
    ),
  ];

  group('Readiness issue filters', () {
    test('All retains backend errors and warnings locally', () {
      expect(_filter(issues), hasLength(3));
    });

    test('Errors retains only backend error severity', () {
      final result = _filter(issues, severity: ValidationSeverity.error);
      expect(result, hasLength(2));
      expect(
        result.every((ValidationIssue issue) => issue.severity == 'error'),
        isTrue,
      );
    });

    test('Warnings retains only backend warning severity', () {
      final result = _filter(issues, severity: ValidationSeverity.warning);
      expect(result.single.code, 'PRODUCT_OUTSIDE_SCHEDULE');
    });

    test('search matches authoritative message and manager group title', () {
      expect(
        _filter(issues, search: 'espresso').single.code,
        'PRODUCT_MISSING_ACTIVE_VARIANT',
      );
      expect(
        _filter(issues, search: 'availability').single.code,
        'PRODUCT_OUTSIDE_SCHEDULE',
      );
    });

    test('a no-match search returns a compact local empty result', () {
      expect(_filter(issues, search: 'does not exist'), isEmpty);
    });

    test('filter and search mutations make no validation request', () async {
      final repository = _NoRequestRepository();
      final cubit = MenuReviewCubit(repository: repository);
      await cubit.load();
      expect(repository.validationCalls, 1);

      cubit.setIssueFilters(
        severity: ValidationSeverity.warning,
        search: 'latte',
      );
      cubit.setIssueFilters(clearSeverity: true, search: '');

      expect(repository.validationCalls, 1);
      expect(cubit.state.search, '');
      await cubit.close();
    });
  });

  group('Readiness presentation classification', () {
    test('classifies representative known codes centrally', () {
      expect(
        ValidationIssuePresentation.categoryFor(issues.first),
        ReadinessIssueCategory.sections,
      );
      expect(
        ValidationIssuePresentation.categoryFor(issues[1]),
        ReadinessIssueCategory.variants,
      );
      expect(
        ValidationIssuePresentation.categoryFor(
          _issue(code: 'VARIANT_INVALID_EFFECTIVE_PRICE'),
        ),
        ReadinessIssueCategory.pricing,
      );
      expect(
        ValidationIssuePresentation.categoryFor(
          _issue(code: 'VARIANT_RECIPE_MISSING'),
        ),
        ReadinessIssueCategory.recipesMaterials,
      );
      expect(
        ValidationIssuePresentation.categoryFor(
          _issue(code: 'MODIFIER_GROUP_ARCHIVED'),
        ),
        ReadinessIssueCategory.modifiers,
      );
      expect(
        ValidationIssuePresentation.categoryFor(issues.last),
        ReadinessIssueCategory.availability,
      );
    });

    test('scope no-menu is excluded from ordinary groups', () {
      final noMenu = _issue(code: 'NO_ASSIGNED_MENU', entityType: 'scope');
      expect(_filter(<ValidationIssue>[noMenu]), isEmpty);
      expect(
        ValidationIssuePresentation.actionFor(noMenu),
        ReadinessIssueAction.goToAssignments,
      );
    });

    test('unknown code stays visible under Other without a fake action', () {
      final unknown = _issue(
        code: 'FUTURE_BACKEND_CODE',
        entityType: 'product',
      );
      expect(
        ValidationIssuePresentation.categoryFor(unknown),
        ReadinessIssueCategory.other,
      );
      expect(
        ValidationIssuePresentation.actionFor(unknown),
        ReadinessIssueAction.none,
      );
    });

    test('navigation only uses supplied, supported context', () {
      expect(
        ValidationIssuePresentation.actionFor(
          _issue(code: 'MENU_ARCHIVED', entityType: 'menu', menuId: 10),
        ),
        ReadinessIssueAction.openMenu,
      );
      expect(
        ValidationIssuePresentation.actionFor(issues[1]),
        ReadinessIssueAction.openProduct,
      );
      expect(
        ValidationIssuePresentation.actionFor(
          _issue(code: 'VARIANT_RECIPE_MISSING', entityType: 'variant'),
        ),
        ReadinessIssueAction.none,
      );
    });

    test('group counts follow the active local result', () {
      final groups = groupReadinessIssues(_filter(issues, search: 'espresso'));
      expect(groups, hasLength(1));
      expect(groups.single.category, ReadinessIssueCategory.variants);
      expect(groups.single.issues, hasLength(1));
    });
  });
}

List<ValidationIssue> _filter(
  Iterable<ValidationIssue> values, {
  ValidationSeverity? severity,
  String search = '',
}) => filterReadinessIssues(
  values,
  severity: severity,
  search: search,
  categoryTitle: (ReadinessIssueCategory category) => category.name,
);

ValidationIssue _issue({
  required String code,
  String severity = 'error',
  String entityType = 'variant',
  int? entityId,
  int menuId = 0,
  String message = 'Backend message',
}) => ValidationIssue(
  code: code,
  severity: severity,
  message: message,
  entityType: entityType,
  entityId: entityId,
  menuId: menuId,
);

class _NoRequestRepository extends BackendMenuCatalogRepository {
  _NoRequestRepository()
    : super(DioApiClient(dio: Dio(BaseOptions(baseUrl: 'http://localhost/'))));

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
  Future<MenuValidationResult> validateMenuCollection(
    ReviewContext context,
  ) async {
    validationCalls++;
    return MenuValidationResult.fromJson(<String, dynamic>{
      'isValid': true,
      'errorCount': 0,
      'warningCount': 0,
      'informationCount': 0,
      'errors': const <Object>[],
      'warnings': const <Object>[],
      'information': const <Object>[],
    });
  }

  @override
  Future<PublishedMenuVersion?> getCurrentPublishedVersion(
    ReviewContext context,
  ) async => null;
}

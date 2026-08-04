import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:windows_application/core/network/api_exception.dart';
import 'package:windows_application/core/network/dio_api_client.dart';
import 'package:windows_application/features/menu_management/assignments/models/menu_assignment_models.dart';
import 'package:windows_application/features/menu_management/menus/models/menu_models.dart';
import 'package:windows_application/features/menu_management/repositories/menu_catalog_repository.dart';
import 'package:windows_application/features/menu_management/review/controllers/menu_review_cubit.dart';
import 'package:windows_application/features/menu_management/review/models/review_models.dart';
import 'package:windows_application/features/pos/models/branch.dart';

void main() {
  test(
    'publication models parse server version and no-change metadata safely',
    () {
      final MenuPublicationResult result = MenuPublicationResult.fromJson(
        <String, dynamic>{
          'published': false,
          'noChanges': true,
          'publicationId': 31,
          'version': _versionJson(status: 'future_status'),
          'validation': <String, dynamic>{
            'isValid': true,
            'errorCount': 0,
            'warningCount': 2,
            'informationCount': 1,
          },
        },
      );

      expect(result.noChanges, isTrue);
      expect(result.version.status, 'future_status');
      expect(result.validation.warningCount, 2);
    },
  );

  test(
    'publishing uses validated selected scope and refreshes current Version',
    () async {
      final _PublishingRepository repository = _PublishingRepository();
      final MenuReviewCubit cubit = MenuReviewCubit(repository: repository);

      await cubit.load(menuId: 10);
      await cubit.validate();
      await cubit.publish();

      expect(repository.publishedContexts, hasLength(1));
      expect(repository.publishedContexts.single.menuId, 10);
      expect(cubit.state.publicationStatus, PublicationActionStatus.success);
      expect(cubit.state.currentVersion?.versionNumber, 2);
    },
  );

  test(
    'stale current Version responses are ignored after scope changes',
    () async {
      final _PublishingRepository repository = _PublishingRepository();
      final Completer<PublishedMenuVersion?> stale =
          Completer<PublishedMenuVersion?>();
      repository.currentLoader = (_) => stale.future;
      final MenuReviewCubit cubit = MenuReviewCubit(repository: repository);

      unawaited(cubit.load());
      await Future<void>.delayed(Duration.zero);
      repository.currentLoader = (_) => Future<PublishedMenuVersion?>.value(
        PublishedMenuVersion.fromJson(_versionJson(version: 2)),
      );
      cubit.selectScope(10);
      await Future<void>.delayed(Duration.zero);
      stale.complete(PublishedMenuVersion.fromJson(_versionJson(version: 1)));
      await Future<void>.delayed(Duration.zero);

      expect(cubit.state.currentVersion?.versionNumber, isNot(1));
    },
  );

  test(
    'preview controls do not discard current Version for the same scope',
    () async {
      final _PublishingRepository repository = _PublishingRepository();
      final Completer<PublishedMenuVersion?> current =
          Completer<PublishedMenuVersion?>();
      repository.currentLoader = (_) => current.future;
      final MenuReviewCubit cubit = MenuReviewCubit(repository: repository);

      unawaited(cubit.load());
      await Future<void>.delayed(Duration.zero);
      cubit.setLanguage('ar');
      current.complete(PublishedMenuVersion.fromJson(_versionJson(version: 3)));
      await Future<void>.delayed(Duration.zero);

      expect(cubit.state.currentVersionStatus, ReviewRequestStatus.loaded);
      expect(cubit.state.currentVersion?.versionNumber, 3);
    },
  );

  test(
    'no-change and blocked publication states remain server authoritative',
    () async {
      final _PublishingRepository repository = _PublishingRepository();
      final MenuReviewCubit cubit = MenuReviewCubit(repository: repository);
      await cubit.load(menuId: 10);
      await cubit.validate();

      repository.publicationLoader = (_) =>
          Future<MenuPublicationResult>.value(_publication(noChanges: true));
      await cubit.publish();
      expect(cubit.state.publicationStatus, PublicationActionStatus.noChanges);
      expect(cubit.state.lastPublication?.published, isFalse);

      repository.validationLoader = (_) =>
          Future<MenuValidationResult>.value(_validation(canPublish: false));
      repository.publicationLoader = (_) => Future<MenuPublicationResult>.error(
        const ApiException(
          message: 'Menu validation failed.',
          statusCode: 422,
          validationErrors: <String, List<String>>{
            'publish': <String>['Menu validation failed.'],
          },
        ),
      );
      await cubit.publish();

      expect(
        cubit.state.publicationStatus,
        PublicationActionStatus.validationBlocked,
      );
      expect(cubit.state.validation?.canPublish, isFalse);
    },
  );

  test(
    'duplicate publishing is prevented while a request is in flight',
    () async {
      final _PublishingRepository repository = _PublishingRepository();
      final Completer<MenuPublicationResult> publication =
          Completer<MenuPublicationResult>();
      repository.publicationLoader = (_) => publication.future;
      final MenuReviewCubit cubit = MenuReviewCubit(repository: repository);
      await cubit.load(menuId: 10);
      await cubit.validate();

      unawaited(cubit.publish());
      unawaited(cubit.publish());
      await Future<void>.delayed(Duration.zero);
      expect(repository.publishedContexts, hasLength(1));
      publication.complete(_publication());
      await Future<void>.delayed(Duration.zero);
    },
  );

  test(
    'an unassigned or archived Menu cannot become the publishing scope',
    () async {
      final _PublishingRepository repository = _PublishingRepository();
      final MenuReviewCubit cubit = MenuReviewCubit(repository: repository);
      await cubit.load(menuId: 10);

      cubit.selectScope(999);
      expect(cubit.state.menuId, 10);

      repository.assignments = <MenuAssignment>[_assignment(archived: true)];
      await cubit.load(menuId: 10);
      expect(cubit.state.menuId, isNull);
      expect(cubit.state.eligibleMenus, isEmpty);
    },
  );
}

class _PublishingRepository extends BackendMenuCatalogRepository {
  _PublishingRepository()
    : super(
        DioApiClient(
          dio: Dio(BaseOptions(baseUrl: 'http://localhost/api/v1/')),
        ),
      );

  final List<ReviewContext> publishedContexts = <ReviewContext>[];
  List<MenuAssignment> assignments = <MenuAssignment>[_assignment()];
  Future<PublishedMenuVersion?> Function(ReviewContext context)? currentLoader;
  Future<MenuPublicationResult> Function(ReviewContext context)?
  publicationLoader;
  Future<MenuValidationResult> Function(ReviewContext context)?
  validationLoader;

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
  Future<MenuValidationResult> validateMenu(int id, ReviewContext context) =>
      validationLoader?.call(context) ??
      Future<MenuValidationResult>.value(_validation());

  @override
  Future<MenuValidationResult> validateMenuCollection(ReviewContext context) =>
      validationLoader?.call(context) ??
      Future<MenuValidationResult>.value(_validation());

  @override
  Future<MenuPublicationResult> publishMenuScope(ReviewContext context) async {
    publishedContexts.add(context);
    return publicationLoader?.call(context) ?? _publication();
  }

  @override
  Future<PublishedMenuVersion?> getCurrentPublishedVersion(
    ReviewContext context,
  ) =>
      currentLoader?.call(context) ??
      Future<PublishedMenuVersion?>.value(
        PublishedMenuVersion.fromJson(_versionJson(version: 2)),
      );
}

MenuValidationResult _validation({bool canPublish = true}) =>
    MenuValidationResult.fromJson(<String, dynamic>{
      'isValid': canPublish,
      'errorCount': canPublish ? 0 : 1,
      'warningCount': 0,
      'informationCount': 0,
    });

MenuPublicationResult _publication({bool noChanges = false}) =>
    MenuPublicationResult.fromJson(<String, dynamic>{
      'published': !noChanges,
      'noChanges': noChanges,
      'publicationId': 32,
      'version': _versionJson(version: 2),
      'validation': <String, dynamic>{
        'isValid': true,
        'errorCount': 0,
        'warningCount': 0,
        'informationCount': 0,
      },
    });

Map<String, dynamic> _versionJson({
  int version = 1,
  String status = 'current',
}) => <String, dynamic>{
  'id': version,
  'versionNumber': version,
  'checksum': 'a' * 64,
  'status': status,
  'branchId': 1,
  'channel': 'pos',
  'publishedAt': '2026-08-02T10:00:00+03:00',
  'publicationId': 31,
};

MenuAssignment _assignment({bool archived = false}) => MenuAssignment(
  id: 1,
  menuId: 10,
  branchId: 1,
  channel: 'pos',
  priority: 0,
  isActive: true,
  createdAt: null,
  updatedAt: null,
  menu: MenuRecord.fromJson(<String, dynamic>{
    'id': 10,
    'name': 'Main',
    if (archived) 'archivedAt': '2026-08-01T00:00:00Z',
  }),
);

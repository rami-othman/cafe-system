import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:windows_application/core/network/api_exception.dart';
import 'package:windows_application/core/network/dio_api_client.dart';
import 'package:windows_application/features/menu_management/repositories/menu_catalog_repository.dart';
import 'package:windows_application/features/menu_management/review/models/review_models.dart';
import 'package:windows_application/features/menu_management/versions/controllers/published_version_cubit.dart';
import 'package:windows_application/features/menu_management/versions/models/published_version_models.dart';

void main() {
  group('PublishedVersionCubit history lifecycle', () {
    test(
      'loads one bounded metadata-only history request for its scope',
      () async {
        final repository = _VersionsRepository();
        final cubit = PublishedVersionCubit(repository: repository);

        await cubit.setContext(1, 'pos');

        expect(cubit.state.historyStatus, VersionRequestStatus.loaded);
        expect(cubit.state.history?.items.map((item) => item.id), <int>[3, 2]);
        expect(cubit.state.history?.items.first.isCurrent, isTrue);
        expect(repository.historyCalls, <_HistoryCall>[
          _HistoryCall(1, 'pos', 1),
        ]);
      },
    );

    test('scope changes reset to page one and ignore stale history', () async {
      final repository = _VersionsRepository();
      final stale = Completer<PublishedVersionPage>();
      repository.historyLoader = (_, _, _) => stale.future;
      final cubit = PublishedVersionCubit(repository: repository);

      unawaited(cubit.setContext(1, 'pos'));
      await Future<void>.delayed(Duration.zero);
      repository.historyLoader = (_, _, page) =>
          Future<PublishedVersionPage>.value(
            _page(page, <PublishedVersion>[_version(8)]),
          );
      await cubit.setContext(2, 'online');
      stale.complete(_page(1, <PublishedVersion>[_version(99)]));
      await Future<void>.delayed(Duration.zero);

      expect(cubit.state.scopeKey, '2|online');
      expect(cubit.state.history?.page, 1);
      expect(cubit.state.history?.items.single.id, 8);
    });

    test(
      'pagination, refresh, empty response and backend ordering are preserved',
      () async {
        final repository = _VersionsRepository();
        repository.historyLoader = (_, _, page) =>
            Future<PublishedVersionPage>.value(
              page == 1
                  ? _page(1, <PublishedVersion>[
                      _version(7),
                      _version(4),
                    ], total: 3)
                  : _page(2, <PublishedVersion>[_version(1)], total: 3),
            );
        final cubit = PublishedVersionCubit(repository: repository);

        await cubit.setContext(1, 'pos');
        await cubit.nextPage();
        await cubit.previousPage();
        await cubit.refresh();

        expect(repository.historyCalls.map((call) => call.page), <int>[
          1,
          2,
          1,
          1,
        ]);
        expect(cubit.state.history?.items.map((item) => item.id), <int>[7, 4]);

        repository.historyLoader = (_, _, page) =>
            Future<PublishedVersionPage>.value(
              _page(page, const <PublishedVersion>[]),
            );
        await cubit.refresh();
        expect(cubit.state.history?.items, isEmpty);
      },
    );

    test(
      'duplicate history load is prevented and failure retains loaded history',
      () async {
        final repository = _VersionsRepository();
        final pending = Completer<PublishedVersionPage>();
        final cubit = PublishedVersionCubit(repository: repository);
        await cubit.setContext(1, 'pos');
        final history = cubit.state.history;
        repository.historyLoader = (_, _, _) => pending.future;

        unawaited(cubit.refresh());
        unawaited(cubit.refresh());
        await Future<void>.delayed(Duration.zero);
        expect(repository.historyCalls, hasLength(2));
        pending.completeError(
          const ApiException(message: 'History unavailable'),
        );
        await Future<void>.delayed(Duration.zero);

        expect(cubit.state.historyStatus, VersionRequestStatus.failure);
        expect(cubit.state.history, history);
        expect(cubit.state.historyError, 'History unavailable');
      },
    );
  });

  group('PublishedVersionCubit detail and comparison', () {
    test(
      'detail is opt-in and payload failure preserves detail metadata',
      () async {
        final repository = _VersionsRepository();
        final cubit = PublishedVersionCubit(repository: repository);
        await cubit.setContext(1, 'pos');
        final version = cubit.state.history!.items.last;

        await cubit.openDetail(version);
        expect(repository.detailCalls, <_DetailCall>[
          _DetailCall(version.id, false),
        ]);
        expect(cubit.state.detail?.payload, isNull);
        final detail = cubit.state.detail;

        repository.detailLoader = (_, includePayload) => includePayload
            ? Future<PublishedVersionDetail>.error(
                const ApiException(message: 'Payload unavailable'),
              )
            : Future<PublishedVersionDetail>.value(_detail(version));
        await cubit.loadPayload();

        expect(repository.detailCalls.last, _DetailCall(version.id, true));
        expect(cubit.state.payloadStatus, VersionRequestStatus.failure);
        expect(cubit.state.detail, detail);
      },
    );

    test(
      'comparison is backend-owned, stale-safe, and de-duplicated',
      () async {
        final repository = _VersionsRepository();
        final pending = Completer<VersionComparison>();
        final cubit = PublishedVersionCubit(repository: repository);
        await cubit.setContext(1, 'pos');
        final newest = cubit.state.history!.items.first;
        final oldest = cubit.state.history!.items.last;
        cubit.toggleComparisonSelection(newest);
        cubit.toggleComparisonSelection(oldest);
        cubit.toggleComparisonSelection(_version(1));
        expect(cubit.state.comparisonSelection, <PublishedVersion>[
          newest,
          oldest,
        ]);
        repository.comparisonLoader = (_, _) => pending.future;

        unawaited(cubit.compareSelected());
        unawaited(cubit.compareSelected());
        await Future<void>.delayed(Duration.zero);
        expect(repository.comparisonCalls, <_ComparisonCall>[
          _ComparisonCall(oldest.id, newest.id),
        ]);
        await cubit.setContext(2, 'online');
        pending.complete(_comparison());
        await Future<void>.delayed(Duration.zero);
        expect(cubit.state.comparison, isNull);
      },
    );
  });

  group('PublishedVersionCubit rollback', () {
    test('does not allow a current Version to enter rollback', () async {
      final repository = _VersionsRepository();
      final cubit = PublishedVersionCubit(repository: repository);
      await cubit.setContext(1, 'pos');
      cubit.beginRollback(_version(3, current: true));
      await cubit.rollback('not allowed');
      expect(repository.rollbackCalls, isEmpty);
      expect(cubit.state.rollbackStatus, RollbackStatus.idle);
    });

    test(
      'successful and no-change rollback refresh history and current Version',
      () async {
        final repository = _VersionsRepository();
        final cubit = PublishedVersionCubit(repository: repository);
        await cubit.setContext(1, 'pos');
        final target = cubit.state.history!.items.last;
        final historyCalls = repository.historyCalls.length;

        cubit.beginRollback(target);
        await cubit.rollback('correct menu');
        expect(cubit.state.rollbackStatus, RollbackStatus.success);
        expect(cubit.state.rollbackResult?.sourceVersionId, target.id);
        expect(cubit.state.rollbackResult?.versionId, isNot(target.id));
        expect(repository.historyCalls.length, historyCalls + 1);
        expect(repository.rollbackCalls.single.reason, 'correct menu');

        repository.rollbackLoader = (_, _) =>
            Future<RollbackResult>.value(_rollback(noChanges: true));
        cubit.beginRollback(target);
        await cubit.rollback('');
        expect(cubit.state.rollbackStatus, RollbackStatus.noChanges);
        expect(cubit.state.rollbackResult?.versionId, target.id);
        expect(repository.historyCalls.length, historyCalls + 2);
      },
    );

    test(
      'duplicate and stale rollback responses do not overwrite a new scope',
      () async {
        final repository = _VersionsRepository();
        final pending = Completer<RollbackResult>();
        repository.rollbackLoader = (_, _) => pending.future;
        final cubit = PublishedVersionCubit(repository: repository);
        await cubit.setContext(1, 'pos');
        cubit.beginRollback(cubit.state.history!.items.last);

        unawaited(cubit.rollback('one'));
        unawaited(cubit.rollback('two'));
        await Future<void>.delayed(Duration.zero);
        expect(repository.rollbackCalls, hasLength(1));
        await cubit.setContext(2, 'online');
        pending.complete(_rollback());
        await Future<void>.delayed(Duration.zero);
        expect(cubit.state.scopeKey, '2|online');
        expect(cubit.state.rollbackResult, isNull);
      },
    );
  });
}

class _VersionsRepository extends BackendMenuCatalogRepository {
  _VersionsRepository()
    : super(DioApiClient(dio: Dio(BaseOptions(baseUrl: 'http://localhost/'))));

  final List<_HistoryCall> historyCalls = <_HistoryCall>[];
  final List<_DetailCall> detailCalls = <_DetailCall>[];
  final List<_ComparisonCall> comparisonCalls = <_ComparisonCall>[];
  final List<_RollbackCall> rollbackCalls = <_RollbackCall>[];
  Future<PublishedVersionPage> Function(int, String, int)? historyLoader;
  Future<PublishedVersionDetail> Function(int, bool)? detailLoader;
  Future<VersionComparison> Function(int, int)? comparisonLoader;
  Future<RollbackResult> Function(int, String?)? rollbackLoader;

  @override
  Future<PublishedVersionPage> listPublishedVersions({
    required int branchId,
    required String channel,
    required int page,
    int perPage = 20,
  }) {
    historyCalls.add(_HistoryCall(branchId, channel, page));
    return historyLoader?.call(branchId, channel, page) ??
        Future<PublishedVersionPage>.value(
          _page(page, <PublishedVersion>[
            _version(3, current: true),
            _version(2),
          ]),
        );
  }

  @override
  Future<PublishedMenuVersion?> getCurrentPublishedVersion(
    ReviewContext context,
  ) => Future<PublishedMenuVersion?>.value(
    PublishedMenuVersion.fromJson(<String, dynamic>{
      'id': 3,
      'versionNumber': 3,
      'checksum': 'current-checksum',
      'status': 'current',
    }),
  );

  @override
  Future<PublishedVersionDetail> getPublishedVersion(
    int id, {
    bool includePayload = false,
  }) {
    detailCalls.add(_DetailCall(id, includePayload));
    return detailLoader?.call(id, includePayload) ??
        Future<PublishedVersionDetail>.value(_detail(_version(id)));
  }

  @override
  Future<VersionComparison> comparePublishedVersions(
    int id,
    int againstVersionId,
  ) {
    comparisonCalls.add(_ComparisonCall(id, againstVersionId));
    return comparisonLoader?.call(id, againstVersionId) ??
        Future<VersionComparison>.value(_comparison());
  }

  @override
  Future<RollbackResult> rollbackPublishedVersion(int id, {String? reason}) {
    rollbackCalls.add(_RollbackCall(id, reason));
    return rollbackLoader?.call(id, reason) ??
        Future<RollbackResult>.value(_rollback());
  }
}

PublishedVersion _version(int id, {bool current = false}) => PublishedVersion(
  id: id,
  versionNumber: id,
  checksum: 'checksum-$id',
  status: current ? 'current' : 'superseded',
  publishedAt: '2026-08-02T10:00:00Z',
  isCurrent: current,
  publicationId: id,
);
PublishedVersionPage _page(
  int page,
  List<PublishedVersion> items, {
  int total = 2,
}) => PublishedVersionPage(items: items, page: page, perPage: 2, total: total);
PublishedVersionDetail _detail(PublishedVersion version) =>
    PublishedVersionDetail(
      version: version,
      summary: const SnapshotSummary(
        menuCount: 1,
        sectionCount: 2,
        productCount: 3,
        variantCount: 4,
        modifierGroupCount: 5,
      ),
    );
VersionComparison _comparison() => const VersionComparison(
  fromId: 3,
  fromVersionNumber: 3,
  toId: 2,
  toVersionNumber: 2,
  sameChecksum: false,
  truncated: true,
  changes: <String, List<String>>{
    'productsChanged': <String>['3'],
  },
);
RollbackResult _rollback({bool noChanges = false}) => RollbackResult(
  rolledBack: !noChanges,
  noChanges: noChanges,
  publicationId: 20,
  sourceVersionId: 2,
  sourceVersionNumber: 2,
  versionId: noChanges ? 2 : 4,
  versionNumber: noChanges ? 2 : 4,
  checksum: 'checksum-2',
  status: 'current',
);

class _HistoryCall {
  const _HistoryCall(this.branchId, this.channel, this.page);
  final int branchId;
  final String channel;
  final int page;
  @override
  bool operator ==(Object other) =>
      other is _HistoryCall &&
      other.branchId == branchId &&
      other.channel == channel &&
      other.page == page;
  @override
  int get hashCode => Object.hash(branchId, channel, page);
}

class _DetailCall {
  const _DetailCall(this.id, this.payload);
  final int id;
  final bool payload;
  @override
  bool operator ==(Object other) =>
      other is _DetailCall && other.id == id && other.payload == payload;
  @override
  int get hashCode => Object.hash(id, payload);
}

class _ComparisonCall {
  const _ComparisonCall(this.id, this.againstId);
  final int id;
  final int againstId;
  @override
  bool operator ==(Object other) =>
      other is _ComparisonCall &&
      other.id == id &&
      other.againstId == againstId;
  @override
  int get hashCode => Object.hash(id, againstId);
}

class _RollbackCall {
  const _RollbackCall(this.id, this.reason);
  final int id;
  final String? reason;
}

import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:windows_application/core/network/api_exception.dart';
import 'package:windows_application/core/network/dio_api_client.dart';
import 'package:windows_application/features/menu_management/catalog_setup/controllers/catalog_setup_cubit.dart';
import 'package:windows_application/features/menu_management/catalog_setup/models/catalog_setup_models.dart';
import 'package:windows_application/features/menu_management/models/catalog_models.dart';
import 'package:windows_application/features/menu_management/repositories/menu_catalog_repository.dart';

void main() {
  test(
    'Catalog Setup model parses optional metadata and emits only supported fields',
    () {
      final record = CatalogSetupRecord.fromJson(<String, dynamic>{
        'id': 4,
        'name': 'Coffee Bar',
        'nameAr': 'قهوة',
        'code': 'COF',
        'printerName': 'bar-printer',
        'isActive': false,
        'sortOrder': 3,
        'productCount': 2,
      });
      expect(record.productCount, 2);
      expect(record.nameEn, isEmpty);
      expect(
        CatalogSetupKindPath.fromQuery('not-a-tab'),
        CatalogSetupKind.categories,
      );
      expect(
        CatalogSetupDraft.fromRecord(
          record,
        ).toJson(CatalogSetupKind.kitchenStations),
        <String, dynamic>{
          'name': 'Coffee Bar',
          'nameAr': 'قهوة',
          'nameEn': null,
          'code': 'COF',
          'printerName': 'bar-printer',
          'isActive': false,
        },
      );
    },
  );

  test(
    'Catalog Setup repository uses the real query and mutation contracts',
    () async {
      final List<RequestOptions> requests = <RequestOptions>[];
      final Dio dio = Dio(BaseOptions(baseUrl: 'http://localhost/api/v1/'));
      dio.interceptors.add(
        InterceptorsWrapper(
          onRequest: (options, handler) {
            requests.add(options);
            final Map<String, dynamic> record = <String, dynamic>{
              'id': 4,
              'name': 'Coffee Bar',
              'code': 'BAR',
              'isActive': true,
              'sortOrder': 0,
              'productCount': 2,
            };
            handler.resolve(
              Response<dynamic>(
                requestOptions: options,
                data: options.method == 'GET'
                    ? <String, dynamic>{
                        'data': <Map<String, dynamic>>[record],
                        'meta': <String, dynamic>{
                          'currentPage': 2,
                          'lastPage': 3,
                          'perPage': 10,
                          'total': 21,
                        },
                      }
                    : <String, dynamic>{'data': record},
              ),
            );
          },
        ),
      );
      final BackendMenuCatalogRepository repository =
          BackendMenuCatalogRepository(DioApiClient(dio: dio));

      for (final CatalogSetupKind kind in CatalogSetupKind.values) {
        await repository.listCatalogSetup(
          kind: kind,
          status: CatalogSetupStatus.all,
          search: ' coffee ',
          page: 2,
          perPage: 10,
        );
        await repository.createCatalogSetup(
          kind,
          const CatalogSetupDraft(
            name: 'Coffee Bar',
            nameAr: 'قهوة',
            nameEn: 'Coffee Bar',
            code: 'BAR',
            description: 'Hot drinks',
            printerName: 'bar-printer',
          ),
        );
        await repository.updateCatalogSetup(
          kind,
          4,
          const CatalogSetupDraft(name: 'Updated'),
        );
        await repository.archiveCatalogSetup(kind, 4);
        await repository.restoreCatalogSetup(kind, 4);
        await repository.reorderCatalogSetup(kind, <CatalogSetupRecord>[
          _record('Second', id: 8),
          _record('First', id: 4),
        ]);
      }

      for (final CatalogSetupKind kind in CatalogSetupKind.values) {
        final String path = 'admin/catalog/${kind.path}';
        final RequestOptions list = requests.firstWhere(
          (request) => request.method == 'GET' && request.path == path,
        );
        expect(list.queryParameters, <String, dynamic>{
          'status': 'all',
          'page': 2,
          'perPage': 10,
          'search': 'coffee',
        });
        final RequestOptions create = requests.firstWhere(
          (request) => request.method == 'POST' && request.path == path,
        );
        final Map<String, dynamic> payload = Map<String, dynamic>.from(
          create.data as Map<dynamic, dynamic>,
        );
        expect(payload.containsKey('tenantId'), isFalse);
        expect(payload.containsKey('id'), isFalse);
        expect(payload.containsKey('productCount'), isFalse);
        expect(payload.containsKey('createdAt'), isFalse);
        expect(payload.containsKey('updatedAt'), isFalse);
        expect(payload['name'], 'Coffee Bar');
        if (kind == CatalogSetupKind.categories) {
          expect(payload, <String, dynamic>{
            'name': 'Coffee Bar',
            'description': 'Hot drinks',
            'isActive': true,
          });
        } else if (kind == CatalogSetupKind.reportingCategories) {
          expect(payload['description'], 'Hot drinks');
        } else {
          expect(payload.containsKey('description'), isFalse);
          expect(payload['printerName'], 'bar-printer');
        }
        expect(
          requests.any(
            (request) => request.method == 'PATCH' && request.path == '$path/4',
          ),
          isTrue,
        );
        expect(
          requests.any(
            (request) =>
                request.method == 'POST' && request.path == '$path/4/archive',
          ),
          isTrue,
        );
        expect(
          requests.any(
            (request) =>
                request.method == 'POST' && request.path == '$path/4/restore',
          ),
          isTrue,
        );
        final RequestOptions reorder = requests.firstWhere(
          (request) =>
              request.method == 'POST' && request.path == '$path/reorder',
        );
        expect(reorder.data, <String, dynamic>{
          'items': <Map<String, int>>[
            <String, int>{'id': 8, 'sortOrder': 0},
            <String, int>{'id': 4, 'sortOrder': 1},
          ],
        });
      }
    },
  );

  test(
    'Catalog Setup Cubit changes search/filter and ignores a stale list',
    () async {
      final repository = _CatalogSetupRepository();
      final pending = Completer<CatalogSetupPage>();
      repository.loader = (_, _, _, _) => pending.future;
      final cubit = CatalogSetupCubit(repository: repository);
      unawaited(cubit.initialize(CatalogSetupKind.categories));
      await Future<void>.delayed(Duration.zero);
      repository.loader = (_, _, _, page) =>
          Future<CatalogSetupPage>.value(_page(page, 'Station'));
      await cubit.selectKind(CatalogSetupKind.kitchenStations);
      pending.complete(_page(1, 'stale'));
      await Future<void>.delayed(Duration.zero);
      expect(cubit.state.kind, CatalogSetupKind.kitchenStations);
      expect(cubit.state.page!.items.first.name, 'Station');
      await cubit.setStatus(CatalogSetupStatus.archived);
      await cubit.setSearch('cold');
      expect(repository.calls.last.status, CatalogSetupStatus.archived);
      expect(repository.calls.last.search, 'cold');
    },
  );

  test(
    'Catalog Setup prevents duplicate mutations and refreshes after archive and reorder',
    () async {
      final repository = _CatalogSetupRepository();
      final pending = Completer<CatalogSetupRecord>();
      repository.archiveLoader = (_) => pending.future;
      final cubit = CatalogSetupCubit(repository: repository);
      await cubit.initialize(CatalogSetupKind.categories);
      unawaited(cubit.archive(1));
      unawaited(cubit.archive(1));
      await Future<void>.delayed(Duration.zero);
      expect(repository.archives, <int>[1]);
      pending.complete(_record('Category'));
      await Future<void>.delayed(Duration.zero);
      await cubit.move(1, 1);
      expect(repository.reorders, hasLength(1));
    },
  );

  test('Catalog Setup keeps independent tab filters and pagination', () async {
    final repository = _CatalogSetupRepository();
    final cubit = CatalogSetupCubit(repository: repository);
    await cubit.initialize(CatalogSetupKind.categories);
    await cubit.setStatus(CatalogSetupStatus.archived);
    await cubit.setSearch('coffee');
    await cubit.load(page: 2);
    await cubit.selectKind(CatalogSetupKind.kitchenStations);
    await cubit.setSearch('bar');
    await cubit.selectKind(CatalogSetupKind.categories);

    expect(cubit.state.kind, CatalogSetupKind.categories);
    expect(cubit.state.status, CatalogSetupStatus.archived);
    expect(cubit.state.search, 'coffee');
    expect(cubit.state.page!.meta.currentPage, 2);
    expect(repository.calls.last, isA<_Call>());
    expect(repository.calls.last.kind, CatalogSetupKind.categories);
    expect(repository.calls.last.status, CatalogSetupStatus.archived);
    expect(repository.calls.last.search, 'coffee');
    expect(repository.calls.last.page, 2);
    await cubit.close();
  });

  test('Catalog Setup ignores stale filter and mutation responses', () async {
    final repository = _CatalogSetupRepository();
    final pending = Completer<CatalogSetupPage>();
    repository.loader = (kind, status, search, page) {
      if (search.isEmpty) return pending.future;
      return Future<CatalogSetupPage>.value(_page(page, search));
    };
    final cubit = CatalogSetupCubit(repository: repository);
    unawaited(cubit.initialize(CatalogSetupKind.categories));
    await Future<void>.delayed(Duration.zero);
    await cubit.setSearch('fresh');
    pending.complete(_page(1, 'stale'));
    await Future<void>.delayed(Duration.zero);
    expect(cubit.state.page!.items.first.name, 'fresh');

    repository.createLoader = (_) => Future<CatalogSetupRecord>.error(
      const ApiException(message: 'Rejected'),
    );
    await cubit.create(const CatalogSetupDraft(name: 'Rejected'));
    expect(cubit.state.requestStatus, CatalogSetupRequestStatus.failure);
    expect(cubit.state.page!.items.first.name, 'fresh');
    expect(cubit.state.error, 'Rejected');
    await cubit.close();
  });
}

class _CatalogSetupRepository extends BackendMenuCatalogRepository {
  _CatalogSetupRepository()
    : super(DioApiClient(dio: Dio(BaseOptions(baseUrl: 'http://localhost/'))));
  final List<_Call> calls = <_Call>[];
  final List<int> archives = <int>[];
  final List<List<CatalogSetupRecord>> reorders = <List<CatalogSetupRecord>>[];
  Future<CatalogSetupPage> Function(
    CatalogSetupKind,
    CatalogSetupStatus,
    String,
    int,
  )?
  loader;
  Future<CatalogSetupRecord> Function(int)? archiveLoader;
  Future<CatalogSetupRecord> Function(CatalogSetupDraft)? createLoader;
  @override
  Future<CatalogSetupPage> listCatalogSetup({
    required CatalogSetupKind kind,
    required CatalogSetupStatus status,
    required String search,
    required int page,
    int perPage = 20,
  }) {
    calls.add(_Call(kind, status, search, page));
    return loader?.call(kind, status, search, page) ??
        Future<CatalogSetupPage>.value(_page(page, 'Category'));
  }

  @override
  Future<CatalogSetupRecord> archiveCatalogSetup(
    CatalogSetupKind kind,
    int id,
  ) {
    archives.add(id);
    return archiveLoader?.call(id) ??
        Future<CatalogSetupRecord>.value(_record('Category'));
  }

  @override
  Future<CatalogSetupRecord> createCatalogSetup(
    CatalogSetupKind kind,
    CatalogSetupDraft draft,
  ) =>
      createLoader?.call(draft) ??
      Future<CatalogSetupRecord>.value(_record(draft.name));

  @override
  Future<void> reorderCatalogSetup(
    CatalogSetupKind kind,
    List<CatalogSetupRecord> items,
  ) async {
    reorders.add(items);
  }
}

CatalogSetupPage _page(int page, String name) => CatalogSetupPage(
  items: <CatalogSetupRecord>[_record(name), _record('$name 2', id: 2)],
  meta: CatalogPagination(
    currentPage: page,
    lastPage: 1,
    perPage: 20,
    total: 2,
  ),
);
CatalogSetupRecord _record(String name, {int id = 1}) => CatalogSetupRecord(
  id: id,
  name: name,
  nameAr: '',
  nameEn: '',
  description: '',
  code: '',
  printerName: '',
  branchId: null,
  isActive: true,
  sortOrder: id,
  productCount: 0,
);

class _Call {
  const _Call(this.kind, this.status, this.search, this.page);
  final CatalogSetupKind kind;
  final CatalogSetupStatus status;
  final String search;
  final int page;
}

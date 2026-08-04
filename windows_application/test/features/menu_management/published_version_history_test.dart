import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:windows_application/core/network/dio_api_client.dart';
import 'package:windows_application/features/menu_management/repositories/menu_catalog_repository.dart';
import 'package:windows_application/features/menu_management/versions/models/published_version_models.dart';

void main() {
  test('published Version models parse bounded backend contracts safely', () {
    final PublishedVersionPage page = PublishedVersionPage.fromEnvelope(
      <String, dynamic>{
        'data': <Map<String, dynamic>>[
          <String, dynamic>{
            'id': 12,
            'versionNumber': 4,
            'checksum': 'checksum',
            'status': 'future_status',
            'publishedAt': '2026-08-02T10:00:00Z',
            'publicationId': 31,
            'publicationStatus': 'published',
            'isCurrent': false,
            'changeSummary': <String, dynamic>{'sourceVersionId': 8},
          },
        ],
        'meta': <String, dynamic>{'currentPage': 2, 'perPage': 20, 'total': 21},
      },
    );
    expect(page.items.single.status, 'future_status');
    expect(page.hasPrevious, isTrue);
    expect(page.hasNext, isFalse);

    final PublishedVersionDetail detail = PublishedVersionDetail.fromJson(
      <String, dynamic>{
        ...page.items.single.singleToJson(),
        'branchId': 1,
        'channel': 'pos',
        'snapshotSummary': <String, dynamic>{
          'menuCount': 1,
          'sectionCount': 2,
          'productCount': 3,
          'variantCount': 4,
          'modifierGroupCount': 5,
        },
        'payload': <String, dynamic>{'menus': <dynamic>[]},
      },
    );
    expect(detail.summary.modifierGroupCount, 5);
    expect(detail.payload, isNotNull);

    final VersionComparison comparison = VersionComparison.fromJson(
      <String, dynamic>{
        'fromVersion': <String, dynamic>{'id': 1, 'versionNumber': 1},
        'toVersion': <String, dynamic>{'id': 2, 'versionNumber': 2},
        'sameChecksum': true,
        'truncated': true,
        'changes': <String, dynamic>{
          'productsAdded': <int>[90],
        },
      },
    );
    expect(comparison.sameChecksum, isTrue);
    expect(comparison.truncated, isTrue);
    expect(comparison.changes['productsAdded'], <String>['90']);

    final RollbackResult rollback = RollbackResult.fromJson(<String, dynamic>{
      'rolledBack': false,
      'noChanges': true,
      'publicationId': 33,
      'sourceVersion': <String, dynamic>{'id': 2, 'versionNumber': 2},
      'version': <String, dynamic>{
        'id': 2,
        'versionNumber': 2,
        'checksum': 'same',
        'status': 'current',
      },
    });
    expect(rollback.noChanges, isTrue);
    expect(rollback.rolledBack, isFalse);
  });

  test('repository uses only Version API request fields', () async {
    final List<RequestOptions> requests = <RequestOptions>[];
    final Dio dio = Dio(BaseOptions(baseUrl: 'http://localhost/api/v1/'))
      ..interceptors.add(
        InterceptorsWrapper(
          onRequest: (options, handler) {
            requests.add(options);
            final dynamic body = switch (options.path) {
              String path when path.endsWith('/versions') => <String, dynamic>{
                'data': <Map<String, dynamic>>[_versionJson()],
                'meta': <String, dynamic>{
                  'currentPage': 1,
                  'perPage': 20,
                  'total': 1,
                },
              },
              String path when path.endsWith('/compare') => <String, dynamic>{
                'data': <String, dynamic>{
                  'fromVersion': <String, dynamic>{
                    'id': 12,
                    'versionNumber': 4,
                  },
                  'toVersion': <String, dynamic>{'id': 9, 'versionNumber': 3},
                  'sameChecksum': false,
                  'truncated': false,
                  'changes': <String, dynamic>{},
                },
              },
              String path when path.endsWith('/rollback') => <String, dynamic>{
                'data': <String, dynamic>{
                  'rolledBack': true,
                  'noChanges': false,
                  'publicationId': 30,
                  'sourceVersion': <String, dynamic>{
                    'id': 12,
                    'versionNumber': 4,
                  },
                  'version': <String, dynamic>{
                    'id': 13,
                    'versionNumber': 5,
                    'checksum': 'next',
                    'status': 'current',
                  },
                },
              },
              _ => <String, dynamic>{
                'data': <String, dynamic>{
                  ..._versionJson(),
                  'branchId': 1,
                  'channel': 'pos',
                  'snapshotSummary': <String, dynamic>{
                    'menuCount': 0,
                    'sectionCount': 0,
                    'productCount': 0,
                    'variantCount': 0,
                    'modifierGroupCount': 0,
                  },
                },
              },
            };
            handler.resolve(
              Response<dynamic>(requestOptions: options, data: body),
            );
          },
        ),
      );
    final repository = BackendMenuCatalogRepository(DioApiClient(dio: dio));

    await repository.listPublishedVersions(
      branchId: 1,
      channel: 'pos',
      page: 1,
    );
    await repository.getPublishedVersion(12);
    await repository.getPublishedVersion(12, includePayload: true);
    await repository.comparePublishedVersions(12, 9);
    await repository.rollbackPublishedVersion(
      12,
      reason: 'Correct mistaken menu',
    );

    expect(requests[0].path, endsWith('admin/menu-management/versions'));
    expect(requests[0].queryParameters, <String, dynamic>{
      'branchId': 1,
      'channel': 'pos',
      'page': 1,
      'perPage': 20,
    });
    expect(requests[1].queryParameters, isEmpty);
    expect(requests[2].queryParameters, <String, dynamic>{
      'includePayload': true,
    });
    expect(requests[3].queryParameters, <String, dynamic>{
      'againstVersionId': 9,
    });
    expect(requests[4].data, <String, dynamic>{
      'reason': 'Correct mistaken menu',
    });
  });
}

Map<String, dynamic> _versionJson() => <String, dynamic>{
  'id': 12,
  'versionNumber': 4,
  'checksum': 'checksum',
  'status': 'superseded',
  'publishedAt': '2026-08-02T10:00:00Z',
  'publicationId': 31,
};

extension on PublishedVersion {
  Map<String, dynamic> singleToJson() => <String, dynamic>{
    'id': id,
    'versionNumber': versionNumber,
    'checksum': checksum,
    'status': status,
    'publishedAt': publishedAt,
    'publicationId': publicationId,
    'publicationStatus': publicationStatus,
    'isCurrent': isCurrent,
    'changeSummary': changeSummary,
  };
}

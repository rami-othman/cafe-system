import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:windows_application/core/network/api_exception.dart';
import 'package:windows_application/core/network/dio_api_client.dart';
import 'package:windows_application/features/auth/repositories/auth_repository.dart';
import 'package:windows_application/features/auth/models/auth_session.dart';

void main() {
  group('ApiAuthRepository login request mapping', () {
    test('email input sends email only', () async {
      Map<String, dynamic>? payload;
      final ApiAuthRepository repository = _repository((data) {
        payload = data;
      });

      await repository.login(
        identifier: 'manager@example.test',
        password: 'password',
      );

      expect(payload?['email'], 'manager@example.test');
      expect(payload, isNot(contains('username')));
    });

    test('username input sends username only', () async {
      Map<String, dynamic>? payload;
      final ApiAuthRepository repository = _repository((data) {
        payload = data;
      });

      await repository.login(identifier: 'cashier', password: 'password');

      expect(payload?['username'], 'cashier');
      expect(payload, isNot(contains('email')));
    });

    test('identifier is never sent', () async {
      for (final String identifier in <String>[
        'manager@example.test',
        'cashier',
      ]) {
        Map<String, dynamic>? payload;
        final ApiAuthRepository repository = _repository((data) {
          payload = data;
        });

        await repository.login(identifier: identifier, password: 'password');

        expect(payload, isNot(contains('identifier')));
      }
    });

    test(
      'surrounding whitespace is trimmed before sending the username',
      () async {
        Map<String, dynamic>? payload;
        final ApiAuthRepository repository = _repository((data) {
          payload = data;
        });

        await repository.login(identifier: '  cashier  ', password: 'password');

        expect(payload?['username'], 'cashier');
      },
    );

    test('successful login still parses the session response', () async {
      final ApiAuthRepository repository = _repository((_) {});

      final session = await repository.login(
        identifier: 'manager@example.test',
        password: 'password',
      );

      expect(session.accessToken, 'opaque-token');
      expect(session.user.id, 7);
      expect(session.tenant.id, 4);
      expect(session.mustChangePassword, isTrue);
    });

    for (final ({String name, dynamic response}) malformed
        in <({String name, dynamic response})>[
          (
            name: 'an empty access token',
            response: <String, dynamic>{..._sessionResponse, 'accessToken': ''},
          ),
          (
            name: 'a non-string access token',
            response: <String, dynamic>{..._sessionResponse, 'accessToken': 7},
          ),
          (
            name: 'a missing must-change-password flag',
            response: _without(_sessionResponse, 'mustChangePassword'),
          ),
          (
            name: 'a non-boolean must-change-password flag',
            response: <String, dynamic>{
              ..._sessionResponse,
              'mustChangePassword': 'true',
            },
          ),
          (
            name: 'a missing user map',
            response: _without(_sessionResponse, 'user'),
          ),
          (
            name: 'a non-map user',
            response: <String, dynamic>{
              ..._sessionResponse,
              'user': <dynamic>[],
            },
          ),
          (
            name: 'an invalid user id',
            response: <String, dynamic>{
              ..._sessionResponse,
              'user': <String, dynamic>{
                ...(_sessionResponse['user'] as Map<String, dynamic>),
                'id': '7',
              },
            },
          ),
          (
            name: 'a missing user id',
            response: <String, dynamic>{
              ..._sessionResponse,
              'user': _without(
                _sessionResponse['user'] as Map<String, dynamic>,
                'id',
              ),
            },
          ),
          (
            name: 'a zero user id',
            response: <String, dynamic>{
              ..._sessionResponse,
              'user': <String, dynamic>{
                ...(_sessionResponse['user'] as Map<String, dynamic>),
                'id': 0,
              },
            },
          ),
          (
            name: 'a negative user id',
            response: <String, dynamic>{
              ..._sessionResponse,
              'user': <String, dynamic>{
                ...(_sessionResponse['user'] as Map<String, dynamic>),
                'id': -7,
              },
            },
          ),
          (
            name: 'a missing tenant map',
            response: _without(_sessionResponse, 'tenant'),
          ),
          (
            name: 'a non-map tenant',
            response: <String, dynamic>{
              ..._sessionResponse,
              'tenant': 'Cafe 618',
            },
          ),
          (
            name: 'an invalid tenant id',
            response: <String, dynamic>{
              ..._sessionResponse,
              'tenant': <String, dynamic>{
                ...(_sessionResponse['tenant'] as Map<String, dynamic>),
                'id': 1.5,
              },
            },
          ),
          (
            name: 'a missing tenant id',
            response: <String, dynamic>{
              ..._sessionResponse,
              'tenant': _without(
                _sessionResponse['tenant'] as Map<String, dynamic>,
                'id',
              ),
            },
          ),
          (
            name: 'a zero tenant id',
            response: <String, dynamic>{
              ..._sessionResponse,
              'tenant': <String, dynamic>{
                ...(_sessionResponse['tenant'] as Map<String, dynamic>),
                'id': 0,
              },
            },
          ),
          (
            name: 'a negative tenant id',
            response: <String, dynamic>{
              ..._sessionResponse,
              'tenant': <String, dynamic>{
                ...(_sessionResponse['tenant'] as Map<String, dynamic>),
                'id': -4,
              },
            },
          ),
          (
            name: 'a missing role',
            response: <String, dynamic>{
              ..._sessionResponse,
              'user': _without(
                _sessionResponse['user'] as Map<String, dynamic>,
                'role',
              ),
            },
          ),
          (
            name: 'an empty role',
            response: <String, dynamic>{
              ..._sessionResponse,
              'user': <String, dynamic>{
                ...(_sessionResponse['user'] as Map<String, dynamic>),
                'role': '',
              },
            },
          ),
          (
            name: 'a non-string role',
            response: <String, dynamic>{
              ..._sessionResponse,
              'user': <String, dynamic>{
                ...(_sessionResponse['user'] as Map<String, dynamic>),
                'role': 1,
              },
            },
          ),
          (
            name: 'a missing session map',
            response: _without(_sessionResponse, 'session'),
          ),
          (
            name: 'a non-map session',
            response: <String, dynamic>{..._sessionResponse, 'session': false},
          ),
          (
            name: 'a malformed validation timestamp',
            response: <String, dynamic>{
              ..._sessionResponse,
              'session': <String, dynamic>{
                ...(_sessionResponse['session'] as Map<String, dynamic>),
                'lastValidatedAt': 'not-a-date',
              },
            },
          ),
          (
            name: 'a missing validation timestamp',
            response: <String, dynamic>{
              ..._sessionResponse,
              'session': _without(
                _sessionResponse['session'] as Map<String, dynamic>,
                'lastValidatedAt',
              ),
            },
          ),
          (
            name: 'a non-string validation timestamp',
            response: <String, dynamic>{
              ..._sessionResponse,
              'session': <String, dynamic>{
                ...(_sessionResponse['session'] as Map<String, dynamic>),
                'lastValidatedAt': 123,
              },
            },
          ),
          (
            name: 'an invalid offline maximum age',
            response: <String, dynamic>{
              ..._sessionResponse,
              'session': <String, dynamic>{
                ...(_sessionResponse['session'] as Map<String, dynamic>),
                'offlineSessionMaxAgeSeconds': '43200',
              },
            },
          ),
          (
            name: 'a missing offline maximum age',
            response: <String, dynamic>{
              ..._sessionResponse,
              'session': _without(
                _sessionResponse['session'] as Map<String, dynamic>,
                'offlineSessionMaxAgeSeconds',
              ),
            },
          ),
          (
            name: 'a zero offline maximum age',
            response: <String, dynamic>{
              ..._sessionResponse,
              'session': <String, dynamic>{
                ...(_sessionResponse['session'] as Map<String, dynamic>),
                'offlineSessionMaxAgeSeconds': 0,
              },
            },
          ),
          (
            name: 'a negative offline maximum age',
            response: <String, dynamic>{
              ..._sessionResponse,
              'session': <String, dynamic>{
                ...(_sessionResponse['session'] as Map<String, dynamic>),
                'offlineSessionMaxAgeSeconds': -1,
              },
            },
          ),
          (
            name: 'a map with a non-string key',
            response: <dynamic, dynamic>{..._sessionResponse, 7: 'invalid'},
          ),
        ]) {
      test(
        'malformed successful login payload with ${malformed.name} is rejected',
        () async {
          final ApiAuthRepository repository = _repository(
            (_) {},
            response: malformed.response,
          );

          expect(
            repository.login(identifier: 'cashier', password: 'password'),
            throwsA(isA<AuthInvalidResponseException>()),
          );
        },
      );
    }

    test('login rejects a missing shared token type', () {
      final ApiAuthRepository repository = _repository(
        (_) {},
        response: _without(_sessionResponse, 'tokenType'),
      );

      expect(
        repository.login(identifier: 'cashier', password: 'password'),
        throwsA(isA<AuthInvalidResponseException>()),
      );
    });

    test('login rejects a missing authoritative branch-access contract', () {
      final ApiAuthRepository repository = _repository(
        (_) {},
        response: _without(_sessionResponse, 'branchAccess'),
      );

      expect(
        repository.login(identifier: 'cashier', password: 'password'),
        throwsA(isA<AuthInvalidResponseException>()),
      );
    });

    test('422 login responses remain typed validation errors', () async {
      final ApiAuthRepository repository = _repository((_) {}, statusCode: 422);

      expect(
        repository.login(identifier: 'cashier', password: 'password'),
        throwsA(
          isA<ApiException>()
              .having(
                (ApiException error) => error.type,
                'type',
                ApiErrorType.validation,
              )
              .having(
                (ApiException error) => error.statusCode,
                'status code',
                422,
              ),
        ),
      );
    });
  });

  group('ApiAuthRepository auth/me response validation', () {
    test('valid auth/me response retains only the verified cached token', () async {
      final ApiAuthRepository repository = _meRepository(_meResponse);

      final session = await repository.me(_cachedSession());

      expect(session.accessToken, 'cached-opaque-token');
      expect(session.user.role, 'manager');
      expect(session.customerManagementAllowed, isTrue);
      expect(session.expiresAt, DateTime.utc(2026, 10, 1));
    });

    for (final ({String name, dynamic response}) malformed
        in <({String name, dynamic response})>[
          (name: 'a non-map payload', response: <dynamic>[]),
          (name: 'a missing token type', response: _without(_meResponse, 'tokenType')),
          (
            name: 'a non-Bearer token type',
            response: <String, dynamic>{..._meResponse, 'tokenType': 'Basic'},
          ),
          (
            name: 'a missing password-change flag',
            response: _without(_meResponse, 'mustChangePassword'),
          ),
          (
            name: 'a wrong-type user identifier',
            response: <String, dynamic>{
              ..._meResponse,
              'user': <String, dynamic>{
                ...(_meResponse['user'] as Map<String, dynamic>),
                'id': '7',
              },
            },
          ),
          (
            name: 'a missing user role',
            response: <String, dynamic>{
              ..._meResponse,
              'user': _without(_meResponse['user'] as Map<String, dynamic>, 'role'),
            },
          ),
          (
            name: 'a wrong-type tenant identifier',
            response: <String, dynamic>{
              ..._meResponse,
              'tenant': <String, dynamic>{
                ...(_meResponse['tenant'] as Map<String, dynamic>),
                'id': '4',
              },
            },
          ),
          (
            name: 'a wrong-type user role',
            response: <String, dynamic>{
              ..._meResponse,
              'user': <String, dynamic>{
                ...(_meResponse['user'] as Map<String, dynamic>),
                'role': 7,
              },
            },
          ),
          (
            name: 'a missing authenticated timestamp',
            response: <String, dynamic>{
              ..._meResponse,
              'session': _without(
                _meResponse['session'] as Map<String, dynamic>,
                'authenticatedAt',
              ),
            },
          ),
          (
            name: 'a missing capability permission',
            response: <String, dynamic>{
              ..._meResponse,
              'capabilities': <String, dynamic>{'customer': <String, dynamic>{}},
            },
          ),
          (
            name: 'a wrong-type capability permission',
            response: <String, dynamic>{
              ..._meResponse,
              'capabilities': <String, dynamic>{
                'customer': <String, dynamic>{'manage': 'true'},
              },
            },
          ),
          (
            name: 'a missing tenant status',
            response: <String, dynamic>{
              ..._meResponse,
              'tenant': _without(
                _meResponse['tenant'] as Map<String, dynamic>,
                'status',
              ),
            },
          ),
          (
            name: 'a missing session identifier',
            response: <String, dynamic>{
              ..._meResponse,
              'session': _without(
                _meResponse['session'] as Map<String, dynamic>,
                'id',
              ),
            },
          ),
          (
            name: 'a wrong-type session identifier',
            response: <String, dynamic>{
              ..._meResponse,
              'session': <String, dynamic>{
                ...(_meResponse['session'] as Map<String, dynamic>),
                'id': '12',
              },
            },
          ),
          (
            name: 'a malformed validation timestamp',
            response: <String, dynamic>{
              ..._meResponse,
              'session': <String, dynamic>{
                ...(_meResponse['session'] as Map<String, dynamic>),
                'lastValidatedAt': 'not-a-date',
              },
            },
          ),
          (
            name: 'a missing token expiry',
            response: _without(_meResponse, 'expiresAt'),
          ),
          (
            name: 'mismatched top-level and session expiry',
            response: <String, dynamic>{
              ..._meResponse,
              'session': <String, dynamic>{
                ...(_meResponse['session'] as Map<String, dynamic>),
                'expiresAt': '2026-10-02T00:00:00.000Z',
              },
            },
          ),
          (
            name: 'a wrong-type offline authority window',
            response: <String, dynamic>{
              ..._meResponse,
              'session': <String, dynamic>{
                ...(_meResponse['session'] as Map<String, dynamic>),
                'offlineSessionMaxAgeSeconds': '43200',
              },
            },
          ),
        ]) {
      test('malformed successful auth/me payload with ${malformed.name} is rejected', () {
        final ApiAuthRepository repository = _meRepository(malformed.response);

        expect(
          repository.me(_cachedSession()),
          throwsA(isA<AuthInvalidResponseException>()),
        );
      });
    }

    test('an empty cached token cannot be accepted as auth/me authority', () {
      final ApiAuthRepository repository = _meRepository(_meResponse);

      expect(
        repository.me(_cachedSession(accessToken: '')),
        throwsA(isA<AuthInvalidResponseException>()),
      );
    });
  });
}

ApiAuthRepository _repository(
  void Function(Map<String, dynamic> data) capture, {
  int? statusCode,
  dynamic response,
}) {
  final Dio dio = Dio(BaseOptions(baseUrl: 'http://localhost/api/v1/'));
  dio.interceptors.add(
    InterceptorsWrapper(
      onRequest: (RequestOptions options, RequestInterceptorHandler handler) {
        capture((options.data as Map).cast<String, dynamic>());
        if (statusCode != null) {
          handler.reject(
            DioException(
              requestOptions: options,
              type: DioExceptionType.badResponse,
              response: Response<dynamic>(
                requestOptions: options,
                statusCode: statusCode,
                data: <String, dynamic>{
                  'message': 'Provide exactly one of email or username.',
                  'errors': <String, dynamic>{
                    'identifier': <String>[
                      'Provide exactly one of email or username.',
                    ],
                  },
                },
              ),
            ),
          );
          return;
        }
        handler.resolve(
          Response<dynamic>(
            requestOptions: options,
            statusCode: 200,
            data: <String, dynamic>{'data': response ?? _sessionResponse},
          ),
        );
      },
    ),
  );

  return ApiAuthRepository(DioApiClient(dio: dio));
}

ApiAuthRepository _meRepository(dynamic response) {
  final Dio dio = Dio(BaseOptions(baseUrl: 'http://localhost/api/v1/'));
  dio.interceptors.add(
    InterceptorsWrapper(
      onRequest: (RequestOptions options, RequestInterceptorHandler handler) {
        expect(options.path, 'auth/me');
        handler.resolve(
          Response<dynamic>(
            requestOptions: options,
            statusCode: 200,
            data: <String, dynamic>{'data': response},
          ),
        );
      },
    ),
  );
  return ApiAuthRepository(DioApiClient(dio: dio));
}

final Map<String, dynamic> _sessionResponse = <String, dynamic>{
  'accessToken': 'opaque-token',
  'tokenType': 'Bearer',
  'expiresAt': '2026-10-01T00:00:00.000Z',
  'mustChangePassword': true,
  'user': <String, dynamic>{
    'id': 7,
    'name': 'Rami',
    'role': 'manager',
    'status': 'active',
    'email': 'manager@example.test',
    'username': null,
  },
  'tenant': <String, dynamic>{
    'id': 4,
    'name': 'Cafe 618',
    'status': 'active',
  },
  'capabilities': <String, dynamic>{
    'customer': <String, dynamic>{'manage': true},
  },
  'session': <String, dynamic>{
    'id': 12,
    'deviceName': 'Cafe System 618 Windows',
    'authenticatedAt': '2026-09-01T00:00:00.000Z',
    'lastValidatedAt': '2026-09-01T10:00:00Z',
    'expiresAt': '2026-10-01T00:00:00.000Z',
    'offlineSessionMaxAgeSeconds': 43200,
  },
  'branchAccess': <String, dynamic>{
    'allBranches': false,
    'branchIds': <int>[8],
  },
};

Map<String, dynamic> _without(Map<String, dynamic> source, String key) =>
    Map<String, dynamic>.of(source)..remove(key);

AuthSession _cachedSession({String accessToken = 'cached-opaque-token'}) =>
    AuthSession(
      accessToken: accessToken,
      user: const AuthUser(id: 7, name: 'Cached Rami', role: 'employee'),
      tenant: const AuthTenant(id: 4, name: 'Cached Cafe'),
      mustChangePassword: false,
      lastValidatedAt: DateTime.utc(2026, 9, 1),
      offlineSessionMaxAgeSeconds: 43200,
      expiresAt: DateTime.utc(2026, 10, 1),
    );

final Map<String, dynamic> _meResponse = <String, dynamic>{
  'tokenType': 'Bearer',
  'expiresAt': '2026-10-01T00:00:00.000Z',
  'mustChangePassword': false,
  'user': <String, dynamic>{
    'id': 7,
    'name': 'Rami',
    'role': 'manager',
    'status': 'active',
    'email': 'manager@example.test',
    'username': null,
  },
  'tenant': <String, dynamic>{
    'id': 4,
    'name': 'Cafe 618',
    'status': 'active',
  },
  'capabilities': <String, dynamic>{
    'customer': <String, dynamic>{'manage': true},
  },
  'session': <String, dynamic>{
    'id': 12,
    'deviceName': 'Cafe System 618 Windows',
    'authenticatedAt': '2026-09-01T00:00:00.000Z',
    'lastValidatedAt': '2026-09-16T12:00:00.000Z',
    'expiresAt': '2026-10-01T00:00:00.000Z',
    'offlineSessionMaxAgeSeconds': 43200,
  },
  'branchAccess': <String, dynamic>{
    'allBranches': false,
    'branchIds': <int>[8],
  },
};

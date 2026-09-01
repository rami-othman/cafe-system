import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:windows_application/core/network/api_exception.dart';
import 'package:windows_application/core/network/dio_api_client.dart';
import 'package:windows_application/features/auth/repositories/auth_repository.dart';

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
}

ApiAuthRepository _repository(
  void Function(Map<String, dynamic> data) capture, {
  int? statusCode,
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
            data: <String, dynamic>{'data': _sessionResponse},
          ),
        );
      },
    ),
  );

  return ApiAuthRepository(DioApiClient(dio: dio));
}

final Map<String, dynamic> _sessionResponse = <String, dynamic>{
  'accessToken': 'opaque-token',
  'mustChangePassword': true,
  'user': <String, dynamic>{
    'id': 7,
    'name': 'Rami',
    'role': 'manager',
    'email': 'manager@example.test',
  },
  'tenant': <String, dynamic>{'id': 4, 'name': 'Cafe 618'},
  'session': <String, dynamic>{
    'lastValidatedAt': '2026-09-01T10:00:00Z',
    'offlineSessionMaxAgeSeconds': 43200,
  },
};

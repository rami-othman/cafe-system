import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:windows_application/core/network/api_exception.dart';
import 'package:windows_application/core/network/dio_api_client.dart';

void main() {
  test(
    'maps closed backend connection to a safe typed network error',
    () async {
      final Dio dio = Dio(
        BaseOptions(baseUrl: 'http://127.0.0.1:8000/api/v1/'),
      );
      dio.interceptors.add(
        InterceptorsWrapper(
          onRequest:
              (RequestOptions options, RequestInterceptorHandler handler) {
                handler.reject(
                  DioException(
                    requestOptions: options,
                    type: DioExceptionType.unknown,
                    error: const HttpException(
                      'Connection closed before full header was received',
                    ),
                  ),
                );
              },
        ),
      );
      final DioApiClient client = DioApiClient(dio: dio);

      expect(
        client.get('branches'),
        throwsA(
          isA<ApiException>()
              .having(
                (ApiException exception) => exception.message,
                'message',
                'Connection unavailable.',
              )
              .having(
                (ApiException exception) => exception.type,
                'type',
                ApiErrorType.networkUnavailable,
              ),
        ),
      );
    },
  );

  for (final ({int status, Map<String, dynamic> body, ApiErrorType type})
      testCase
      in <({int status, Map<String, dynamic> body, ApiErrorType type})>[
        (
          status: 401,
          body: <String, dynamic>{'message': 'framework detail'},
          type: ApiErrorType.unauthenticated,
        ),
        (
          status: 403,
          body: <String, dynamic>{'message': 'framework detail'},
          type: ApiErrorType.forbidden,
        ),
        (
          status: 409,
          body: <String, dynamic>{
            'message': 'The menu version is stale.',
            'code': 'MENU_VERSION_STALE',
          },
          type: ApiErrorType.conflict,
        ),
        (
          status: 422,
          body: <String, dynamic>{
            'message': 'The selected branch is invalid.',
            'errors': <String, dynamic>{
              'branchId': <String>['The selected branch is invalid.'],
            },
          },
          type: ApiErrorType.validation,
        ),
        (
          status: 500,
          body: <String, dynamic>{'message': 'SQLSTATE technical detail'},
          type: ApiErrorType.server,
        ),
      ]) {
    test('maps HTTP ${testCase.status} to ${testCase.type}', () async {
      final Dio dio = Dio(BaseOptions(baseUrl: 'http://example.test/api/'));
      dio.interceptors.add(
        InterceptorsWrapper(
          onRequest:
              (RequestOptions options, RequestInterceptorHandler handler) {
                handler.reject(
                  DioException(
                    requestOptions: options,
                    type: DioExceptionType.badResponse,
                    response: Response<dynamic>(
                      requestOptions: options,
                      statusCode: testCase.status,
                      data: testCase.body,
                    ),
                  ),
                );
              },
        ),
      );

      expect(
        DioApiClient(dio: dio).get('resource'),
        throwsA(
          isA<ApiException>()
              .having((ApiException error) => error.type, 'type', testCase.type)
              .having(
                (ApiException error) => error.validationErrors,
                'validation errors',
                testCase.status == 422 ? isNotNull : anything,
              )
              .having(
                (ApiException error) => error.code,
                'stable code',
                testCase.status == 409 ? 'MENU_VERSION_STALE' : anything,
              ),
        ),
      );
    });
  }
}

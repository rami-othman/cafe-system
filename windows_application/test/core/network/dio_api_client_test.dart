import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:windows_application/core/network/api_exception.dart';
import 'package:windows_application/core/network/dio_api_client.dart';

void main() {
  test(
    'maps closed backend connection to backend not reachable message',
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
          isA<ApiException>().having(
            (ApiException exception) => exception.message,
            'message',
            'Backend is not reachable. Start Laravel server on http://localhost:8000.',
          ),
        ),
      );
    },
  );
}

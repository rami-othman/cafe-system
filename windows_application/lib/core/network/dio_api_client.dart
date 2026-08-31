import 'package:dio/dio.dart';
import '../config/api_config.dart';
import 'api_exception.dart';
import 'api_response_parser.dart';

class DioApiClient {
  DioApiClient({Dio? dio})
    : _dio =
          dio ??
          Dio(
            BaseOptions(
              baseUrl: _normalizedBaseUrl,
              connectTimeout: const Duration(seconds: 15),
              sendTimeout: const Duration(seconds: 10),
              receiveTimeout: const Duration(seconds: 15),
              headers: <String, Object?>{
                Headers.acceptHeader: 'application/json',
                Headers.contentTypeHeader: 'application/json',
                if (ApiConfig.defaultTenantId > 0)
                  'X-Tenant-Id': ApiConfig.defaultTenantId,
              },
            ),
          ) {
    _dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (RequestOptions options, RequestInterceptorHandler handler) {
          options.headers[Headers.acceptHeader] = 'application/json';
          if (options.data is FormData) {
            options.headers.remove(Headers.contentTypeHeader);
          } else {
            options.headers[Headers.contentTypeHeader] = 'application/json';
          }
          if (ApiConfig.defaultTenantId > 0) {
            options.headers['X-Tenant-Id'] = ApiConfig.defaultTenantId;
          } else {
            options.headers.remove('X-Tenant-Id');
          }
          handler.next(options);
        },
      ),
    );
  }

  final Dio _dio;

  static String get _normalizedBaseUrl {
    return ApiConfig.baseUrl.endsWith('/')
        ? ApiConfig.baseUrl
        : '${ApiConfig.baseUrl}/';
  }

  Future<dynamic> get(String path, {Map<String, dynamic>? queryParameters}) {
    return _send(
      () => _dio.get<dynamic>(path, queryParameters: queryParameters),
    );
  }

  /// Returns the complete Laravel response body. Most existing endpoints use
  /// [get], which unwraps the conventional `data` field. Paginated endpoints
  /// also need their `meta` object, so they opt in to this method.
  Future<dynamic> getEnvelope(
    String path, {
    Map<String, dynamic>? queryParameters,
  }) {
    return _sendEnvelope(
      () => _dio.get<dynamic>(path, queryParameters: queryParameters),
    );
  }

  Future<dynamic> post(
    String path, {
    Object? data,
    Map<String, dynamic>? queryParameters,
  }) {
    return _send(
      () => _dio.post<dynamic>(
        path,
        data: data,
        queryParameters: queryParameters,
      ),
    );
  }

  Future<dynamic> postMultipart(String path, {required FormData data}) {
    return _send(
      () => _dio.post<dynamic>(
        path,
        data: data,
        options: Options(contentType: Headers.multipartFormDataContentType),
      ),
    );
  }

  Future<dynamic> patch(
    String path, {
    Object? data,
    Map<String, dynamic>? queryParameters,
  }) {
    return _send(
      () => _dio.patch<dynamic>(
        path,
        data: data,
        queryParameters: queryParameters,
      ),
    );
  }

  Future<dynamic> put(
    String path, {
    Object? data,
    Map<String, dynamic>? queryParameters,
  }) {
    return _send(
      () =>
          _dio.put<dynamic>(path, data: data, queryParameters: queryParameters),
    );
  }

  Future<dynamic> delete(
    String path, {
    Object? data,
    Map<String, dynamic>? queryParameters,
  }) {
    return _send(
      () => _dio.delete<dynamic>(
        path,
        data: data,
        queryParameters: queryParameters,
      ),
    );
  }

  Future<dynamic> _send(Future<Response<dynamic>> Function() request) async {
    try {
      final Response<dynamic> response = await request();
      return ApiResponseParser.unwrapData(response.data);
    } on DioException catch (error) {
      throw _handleDioException(error);
    }
  }

  Future<dynamic> _sendEnvelope(
    Future<Response<dynamic>> Function() request,
  ) async {
    try {
      return (await request()).data;
    } on DioException catch (error) {
      throw _handleDioException(error);
    }
  }

  ApiException _handleDioException(DioException error) {
    final int? statusCode = error.response?.statusCode;
    final dynamic body = error.response?.data;
    final String? responseMessage = _messageFromBody(body);
    final String? responseCode = _codeFromBody(body);

    if (_isBackendOffline(error)) {
      return ApiException(
        message: 'Connection unavailable.',
        type: ApiErrorType.networkUnavailable,
      );
    }

    if (statusCode == 422) {
      return ApiException(
        message: responseMessage ?? 'The submitted data was invalid.',
        statusCode: statusCode,
        validationErrors: _validationErrorsFromBody(body),
        code: responseCode,
        type: ApiErrorType.validation,
      );
    }

    if (statusCode == 401) {
      return ApiException(
        message: 'Authentication required.',
        statusCode: statusCode,
        code: responseCode,
        type: ApiErrorType.unauthenticated,
      );
    }

    if (statusCode == 403) {
      return ApiException(
        message: 'You do not have permission to perform this action.',
        statusCode: statusCode,
        code: responseCode,
        type: ApiErrorType.forbidden,
      );
    }

    if (statusCode == 409) {
      return ApiException(
        message:
            responseMessage ?? 'This action conflicts with the current state.',
        statusCode: statusCode,
        code: responseCode,
        type: ApiErrorType.conflict,
      );
    }

    if (statusCode == 404) {
      return ApiException(
        message: responseMessage ?? 'The requested resource was not found.',
        statusCode: statusCode,
        code: responseCode,
      );
    }

    if (statusCode != null && statusCode >= 500) {
      return ApiException(
        message: 'Something went wrong. Please try again.',
        statusCode: statusCode,
        type: ApiErrorType.server,
      );
    }

    return ApiException(
      message: responseMessage ?? 'Unexpected network error. Please try again.',
      statusCode: statusCode,
      code: responseCode,
      type: ApiErrorType.unknown,
    );
  }

  bool _isBackendOffline(DioException error) {
    if (error.type == DioExceptionType.unknown) {
      final String errorText = error.error.toString().toLowerCase();
      return errorText.contains('httpexception') ||
          errorText.contains('socketexception') ||
          errorText.contains('connection closed before full header') ||
          errorText.contains('connection refused') ||
          errorText.contains('failed host lookup');
    }

    return error.type == DioExceptionType.connectionError ||
        error.type == DioExceptionType.connectionTimeout ||
        error.type == DioExceptionType.sendTimeout ||
        error.type == DioExceptionType.receiveTimeout;
  }

  String? _messageFromBody(dynamic body) {
    if (body is Map<String, dynamic>) {
      final dynamic message = body['message'];
      if (message is String && message.trim().isNotEmpty) {
        return message;
      }
    }

    return null;
  }

  String? _codeFromBody(dynamic body) {
    if (body is Map<String, dynamic>) {
      final dynamic code = body['code'];
      if (code is String && code.trim().isNotEmpty) return code;
    }

    return null;
  }

  Map<String, List<String>>? _validationErrorsFromBody(dynamic body) {
    if (body is! Map<String, dynamic>) {
      return null;
    }

    final dynamic errors = body['errors'];
    if (errors is! Map<String, dynamic>) {
      return null;
    }

    return errors.map((String key, dynamic value) {
      if (value is List) {
        return MapEntry(
          key,
          value.map((dynamic item) => item.toString()).toList(growable: false),
        );
      }

      return MapEntry(key, <String>[value.toString()]);
    });
  }
}

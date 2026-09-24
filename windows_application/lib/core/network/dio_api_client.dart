import 'dart:typed_data';

import 'package:dio/dio.dart';
import '../config/api_config.dart';
import 'current_locale.dart';
import 'api_exception.dart';
import 'api_response_parser.dart';

class DioApiClient {
  DioApiClient({Dio? dio})
    : _dio =
          dio ??
          Dio(
            BaseOptions(
              baseUrl: _normalizedBaseUrl,
              // A request that reaches Laravel may commit after the client
              // times out. These bounds accommodate staging TLS/storage
              // latency without authorizing automatic mutation retries.
              connectTimeout: const Duration(seconds: 10),
              sendTimeout: const Duration(seconds: 30),
              receiveTimeout: const Duration(seconds: 45),
              headers: <String, Object?>{
                Headers.acceptHeader: 'application/json',
                Headers.contentTypeHeader: 'application/json',
              },
            ),
          ) {
    _dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (RequestOptions options, RequestInterceptorHandler handler) {
          options.headers[Headers.acceptHeader] = 'application/json';
          options.headers['Accept-Language'] = CurrentLocale.languageCode;
          if (options.data is FormData) {
            options.headers.remove(Headers.contentTypeHeader);
          } else {
            options.headers[Headers.contentTypeHeader] = 'application/json';
          }
          // Tenant identity is derived from the bearer token. Never send the
          // legacy X-Tenant-Id header on authenticated operational requests.
          options.headers.remove('X-Tenant-Id');
          handler.next(options);
        },
      ),
    );
  }

  final Dio _dio;
  int? _authenticatedTenantId;
  String? _accessToken;
  void Function(ApiException error)? onAuthenticationFailure;
  void Function(ApiException error, String? requestToken)?
  onAuthenticatedFailureWithToken;

  int? get authenticatedTenantId => _authenticatedTenantId;
  String? get accessToken => _accessToken;

  /// The API uses opaque bearer tokens. The token is held in memory and is
  /// supplied by the auth session owner after a secure-store restore or login.
  void setAccessToken(String? token) {
    if (token == null || token.isEmpty) {
      _accessToken = null;
      _dio.options.headers.remove('Authorization');
      return;
    }
    _accessToken = token;
    _dio.options.headers['Authorization'] = 'Bearer $token';
  }

  void setAuthenticatedTenantId(int? tenantId) {
    _authenticatedTenantId = tenantId != null && tenantId > 0 ? tenantId : null;
  }

  static String get _normalizedBaseUrl {
    return ApiConfig.baseUrl.endsWith('/')
        ? ApiConfig.baseUrl
        : '${ApiConfig.baseUrl}/';
  }

  Future<dynamic> get(
    String path, {
    Map<String, dynamic>? queryParameters,
    bool suppressAuthenticationFailure = false,
  }) {
    return _send(
      () => _dio.get<dynamic>(path, queryParameters: queryParameters),
      suppressAuthenticationFailure: suppressAuthenticationFailure,
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

  Future<Uint8List> getBytes(String path) async {
    try {
      final Response<List<int>> response = await _dio.get<List<int>>(
        path,
        options: Options(responseType: ResponseType.bytes),
      );
      return Uint8List.fromList(response.data ?? const <int>[]);
    } on DioException catch (error) {
      final ApiException apiError = _handleDioException(error);
      if (_isAuthenticatedRequest(error, apiError)) {
        _notifyAuthenticatedFailure(error, apiError);
      }
      throw apiError;
    }
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

  Future<dynamic> _send(
    Future<Response<dynamic>> Function() request, {
    bool suppressAuthenticationFailure = false,
  }) async {
    try {
      final Response<dynamic> response = await request();
      return ApiResponseParser.unwrapData(response.data);
    } on DioException catch (error) {
      final ApiException apiError = _handleDioException(error);
      if (!suppressAuthenticationFailure &&
          _isAuthenticatedRequest(error, apiError)) {
        _notifyAuthenticatedFailure(error, apiError);
      }
      throw apiError;
    }
  }

  Future<dynamic> _sendEnvelope(
    Future<Response<dynamic>> Function() request,
  ) async {
    try {
      return (await request()).data;
    } on DioException catch (error) {
      final ApiException apiError = _handleDioException(error);
      if (_isAuthenticatedRequest(error, apiError)) {
        _notifyAuthenticatedFailure(error, apiError);
      }
      throw apiError;
    }
  }

  ApiException _handleDioException(DioException error) {
    final int? statusCode = error.response?.statusCode;
    final dynamic body = error.response?.data;
    final String? responseMessage = _messageFromBody(body);
    final String? responseCode = _codeFromBody(body);

    if (error.type == DioExceptionType.connectionTimeout) {
      return const ApiException(
        message: 'Connection timed out before the server could be reached.',
        type: ApiErrorType.connectionTimeout,
      );
    }

    if (error.type == DioExceptionType.sendTimeout) {
      return const ApiException(
        message:
            'Upload timed out before it completed. Do not retry unless you confirm the result.',
        type: ApiErrorType.sendTimeout,
      );
    }

    if (error.type == DioExceptionType.receiveTimeout) {
      return const ApiException(
        message:
            'The server response timed out. The operation may have completed; check before retrying.',
        type: ApiErrorType.receiveTimeout,
      );
    }

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

  bool _isAuthenticatedRequest(DioException error, ApiException apiError) =>
      error.requestOptions.headers['Authorization'] != null &&
      (apiError.type == ApiErrorType.unauthenticated ||
          apiError.type == ApiErrorType.forbidden);

  void _notifyAuthenticatedFailure(DioException error, ApiException apiError) {
    final String? header =
        error.requestOptions.headers['Authorization'] as String?;
    final String? requestToken = header?.startsWith('Bearer ') == true
        ? header!.substring('Bearer '.length)
        : null;
    onAuthenticatedFailureWithToken?.call(apiError, requestToken);
    onAuthenticationFailure?.call(apiError);
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

    return error.type == DioExceptionType.connectionError;
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

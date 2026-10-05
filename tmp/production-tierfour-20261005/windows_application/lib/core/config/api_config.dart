class ApiConfig {
  const ApiConfig._();

  static const String baseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://localhost:8000/api/v1',
  );

  /// Bearer tokens are issued by `/auth/login`; tenant and actor are derived
  /// by Laravel from this token, never from frontend headers.
  static const String apiToken = String.fromEnvironment('API_TOKEN');
}

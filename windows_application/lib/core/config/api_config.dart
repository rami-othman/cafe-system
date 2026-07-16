class ApiConfig {
  const ApiConfig._();

  static const String baseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://localhost:8000/api/v1',
  );

  /// Leave tenant resolution to the backend unless a deployment explicitly
  /// supplies a tenant ID at build time. Database IDs are not stable across
  /// fresh installs or reseeds.
  static const int defaultTenantId = int.fromEnvironment(
    'TENANT_ID',
    defaultValue: 0,
  );
}

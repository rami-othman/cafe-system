import 'package:flutter/foundation.dart';

import '../config/api_config.dart';
import '../services/service_locator.dart';
import 'dio_api_client.dart';

/// Debug-only convenience so a developer running `flutter run -d windows`
/// does not have to pass `--dart-define=API_TOKEN=...` or click through a
/// login screen to exercise authenticated screens locally. It performs a
/// real `/auth/login` call against the local backend using the dev-seed
/// owner account from `TenantAccessSeeder` (`owner@cafe618.local`) and
/// stores the genuine token Laravel issues. Backend auth/tenant/permission
/// enforcement is untouched; this only automates the client-side login step,
/// and only when running in debug mode with no explicit API_TOKEN supplied.
Future<void> bootstrapDevAuthIfNeeded() async {
  if (!kDebugMode || ApiConfig.apiToken.isNotEmpty) {
    return;
  }

  try {
    final DioApiClient apiClient = serviceLocator<DioApiClient>();
    final dynamic result = await apiClient
        .post(
          'auth/login',
          data: <String, String>{
            'email': 'owner@cafe618.local',
            'password': 'owner-local-dev',
            'deviceName': 'flutter-dev-bootstrap',
          },
        )
        .timeout(const Duration(seconds: 5));

    final String? token = result is Map ? result['token'] as String? : null;
    if (token != null && token.isNotEmpty) {
      apiClient.setAccessToken(token);
      debugPrint('Dev auth bootstrap: signed in as owner@cafe618.local.');
    }
  } catch (error) {
    debugPrint(
      'Dev auth bootstrap skipped (backend unreachable or dev seed '
      'missing): $error',
    );
  }
}

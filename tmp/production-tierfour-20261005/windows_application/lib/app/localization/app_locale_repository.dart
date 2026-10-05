import 'package:shared_preferences/shared_preferences.dart';

abstract interface class AppLocaleRepository {
  Future<String?> loadLocaleCode();
  Future<bool> saveLocaleCode(String localeCode);
}

class SharedPreferencesAppLocaleRepository implements AppLocaleRepository {
  static const String preferenceKey = 'app_locale';

  @override
  Future<String?> loadLocaleCode() async {
    try {
      return (await SharedPreferences.getInstance()).getString(preferenceKey);
    } catch (_) {
      return null;
    }
  }

  @override
  Future<bool> saveLocaleCode(String localeCode) async {
    try {
      return await (await SharedPreferences.getInstance()).setString(
        preferenceKey,
        localeCode,
      );
    } catch (_) {
      return false;
    }
  }
}

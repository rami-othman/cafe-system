/// The Dio client has no Cubit/BuildContext access, so `AppLocaleCubit`
/// mirrors its active language code here on every change. The API client
/// reads it to send the dedicated `X-App-Locale` header, letting the
/// backend's validation and error messages match whatever language the
/// user actually has selected.
class CurrentLocale {
  CurrentLocale._();

  static String languageCode = 'en';
}

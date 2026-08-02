import 'dart:ui';

import 'package:flutter_bloc/flutter_bloc.dart';

import 'app_locale_repository.dart';
import 'app_locale_state.dart';

class AppLocaleCubit extends Cubit<AppLocaleState> {
  AppLocaleCubit({
    required this.repository,
    Locale Function()? systemLocale,
  }) : _systemLocale =
           systemLocale ?? (() => PlatformDispatcher.instance.locale),
       super(const AppLocaleState(locale: Locale('en')));

  static const Locale english = Locale('en');
  static const Locale arabic = Locale('ar');
  static const List<Locale> supportedLocales = <Locale>[english, arabic];

  final AppLocaleRepository repository;
  final Locale Function() _systemLocale;

  Future<void> loadInitialLocale() async {
    String? savedCode;
    try {
      savedCode = await repository.loadLocaleCode();
    } catch (_) {
      savedCode = null;
    }
    final Locale locale =
        _localeFromCode(savedCode) ?? resolveSystemLocale(_systemLocale());
    emit(AppLocaleState(locale: locale, isLoaded: true));
  }

  Future<void> selectEnglish() => selectLocale(english);

  Future<void> selectArabic() => selectLocale(arabic);

  Future<void> selectLocale(Locale locale) async {
    final Locale resolved = _localeFromCode(locale.languageCode) ?? english;
    if (state.locale == resolved && state.isLoaded) {
      return;
    }
    emit(AppLocaleState(locale: resolved, isLoaded: true));
    try {
      await repository.saveLocaleCode(resolved.languageCode);
    } catch (_) {
      // A preference write must never roll back an already visible selection.
    }
  }

  static Locale resolveSystemLocale(Locale systemLocale) =>
      _localeFromCode(systemLocale.languageCode) ?? english;

  static Locale? _localeFromCode(String? localeCode) {
    return switch (localeCode?.toLowerCase()) {
      'en' => english,
      'ar' => arabic,
      _ => null,
    };
  }
}

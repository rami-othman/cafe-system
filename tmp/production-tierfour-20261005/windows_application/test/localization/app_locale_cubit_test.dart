import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:windows_application/app/localization/app_locale_cubit.dart';
import 'package:windows_application/app/localization/app_locale_repository.dart';

void main() {
  group('AppLocaleCubit', () {
    test(
      'loads a saved Arabic preference and persists a changed selection',
      () async {
        final _MemoryLocaleRepository repository = _MemoryLocaleRepository(
          'ar',
        );
        final AppLocaleCubit cubit = AppLocaleCubit(
          repository: repository,
          systemLocale: () => const Locale('en'),
        );

        await cubit.loadInitialLocale();
        expect(cubit.state.locale, AppLocaleCubit.arabic);

        await cubit.selectEnglish();
        expect(cubit.state.locale, AppLocaleCubit.english);
        expect(repository.savedCode, 'en');
      },
    );

    test(
      'uses a supported system locale and safely falls back for invalid data',
      () async {
        final AppLocaleCubit arabicSystem = AppLocaleCubit(
          repository: _MemoryLocaleRepository('invalid'),
          systemLocale: () => const Locale('ar', 'SY'),
        );
        await arabicSystem.loadInitialLocale();
        expect(arabicSystem.state.locale, AppLocaleCubit.arabic);

        final AppLocaleCubit unsupportedSystem = AppLocaleCubit(
          repository: _ThrowingLocaleRepository(),
          systemLocale: () => const Locale('fr'),
        );
        await unsupportedSystem.loadInitialLocale();
        expect(unsupportedSystem.state.locale, AppLocaleCubit.english);
      },
    );

    test(
      'does not emit or save when the already selected locale is selected',
      () async {
        final _MemoryLocaleRepository repository = _MemoryLocaleRepository(
          'en',
        );
        final AppLocaleCubit cubit = AppLocaleCubit(repository: repository);
        await cubit.loadInitialLocale();
        await cubit.selectEnglish();
        expect(repository.saveCount, 0);
      },
    );
  });
}

class _MemoryLocaleRepository implements AppLocaleRepository {
  _MemoryLocaleRepository(this.value);

  String? value;
  String? savedCode;
  int saveCount = 0;

  @override
  Future<String?> loadLocaleCode() async => value;

  @override
  Future<bool> saveLocaleCode(String localeCode) async {
    savedCode = localeCode;
    saveCount++;
    return true;
  }
}

class _ThrowingLocaleRepository implements AppLocaleRepository {
  @override
  Future<String?> loadLocaleCode() => Future<String?>.error(Exception('read'));

  @override
  Future<bool> saveLocaleCode(String localeCode) => Future<bool>.value(false);
}

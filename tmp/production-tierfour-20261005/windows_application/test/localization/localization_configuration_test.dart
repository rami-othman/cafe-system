import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:windows_application/app/localization/app_locale_cubit.dart';
import 'package:windows_application/app/localization/localized_backend_values.dart';
import 'package:windows_application/l10n/app_localizations.dart';

void main() {
  test('only English and Arabic are official supported locales', () {
    expect(AppLocaleCubit.supportedLocales, const <Locale>[
      Locale('en'),
      Locale('ar'),
    ]);
    expect(AppLocalizations.delegate.isSupported(const Locale('en')), isTrue);
    expect(AppLocalizations.delegate.isSupported(const Locale('ar')), isTrue);
    expect(AppLocalizations.delegate.isSupported(const Locale('fr')), isFalse);
  });

  test(
    'generated translations and backend value labels load in both locales',
    () async {
      final AppLocalizations english = await AppLocalizations.delegate.load(
        const Locale('en'),
      );
      final AppLocalizations arabic = await AppLocalizations.delegate.load(
        const Locale('ar'),
      );

      expect(english.navigationOrders, 'Orders');
      expect(arabic.navigationOrders, 'الطلبات');
      expect(english.productCount(2), '2 products');
      expect(arabic.productCount(2), isNotEmpty);
      expect(LocalizedBackendValues.label(arabic, 'sold_out'), 'نفد');
      expect(
        LocalizedBackendValues.label(english, 'future_value'),
        'Future Value',
      );
    },
  );
}

import 'package:flutter/widgets.dart';

import '../../l10n/app_localizations.dart';
import '../../l10n/app_localizations_ar.dart';

extension LocalizationBuildContext on BuildContext {
  /// Uses the configured delegate in the application and a safe Arabic
  /// fallback for isolated widgets, previews, and test harnesses.
  AppLocalizations get l10n => maybeL10n ?? AppLocalizationsAr();

  /// Allows isolated widgets to retain their established English fallback in
  /// tests and embedded tooling that intentionally omits app delegates.
  AppLocalizations? get maybeL10n =>
      Localizations.of<AppLocalizations>(this, AppLocalizations);

  bool get isArabic => Localizations.localeOf(this).languageCode == 'ar';
}

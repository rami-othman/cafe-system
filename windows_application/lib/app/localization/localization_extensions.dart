import 'package:flutter/widgets.dart';

import '../../l10n/app_localizations.dart';

extension LocalizationBuildContext on BuildContext {
  AppLocalizations get l10n => AppLocalizations.of(this);

  /// Allows isolated widgets to retain their established English fallback in
  /// tests and embedded tooling that intentionally omits app delegates.
  AppLocalizations? get maybeL10n =>
      Localizations.of<AppLocalizations>(this, AppLocalizations);

  bool get isArabic => Localizations.localeOf(this).languageCode == 'ar';
}

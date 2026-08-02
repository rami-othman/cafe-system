# Flutter Localization Architecture

The Windows Flutter application officially supports exactly English (`en`) and
Arabic (`ar`). Flutter's official `gen_l10n` system generates
`windows_application/lib/l10n/app_localizations.dart` from:

- `windows_application/lib/l10n/app_en.arb`
- `windows_application/lib/l10n/app_ar.arb`

Run `flutter gen-l10n` after changing ARB files; it is also run by normal Flutter
build tooling because `flutter.generate: true` is enabled in `pubspec.yaml`.
Use descriptive, feature-oriented keys and ICU placeholders/plurals. Do not build
sentences by concatenating translated fragments in widgets.

## Locale state and persistence

`AppLocaleCubit` is application state. Its repository stores an explicit user
choice under the stable `app_locale` key using `shared_preferences`. Only `en` and
`ar` are accepted. With no valid saved choice, the cubit uses a matching operating
system locale; unsupported system locales safely use English. Read and write
failures are deliberately non-fatal, so they never prevent the application opening.

The selector is in the shared top bar and updates `MaterialApp.router.locale`
without replacing the GoRouter configuration. This preserves the active route and
feature Cubits. Widgets must never call storage themselves.

## RTL, technical values, and formatting

Arabic uses Flutter's locale-driven `TextDirection.rtl`. Layouts should use
directional geometry (`EdgeInsetsDirectional`, `AlignmentDirectional`,
`BorderDirectional`, `TextAlign.start/end`) and mirror suitable navigation icons;
logical list/data order must not be reversed merely for RTL. Keep LTR islands only
around technical values such as SKU, barcode, email, URLs, API codes, IDs, decimal
entry, ISO diagnostics, checksums, phone numbers, and time ranges.

`LocalizedFormatters` is for locale-specific dates, date-times, numbers, decimals,
and display currency. Currency codes still come from the branch/tenant; API decimal
serialization remains locale-independent. `CurrencyFormatter.formatForContext` is
available for shared UI that already has a `BuildContext`.

## Backend display values

`LocalizedEntityText.resolve` provides the single fallback order for localized
backend fields without mutating response models: Arabic field/default/English for
Arabic, English field/default/Arabic for English, then a caller-provided safe
fallback. `LocalizedBackendValues` maps known backend enums, status values, reason
codes, severity, sales channel, and price-source values at the presentation edge.
Unknown values are humanized safely rather than crashing. Raw codes remain in data
and domain models and are never sent back translated.

For Laravel 422 responses, continue associating server field errors with the
correct controls. Prefer an ARB message for known application rules, retain useful
server detail otherwise, and use the localized generic form error for unknown
responses. Never render raw JSON, SQL, stack traces, or tenant IDs.

## Adding a language or feature

Add a third ARB file, update the supported-locale list deliberately, provide all
new strings in every ARB file, regenerate localization classes, and add Cubit,
selector, RTL/LTR, formatter, and representative-screen tests. New features must
add user-facing ARB keys as part of their initial implementation; API wire values,
identifiers, routes, logs, and user-entered product content are intentionally not
translated.

Menu Management functionality remains paused at Phase 4E.1 + 4E.2. This
localization work does not add publishing, current-version, version-history,
comparison, rollback, or POS-sync behavior.

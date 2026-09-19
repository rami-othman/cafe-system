import 'package:intl/intl.dart';

import '../../../core/utils/currency_formatter.dart';
import '../../../l10n/app_localizations.dart';
import '../models/discount_list_item.dart';

extension DiscountPresentation on DiscountListItem {
  String secondaryLabel(AppLocalizations l10n) =>
      code == null ? l10n.discountManual : l10n.discountCodeValue(code!);

  String typeLabel(AppLocalizations l10n) => switch (type) {
    'fixed' => l10n.discountFixedAmount,
    'bogo' => l10n.discountV2PackageBundle,
    _ => l10n.discountPercentage,
  };

  String valueLabel(AppLocalizations l10n) => switch (type) {
    'fixed' => l10n.discountAmountOff(
      CurrencyFormatter.format(value, locale: l10n.localeName),
    ),
    'bogo' => l10n.discountBundleValue(value.toInt()),
    _ => l10n.discountPercentOff(_decimal(value)),
  };

  String conditionsLabel(AppLocalizations l10n) =>
      conditions?.trim().isNotEmpty == true
      ? conditions!
      : l10n.discountNoConditions;

  String periodLabel(AppLocalizations l10n) {
    final DateFormat format = DateFormat.yMMMd(l10n.localeName);
    final DateTime? start = startDate ?? startsAt;
    final DateTime? end = endDate ?? endsAt;
    if (startDate == null &&
        endDate == null &&
        displayPeriodPrimary?.trim().isNotEmpty == true) {
      return displayPeriodPrimary!;
    }
    if (start == null && end == null) return l10n.discountAlwaysValid;
    if (start == null) return l10n.discountUntil(format.format(end!));
    if (end == null) return l10n.discountFrom(format.format(start));
    return l10n.discountDateRange(format.format(start), format.format(end));
  }

  String savedValueLabel(AppLocalizations l10n) =>
      CurrencyFormatter.format(estimatedSavedValue, locale: l10n.localeName);

  bool matchesLocalizedLabel(String query, AppLocalizations l10n) {
    final String normalized = query.trim().toLowerCase();
    if (normalized.isEmpty) return true;
    return <String>[
      secondaryLabel(l10n),
      typeLabel(l10n),
      status.label(l10n),
    ].any((String label) => label.toLowerCase().contains(normalized));
  }

  static String _decimal(double value) => value == value.truncateToDouble()
      ? value.toInt().toString()
      : value.toString();
}

String discountChannelLabel(String channel, AppLocalizations l10n) =>
    switch (channel) {
      'pos' => l10n.discountChannelPos,
      'waiter_app' => l10n.discountChannelWaiterApp,
      'kiosk' => l10n.discountChannelKiosk,
      'qr_ordering' => l10n.discountChannelQrOrdering,
      'delivery' => l10n.discountChannelDelivery,
      'online_ordering' => l10n.discountChannelOnlineOrdering,
      _ => channel,
    };

extension DiscountStatusPresentation on DiscountStatus {
  String label(AppLocalizations l10n) => switch (this) {
    DiscountStatus.active => l10n.discountActive,
    DiscountStatus.inactive => l10n.discountInactive,
    DiscountStatus.scheduled => l10n.discountScheduled,
    DiscountStatus.expired => l10n.discountExpired,
  };
}

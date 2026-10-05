import '../../l10n/app_localizations.dart';

/// Presentation-only labels for backend wire values. Unknown values remain
/// inspectable instead of causing a rendering failure.
abstract final class LocalizedBackendValues {
  static String label(AppLocalizations l10n, String? value) {
    final String normalized = value?.trim().toLowerCase() ?? '';
    final String? localized = switch (normalized) {
      'active' => l10n.commonActive,
      'inactive' => l10n.commonInactive,
      'available' => l10n.commonAvailable,
      'sold_out' || 'soldout' => l10n.commonSoldOut,
      'pending' => l10n.statusPending,
      'open' => l10n.statusOpen,
      'completed' || 'complete' => l10n.statusCompleted,
      'cancelled' || 'canceled' => l10n.statusCancelled,
      'paid' => l10n.statusPaid,
      'unpaid' => l10n.statusUnpaid,
      'archived' => l10n.statusArchived,
      'draft' => l10n.statusDraft,
      'published' => l10n.statusPublished,
      'scheduled' => l10n.statusScheduled,
      'temporarily_unavailable' => l10n.statusTemporarilyUnavailable,
      'assigned' => l10n.statusAssigned,
      'unassigned' => l10n.statusUnassigned,
      'base' || 'base_price' => l10n.priceSourceBase,
      'override' || 'override_price' => l10n.priceSourceOverride,
      'error' => l10n.validationSeverityError,
      'warning' => l10n.validationSeverityWarning,
      'info' || 'information' => l10n.validationSeverityInfo,
      'pos' => l10n.salesChannelPos,
      'online' => l10n.salesChannelOnline,
      'simple' => l10n.productTypeSimple,
      'variant' || 'variable' => l10n.productTypeVariant,
      _ => null,
    };
    return localized ?? _humanize(value) ?? l10n.commonUnknown;
  }

  static String? _humanize(String? value) {
    final String cleaned = value?.trim() ?? '';
    if (cleaned.isEmpty) return null;
    return cleaned
        .replaceAll(RegExp(r'[_-]+'), ' ')
        .split(RegExp(r'\s+'))
        .map(
          (String word) => word.isEmpty
              ? word
              : '${word[0].toUpperCase()}${word.substring(1)}',
        )
        .join(' ');
  }
}

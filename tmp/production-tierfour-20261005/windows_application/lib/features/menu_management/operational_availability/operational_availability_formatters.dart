import 'package:intl/intl.dart';

import 'models/operational_availability_models.dart';

const List<String> operationalSalesChannels = <String>[
  'pos',
  'waiter_app',
  'kiosk',
  'qr_ordering',
  'delivery',
  'online_ordering',
];

String operationalChannelLabel(String channel) => switch (channel) {
  'all' => 'All channels',
  'pos' => 'POS',
  'waiter_app' => 'Waiter app',
  'kiosk' => 'Kiosk',
  'qr_ordering' => 'QR ordering',
  'delivery' => 'Delivery',
  'online_ordering' => 'Online ordering',
  _ => channel,
};

String operationalScopeLabel(OperationalAvailabilityOverride item) =>
    '${item.branchName} · ${operationalChannelLabel(item.channel)}';

String operationalDate(DateTime? value) =>
    value == null ? '—' : DateFormat.yMMMd().add_jm().format(value);

String operationalQuantity(double? value) => value == null
    ? '—'
    : value == value.roundToDouble()
    ? value.toInt().toString()
    : value.toString();

String operationalLevelLabel(OperationalAvailabilityLevel level) =>
    switch (level) {
      OperationalAvailabilityLevel.product => 'Product',
      OperationalAvailabilityLevel.variant => 'Variant',
    };

import 'package:intl/intl.dart';

import 'models/availability_models.dart';

const List<String> availabilityChannels = <String>[
  'pos',
  'waiter_app',
  'kiosk',
  'qr_ordering',
  'delivery',
  'online_ordering',
];
const List<String> _days = <String>[
  'Sun',
  'Mon',
  'Tue',
  'Wed',
  'Thu',
  'Fri',
  'Sat',
];
String availabilityDayLabel(int? day) => day == null ? 'Daily' : _days[day];
String availabilityChannelLabel(String value) => switch (value) {
  'pos' => 'POS',
  'waiter_app' => 'Waiter App',
  'kiosk' => 'Kiosk',
  'qr_ordering' => 'QR Ordering',
  'delivery' => 'Delivery',
  'online_ordering' => 'Online Ordering',
  _ => value,
};
String scheduleSummary(AvailabilityRuleDraft rule) {
  final List<String> parts = <String>[availabilityDayLabel(rule.dayOfWeek)];
  if (rule.startTime != null) {
    parts.add(
      '${rule.startTime}–${rule.endTime}${rule.isOvernight ? ' · Overnight' : ''}',
    );
  } else {
    parts.add('No time restriction');
  }
  if (rule.startDate != null || rule.endDate != null) {
    parts.add('${_date(rule.startDate)}–${_date(rule.endDate)}');
  }
  return parts.join(' · ');
}

String _date(String? value) {
  if (value == null) return '…';
  final DateTime? date = DateTime.tryParse(value);
  return date == null ? value : DateFormat.MMMd().format(date);
}

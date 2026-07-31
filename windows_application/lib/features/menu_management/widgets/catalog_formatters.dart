import 'package:intl/intl.dart';

import '../../../core/utils/currency_formatter.dart';

String catalogMoney(num value) => CurrencyFormatter.format(value);
String catalogDate(DateTime? value) =>
    value == null ? '—' : DateFormat.yMMMd().add_jm().format(value);
String productTypeLabel(String value) => switch (value) {
  'open_price' => 'Open price',
  'combo' => 'Combo',
  _ => 'Standard',
};
String booleanLabel(bool value) => value ? 'Yes' : 'No';

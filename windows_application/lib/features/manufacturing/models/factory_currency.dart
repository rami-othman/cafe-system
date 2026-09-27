import 'package:equatable/equatable.dart';

class FactoryCurrencySelection extends Equatable {
  const FactoryCurrencySelection({this.currency = 'SYP', this.rate = ''});
  final String currency;
  final String rate;
  double get multiplier => currency == 'USD' ? double.tryParse(rate) ?? 0 : 1;
  bool get valid =>
      currency == 'SYP' ||
      (multiplier > 0 &&
          multiplier <= 1000000000 &&
          RegExp(r'^\d+(\.\d{1,6})?$').hasMatch(rate));
  String fromBase(String value) => multiplier > 0
      ? ((double.tryParse(value) ?? 0) / multiplier).toStringAsFixed(
          currency == 'USD' ? 6 : 2,
        )
      : '0';
  String switchAmount(
    String value,
    FactoryCurrencySelection next, {
    int precision = 2,
  }) => currency == next.currency || multiplier <= 0 || next.multiplier <= 0
      ? value
      : ((double.tryParse(value) ?? 0) * multiplier / next.multiplier)
            .toStringAsFixed(precision);
  Map<String, dynamic> get payload => <String, dynamic>{
    'documentCurrency': currency,
    if (currency == 'USD') 'usdToSyp': rate,
  };
  factory FactoryCurrencySelection.fromSnapshot(Map<String, dynamic>? value) =>
      FactoryCurrencySelection(
        currency: value?['currency'] as String? ?? 'SYP',
        rate: '${value?['rate'] ?? ''}',
      );
  @override
  List<Object?> get props => <Object?>[currency, rate];
}

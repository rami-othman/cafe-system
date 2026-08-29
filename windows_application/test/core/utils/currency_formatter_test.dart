import 'package:flutter_test/flutter_test.dart';
import 'package:windows_application/core/utils/currency_formatter.dart';
import 'package:windows_application/features/pos/models/branch.dart';

void main() {
  group('CurrencyFormatter', () {
    test('formats decimal Syrian Pound amounts for each manager locale', () {
      expect(
        CurrencyFormatter.format(3.5, locale: 'en_US', currencyCode: 'SYP'),
        '3.5 SYP',
      );
      expect(
        CurrencyFormatter.format(3.5, locale: 'ar', currencyCode: 'SYP'),
        '3.5 ل.س',
      );
    });

    test('formats whole Syrian Pound amounts for English managers', () {
      expect(
        CurrencyFormatter.format(12000, locale: 'en_US', currencyCode: 'SYP'),
        '12,000 SYP',
      );
    });

    test(
      'formats whole Syrian Pound amounts with the Arabic display suffix',
      () {
        expect(
          CurrencyFormatter.format(12000, locale: 'ar', currencyCode: 'SYP'),
          '12,000 ل.س',
        );
      },
    );

    test('formats a positive modifier delta without an FX conversion', () {
      expect(
        '+${CurrencyFormatter.format(2000, locale: 'en_US')}',
        '+2,000 SYP',
      );
      expect('+${CurrencyFormatter.format(2000, locale: 'ar')}', '+2,000 ل.س');
    });

    test('keeps meaningful stored decimal precision without forcing .00', () {
      expect(CurrencyFormatter.format(6.75), '6.75 SYP');
      expect(CurrencyFormatter.format(6), '6 SYP');
    });
  });

  test('Downtown branch resolves its API currency code as SYP', () {
    final Branch downtown = Branch.fromJson(<String, dynamic>{
      'id': 1,
      'name': 'Downtown',
      'currency': 'SYP',
      'timezone': 'Asia/Damascus',
      'isActive': true,
    });

    expect(downtown.currency, 'SYP');
  });
}

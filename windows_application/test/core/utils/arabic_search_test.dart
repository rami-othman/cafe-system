import 'package:flutter_test/flutter_test.dart';
import 'package:windows_application/core/utils/arabic_search.dart';

void main() {
  bool found(String query, List<String> fields) =>
      ArabicSearch.score(query, fields) > 0;

  test('normalisation unifies letter variants, digits and marks', () {
    expect(
      ArabicSearch.normalize('الأجهزة الإلكترونية'),
      'الاجهزه الالكترونيه',
    );
    expect(ArabicSearch.normalize('مُحَمَّد ١٢٣'), 'محمد 123');
    expect(ArabicSearch.normalize('موردين › أرت'), 'موردين ارت');
  });

  test('the reported typo query finds the electronics account', () {
    const fields = <String>[
      '1141',
      'الاجهزة الكهربائية والالكترونية',
      'Electric and electronic devices',
      'الموجودات الثابتة',
    ];
    expect(found('الاجهزة الالكتزو', fields), isTrue);
    expect(found('اجهزه كهربائيه', fields), isTrue);
    expect(found('الكترونية اجهزة', fields), isTrue);
    expect(found('اجهز', fields), isTrue);
  });

  test('every word must match; unrelated rows are rejected', () {
    const fields = <String>['22321', 'محمصة ارت للبن المختص', '', 'موردين'];
    expect(found('محمصه ارت', fields), isTrue);
    expect(found('موردين ارت', fields), isTrue);
    expect(found('22321', fields), isTrue);
    expect(found('محمصة سويلانو', fields), isFalse);
    expect(found('مطبعة', fields), isFalse);
  });

  test('short words never fuzzy-match and codes match by prefix only', () {
    expect(found('لبن', <String>['9', 'لتر', '', '']), isFalse);
    expect(found('223', <String>['22321', 'x', '', '']), isTrue);
    expect(found('2233', <String>['22321', 'x', '', '']), isFalse);
  });

  test('index ranks exact matches above typo matches and honours filters', () {
    final rows = <List<String>>[
      <String>['2', 'محمسة سلان', '', ''],
      <String>['1', 'محمصة سلان', '', ''],
      <String>['3', 'مطبعة', '', ''],
    ];
    final index = ArabicSearchIndex<List<String>>(rows, (row) => row);
    expect(index.search('محمصة').map((r) => r[0]).toList(), <String>['1', '2']);
    expect(index.search('محمصة', where: (r) => r[0] != '1').length, 1);
    expect(index.search('').length, 3);
  });
}

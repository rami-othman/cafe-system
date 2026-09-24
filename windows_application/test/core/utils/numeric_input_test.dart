import 'package:flutter_test/flutter_test.dart';
import 'package:windows_application/core/utils/numeric_input.dart';

void main() {
  group('NumericInput.normalize', () {
    test('plain ascii decimal passes through', () {
      expect(NumericInput.normalize('0.4'), '0.4');
    });

    test('leading dot gets a leading zero', () {
      expect(NumericInput.normalize('.4'), '0.4');
    });

    test('comma as the only separator is treated as decimal', () {
      expect(NumericInput.normalize('0,4'), '0.4');
    });

    test('arabic decimal separator is normalized', () {
      expect(NumericInput.normalize('٠٫٤'), '0.4');
    });

    test('arabic digits with comma decimal separator', () {
      expect(NumericInput.normalize('٠,٤'), '0.4');
    });

    test('persian digits are normalized', () {
      expect(NumericInput.normalize('۱۸۵۰'), '1850');
    });

    test('a comma alongside a dot is treated as thousands noise, not decimal', () {
      expect(NumericInput.normalize('1,234.56'), '1234.56');
    });

    test('blank input has nothing to normalize', () {
      expect(NumericInput.normalize(''), isNull);
      expect(NumericInput.normalize('   '), isNull);
    });
  });

  group('NumericInput.parse', () {
    test('parses the repeating-decimal example inputs', () {
      expect(NumericInput.parse('1850'), 1850);
      expect(NumericInput.parse('350'), 350);
    });

    test('parses every documented client input form to the same value', () {
      for (final String input in <String>['0.4', '.4', '0,4', '٠٫٤', '٠,٤']) {
        expect(NumericInput.parse(input), 0.4, reason: 'input: $input');
      }
    });

    test('unparseable input returns null, not zero', () {
      expect(NumericInput.parse('abc'), isNull);
    });
  });
}

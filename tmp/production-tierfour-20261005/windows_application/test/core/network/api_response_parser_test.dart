import 'package:flutter_test/flutter_test.dart';
import 'package:windows_application/core/network/api_response_parser.dart';

void main() {
  group('ApiResponseParser.unwrapData', () {
    test('returns Laravel data wrapper contents', () {
      final result = ApiResponseParser.unwrapData(<String, Object?>{
        'data': <String, Object?>{'id': 42},
      });

      expect(result, <String, Object?>{'id': 42});
    });

    test('returns original body when data wrapper is absent', () {
      final body = <String, Object?>{'message': 'accepted'};

      expect(ApiResponseParser.unwrapData(body), same(body));
    });

    test('returns null body safely', () {
      expect(ApiResponseParser.unwrapData(null), isNull);
    });
  });
}

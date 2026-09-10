import 'package:flutter_test/flutter_test.dart';
import 'package:windows_application/features/reports/controllers/report_memory_cache.dart';

void main() {
  test('report cache is bounded and promotes recently used entries', () {
    final cache = ReportMemoryCache<String>(capacity: 2)
      ..put('first', '1')
      ..put('second', '2');

    expect(cache.read('first'), '1');
    cache.put('third', '3');

    expect(cache.read('first'), '1');
    expect(cache.read('second'), isNull);
    expect(cache.read('third'), '3');
  });
}

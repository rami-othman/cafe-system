import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('production customer management has no prototype-only paths', () {
    final Directory root = Directory('lib/features/customer_management');
    final List<File> files = root
        .listSync(recursive: true)
        .whereType<File>()
        .where((File file) => file.path.endsWith('.dart'))
        .toList();
    final String source = files
        .map((File file) => file.readAsStringSync())
        .join('\n');
    final String presentationSource = files
        .where(
          (File file) =>
              file.path.contains('views') || file.path.contains('widgets'),
        )
        .map((File file) => file.readAsStringSync())
        .join('\n');
    final String groupFormSource = File(
      'lib/features/customer_management/views/customer_group_form_screen.dart',
    ).readAsStringSync();

    expect(
      source,
      isNot(
        matches(
          RegExp(r'seed(ed)?|demo|simulat(ed|ion)?', caseSensitive: false),
        ),
      ),
    );
    expect(
      source,
      isNot(
        matches(
          RegExp(
            r'last\s+visit|recent\s+orders?|order\s+history|average\s+order|spending\s+total|group\s+description',
            caseSensitive: false,
          ),
        ),
      ),
    );
    expect(source, isNot(matches(RegExp(r'C-\d{3,}'))));
    expect(source, isNot(contains('customerIds: <int>[1')));
    expect(source, isNot(contains('X-Tenant-Id')));
    expect(source, isNot(matches(RegExp(r'customerIds:\s*<int>\s*\['))));
    expect(
      source,
      isNot(
        matches(
          RegExp(
            r'golden|fixture|design_refs?|prototype.*array',
            caseSensitive: false,
          ),
        ),
      ),
    );
    expect(
      presentationSource,
      isNot(matches(RegExp(r'''Text\(\s*['"][A-Za-z\u0600-\u06ff]'''))),
    );
    expect(
      source,
      isNot(
        matches(
          RegExp(
            r'CustomerPhoneNormalizer|normalize.*phone|phone.*normalize|format.*phone|phone.*format|generate.*customer.?number',
            caseSensitive: false,
          ),
        ),
      ),
    );
    expect(
      groupFormSource,
      isNot(
        matches(
          RegExp(r'DropdownButton|Switch|Checkbox', caseSensitive: false),
        ),
      ),
    );
  });
}

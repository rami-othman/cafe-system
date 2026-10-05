import 'package:flutter_test/flutter_test.dart';
import 'package:windows_application/features/customer_management/models/customer_group_models.dart';
import 'package:windows_application/features/customer_management/models/customer_models.dart';

void main() {
  test('parses the authoritative customer profile and retained group', () {
    final Customer customer = Customer.fromJson(<String, dynamic>{
      'id': 41,
      'customerNumber': 'C-000041',
      'name': 'Rami',
      'email': 'rami@example.test',
      'birthDate': '1990-02-03',
      'notes': null,
      'status': 'inactive',
      'phones': <Map<String, dynamic>>[
        <String, dynamic>{
          'id': 8,
          'rawNumber': '+963 999',
          'type': 'mobile',
          'isPrimary': true,
        },
      ],
      'groups': <Map<String, dynamic>>[
        <String, dynamic>{'id': 4, 'name': 'Archived', 'status': 'archived'},
      ],
      'allowedActions': <String>['activate', 'archive'],
    });

    expect(customer.customerNumber, 'C-000041');
    expect(customer.lifecycle, CustomerLifecycle.inactive);
    expect(customer.phones.single.isPrimary, isTrue);
    expect(customer.groups.single.lifecycle, CustomerLifecycle.archived);
    expect(customer.allowedActions, contains('activate'));
    expect(customer.birthDate, DateTime.utc(1990, 2, 3));
  });

  test('rejects a missing required customer identity', () {
    expect(
      () => Customer.fromJson(<String, dynamic>{'name': 'Incomplete'}),
      throwsFormatException,
    );
  });

  test(
    'preserves nullable fields, all lifecycle values, and allowed actions',
    () {
      for (final String status in <String>['active', 'inactive', 'archived']) {
        final Customer customer = Customer.fromJson(<String, dynamic>{
          'id': 12,
          'customerNumber': 'C-000012',
          'name': 'No contact',
          'status': status,
          'email': null,
          'birthDate': null,
          'notes': null,
          'phones': const <dynamic>[],
          'groups': const <dynamic>[],
          'allowedActions': const <String>['archive'],
        });

        expect(customer.email, isNull);
        expect(customer.birthDate, isNull);
        expect(customer.notes, isNull);
        expect(customer.allowedActions, <String>{'archive'});
      }
    },
  );

  test('rejects invalid lifecycle and malformed page metadata', () {
    expect(
      () => Customer.fromJson(<String, dynamic>{
        'id': 1,
        'customerNumber': 'C-000001',
        'name': 'Bad state',
        'status': 'deleted',
        'phones': const <dynamic>[],
        'groups': const <dynamic>[],
        'allowedActions': const <dynamic>[],
      }),
      throwsFormatException,
    );
    expect(
      () => CustomerPage<Customer>.fromEnvelope(<String, dynamic>{
        'data': const <dynamic>[],
        'meta': <String, dynamic>{
          'currentPage': 0,
          'lastPage': 1,
          'perPage': 30,
          'total': 0,
        },
      }, Customer.fromJson),
      throwsFormatException,
    );
  });

  test(
    'rejects malformed allowed actions instead of silently dropping them',
    () {
      expect(
        () => Customer.fromJson(<String, dynamic>{
          'id': 1,
          'customerNumber': 'C-000001',
          'name': 'Bad actions',
          'status': 'active',
          'phones': const <dynamic>[],
          'groups': const <dynamic>[],
          'allowedActions': const <dynamic>['archive', 4],
        }),
        throwsFormatException,
      );
    },
  );

  test(
    'rejects malformed required profile collections instead of hiding them',
    () {
      final Map<String, dynamic> profile = <String, dynamic>{
        'id': 41,
        'customerNumber': 'C-000041',
        'name': 'Rami',
        'status': 'active',
        'phones': 'not-a-list',
        'groups': const <dynamic>[],
        'allowedActions': const <String>[],
      };

      expect(() => Customer.fromJson(profile), throwsFormatException);
    },
  );

  test(
    'parses group and pagination metadata without manufacturing identity',
    () {
      final CustomerGroup group = CustomerGroup.fromJson(<String, dynamic>{
        'id': 7,
        'name': 'VIP',
        'status': 'active',
        'memberCount': 3,
        'createdAt': '2026-09-10T12:00:00Z',
      });
      final CustomerPage<CustomerGroup> page =
          CustomerPage<CustomerGroup>.fromEnvelope(<String, dynamic>{
            'data': <Map<String, dynamic>>[
              <String, dynamic>{
                'id': 7,
                'name': 'VIP',
                'status': 'active',
                'memberCount': 3,
              },
            ],
            'meta': <String, dynamic>{
              'currentPage': 2,
              'lastPage': 4,
              'perPage': 25,
              'total': 77,
            },
          }, CustomerGroup.fromJson);

      expect(group.memberCount, 3);
      expect(page.meta.currentPage, 2);
      expect(page.items.single.name, 'VIP');
    },
  );
}

import 'package:flutter_test/flutter_test.dart';
import 'package:windows_application/features/customer_management/models/customer_drafts.dart';

void main() {
  test(
    'serializes raw phones and retained archived groups without derived fields',
    () {
      final CustomerDraft draft = CustomerDraft(
        name: '  Rami  ',
        email: 'rami@example.test',
        birthDate: DateTime.utc(1990, 2, 3),
        notes: 'Keep raw values.',
        phones: const <CustomerPhoneDraft>[
          CustomerPhoneDraft(
            rowId: 'phone-a',
            rawNumber: '+963 (999) 1',
            type: 'mobile',
            isPrimary: true,
          ),
          CustomerPhoneDraft(
            rowId: 'phone-b',
            rawNumber: '00963 999 2',
            type: 'home',
            isPrimary: false,
          ),
        ],
        groupIds: <int>{3, 9},
      );

      expect(draft.isReadyToSubmit, isTrue);
      expect(draft.toJson(), <String, dynamic>{
        'name': 'Rami',
        'email': 'rami@example.test',
        'birthDate': '1990-02-03',
        'notes': 'Keep raw values.',
        'phones': <Map<String, dynamic>>[
          <String, dynamic>{
            'rawNumber': '+963 (999) 1',
            'type': 'mobile',
            'isPrimary': true,
          },
          <String, dynamic>{
            'rawNumber': '00963 999 2',
            'type': 'home',
            'isPrimary': false,
          },
        ],
        'groupIds': <int>[3, 9],
      });
    },
  );

  test('requires an explicit primary only when phones exist', () {
    const CustomerDraft noPhone = CustomerDraft(name: 'No Phone');
    const CustomerDraft noPrimary = CustomerDraft(
      name: 'Missing Primary',
      phones: <CustomerPhoneDraft>[
        CustomerPhoneDraft(
          rowId: 'phone-a',
          rawNumber: '123',
          type: 'mobile',
          isPrimary: false,
        ),
      ],
    );

    expect(noPhone.isReadyToSubmit, isTrue);
    expect(noPrimary.isReadyToSubmit, isFalse);
    expect(noPhone.toJson()['phones'], isEmpty);
  });

  test('rejects multiple primary phones and preserves stable row identity', () {
    const CustomerDraft draft = CustomerDraft(
      name: 'Two phones',
      phones: <CustomerPhoneDraft>[
        CustomerPhoneDraft(
          rowId: 'stable-a',
          rawNumber: '+963 1',
          type: 'mobile',
          isPrimary: true,
        ),
        CustomerPhoneDraft(
          rowId: 'stable-b',
          rawNumber: '+963 2',
          type: 'home',
          isPrimary: true,
        ),
      ],
    );

    expect(draft.isReadyToSubmit, isFalse);
    expect(
      draft.phones.map((CustomerPhoneDraft phone) => phone.rowId),
      <String>['stable-a', 'stable-b'],
    );
  });

  test(
    'can deliberately clear nullable draft values without changing phones',
    () {
      final CustomerDraft source = CustomerDraft(
        name: 'Customer',
        email: 'customer@example.test',
        birthDate: DateTime.utc(1990, 1, 2),
        notes: 'Note',
        phones: const <CustomerPhoneDraft>[
          CustomerPhoneDraft(
            rowId: 'stable-a',
            rawNumber: '+963 1',
            type: 'mobile',
            isPrimary: true,
          ),
        ],
      );

      final CustomerDraft cleared = source.copyWith(
        clearEmail: true,
        clearBirthDate: true,
        clearNotes: true,
      );

      expect(cleared.email, isNull);
      expect(cleared.birthDate, isNull);
      expect(cleared.notes, isNull);
      expect(cleared.phones.single.rowId, 'stable-a');
    },
  );
}

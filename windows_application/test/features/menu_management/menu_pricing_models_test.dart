import 'package:flutter_test/flutter_test.dart';
import 'package:windows_application/features/menu_management/pricing/menu_pricing_access.dart';
import 'package:windows_application/features/menu_management/pricing/configured_price_validation.dart';
import 'package:windows_application/features/menu_management/pricing/models/menu_price_adjustment_models.dart';
import 'package:windows_application/features/menu_management/pricing/models/menu_pricing_models.dart';

void main() {
  test(
    'pricing exact decimals preserve signed and high precision wire values',
    () {
      expect(ExactDecimal.fromJson('-300.00').value, '-300.00');
      expect(
        ExactDecimal.fromJson('12546.000000000000000001').value,
        '12546.000000000000000001',
      );
    },
  );

  test('mixed manual drafts serialize set and reset without reset price', () {
    expect(
      const ManualPriceDraft.set(10, '13000.00').toJson(),
      <String, dynamic>{'variantId': 10, 'action': 'set', 'price': '13000.00'},
    );
    expect(const ManualPriceDraft.reset(11).toJson(), <String, dynamic>{
      'variantId': 11,
      'action': 'reset',
    });
  });

  test('server preview retains raw price and acknowledgement count', () {
    final adjustment = MenuPriceAdjustment.fromJson(<String, dynamic>{
      'id': 1,
      'status': 'previewed',
      'fingerprint': 'a' * 64,
      'context': <String, dynamic>{
        'menuId': 1,
        'branchId': 2,
        'channel': 'pos',
      },
      'operation': 'percentage_increase',
      'amount': '2',
      'roundingMode': 'round_down',
      'roundingStep': '1000.00',
      'summary': <String, dynamic>{'oppositeDirectionCount': 1},
      'items': <Map<String, dynamic>>[
        <String, dynamic>{
          'variantId': 10,
          'productName': 'Coffee',
          'variantName': 'Regular',
          'action': 'set',
          'originalEffectivePrice': '12300.00',
          'originalSource': 'base',
          'rawCalculatedPrice': '12546.000000000001',
          'finalNewPrice': '12000.00',
          'finalSource': 'menu',
          'difference': '-300.00',
          'finalMovement': 'decrease',
          'oppositeDirection': true,
          'configurationEffect': 'create_override',
        },
      ],
    });
    expect(adjustment.oppositeDirectionCount, 1);
    expect(
      adjustment.items.single.rawCalculatedPrice!.value,
      '12546.000000000001',
    );
    expect(adjustment.items.single.difference.value, '-300.00');
  });

  test('central access allows only owner and manager', () {
    expect(MenuPricingAccess.canManageRole('owner'), isTrue);
    expect(MenuPricingAccess.canManageRole('manager'), isTrue);
    expect(MenuPricingAccess.canManageRole('employee'), isFalse);
  });

  test(
    'exact input validation rejects every zero form and accepts Arabic numerals',
    () {
      for (final value in <String>['0', '0.0', '0.00', '00', '٠', '٠٫٠']) {
        expect(PricingDecimalInput.money(value), isNotNull, reason: value);
      }
      expect(PricingDecimalInput.normalize('١٢٫٥٠'), '12.50');
      expect(PricingDecimalInput.money('١٢٫٥٠'), isNull);
      expect(PricingDecimalInput.roundingStep('0.05'), isNull);
      expect(
        PricingDecimalInput.amount('100', percentageDecrease: true),
        isNotNull,
      );
    },
  );
}

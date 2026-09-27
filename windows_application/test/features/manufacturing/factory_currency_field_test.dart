import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:windows_application/core/network/dio_api_client.dart';
import 'package:windows_application/core/services/service_locator.dart';
import 'package:windows_application/features/manufacturing/controllers/factory_currency_cubit.dart';
import 'package:windows_application/features/manufacturing/models/factory_currency.dart';
import 'package:windows_application/features/manufacturing/repositories/factory_currency_repository.dart';
import 'package:windows_application/features/manufacturing/widgets/factory_currency_field.dart';

class _Repository extends FactoryCurrencyRepository {
  _Repository() : super(DioApiClient(dio: Dio()));
  FactoryCurrencySelection? saved;
  int? savedBranch;
  @override
  Future<FactoryCurrencySelection> load(int branchId) async =>
      saved ?? const FactoryCurrencySelection(rate: '10000');
  @override
  Future<void> save(int branchId, FactoryCurrencySelection selection) async {
    savedBranch = branchId;
    saved = selection;
  }
}

void main() {
  testWidgets('editing a SYP document uses the saved dollar rate while a USD document keeps its own rate', (tester) async {
    final repository = _Repository()..saved = const FactoryCurrencySelection(currency: 'USD', rate: '12000');
    if (serviceLocator.isRegistered<FactoryCurrencyCubit>()) {
      serviceLocator.unregister<FactoryCurrencyCubit>();
    }
    serviceLocator.registerFactory<FactoryCurrencyCubit>(() => FactoryCurrencyCubit(repository));
    addTearDown(() => serviceLocator.unregister<FactoryCurrencyCubit>());
    await tester.pumpWidget(MaterialApp(home: Scaffold(body: FactoryCurrencyField(
      key: const ValueKey('syp-document'), branchId: 5, initial: const FactoryCurrencySelection(rate: '1'), onChanged: (_) {},
    ))));
    await tester.pumpAndSettle();
    expect(tester.widget<TextFormField>(find.byType(TextFormField)).initialValue, '12000');
    expect(find.text('ليرة سورية SYP'), findsOneWidget);
    await tester.pumpWidget(MaterialApp(home: Scaffold(body: FactoryCurrencyField(
      key: const ValueKey('usd-document'), branchId: 5, initial: const FactoryCurrencySelection(currency: 'USD', rate: '10000'), onChanged: (_) {},
    ))));
    await tester.pumpAndSettle();
    expect(tester.widget<TextFormField>(find.byType(TextFormField)).initialValue, '10000');
    expect(find.text('دولار أمريكي USD'), findsOneWidget);
  });
  testWidgets(
    'factory rate saves once and a historic document retains its original USD amount',
    (tester) async {
      final repository = _Repository();
      if (serviceLocator.isRegistered<FactoryCurrencyCubit>()) {
        serviceLocator.unregister<FactoryCurrencyCubit>();
      }
      serviceLocator.registerFactory<FactoryCurrencyCubit>(
        () => FactoryCurrencyCubit(repository),
      );
      addTearDown(() => serviceLocator.unregister<FactoryCurrencyCubit>());
      FactoryCurrencySelection? chosen;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: FactoryCurrencyField(
              branchId: 5,
              amount: 25,
              onChanged: (value) => chosen = value,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byType(DropdownButtonFormField<String>));
      await tester.pumpAndSettle();
      await tester.tap(find.text('دولار أمريكي USD').last);
      await tester.pumpAndSettle();
      expect(chosen?.currency, 'USD');
      expect(find.text('25.00 USD = 250000.00 SYP'), findsOneWidget);
      await tester.enterText(find.byType(TextFormField), '12000');
      await tester.tap(find.text('حفظ العملة وسعر الصرف كإعدادات المعمل'));
      await tester.pumpAndSettle();
      expect(repository.savedBranch, 5);
      expect(repository.saved?.rate, '12000');
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: FactoryCurrencyDocument(
              snapshot: <String, dynamic>{
                'currency': 'USD',
                'rate': '10000',
                'input': <String, dynamic>{'amount': '25.00'},
              },
              baseAmount: '250000.00',
            ),
          ),
        ),
      );
      expect(find.text('مبلغ المستند: 25.00 USD'), findsOneWidget);
      expect(find.text('سعر الصرف المحفوظ: 1 USD = 10000 SYP'), findsOneWidget);
    },
  );
}

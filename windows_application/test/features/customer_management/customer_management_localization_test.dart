import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:windows_application/features/customer_management/controllers/customer_detail_cubit.dart';
import 'package:windows_application/features/customer_management/models/customer_models.dart';
import 'package:windows_application/features/customer_management/repositories/customer_management_repository.dart';
import 'package:windows_application/features/customer_management/views/customer_detail_screen.dart';
import 'package:windows_application/l10n/app_localizations.dart';

void main() {
  testWidgets('renders Arabic labels and isolates mixed-direction values', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('ar'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: BlocProvider<CustomerDetailCubit>(
            create: (_) => CustomerDetailCubit(_Repository()),
            child: const CustomerDetailScreen(customerId: 7),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('أرقام الهواتف'), findsOneWidget);
    expect(find.text('محمول'), findsOneWidget);
    expect(find.text('mobile'), findsNothing);
    expect(find.byType(Directionality), findsWidgets);
    expect(find.text('C-000007'), findsWidgets);
    expect(find.text('+963 9 123'), findsWidgets);
  });
}

class _Repository implements CustomerManagementRepository {
  @override
  Future<Customer> getCustomer(int customerId) async => const Customer(
    id: 7,
    customerNumber: 'C-000007',
    name: 'ليلى الطويلة جداً',
    lifecycle: CustomerLifecycle.active,
    phones: <CustomerPhone>[
      CustomerPhone(
        id: 1,
        rawNumber: '+963 9 123',
        type: 'mobile',
        isPrimary: true,
      ),
    ],
    groups: <CustomerGroupSummary>[],
    allowedActions: <String>{},
  );

  @override
  noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
